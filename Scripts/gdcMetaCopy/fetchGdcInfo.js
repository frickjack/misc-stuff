const fs = require('fs');
const gdcHelper = require('./lib/gdcHelper');
const utils = require('./lib/utils');

const logLevel = utils.logLevel;
const defaultInputFolder = './data-in';
const defaultOutputFolder = './data-out';


/**
 * Fetch the specified record, and save it on success,
 * or log error on failure.
 * 
 * @param {string} uuidStr
 * @param {IndexdMeta} metaSuper optional supplemental metadata
 *      to merge into the result
 * @param {string} outputFolder
 * @param {key:info} gdcCache optional cached data to avoid network requests
 * @reutrn {Promise} that always succeeds 
 */
async function fetchAndProcessRecord(uuidStr, metaSuper, outputFolder, gdcCache) {
  return gdcHelper.fetchGdcRecord(uuidStr, metaSuper, gdcCache).then(
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
  if (!record.did) { throw new Error('Invalid record - no did', record); }
  const uuidStr = record.did;
  const jsonStr = JSON.stringify(record, null, 4);
  const savePath = outputFolder + '/' + uuidStr + '.json';
  logLevel > 1 && console.log(`Saving record: ${jsonStr} to ${savePath}\n`);
  await utils.writeFile(savePath, jsonStr);
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
  await utils.writeFile(savePath, jsonStr);
  return record;
}


async function test() {
  const outputFolder = './data-out/test';
  await utils.mkdirpPromise(outputFolder + '/errors');
  const recordList = [
    'fdde0200-8912-4c8d-87b3-1bb3248acbed',  // https://api.gdc.cancer.gov/legacy/files/fdde0200-8912-4c8d-87b3-1bb3248acbed
    '51d416e5-bae8-4a1e-a849-f99131febe10',  // POST /legacy/files/
    'ffa1d254-3cb6-4ee1-a1a5-52482637a43d',  // GET /legacy/files/id
    '01de7763-a374-43e3-9965-6c577394c306',  // GET /files/id
    '01263a92-ccf8-4d12-a2e3-0fa4ed3de5ba',  // POST /files/
    '01de7763-a374-43e3-9965-6c577394cXXX',  // bogus id
  ];

  return utils.chunkForEach(recordList, 10, 
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
  await utils.mkdirpPromise(outputFolder + '/errors');
  
  return utils.readFile(inputPath).then(
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
      return utils.chunkForEach(recordList, 10, 
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
  await utils.mkdirpPromise(outputFolder + '/errors');
  
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
      return utils.chunkForEach(recordList, 10, 
                async function(rec){ return saveRecord(gdcHelper.buildIndexdRecord(rec), outputFolder); }
              );
    }
  ).catch( 
    function(err) {
      console.log('Error!', err);
      return Promise.reject(err);
    }
  );
}


/**
 * Given a manifest listing a series of s3://bucket/... paths with
 * an embedded gdc uuid id in the path, fill an output folder
 * with .json files ready to post to an indexd index.
 * 
 * @param {string} inputPath to manifest file
 * @param {string} outputFolder 
 * @param {id:info} gdcCache cache
 */
async function processS3Manifest(inputPath, outputFolder, gdcCache) {
  console.log(`Creating ${outputFolder}`);
  gdcCache = gdcCache || {};
  await utils.mkdirpPromise(outputFolder + '/errors');
  const outputBucketExists = {};
  
  // get the set of ids that have already been processed
  const alreadyProcessed = await utils.globp(outputFolder + '/**/*.json')
    .then(
      function(files) {
        return files.map(path => utils.extractIdFromPath(path))
          .reduce(function(acc,it) {
            acc[it] = true;
            return acc;
          }, {});
      }
    );

  console.log(`Loaded output folder glob: ${outputFolder}`);
  return utils.readFile(inputPath)
    .then(
      function(data) {
        //console.log('Got data: ' + data );
        const recordList = data.split(/[\r\n]+/).map(
          function(line) {
            if (line.match(/s3:\/\/[^\/]+\/\S+$/)) {
              // looks like a valid S3 path - try to pick out the object id
              const id = utils.extractIdFromPath(line);
              return { did: id, urls:[ line ] };
            } else {
              console.log('Ingoring invalid input line: ' + line);
            }
            return undefined;
          }
        ).filter(
          rec => {
            return (!!rec) && (!alreadyProcessed[rec.did]);
          }
        );
        console.log(`Loading unprocessed records: ${recordList.length}`);
        let progressCount = 0;
        return utils.chunkForEach(recordList, 10, 
          async function(rec){ 
            // pick a time-based output bucket
            const outputBucketPath = outputFolder + '/' + (Math.floor(Date.now() / (1000*60*10)) % 100);
            let mkBucketPromise = outputBucketExists[ outputBucketPath ];
            if (!mkBucketPromise) {
              mkBucketPromise = utils.mkdirpPromise(outputBucketPath + '/errors');
              outputBucketExists[ outputBucketPath ] = mkBucketPromise;
            }
            return mkBucketPromise.then(
              function() {
                fetchAndProcessRecord(rec.did, rec, outputBucketPath, gdcCache).then(
                  function() {
                    progressCount += 1;
                    if (0 == progressCount % 500) {
                      console.log('Progress: ' + progressCount + ' records');
                    }
                  }
                );
              }
            );
          }
        );
      }
    ).catch( 
      function(err) {
        console.log('Error!', err);
        return Promise.reject(err);
      }
    );
}

async function loadGdcCache() {
  const cacheFile = defaultInputFolder + '/gdcCache.json';
  // First - try to read cache from local cache file
  return utils.readFile(cacheFile).then(
    function(jsonStr) {
      console.log('Cache hit');
      return JSON.parse(jsonStr);
    },
    function(err) {
      // otherwise fetch from gdc
      console.log('Cache miss? ' + err);
      return gdcHelper.fetchGdcIndex()
        .then(
          function(cache) {
            // save cache file
            const cacheStr = JSON.stringify(cache);
            //console.log('Saving cache: ' + cacheStr);
            return utils.writeFile(cacheFile, cacheStr).then(
              () => cache
            );
          }
        );
    }
  ).then(
    function (cacheList) {
      // convert to did keyed hash map
      return cacheList.reduce(function(acc, it) {
          acc[it.did] = it;
          return acc;
        }, {}
      );
    }
  );
}

async function main() {
  //await test();
  const gdcCache = await loadGdcCache();
  console.log(`gdc cache loaded`);
  //await processTsvId2Path(defaultInputFolder + '/TCGA_staging_data.tsv', defaultOutputFolder + '/TCGA_staging_data');
  //await processDcfCsvManifest(defaultInputFolder + '/manifest_for_DCF_20180613_update.csv', defaultOutputFolder + '/DCF_manifest_20180613');
  
  if (process.argv.length < 3) {
    console.log("Use: node bla.js bucket-name");
    return;
  }
  const bucketName = process.argv[2];
  await processS3Manifest(
    defaultInputFolder + '/' + bucketName + '.manifest.csv',
    defaultOutputFolder + '/' + bucketName,
    gdcCache
  );
  
}

main();
