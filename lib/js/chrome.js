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
var protocol;

async function main(port, entrypointUri, scriptUri, printTestOutput) {
    protocol = await CDP({port: port});
    try {
        const {Page, Profiler, Runtime} = protocol;
        await Page.enable();
        await Profiler.enable();
        await Runtime.enable();

        Runtime.consoleAPICalled(entry => {
            const type = entry.type;
            const value = (entry.args.length > 0 ? entry.args[0].value : '');
            if (['log', 'debug', 'info', 'warning'].includes(type)) {
                if (printTestOutput === 'true') {
                    console.log(value);
                }

                if (value.includes('All tests passed!')) {
                    onSuccess(Profiler);
                } else if (value.includes('Some tests failed')) {
                    exitWithCode(1);
                }
            } else if (type === 'error') {
                if (printTestOutput === 'true') {
                    console.error(value);
                }
                exitWithCode(2);
            }
        });

        await Profiler.startPreciseCoverage(false, true);
        Page.navigate({url: entrypointUri});

        await new Promise(resolve => {
            setTimeout(resolve, 10000)
        });
    } catch (err) {
        console.error(err);
        exitWithCode(3);
    }
}

async function onSuccess(Profiler) {
    const res = await Profiler.takePreciseCoverage();
    await Profiler.stopPreciseCoverage();

    //console.log(res.result.find(script => script.url === scriptUri));
    //TODO(komposten): Analyze the results.
    exitWithCode(0);
}

async function exitWithCode(code) {
    if (code === 1) {
    } else if (code === 2) {
        console.error('En error occurred while running the tests');
    } else if (code === 3) {
        console.error('En error occurred while communicating with Chrome');
    }

    await protocol.close();
    process.exit(code);
}

main(process.argv[2], process.argv[3], process.argv[4], process.argv[5]).then().catch(console.error);