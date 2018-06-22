const fetch = require('node-fetch');
const mkdirp = require('mkdirp');
const fs = require('fs');

const logLevel = 3;
const gdcUrlBase = 'https://api.gdc.cancer.gov';
const defaultInputFolder = './data-in';
const defaultOutputFolder = './data-out';


function a_mkdirp(pathStr) {
  return new Promise( function(resolve, reject) {
    mkdirp(pathStr, function(err) {
      if(err) { 
        reject(err);
      } else {
        resolve(pathStr);
      }
    })
  });
}

/**
 * Build index record
 * @param {object} meta object to validate with { acl, did, file_name, hashes.md5, size, urls }
 */
function buildIndexdRecord(meta) {
  const record = {
    "acl": [
    ],
    "did": "",
    //"file_name": "",
    "form": "object",
    "hashes": {
      //"md5": "c1898b7f2865ef7d7847b40e58f7c49c"
    },
    "metadata": {},
    "size": 0,
    "urls": [
      //"s3://tcga-protected-dcf-databucket-gen3/testdata"
    ],
    "urls_metadata": {
      //"s3://tcga-protected-dcf-databucket-gen3/testdata": {
      //"acls": "test"
      //}
    },
    ... meta
  };

  if( ! (record.acl.length > 0 
        && record.did //&& record.file_name 
        && record.hashes.md5 
        && record.size > 0 && record.urls.length > 0) ) 
  {
    let msg = console.log('Invalid record: ' + JSON.stringify(record, null, 4));
    logLevel > 0 && console.log(msg);
    throw new Error(msg);
  }
  return record;
}

/**
 * Little helper to build a post filter for gdc-api/legacy/files
 * @param {string} uuidStr 
 * @return {object} filter
 */
function buildQueryFilter(uuidStr) {
  return {
    filters: {
      content: {
        field: 'index_files.file_id',
        value: uuidStr
      },
      op: '='
    },
    fields: 'index_files.file_id,acl,index_files.md5sum,index_files.file_size,index_files.file_name'
  };
}

const retryBackoff = [ 2000, 4000, 8000, 16000 ];

/**
 * Wrapper around fetch - retries call on 429 status
 * up to 4 times with exponential backoff
 * 
 * @param {string} urlStr 
 * @param {*} opts 
 */
async function fetchJsonRetry(urlStr, opts) {
  var retryCount = 0;
  
  async function doRequest()  {
    return fetch(urlStr, opts
    ).then( 
      (res) => {
        if ( res.status == 429 && retryCount < retryBackoff.length ) { // throttling from server 
          return new Promise(function(resolve, reject){
            // sleep and try again ...
            const sleepMs = retryBackoff[retryCount] + Math.floor(Math.random()*2000);
            retryCount += 1;
            logLevel > 1 && console.log('throttling from server, sleeping ' + sleepMs);
            setTimeout(function(){
              resolve('ok');
              logLevel > 5 && console.log('Retrying urlStr');
            }, sleepMs);
          }).then(doRequest);
        }
        if( res.status !== 200 ) { 
          return Promise.reject('failed fetch, got ' + res.status + ' on ' + urlStr);
        }
        return res.json();
      }
    );
  }

  return doRequest();
}

/**
 * Try to find the record in the "current" GDC file info index
 * @param {string} uuidStr
 * @param {IndexdMeta} metaSuper optional supplemental metadata
 *      to merge into the result
 * @return Promise<IndexdMeta> indexd metadata record constructed
 *      by overlaying meta from the server onto metaSuper 
 */
function fetchCurrentRecord(uuidStr, metaSuper) {
  const urlStr = gdcUrlBase + '/files/' + uuidStr;
  
  return fetchJsonRetry(urlStr
  ).then(
    function(info) {
      logLevel > 5 && console.log('fetchCurrentRecord got: ' + JSON.stringify(info, null, 4));
      const record = {
        acl: info.data.acl.map( name => name == "open" ? "*" : name ),
        did: uuidStr,
        size: info.data.file_size,
        //file_name: info.data.file_name,
        hashes: {
          md5: info.data.md5sum
        },
        ... metaSuper
      };
      return buildIndexdRecord(record);
    }    
  );
}


/**
 * Try to find the record in the legacy GDC file info index
 * @param {string} uuidStr 
 * @param {string} uuidStr
 * @param {IndexdMeta} metaSuper optional supplemental metadata
 *      to merge into the result
 * @return Promise<IndexdMeta> indexd metadata record constructed
 *      by overlaying meta from the server onto metaSuper 
 */
async function fetchLegacyRecord(uuidStr, metaSuper) {
  const urlStr = gdcUrlBase + '/legacy/files/' + uuidStr;
  return fetchJsonRetry(urlStr
    ).then(
      function(info) {
        logLevel > 5 && console.log("fetchLegacyRecord got: " + JSON.stringify(info, null, 4));
        const record = {
          acl: info.data.acl.map( name => name == "open" ? "*" : name ),
          did: uuidStr,
          size: info.data.file_size,
          //file_name: info.data.file_name,
          hashes: {
            md5: info.data.md5sum
          },
          ... metaSuper
        };
        return buildIndexdRecord(record);
      }    
    );
}

/**
 * BAM indexes (bai) require a custom query - ugh
 * @param {string} uuidStr
 * @param {string} uuidStr
 * @param {IndexdMeta} metaSuper optional supplemental metadata
 *      to merge into the result
 * @param {boolean} legacyApi whether to use legacyApi or currentApi endpoints
 * @return Promise<IndexdMeta> indexd metadata record constructed
 *      by overlaying meta from the server onto metaSuper 
 */
async function fetchIndexRecord(uuidStr, metaSuper, legacyApi=false) {
  const urlStr = gdcUrlBase + (legacyApi ? '/legacy' : '') + '/files/'; // + uuidStr;

  
  const filterStr = JSON.stringify(buildQueryFilter(uuidStr), null, 4);
  
  return fetchJsonRetry(urlStr,
      {
        method: 'POST',
        body: filterStr,
        headers: {
          'content-type': 'application/json'
        }
      } 
    ).then(
      function(info) {
        logLevel > 5 && console.log('fetchIndexRecord(legacy=' + (!!legacyApi) + ') got: ' + JSON.stringify(info, null, 4));
        if ( (!info.data) || (!info.data.hits) || info.data.hits.length !== 1 || info.data.hits[0].index_files.length !== 1 ) {
          return Promise.reject('fetchIndexRecord(legacy=' + (!!legacyApi) + ') did not have exactly 1 hit, had: ' + info.data.hits.length);
        }
        //return info;
        const record = {
          acl: info.data.hits[0].acl.map( name => name == "open" ? "*" : name ),
          did: uuidStr,
          size: info.data.hits[0].index_files[0].file_size,
          //file_name: info.data.hits[0].index_files[0].file_name,
          hashes: {
            md5: info.data.hits[0].index_files[0].md5sum
          },
          ... metaSuper
        };
        return buildIndexdRecord(record);
      }    
    );
}


/**
 * Fetch the GDC metadata for the object with the given uuid -
 * try the current, legacy, and legacy-index endpoints,
 * and return a synthentic IndexD record based on the collected data
 * if any.
 * 
 * @param {string} uuidStr 
 * @param {IndexdMeta} metaSuper optional supplemental metadata
 *      to merge into the result
 * @return Promise<IndexdMeta> indexd metadata record constructed
 *      by overlaying meta from the server onto metaSuper
 * @throws Promise.reject( [err1, err2, ...]) chain of errors before finally gave up 
 */
async function fetchGdcRecord(uuidStr, metaSuper={}) {
  return fetchCurrentRecord(uuidStr, metaSuper).catch(
    function(err1) { // try again
      return fetchLegacyRecord(uuidStr, metaSuper).catch(
        function(err2) { // last try
          //console.log('fetchLegacyRecord failed', err);
          return fetchIndexRecord(uuidStr, metaSuper, false).catch(
            function(err3) {
              return fetchIndexRecord(uuidStr, metaSuper, true).catch(
                function(err4) {
                  return Promise.reject([err1, err2, err3, err4].map(err => typeof err === "string" ? err : "" + err));
                }
              );
            }
          )
        }
      );
    }
  );
}

/**
 * Fetch the specified record, and save it on success,
 * or log error on failure.
 * 
 * @param {string} uuidStr
 * @param {IndexdMeta} metaSuper optional supplemental metadata
 *      to merge into the result
 * @param {string} outputFolder
 * @reutrn {Promise} that always succeeds 
 */
async function fetchAndProcessRecord(uuidStr, metaSuper, outputFolder) {
  return fetchGdcRecord(uuidStr, metaSuper).then(
    function(info) {
      return saveRecord(info, outputFolder);
    }
  ).catch(
    function(err) { // ugh - log error
      return saveError({ did: uuidStr, error: err, ...metaSuper }, outputFolder);
    }
  );  
}

/**
 * Log the given record to the default output folder
 */
async function saveRecord(record, outputFolder=defaultOutputFolder) {
  if (!record.did) { throw new Error('Invalid record', record); }
  const uuidStr = record.did;
  const jsonStr = JSON.stringify(record, null, 4);
  const savePath = outputFolder + '/' + uuidStr + '.json';
  logLevel > 1 && console.log(`Saving record: ${jsonStr} to ${savePath}\n`);
  await writeFile(savePath, jsonStr);
  return record;
}

/**
 * Log the given record to the default error folder
 * @param {} record 
 * @param {*} uuidStr 
 */
async function saveError(record, outputFolder=defaultOutputFolder) {
  const uuidStr = record.did;
  const jsonStr = JSON.stringify(record, null, 4);
  const savePath = outputFolder + '/errors/' + uuidStr + '.json';
  logLevel > 0 && console.log(`ERROR: Saving record: ${jsonStr} to ${savePath}\n`);
  await writeFile(savePath, jsonStr);
  return record;
}

/**
 * Promisfy fs.writeFile ...
 * #
 * @param {string} pathStr 
 * @param {string} dataStr 
 */
async function writeFile(pathStr, dataStr) {
  return new Promise(function(resolve, reject) {
    fs.writeFile(pathStr, dataStr, 'utf8', 
      function(err) {
        if (err) {
          logLevel > 0 && console.log('Failed to save ' + pathStr, err);
          reject(err); 
          return; 
        }
        resolve('ok');
      }
    );
  });
}


/**
 * Process each record in recordList via async function thunk
 * running chunkSize processes in parllel
 * 
 * @param {Array} recordList 
 * @param {int} chunkSize 
 * @param {async function} thunk 
 */
async function chunkForEach(recordList, chunkSize, thunk) {
  const chunkList = recordList.reduce(
    function(acc, record) {
      if (acc.length < 1 || acc[acc.length -1 ].length >= chunkSize) {
        acc.push([]);  // push a new chunk
      }
      const chunk = acc[acc.length - 1];
      chunk.push(record);
      return acc;
    }, []
  );
  
  return chunkList.reduce(
    function(lastChunk, chunk) {
      return lastChunk.then(
        // wait for the last chunk to finish before processing this chunk
        async function() {
          const promiseList = chunk.map(thunk);
          return Promise.all(promiseList);
        }
      );
    }, Promise.resolve('ok')
  );
}

async function test() {
  const outputFolder = './data-out/test';
  await a_mkdirp(outputFolder + '/errors');
  const recordList = [
    'fdde0200-8912-4c8d-87b3-1bb3248acbed',  // https://api.gdc.cancer.gov/legacy/files/fdde0200-8912-4c8d-87b3-1bb3248acbed
    '51d416e5-bae8-4a1e-a849-f99131febe10',  // POST /legacy/files/
    'ffa1d254-3cb6-4ee1-a1a5-52482637a43d',  // GET /legacy/files/id
    '01de7763-a374-43e3-9965-6c577394c306',  // GET /files/id
    '01263a92-ccf8-4d12-a2e3-0fa4ed3de5ba',  // POST /files/
    '01de7763-a374-43e3-9965-6c577394cXXX',  // bogus id
  ];

  return chunkForEach(recordList, 10, 
    function(recordId) {
      return fetchAndProcessRecord(recordId, {urls: [ 'frickjack/bla' ]}, outputFolder);
    }
  );
}

/**
 * Process a TSV of form: id\t object-path
 * @param {string} inputPath 
 */
async function processTsvId2Path(inputPath, outputFolder) {
  await a_mkdirp(outputFolder + '/errors');
  
  return new Promise(
    function(resolve, reject) {
      fs.readFile(inputPath, 'utf8', function(err, data) {
        if (err) {
          reject(err);
          return;
        }
        resolve(data);
      });
    }
  ).then(
    function(data) {
      //console.log('Got data: ' + data );
      const recordList = data.split(/[\r\n]+/).map(
        function(line) {
          const columns = line.split(/\s+/);
          if( columns.length == 2 ) {
            return { did: columns[0], urls: [ columns[1] ] };
          } else {
            console.log('WARNING: ignoring badly formatted file line: ' + line);
            return null;
          }
        }
      ).filter(rec => !!rec);
      return chunkForEach(recordList, 10, 
                async function(rec){ return fetchAndProcessRecord(rec.did, rec, outputFolder); }
              );
    }
  ).catch( 
    function(err) {
      console.log('Error!', err);
      return Promise.reject(err);
    }
  );
}

async function processDcfCsvManifest(inputPath, outputFolder) {
  await a_mkdirp(outputFolder + '/errors');
  
  return new Promise(
    function(resolve, reject) {
      fs.readFile(inputPath, 'utf8', function(err, data) {
        if (err) {
          reject(err);
          return;
        }
        resolve(data);
      });
    }
  ).then(
    function(data) {
      //console.log('Got data: ' + data );
      const recordList = data.split(/[\r\n]+/).splice(1).map(
        function(line) {
          // HACK! for one screwy record with a ',' in the object path - ugh
          const columns = line.replace('G-292,_clone', 'G-292;_clone').split(/[,"\s]+/).map(s => s.replace('G-292;_clone', 'G-292,_clone'));
          if( columns.length == 6 ) {
            return { 
              did: columns[0], 
              urls: [ columns[1] ],
              size: +columns[2],
              hashes: {
                md5: columns[4]
              },
              acl: columns[5].split(/[;\s]+/).filter(s => !!s).map(id => id === 'public' ? '*' : id)
            };
          } else {
            console.log('WARNING: ignoring badly formatted file line: ' + line);
            return null;
          }
        }
      ).filter(rec => !!rec);
      return chunkForEach(recordList, 10, 
                async function(rec){ return saveRecord(buildIndexdRecord(rec), outputFolder); }
              );
    }
  ).catch( 
    function(err) {
      console.log('Error!', err);
      return Promise.reject(err);
    }
  );
}

async function main() {
  await test();
  //await processTsvId2Path(defaultInputFolder + '/TCGA_staging_data.tsv', defaultOutputFolder + '/TCGA_staging_data');
  await processDcfCsvManifest(defaultInputFolder + '/manifest_for_DCF_20180613_update.csv', defaultOutputFolder + '/DCF_manifest_20180613');
}

main();