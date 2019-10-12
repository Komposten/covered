/*
 * Copyright 2019 Jakob Hjelm (Komposten)
 *
 * This file is part of covered.
 *
 * covered is a free Dart library: you can use, redistribute it and/or modify
 * it under the terms of the MIT license as written in the LICENSE file in the root
 * of this project.
 */
 'use strict';

const CDP = require('chrome-remote-interface');
const fs = require('fs');
var protocol;
var testScriptUri;

async function main(port, entrypointUri, scriptUri, testOutputLevel) {
    protocol = await CDP({port: port});
    testScriptUri = scriptUri;
    try {
        const {Page, Profiler, Runtime} = protocol;
        await Page.enable();
        await Profiler.enable();
        await Runtime.enable();

        Runtime.consoleAPICalled(entry => {
            const type = entry.type;
            const value = (entry.args.length > 0 ? entry.args[0].value : '');
            if (type === 'error') {
                if (testOutputLevel === 'verbose') {
                    console.error(value);
                    exitWithCode(2, value);
                } else {
                    exitWithCode(2);
                }
            }

            if (typeof value === 'string' || value instanceof String) {
                if (['log', 'debug', 'info', 'warning'].includes(type)) {
                    testLog(value, testOutputLevel);
                }

                if (value.includes('All tests passed!')) {
                    onSuccess(Profiler);
                } else if (value.includes('Some tests failed')) {
                    exitWithCode(1);
                }
            }
        });

        await Profiler.startPreciseCoverage({callCount: false, detailed: true});
        Page.navigate({url: entrypointUri});
    } catch (err) {
        exitWithCode(3, err);
    }
}

function testLog(text, level) {
    if (level === 'none') return;

    const testLinePattern = /\d+(?::\d+)+(?:\s+[+-~]\d+)*\s*:(?:.+)/;
    const colourSequencePattern = /.\[\d+m/gi;

    let text2 = text.replace(colourSequencePattern, '');

    if (level === 'verbose') {
        console.log(text);
    } else if (level === 'minimal' && text2.match(testLinePattern)) {
        console.log(text);
    } else if (level === 'short' && (text2.match(testLinePattern) ||
        text2.match(/^\s*(Skip|Expected|Actual):/))) {
        console.log(text);
    }
}

async function onSuccess(Profiler) {
    const res = await Profiler.takePreciseCoverage();
    await Profiler.stopPreciseCoverage();
    let script = res.result.find(script => script.url === testScriptUri);

    fs.mkdir('../../js_reports', { recursive: true }, (err) => {
        if (err) {
            exitWithCode(4, err);
        } else {
            fs.writeFile('../../js_reports/chrome.json', JSON.stringify(script), (err) => {
                if (err) {
                    exitWithCode(4, err);
                } else {
                    exitWithCode(0);
                }
            });
        }
    });
}

async function exitWithCode(code, err) {
    if (err) {
        console.error('==ERROR==')
        if (typeof err === 'string' || err instanceof String) {
            console.error(err);
        } else if (err instanceof Error) {
            console.error(err.message);
        } else {
            console.error(JSON.stringify(err));
        }
        console.error('=========')
    }

    if (protocol) {
        await protocol.close();
    }

    process.exit(code);
}

main(process.argv[2], process.argv[3], process.argv[4], process.argv[5]).then().catch((error) => {
    exitWithCode(255, error);
});