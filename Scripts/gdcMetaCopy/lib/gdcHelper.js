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

  // Fixup ACL if necessary
  record.acl = record.acl.map(v => v.toLowerCase()).map(v => v === 'public' ? '*' : v);
  if( ! (record.acl.length > 0 // must have an acl
        && !record.acl.find(v => !(v === '*' || v.startsWith('phs'))) // every acl is public or dbgap code
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

/**
 * Post the given record to indexd - possibly merging the urls
 * if an existing record already exists
 * 
 * @param {string} hostName 
 * @param {string} credsStr 
 * @param {IndexdRecord} data
 * @return {Promise<IndexdRecord>} returned record corresponds to what
 *     is saved in indexd on success 
 */
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
        // only index one url per protocol - prefer new urls
        const urlsByProtocol = oldRec.urls.concat(data.urls).reduce(
          function(acc,url) {
            const lc = url.toLowerCase();
            if (lc.startsWith('gs:')) {
              acc.gs = url;
            } else if (lc.startsWith('s3:')) {
              acc.s3 = url;
            } else {
              throw new Error('ERROR! unknown url protocol: ' + url);
            }
            return acc;
          }, {}
        );
        //console.log('Got urlsByProtocol: ' + JSON.stringify(urlsByProtocol));
        
        const urlList = Object.values(urlsByProtocol);
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
        ).then(
          function() {
            return { ...oldRec, ...updateRec };
          }
        )
      } else {
        //console.log('Record already in indexd ...');
        return Promise.resolve(oldRec);
      }
    },
    function(err){ // no existing record?
      //console.log('No existing data for ' + data.did);
      return fetchJsonRetry(urlBase + 'index/',
        {
          method: 'POST',
          body: JSON.stringify(data),
          headers: {
            'content-type': 'application/json',
            'Authorization': `Basic ${credsStr}`
          }
        } 
      ).then(
        function() { return data; }
      );
    }
  );
}

/**
 * Build id to record map from the gdc manifest file set of form:
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

 * 
 * @param {Array<String>} gdcManifestFileList
 * @return {[String]:{}} id to record map
 */
async function loadGdcManifest(gdcManifestFileList) {
    const rxId = /^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/;

    return Promise.all(
      gdcManifestFileList.map( // read each file
        fileName => utils.readFile(fileName)
      )
    ).then( 
      function (fileContentList) {
        return fileContentList.map(
          // split each file into lines
          content => content.split(/[\r\n]+/)
        ).reduce(
          // combine the 2 files' line lists into a single list
          function(acc, lineList) {
            return acc.concat(lineList)
          }, []
        ).map(
          // tokenize each line, and convert to an indexd record or null
          function(gdcLine) {
            const tokenList = gdcLine.split(/\s+/);
            if (tokenList.length === 8) {
              // .bai record in custom bucket manifest
              tokenList.shift();
            }
            if (tokenList[0].match(rxId)) {
              if (tokenList.length === 5) {
                // looks like a valid line
                return {
                  did: tokenList[0],
                  hashes: {
                    md5: tokenList[2]
                  },
                  size: +tokenList[3],
                  fileName: tokenList[1],
                  acl: [],
                  urls: []
                };
              } else if (tokenList.length === 7) {
                // looks like a valid line
                return {
                  did: tokenList[0],
                  hashes: {
                    md5: tokenList[1]
                  },
                  size: +tokenList[2],
                  fileName: tokenList[6],
                  acl: [],
                  urls: []
                };
              }
            }
            console.log('Ignoring invalid gdc manifest line: ' + JSON.stringify(tokenList));
            return null;
          }
        ).reduce(
          // index the accumulated records by id
          function(acc, rec) {
            if (rec) { // filter out the null records
              if (!acc[rec.did]) {
                acc[rec.did] = rec;
              } //else {
                //gdcDupCount += 1;
                // GDC says clinical/biospeciman XML files are on "both portals" :-p
                //console.log(`duplicate gdc records: ${gdcDupCount}?`, [rec, acc[rec.did]]);
                //}
            }
            return acc;
          }, 
          {}
        );
      }
    );
}

/**
 * Little helper for accumulating/logging errors
 * generated during record processing
 * 
 * @param {string} did 
 * @param {string} mess 
 * @param {object} details 
 * @param {boolean} reportToConsole 
 * @param {Array<{did,mess,details}>} errors 
 */
function pushErrorList(errors, did, mess, details, reportToConsole) {
  const err = {did, mess, details};
  reportToConsole && console.log('ERROR! ' + JSON.stringify(err));
  errors.push(err);
}


/**
 * Given a stream of records from a manifest generate
 * an id to record mapping augmented with data from the gdcDb manifest -
 * filtering out records not in gdcDb
 * 
 * @param {Array<String>} recordStream 
 * @param {[String]:record} gdcDb
 * @paramm {function} pushError 
 */
async function mergeRecordStreamWithGdc(recordStream, gdcDb, pushError) {
  return recordStream.map( // augment with gdc metadata - discard, and log as error if not present in gdc
    function(rec) {
      const gdcInfo = gdcDb[rec.did];
      let result = null;
      if (gdcInfo) {
        if (gdcInfo.fileName === rec.fileName) {
          result = { ...gdcInfo, ...rec };
        } else {
          pushError(rec.did, 'Ignoring bucket entry with mismatch filename', [rec, gdcInfo]);
        }
      } else {
        pushError(rec.did, 'Ugh, untracked bucket key!', rec);
      }
      return result;
    }
  ).reduce(
    function(acc, it) {
      if (it) {
        if (acc[it.did]) {
          pushError(it.did, 'Ugh, duplicate records!', [it, acc[it.did]], true);
        } else {
          acc[it.did] = it;
        }
      }
      return acc;
    }, {}
  );
}


/**
 * Combine manifests to get a unified manifest to upload to DCF.
 * Also generate error report detailing which records are in AWS
 * and not in GDC and vice versa.
 * 
 * 

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
 * @return {[string]:record}
 */
async function generateCloudManifest(bucketManifestFile, gdcManifestFileList, bucketName, aclList) {
  const errors = [];
  function pushError(did, mess, details, reportToConsole) {
    return pushErrorList(errors, did, mess, details, reportToConsole);
  }

  // Regex matches indexd did
  const rxId = /^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/;
  // build id to record data from the gdc manifests
  const gdcDb = await loadGdcManifest(gdcManifestFileList);
  
  // build id to record data for the bucket we have a manifest of
  try {
    const bucketDb = await utils.readFile(bucketManifestFile
    ).then(
      function (content) {
        const recordStream = content.split(/[\r\n]+/ // split file into lines
        ).map( // split each line into tokens
          function(line){ return line.split(/\s+/); }
        ).filter(  // only include valid looking data-file lines
          function(tokenList){
            let isOk = false;
            if (
              tokenList.length === 4 && 
              +tokenList[2] > 0  && // object size
              !tokenList[0].match(/^\s*#/) // line commented out
            ) {
              isOk = !!tokenList[3].match(/^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}\/+[^\/]+$/); // object key (filename) matches id/filename
              if (!isOk) {
                // log error if pattern is not as expected
                pushError('', 'invalid bucket manifest line', { tokenList });
              }
              // else - don't bother logging errors for prefix (non-object) entries in bucket manifest
            }
            return isOk;
          }
        ).map( // convert token list to indexd record
          function(tokenList) {
            const pathParts = tokenList[3].split(/\/+/);
            return {
              did: pathParts[0],
              fileName: pathParts[1],
              acl: aclList,
              urls: [ 's3://' + bucketName + '/' + tokenList[3] ]
            };
          }
        );
        return mergeRecordStreamWithGdc(recordStream, gdcDb, pushError);
      }
    );
    return {
      gdcDb,
      bucketDb,
      errors
    };  
  } catch (err) {
    console.log('Ugh!  Failed to build cloud-manifest: ' + JSON.stringify(err), err);
    return Promise.reject(err);
  }

}

/**
 * Similar to generateCloudManifest, but for the
 * comprehensive (multi-bucket) google manifest
 *
$ head -5 data-in/google20180911_pxd1716/manifest_for_DCF_20180824.csv 
file_gcs_url,file_gdc_id,file_size,file_gcs_timestamp,file_name
gs://5aa919de-0aa0-43ec-9ec3-288481102b6d/tcga/CHOL/RNA/RNA-Seq/UNC-LCCC/ILLUMINA/UNCID_2527433.6fcc3918-f4b0-42ab-b00c-027175606cbd.sorted_genome_alignments.bam.bai,cd82fbcd-4260-4e46-83b2-60f43ac48853,5740904,2016-03-28T20:16:26Z,UNCID_2527433.6fcc3918-f4b0-42ab-b00c-027175606cbd.sorted_genome_alignments.bam.bai
gs://5aa919de-0aa0-43ec-9ec3-288481102b6d/tcga/CHOL/RNA/RNA-Seq/UNC-LCCC/ILLUMINA/UNCID_2528055.63a3bd41-6a68-4eb5-ad4f-0fd05be97ac1.sorted_genome_alignments.bam.bai,58083c7f-92aa-43de-8b7b-bbd11614256e,5772208,2016-03-28T20:16:26Z,UNCID_2528055.63a3bd41-6a68-4eb5-ad4f-0fd05be97ac1.sorted_genome_alignments.bam.bai
gs://5aa919de-0aa0-43ec-9ec3-288481102b6d/tcga/CHOL/RNA/RNA-Seq/UNC-LCCC/ILLUMINA/UNCID_2529222.2649a2ec-8bb0-486e-9eec-ac9c76021b60.sorted_genome_alignments.bam.bai,06816104-0733-472f-9d32-a973d125ccbb,5012400,2016-03-28T20:16:26Z,UNCID_2529222.2649a2ec-8bb0-486e-9eec-ac9c76021b60.sorted_genome_alignments.bam.bai
gs://5aa919de-0aa0-43ec-9ec3-288481102b6d/tcga/CHOL/RNA/RNA-Seq/UNC-LCCC/ILLUMINA/UNCID_2529016.e819d2ae-9cfb-4256-a15c-23fbb3683ee7.sorted_genome_alignments.bam.bai,c996e67d-0d08-462f-a2d4-d0e86ee23fe7,5066464,2016-03-28T20:16:26Z,UNCID_2529016.e819d2ae-9cfb-4256-a15c-23fbb3683ee7.sorted_genome_alignments.bam.bai

 *  
 * @param {string} googleManifestFile 
 * @param {Array<String>} gdcManifestFileList 
 * @param {[string]:string} bucket2Acl gs://bucket to acl
 * @return {[string]:record} googManfiest+gdcManifest+aclMap intersection 
 */
async function generateGoogleManifest(bucketManifestFile, gdcManifestFileList, bucket2Acl) {
  const errors = [];
  function pushError(did, mess, details, reportToConsole) {
    return pushErrorList(errors, did, mess, details, reportToConsole);
  }
  if (Object.values(bucket2Acl).find(it => ! Array.isArray(it))) {
    // paranoid check - verify bucket2Acl values are arrays
    throw new Error('Invalid bucket2Acl mapping', bueckt2Acl);
  }

  // Regex matches indexd did
  const rxId = /^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/;
  const rxBucket = /^(gs:\/\/[^\/\s]+)\//;
  function getBucket(gsUrl) {
    const arr = rxBucket.exec(gsUrl);
    return arr ? arr[1] : null;
  }
  
  // build id to record data from the gdc manifests
  const gdcDb = await loadGdcManifest(gdcManifestFileList);
  
  // build id to record data for the bucket we have a manifest of
  try {
    const bucketDb = await utils.readFile(bucketManifestFile
    ).then(
      function (content) {
        const recordStream = content.split(/[\r\n]+/ // split file into lines
        ).map( // split each line into tokens, strip quotes
          function(line){ return line.split(',', 5).map(tok => tok.replace(/(^[\s"]+)|([\s"]+$)/g, '')); }
        ).filter(  // only include valid looking data-file lines
          function(tokenList){
            let isOk = false;
            if (
              tokenList.length === 5 && 
              +tokenList[2] > 0  && // object size
              !tokenList[0].match(/^\s*#/) // line commented out
            ) {
              const bucketName = getBucket(tokenList[0]);
              // tokenList[0] should be gs://bucketname
              isOk = !!(
                bucketName &&
                bucket2Acl[bucketName] &&
                rxId.test(tokenList[1])
              ); // object key (filename) matches id/filename
              if (!isOk) {
                // log error if pattern is not as expected
                pushError('', 'invalid bucket manifest line', { tokenList });
              }
              // else - don't bother logging errors for prefix (non-object) entries in bucket manifest
            }
            return isOk;
          }
        ).map( // convert token list to indexd record
          function(tokenList) {
            return {
              did: tokenList[1],
              fileName: tokenList[0].replace(/.*\//, ''),
              acl: bucket2Acl[getBucket(tokenList[0])],
              urls: [ tokenList[0] ]
            };
          }
        );
        return mergeRecordStreamWithGdc(recordStream, gdcDb, pushError);
      }
    );
    return {
      gdcDb,
      bucketDb,
      errors
    };  
  } catch (err) {
    console.log('Ugh!  Failed to build cloud-manifest: ' + JSON.stringify(err), err);
    return Promise.reject(err);
  }

}



module.exports = {
  fetchGdcRecord,
  fetchGdcRecordCacheOnly,
  generateCloudManifest,
  generateGoogleManifest,
  buildIndexdRecord,
  fetchGdcIndex,
  postToIndexd
};
