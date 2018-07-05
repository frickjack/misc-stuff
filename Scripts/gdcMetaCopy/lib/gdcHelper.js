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

module.exports = {
  fetchGdcRecord,
  fetchGdcRecordCacheOnly,
  buildIndexdRecord,
  fetchGdcIndex,
  postToIndexd
};
