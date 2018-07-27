const https = require('https');
const fetch = require('node-fetch');
const utils = require('./utils');

const gdcUrlBase = 'https://api.gdc.cancer.gov';
const logLevel = utils.logLevel;
const agent = new https.Agent({
  keepAlive: true,
  keepAliveMsecs: 15000,
  maxSockets: 30
});



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
  async function doRetry(reason) {
    return new Promise(function(resolve, reject){
      // sleep and try again ...
      const retryIndex = retryCount < retryBackoff.length - 1 ? retryCount : retryBackoff.length - 1;
      const sleepMs = retryBackoff[retryIndex] + Math.floor(Math.random()*2000);
      if (retryCount < retryBackoff.length) {
        retryCount += 1;
      }
      logLevel > 1 && console.log('failed fetch ' + reason + ', sleeping ' + sleepMs + ' then retry ' + urlStr);
      setTimeout(function(){
        resolve('ok');
        logLevel > 5 && console.log(`Retrying ${urlStr} after sleep - ${retryCount}`);
      }, sleepMs);
    }).then(doRequest);
  }

  async function doRequest()  {
    if (retryCount > 0) {
      console.log(`Re-fetching ${urlStr} - retry no ${retryCount}`);
    }
    return fetch(urlStr, { agent, ...opts }
    ).then( 
      (res) => {
        if ( res.status == 429 && retryCount < retryBackoff.length ) { // throttling from server 
          return doRetry('throttling from server');        
        }
        if (retryCount > 0) {
          console.log(`No more retries for ${urlStr} - retry count ${retryCount}, status ${res.status}`);
        }
        if( res.status !== 200 ) { 
          return Promise.reject('failed fetch, got ' + res.status + ' on ' + urlStr);
        }
        return res.json();
      },
      (err) => {
        if (retryCount < retryBackoff.length) {
          return doRetry(err);
        }
        return Promise.reject(err);
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
 * @param {key:info} gdcCache of already loaded info to avoid network requests
 * @return Promise<IndexdMeta> indexd metadata record constructed
 *      by overlaying meta from the server onto metaSuper
 * @throws Promise.reject( [err1, err2, ...]) chain of errors before finally gave up 
 */
async function fetchGdcRecord(uuidStr, metaSuper={}, gdcCache={}) {
  if (gdcCache[uuidStr]) {
    let cacheEntry = gdcCache[uuidStr];
    let rec = buildIndexdRecord({ ...cacheEntry, ...metaSuper });
    return Promise.resolve(rec);
  }
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
 * Same as fetchGdcRecord, but does not make calls
 * for data that should be in the cache ...
 * 
 * @param {string} uuidStr 
 * @param {IndexdMeta} metaSuper optional supplemental metadata
 *      to merge into the result
 * @param {key:info} gdcCache of already loaded info to avoid network requests
 * @return Promise<IndexdMeta> indexd metadata record constructed
 *      by overlaying meta from the server onto metaSuper
 * @throws Promise.reject( [err1, err2, ...]) chain of errors before finally gave up 
 */
async function fetchGdcRecordCacheOnly(uuidStr, metaSuper={}, gdcCache={}) {
  if (gdcCache[uuidStr]) {
    let cacheEntry = gdcCache[uuidStr];
    let rec = buildIndexdRecord({ ...cacheEntry, ...metaSuper });
    return Promise.resolve(rec);
  }
  return fetchIndexRecord(uuidStr, metaSuper, false).catch(
    function(err3) {
      return fetchIndexRecord(uuidStr, metaSuper, true).catch(
        function(err4) {
          return Promise.reject([err3, err4].map(err => typeof err === "string" ? err : "" + err));
        }
      );
    }
  );
}

/**
 * Handle paginated fetch
 *      https://docs.gdc.cancer.gov/API/Users_Guide/Search_and_Retrieval/#size-and-from
 * 
 * @param {string} urlBase base URL takes a size and page query parameters
 * @param {int} startRecordIndex 
 * @param {int} pageSize
 * @param {Array} resultList accumulates results 
 */
async function fetchRemainingPages(urlBase, startRecordIndex, pageSize, resultList) {
  const url = urlBase + '?fields=md5sum,file_size,acl&from=' + startRecordIndex + '&size=' + pageSize;
  return fetchJsonRetry(url).then(
    function(raw) {
      const data = raw.data;
      //console.log('Got data', data);
      const page = data.hits.map(
        function(info) {
          return { did: info.id, size: info.file_size, hashes: { md5: info.md5sum }, acl: info.acl.map(name => name == "open" ? "*" : name) };
        }
      );
      resultList.push(...page);
      if (data.pagination && data.pagination.total > data.pagination.from + data.pagination.count) {
        return fetchRemainingPages(urlBase, startRecordIndex + data.pagination.count, pageSize, resultList);
      }
      return resultList;
    }
  );
}

/**
 * Download summary data for all the records in the GDC:
 *     { did, size, hashes: { md5 } }
 * @return Array<IndexdRecord> list of reccords fetched from GDC
 */
async function fetchGdcIndex() {
  return Promise.all( 
    [
      fetchRemainingPages(gdcUrlBase + '/files', 0, 5000, []),
      fetchRemainingPages(gdcUrlBase + '/legacy/files', 0, 5000, [])
    ]
  ).then(
    function(v) {
      return v[0].concat(v[1]);
    }
  );
}

async function postToIndexd(hostName, credsStr, data) {
  const urlBase = `https://${hostName}/index/`;
  // first - check if a record already exists to update
  return fetchJsonRetry(urlBase + data.did).then(
    function(oldRec){ // old record exists - update if necessary
      const urlIndex = oldRec.urls.reduce(
        function(acc,it) {
          acc[it] = true;
          return acc;
        }, {}
      );
      // if some new url is not already indexed, then update
      if (data.urls.find(it => !urlIndex[it])) {
        data.urls.reduce(
          function(acc,it) {
            acc[it] = true;
          }, urlIndex
        );
        const urlList = Object.keys(urlIndex);
        const updateRec = {
          acl: data.acl,
          urls: urlList
        };
        return fetchJsonRetry(urlBase + 'index/' + data.did + '?rev=' + oldRec.rev,
          {
            method: 'PUT',
            body: JSON.stringify(updateRec),
            headers: {
              'content-type': 'application/json',
              'Authorization': `Basic ${credsStr}`
            }
          } 
        );
      } else {
        return Promise.resolve(oldRec);
      }
    },
    function(){ // no existing record?
      return fetchJsonRetry(urlBase + 'index/',
        {
          method: 'POST',
          body: JSON.stringify(data),
          headers: {
            'content-type': 'application/json',
            'Authorization': `Basic ${credsStr}`
          }
        } 
      );
    }
  );
}

/**
 * Combine manifests to get a unified manifest to upload to DCF.
 * Also generate error report detailing which records are in AWS
 * and not in GDC and vice versa.
 * 
 * 
reuben@reuben-pasquini-cdis:~/Code/Littleware/misc-stuff/Scripts/gdcMetaCopy/data-in/gdcRelease11$ head -5 gdc_manifest_20180521_data_release_11.0_active.txt 
id	filename	md5	size	state
0003c9fa-6e97-4fc7-8405-be4be66bf914	0003c9fa-6e97-4fc7-8405-be4be66bf914.vcf.gz	5052597f8752fd2bed1f662ce38e1e70	1172	submitted
0005bd06-3199-4c0a-95ac-3c0707d542f1	0005bd06-3199-4c0a-95ac-3c0707d542f1.vcf.gz	dd4ec12b11a65e000a8d73ad085e3f89	1309	submitted
0006ea6b-dbb7-4191-852b-f082eefbf242	0006ea6b-dbb7-4191-852b-f082eefbf242.vcf.gz	664e801efc7d03e87f8fe78d2a4380e3	964	submitted
00073f13-2ce4-4d50-82b1-51e1017e5f34	00073f13-2ce4-4d50-82b1-51e1017e5f34.vep.vcf.gz	fe046af5564aefb7d029d11a165f05fd	6767	submitted

reuben@reuben-pasquini-cdis:~/Code/Littleware/misc-stuff/Scripts/gdcMetaCopy/data-in/gdcRelease11$ head -5 gdc_manifest_20180521_data_release_11.0_legacy.txt 
id	filename	md5	size	state
1474b8a8-284f-4416-8c66-618340458bb2	G28902.Hs_172.T.3.bam	fb57d20026ac6eaeed6d23f88fa99a9d	9494814273	live
1d322a14-026a-4d35-8de6-1666c8633416	C836.253J-BV.4.bam	68ad31e9436095ab2bc5883a63b344a3	23112568925	live
1dc5aa91-51d0-4108-930b-2776135ed6aa	G28831.J82.3.bam	59d04d484e01e08ea8369673611a04cc	13157781195	live
20ca17de-de36-492a-84d2-0ab0b8605a27	G28059.KMBC-2.1.bam	5ec3a99090452ebbf6c68b9f3e5b9c8f	11029085304	live

reuben@reuben-pasquini-cdis:~/Code/Littleware/misc-stuff/Scripts/gdcMetaCopy/data-in/gdcRelease11$ head -5 ../dcfAwsIndex20180727/ccle-open-access.manifest.tsv 
2018-05-11 12:47:44    5583408 0045c267-ff51-49df-855f-0af0b4f3d151/G41700.ABC-1.5.bam.bai
2018-05-11 12:18:43    5506624 004dd13d-35a3-40a6-8737-97bf2cb8ec52/G26243.HT-1197.2.bam.bai
2018-05-11 11:48:12 9218168832 005a752e-cf77-446a-b708-5a28d3a03170/C836.FTC-238.1.bam
2018-05-11 11:47:58 10810827476 005f9aa9-cb69-4734-9b4f-d93bee8028dc/C836.CADO-ES1.1.bam
2018-05-11 12:58:19    5727712 006aa252-3e06-4527-84a5-95e100fecd8f/C836.HEC-59.2.bam.bai

 * 
 * @param {*} bucketManifestFile 
 * @param {*} gdcManifestFileList 
 * @param {*} aclList 
 */
async function generateCloudManifest(bucketManifestFile, gdcManifestFileList, aclList) {
  const bucketLineList = await (
    utils.readFile(bucketManifestFile).then(
      function(dataStr) { 
        return dataStr.split(/[\r\n]+/);
      }
    )
  );
  const gdcColumns = []
  const gdcDb = await (
    Promise.all(
      gdcManifestFileList.map(
        fileName => utils.readFile(fileName)
      )
    ).then( 
      function (fileContentList) {
        return fileContentList.map(
          // split each file into lines
          content => content.split(/[\r\n]+/)
        ).reduce(
          // combine the 2 files' line lists into a single list
          function(lineList, acc) {
            acc.concat(lineList)
          }, []
        ).map(
          // tokenize each line, and convert to an indexd record or null
          function(gdcLine) {
            const tokenList = gdcLine.split(/\t+/);
            if (tokenList.length == 5 && tokenList[0].match(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)) {
              // looks like a valid line
              return {
                did: tokenList[0],
                hashes: {
                  md5: tokenList[2]
                },
                size: +tokenList[4],
                fileName: tokenList[1],
                acl: aclList
              };
            }
            return null;
          }
        ).reduce(
          // 
        )
      }
    )
  );
}

module.exports = {
  fetchGdcRecord,
  fetchGdcRecordCacheOnly,
  generateCloudManifest,
  buildIndexdRecord,
  fetchGdcIndex,
  postToIndexd
};
