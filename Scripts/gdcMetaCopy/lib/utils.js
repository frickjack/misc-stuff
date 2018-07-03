const fs = require('fs');
const mkdirp = require('mkdirp');
const readline = require('readline');
var glob = require( 'glob' );  

const logLevel = 3;


/**
 * Promisfy mkdirp
 * 
 * @param {string} pathStr 
 */
function mkdirpPromise(pathStr) {
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
 * Promisfied glob
 */
async function globp(pattern) {
  return new Promise(function(resolve, reject) {
    glob(pattern, function(err, files) {
      if (err) {
        reject(err);
      } else {
        resolve(files);
      }
    });
  });
}

/**
 * TODO - process a file by reading chunks of lines,
 * and processing those in parallel while waiting for the
 * next chunk.
 * 
 * @param {string} filePath 
 * @param {int} chunkSize 
 * @param {async function} thunk 
 */
async function chunkReadline(filePath, chunkSize, thunk) {
  return new Promise(function(resolve,reject) {
    var lineReader = readline.createInterface({
      input: fs.createReadStream(filePath)
    });
  
    let recordCount = 0;
    let nextChunk = [];
    let runningPromise = Promise.resolve('ok');
    lineReader.on('line', function (line) {
      //console.log('Line from file:', line);
      nextChunk.push(line);
      if (nextChunk.length >= chunkSize * 2) {
        const readyChunk = nextChunk;
        lineReader.pause();
        runningPromise.finally(
          function() {
            runningPromise = chunkForEach(readyChunk, chunkSize, thunk);
            lineReader.resume();
          }
        );
      }
    });
    lineReader.on('close', function() {
      runningPromise.finally( function() { resolve(recordCount); } );
    });
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

/**
 * Given a path /a//b/c/...
 * where some component is a UUID - extract the UUID
 * 
 * @param {string} pathStr
 * @return {string} uuidStr or undefined if not found 
 */
function extractIdFromPath(pathStr) {
  const id = pathStr.replace(/\.\w+$/, '').split(/\/+/g).find(
    function(token) {
      return token.length === 36 && token.match(/\w\w\w\w\w\w\w\w-\w\w\w\w-\w\w\w\w-\w\w\w\w-\w\w\w\w\w\w\w\w\w\w\w\w/)
    }
  );
  return id;
}

/**
 * Promisfy fs.readFile
 * @param {string} pathStr 
 */
function readFile(pathStr) {
  return new Promise(
    function(resolve, reject) {
      fs.readFile(pathStr, 'utf8', function(err, data) {
        if (err) {
          reject(err);
          return;
        }
        resolve(data);
      });
    }
  );
}

/**
 * Promisfy fs.writeFile ...
 * 
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


module.exports = {
  chunkReadline,
  chunkForEach,
  extractIdFromPath,
  globp,
  get logLevel() { return logLevel; },
  mkdirpPromise,
  readFile,
  writeFile,
};
