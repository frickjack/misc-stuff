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
  logLevel > 12 && console.log(`Saving record: ${jsonStr} to ${savePath}\n`);
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
    function(dataStr) {
      //console.log('Got dataStr: ' + dataStr );
      const recordList = dataStr.split(/[\r\n]+/).map(
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
  
  return utils.readFile(inputPath).then(
    function(dataStr) {
      //console.log('Got dataStr: ' + dataStr );
      const recordList = dataStr.split(/[\r\n]+/).splice(1).map(
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
 * Read the AWS S3 .manifest.csv file
 */
async function readS3Manifest(inputPath) {
  return utils.readFile(inputPath)
    .then(
      function(dataStr) {
        //console.log('Got dataStr: ' + dataStr );
        const recordList = dataStr.split(/[\r\n]+/).map(
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
        );
        return recordList;
      }
    );
}

/**
 * Given a manifest listing a series of s3://bucket/... paths with
 * an embedded gdc uuid id in the path, fill an output folder
 * with .json files ready to post to an indexd index.
 * 
 * @param {Array<{did,urls}>} recordList unprocessed records from manifest file
 * @param {string} outputFolder 
 * @param {id:info} gdcCache cache
 */
async function loadS3Manifest(recordList, outputFolder, gdcCache) {
  console.log(`Creating ${outputFolder}`);
  gdcCache = gdcCache || {};
  await utils.mkdirpPromise(outputFolder + '/errors');
  const outputBucketExists = {};

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
          return fetchAndProcessRecord(rec.did, rec, outputBucketPath, gdcCache).then(
            function() {
              progressCount += 1;
              if (0 == progressCount % 500) {
                console.log('Progress: ' + progressCount + ' records');
              }
              return null;
            }
          );
        }
      );
    }
  );
}

/**
 * Load the json file associated with the given recordList,
 * and post it to indexd
 * 
 * @param {Array<{did,jsonPath}>} recordList unprocessed records from manifest file
 * @param {string} outputFolder 
 * @param {string} indexdUrl
 */
async function pushS3Manifest(recordList, outputFolder, indexdHost, indexdCreds) {
  console.log(`Creating ${outputFolder}`);
  await utils.mkdirpPromise(outputFolder + '/errors');
  const outputBucketExists = {};
  console.log(`Pushing unprocessed records: ${recordList.length}`);
  let progressCount = 0;
  return utils.chunkForEach(recordList, 10, 
    async function (rec) { 
      // pick a time-based output bucket
      const outputBucketPath = outputFolder + '/' + (Math.floor(Date.now() / (1000*60*10)) % 100);
      let mkBucketPromise = outputBucketExists[ outputBucketPath ];
      if (!mkBucketPromise) {
        mkBucketPromise = utils.mkdirpPromise(outputBucketPath + '/errors');
        outputBucketExists[ outputBucketPath ] = mkBucketPromise;
      }
      return mkBucketPromise.then(
        function() {
          return utils.readFile(rec.jsonPath);
        }
      ).then(
        function (dataStr) {
          const data = JSON.parse(dataStr);
          return gdcHelper.postToIndexd(indexdHost, indexdCreds, data);
        }
      ).then(
        function(info) {
          progressCount += 1;
          if (0 == progressCount % 500) {
            console.log('Progress: ' + progressCount + ' records');
          }
          return saveRecord(info, outputBucketPath);
        }
      ).catch(
        function(err) { // ugh - log error
          return saveError({ error: err, ...rec }, outputBucketPath);
        }
      );    
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

const manifestFolder = 'data-in/dcfAwsIndex20180727';
const helpStr = `Use: node fetchGdcInfo.js commandGroup command options
where commandGroup is one of:
    - current
          Query GDC API for metadata for keys in the bucket manifest
    - gdc11
          Load the GDC Release 11 manifest for metadata
where command is one of:
    - test
    - gen-recs bucketName
        Generate indexd records given a manifest 
        (${manifestFolder}/bucketName.cloud-manifest.csv) of form:
             uuid, bucket-path, acl, md5, size
        Writes generated records to ${defaultOutputFolder}/bucketName
    - post-recs bucketName [index-password (default from INDEX_PASSWORD environment)]
         Post the records under ${defaultOutputFolder}/bucketName 
         to nci-crdc.datacommons.io
         using the given indexd password.
         Merges the url lists if a record already exists in indexd.
`;

async function main() {
  // TODO - break main between commands
  //await test();
  //await processTsvId2Path(defaultInputFolder + '/TCGA_staging_data.tsv', defaultOutputFolder + '/TCGA_staging_data');
  //await processDcfCsvManifest(defaultInputFolder + '/manifest_for_DCF_20180613_update.csv', defaultOutputFolder + '/DCF_manifest_20180613');
  
  const bucket2Acl = {
    'ccle-open-access': '*',
    'target-open': '*',
    'target-controlled': 'phs000218',
    'tcga-controlled': 'phs000178',
    'tcga-open': '*',
    'cat-all-buckets': 'frickjack'
  };

  if (process.argv.length < 4) {
    console.log(helpStr);
    return;
  }

  const commandGroup = process.argv[2];
  const command = process.argv[3];
  const bucketName = process.argv[4];
  const outputFolder =  defaultOutputFolder + '/' + bucketName;
  const indexdHost = 'nci-crdc.datacommons.io'; // 'reuben.planx-pla.net'; // 
  const indexdCreds = Buffer.from('gdcapi:' + process.env.INDEX_PASSWORD).toString('base64');  
      
  // get the set of ids that have already been processed
  // glob is a memory pig
  //const bucketManifest = manifestFolder + '/' + bucketName + '.manifest.tsv';
  
  if (!bucket2Acl[bucketName]) {
    console.log(`Invalid bucket name: ${bucketName}
Available buckets: ${Object.keys(bucket2Acl).join(',')}
`);
    return;
  }
  if (commandGroup === 'current') { // generate json record on local fs
    let alreadyProcessed = await utils.globp(outputFolder + '/**/*.json')
    .then(
      function(files) {
        return files.map(
          function (path) {
            return { id: utils.extractIdFromPath(path), path };
          }
        ).reduce(function(acc,it) {
            if (it.id) {
              acc[it.id] = it.path;
            }
            return acc;
          }, {});
      }
    );    
    console.log(`Loaded output folder glob: ${outputFolder}`);

    if (command === 'gen-recs') { // generate json record on local fs
      const recordList = await readS3Manifest(inputPath)
      .then(
        function(manifestList) {
          return manifestList.filter(
            rec => {
              return (!!rec) && (!alreadyProcessed[rec.did]);
            }
          );
        }
      ).catch( 
        function(err) {
          console.log('Error!', err);
          return Promise.reject(err);
        }
      );
      // allow garbage collection 
      alreadyProcessed = undefined;

      const gdcCache = await loadGdcCache();
      console.log(`gdc cache loaded`);

      await loadS3Manifest(
        recordList,
        outputFolder,
        gdcCache
      );
    } else if (command === 'post-recs') {
      const recordList = await readS3Manifest(inputPath)
      .then(
        function(manifestList) {
          return manifestList.map(
            rec => {
              if ((!!rec) && alreadyProcessed[rec.did]) {
                const jsonPath = alreadyProcessed[rec.did];
                if (jsonPath.indexOf('/errors/') < 0) {
                  // process manifest entries with a generated
                  // .json record that is not an error
                  return {
                    jsonPath: alreadyProcessed[rec.did],
                    did: rec.did
                  };
                }
              }
              return false;
            }
          ).filter(rec => !!rec);
        }
      ).catch( 
        function(err) {
          console.log('Error!', err);
          return Promise.reject(err);
        }
      );
      // allow garbage collection 
      alreadyProcessed = undefined;
      await pushS3Manifest(recordList, outputFolder.replace(/\/+$/, '') + '_upload', indexdHost, indexdCreds);
    } else {
      console.log(helpStr);
    }
  } else if (commandGroup === 'gdc11') {
    if (command === 'gen-recs') {
      /*
      Build a cloud manifest that merges 
         * bucket-manifest at ${manifestFolder}/bucketName.manifest.csv with each line of form: bucket-path
         * gdc-manifest from ${defaultInputFolder}/gdcRelease11/*.tsv with each line of form: id fielname md5 size state
         Generates output:
         * id bucket-path acl md5 size state
         Where acl is derived from the bucket-name:
            x ccle-open-access -> "public"
            x target-open -> "public"
            x target-controlled -> "phs000218"
            x tcga-controlled -> "phs000178"
            x tcga-open -> "public"
      */
      // build a .cloud-manifest. file by merging GDC manifest with AWS bucket manifest
      // the .cloud-manifest. holds the json records ready to post to indexd
      const info = await gdcHelper.generateCloudManifest(
        manifestFolder + '/' + bucketName + '.manifest.tsv',
        [ 
          defaultInputFolder + '/gdcRelease11/gdc_manifest_20180521_data_release_11.0_active.txt',
          defaultInputFolder + '/gdcRelease11/gdc_manifest_20180521_data_release_11.0_legacy.txt'
        ],
        bucketName,
        [ bucket2Acl[ bucketName ] ]
      );
      const summary = {
        recs: Object.values(info.bucketDb),
        errors: info.errors
      };
      console.log(`
  Record count: ${summary.recs.length}
  Error count : ${summary.errors.length}
  `
  );
      if (bucketName === 'cat-all-buckets') {
        // Try to determine which gdc objects are not in the buckets
        const gdcRecs = Object.values(info.gdcDb);
        const bucketCount = Object.keys(info.bucketDb).length;
        const missingRecs = gdcRecs.filter(rec => !info.bucketDb[rec.did]);
        console.log(`
  GDC total records count  : ${gdcRecs.length}
  Total bucket keys count  : ${bucketCount}
  GDC missing records count: ${missingRecs.length}
  `);
        const path = manifestFolder + '/gdcMissing.json';
        console.log(`Writing ${path}`);
        await utils.writeFile(path, JSON.stringify(missingRecs));
      } else {
        const path = manifestFolder + '/' + bucketName + '.cloud-manifest.json';
        console.log(`Writing ${path}`);
        await utils.writeFile(path, JSON.stringify(summary));
      }
    } else if (command === 'post-recs') {
      const path = manifestFolder + '/' + bucketName + '.cloud-manifest.json';
      const meta = await utils.readFile(path).then(str => JSON.parse(str));
      const recordList = meta.recs.map(
        function(rec) {
          if(rec.fileName) { // we don't want to include fileName in indexd record
            delete rec.fileName;
          }
          return gdcHelper.buildIndexdRecord(rec);
        }
      );
      const resultFolder = outputFolder.replace(/\/+$/, '') + '_upload';
      let progressCount = 0;
      const outputBucketExists = {};
      return utils.chunkForEach(recordList, 10, 
        async function (rec) { 
          // pick a time-based output bucket
          const outputBucketPath = resultFolder + '/' + (Math.floor(Date.now() / (1000*60*10)) % 100);
          let mkBucketPromise = outputBucketExists[ outputBucketPath ];
          if (!mkBucketPromise) {
            mkBucketPromise = utils.mkdirpPromise(outputBucketPath + '/errors');
            outputBucketExists[ outputBucketPath ] = mkBucketPromise;
          }
          return mkBucketPromise.then(
            function () {
              return gdcHelper.postToIndexd(indexdHost, indexdCreds, rec);
            }
          ).then(
            function(info) {
              progressCount += 1;
              if (0 == progressCount % 500) {
                console.log('Progress: ' + progressCount + ' records');
              }
              return saveRecord(info, outputBucketPath);
            }
          ).catch(
            function(err) { // ugh - log error
              return saveError({ error: err, ...rec }, outputBucketPath);
            }
          );    
        }
      );
    } else {
      console.log(helpStr);
    }
    
  } else {
    console.log(helpStr);
  }
}

module.exports = {
  loadGdcCache
};

main();
