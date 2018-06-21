const fetch = require('node-fetch');
const mkdirp = require('mkdirp');

const gdcUrlBase = 'https://api.gdc.cancer.gov';
const recordsFolder = './records';

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

function buildIndexdRecord(uuidStr, aclList, objectUrlList) {
  const record = {
    "acl": [
      "test"
    ],
    "did": "206dfaa6-bcf1-4bc9-b2d0-77179f0f48fc",
    "file_name": "testdata",
    "form": "object",
    "hashes": {
      "md5": "c1898b7f2865ef7d7847b40e58f7c49c"
    },
    "metadata": {},
    "size": 9,
    "urls": [
      "s3://tcga-protected-dcf-databucket-gen3/testdata"
    ],
    "urls_metadata": {
      "s3://tcga-protected-dcf-databucket-gen3/testdata": {
        "acls": "test"
      }
    }
  };
  return record;
}

/**
 * Try to find the record in the "current" GDC file info index
 * @param {string} uuidStr 
 */
function fetchCurrentRecord(uuidStr) {
  return fetch(gdcUrlBase + '/files/' + uuidStr
    ).then( 
      (res) => {
        if( res.status !== 200 ) { 
          return Promise.reject(res);
        }
        return res.json();
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
    fields: 'index_files.file_id,acl,index_files.md5sum'
  };
}

/**
 * Try to find the record in the legacy GDC file info index
 * @param {string} uuidStr 
 */
async function fetchLegacyRecord(uuidStr) {
  return fetch(gdcUrlBase + '/legacy/files/' + uuidStr
    ).then( 
      (res) => {
        if( res.status !== 200 ) { 
          return Promise.reject(res);
        }
        return res.json();
      } 
  );
}

/**
 * BAM indexes (bai) require a custom query - ugh
 * @param {string} uuidStr 
 */
async function fetchLegacyIndexRecord(uuidStr) {
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
          return Promise.reject(res);
        }
        return res.json();
      } 
    );

}

async function saveRecord(record, uuidStr) {
  const jsonStr = JSON.stringify(record);
  const savePath = recordsFolder + '/' + uuidStr + '.json';
  console.log(`Saving record: ${jsonStr} to ${savePath}`);
}


async function saveRecord(record, uuidStr) {
  const jsonStr = JSON.stringify(record);
  const savePath = recordsFolder + '/' + uuidStr + '.json';
  console.log(`Saving record: ${jsonStr} to ${savePath}\n`);
}

async function saveError(record, uuidStr) {
  const jsonStr = JSON.stringify(record);
  const savePath = recordsFolder + '/errors/' + uuidStr + '.json';
  console.log(`ERROR: Saving record: ${jsonStr} to ${savePath}\n`);
}

async function fetchAndProcessRecord(uuidStr) {
  return fetchCurrentRecord(uuidStr).then(
    function(info) {
      return saveRecord(info, uuidStr)
    }
  ).catch(
    function(err) { // try again
      return fetchLegacyRecord(uuidStr).then(
        function(info) {
          return saveRecord(info, uuidStr);
        }
      ).catch(
        function(err) { // last try
          return fetchLegacyIndexRecord(uuidStr).then(
            function(info) {
              return saveRecord(info, uuidStr);
            }
          ).catch(
            function(err) { // ugh - log error
              return saveError({ uuid: uuidStr, status: err.status }, uuidStr);
            }
          );  
        }
      );
    }
  )
}

async function main() {
  await a_mkdirp(recordsFolder + '/errors');
  const recordList = [
    //'fdde0200-8912-4c8d-87b3-1bb3248acbed',
    '51d416e5-bae8-4a1e-a849-f99131febe10',
    //'ffa1d254-3cb6-4ee1-a1a5-52482637a43d'
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
                return fetchAndProcessRecord(recordId)
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
