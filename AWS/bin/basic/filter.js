//
// nunjucks render stdin
//

const fsPromises = require("fs").promises;
const nunjucks = require("nunjucks");
const console = new require('console').Console(process.stderr);

function filterStrings(variablesStr, templateStr) {
    const variableValues = JSON.parse(variablesStr);
    try {
        process.stdout.write(nunjucks.renderString(templateStr, variableValues));
    } catch (err) {
        console.log(`Failed applying ${variablesStr} variables to template ${templateStr}`, err);
        throw err;
    }
}

/**
 * Read stdin to the end
 * 
 * @return Promise<String>
 */
function readStdin() {
    return new Promise( (resolve, reject) => {
        let buffList = [];
        const clearListeners = () => {
            process.stdin.removeListener('data', dataListener);
            process.stdin.removeListener('end', endListener);
            buffList = [];
        };

        const dataListener = (chunk) => {
            if (!Buffer.isBuffer(chunk)) {
                console.log('non buffer from stdin');
                reject("unexpected non-Buffer from stdin");
                clearListeners();
            } else {
                buffList.push(chunk);
            }
        }
        const endListener = () => {
            console.log("stdin end");
            resolve(Buffer.concat(buffList).toString('utf8'));
            clearListeners();
        };

        process.stdin.on('data', dataListener);     
        process.stdin.on('end', endListener);
    });
}

/**
 * Run the given value through a nunjucks
 * template processing with the given variable values.
 * 
 * @param {string} variablesPath either inline variables json (starts with {}) or path to varialbes.json file 
 * @param {string} templatePath blank or "-" implies stdin, otherwise path to template file
 * @return Promise<string>
 */
function filterPaths(variablesPath, templatePath) {
    let templateStrPr = Promise.resolve("");
    let variablesStrPr = Promise.resolve(variablesPath);
    
    if (! variablesPath.startsWith("{")) {
        variablesStrPr = fsPromises.readFile(variablesPath, { encoding: "utf8" });
    }
    if (templatePath && templatePath != "-") {
        templateStrPr = fsPromises.readFile(templatePath, { encoding: "utf8" });
    } else {
        templateStrPr = readStdin();
    }
    return Promise.all([variablesStrPr, templateStrPr]).then(
        ([variablesStr, templateStr]) => filterStrings(variablesStr, templateStr)
    );
}


function main() {
    const myArgs = process.argv.slice(2);
    if (myArgs.length < 1) {
        console.log("Use: filter variables [templateFile]");
        process.exit(1);
    }
    filterPaths(myArgs[0], myArgs[1]).catch(
        (err) => {
            console.log(err);
        }
    );
}

if (!module.parent) {
    main();
}
