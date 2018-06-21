const fetch = require('node-fetch');
const mkdirp = require('mkdirp');

const gdcUrlBase = 'https://api.gdc.cancer.gov';
const outputFolder = './data-out';
const inputFolder = './data-in';

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
    "file_name": "",
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
        && record.did && record.file_name && record.hashes.md5 
        && record.size > 0 && record.urls.length > 0) ) 
  {
    let msg = console.log('Invalid record: ' + JSON.stringify(record));
    console.log(msg);
    throw new Error(msg);
  }
  return record;
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
  return fetch(urlStr
    ).then( 
      (res) => {
        if( res.status !== 200 ) { 
          return Promise.reject( 'failed fetch, got ' + res.status + ' on ' + urlStr);
        }
        return res.json();
      }
  ).then(
    function(info) {
      console.log('fetchCurrentRecord got: ' + JSON.stringify(info));
      return info;
      const record = {
        acl: info.data.acl.map( name => name == "open" ? "*" : name ),
        did: uuidStr,
        size: info.data.file_size,
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
 * Little helper to build a post filter for gdc-api/legacy/files
 * @param {string} uuidStr 
 * @return {object} filter
 */
function buildLegacyFilter(uuidStr) {
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
  return fetch(urlStr
    ).then( 
      (res) => {
        if( res.status !== 200 ) { 
          return Promise.reject( 'failed fetch, got ' + res.status + ' on ' + urlStr);
        }
        return res.json();
      }
    ).then(
      function(info) {
        console.log("fetchLegacyRecord got: " + JSON.stringify(info));
        const record = {
          acl: info.data.acl.map( name => name == "open" ? "*" : name ),
          did: uuidStr,
          size: info.data.file_size,
          file_name: info.data.file_name,
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
 * @return Promise<IndexdMeta> indexd metadata record constructed
 *      by overlaying meta from the server onto metaSuper 
 */
async function fetchLegacyIndexRecord(uuidStr, metaSuper) {
  const urlStr = gdcUrlBase + '/legacy/files/'; // + uuidStr;
  const filterStr = JSON.stringify(buildLegacyFilter(uuidStr));
  
  return fetch(urlStr,
      {
        method: 'POST',
        body: filterStr,
        headers: {
          'content-type': 'application/json'
        }
      }
    ).then( 
      (res) => {
        if( res.status !== 200 ) {
          return Promise.reject( 'failed fetch, got ' + res.status + ' on ' + urlStr);
        }
        return res.json();
      } 
    ).then(
      function(info) {
        console.log('fetchLegacyIndexRecord got: ' + JSON.stringify(info));
        if ( (!info.data) || (!info.data.hits) || info.data.hits.length !== 1 || info.data.hits[0].index_files.length !== 1 ) {
          return Promise.reject('fetchLegacyIndexRecord did not have exactly 1 hit, had: ' + info.data.hits.length);
        }
        //return info;
        const record = {
          acl: info.data.hits[0].acl.map( name => name == "open" ? "*" : name ),
          did: uuidStr,
          size: info.data.hits[0].index_files[0].file_size,
          file_name: info.data.hits[0].index_files[0].file_name,
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
 * Log the given record to the default output folder
 */
async function saveRecord(record) {
  const uuidStr = record.did;
  const jsonStr = JSON.stringify(record);
  const savePath = outputFolder + '/' + uuidStr + '.json';
  console.log(`Saving record: ${jsonStr} to ${savePath}\n`);
  return record;
}

/**
 * Log the given record to the default error folder
 * @param {} record 
 * @param {*} uuidStr 
 */
async function saveError(record) {
  const uuidStr = record.did;
  const jsonStr = JSON.stringify(record);
  const savePath = outputFolder + '/errors/' + uuidStr + '.json';
  console.log(`ERROR: Saving record: ${jsonStr} to ${savePath}\n`);
  return record;
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
          return fetchLegacyIndexRecord(uuidStr, metaSuper).catch(
            function(err3) {
              return Promise.reject([err1, err2, err3].map(err => typeof err === "string" ? err : "" + err));
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
 * @reutrn {Promise} that always succeeds 
 */
async function fetchAndProcessRecord(uuidStr, metaSuper) {
  return fetchGdcRecord(uuidStr, metaSuper).then(
    function(info) {
      return saveRecord(info);
    }
  ).catch(
    function(err) { // ugh - log error
      return saveError({ did: uuidStr, error: err });
    }
  );  
}

async function main() {
  await a_mkdirp(outputFolder + '/errors');
  const recordList = [
    //'fdde0200-8912-4c8d-87b3-1bb3248acbed', // https://api.gdc.cancer.gov/legacy/files/fdde0200-8912-4c8d-87b3-1bb3248acbed
    '51d416e5-bae8-4a1e-a849-f99131febe10',   // POST /legacy/files/
    //'ffa1d254-3cb6-4ee1-a1a5-52482637a43d',  // GET /legacy/files/id
    //'01de7763-a374-43e3-9965-6c577394c306',  // GET /files/id
  ];
  
  // Process records asynchronously in chunks of 10
  const chunkSize = 10;
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
      let result = lastChunk.then(
        // wait for the last chunk to finish before processing this chunk
        async function() {
          const promiseList = chunk.map(
              function(recordId) {
                return fetchAndProcessRecord(recordId, {urls: [ 'frickjack/bla' ]});
              }
            );
          return Promise.all(promiseList);
        }
      );
      return result;
    }, Promise.resolve('ok')
  );
}

main();
