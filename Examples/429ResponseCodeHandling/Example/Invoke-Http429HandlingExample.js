#!/usr/bin/env node
/*
Shows a standalone HTTP 429 retry handling pattern in JavaScript for Node.js.

Prerequisites:
    Node.js 18 or newer. Node 18+ includes the fetch API used by this script.
    No npm packages are required.

Install prerequisites:
    Windows:
        winget install OpenJS.NodeJS.LTS

    macOS with Homebrew:
        brew install node

    Linux:
        Use your distribution package manager or install Node.js from:
        https://nodejs.org/

Examples:
    node Invoke-Http429HandlingExample.js --uri https://example.test/api --debug

    node Invoke-Http429HandlingExample.js ^
        --uri https://app.action1.com/api/3.0/Me ^
        --method GET ^
        --headers "{\"Accept\":\"application/json\",\"Authorization\":\"Bearer <access-token>\"}" ^
        --max-429-retries 3 ^
        --debug

    The second example sends one GET request to the /Me endpoint in the North
    America region. Replace <access-token> with a valid API access token before
    running it.

    To send 100 requests in a row from cmd.exe:
        for /L %i in (1,1,100) do node Invoke-Http429HandlingExample.js ^
            --uri https://app.action1.com/api/3.0/Me ^
            --method GET ^
            --headers "{\"Accept\":\"application/json\",\"Authorization\":\"Bearer <access-token>\"}" ^
            --max-429-retries 3 ^
            --debug

Node fetch resolves for HTTP error responses instead of throwing for them.
Because of that, this script checks response.status after each fetch call and
handles HTTP 429 in the normal response path. Network-level failures still
throw exceptions and are reported as errors.
*/

'use strict';

const HTTP_METHODS = new Set(['GET', 'POST', 'PUT', 'PATCH', 'DELETE']);
const DEFAULT_REQUEST_TIMEOUT_MS = 60000;

function writeExampleDebug(message, debugEnabled) {
    if (!debugEnabled) {
        return;
    }

    console.error(`DEBUG: ${message}`);
}

function showHelp() {
    console.log(`
Usage:
    node Invoke-Http429HandlingExample.js --uri <url> [options]

Options:
    --uri <url>                       Request URI. Required.
    --method <method>                 GET, POST, PUT, PATCH, or DELETE.
                                      Default: GET.
    --headers <json-object>           Optional JSON object of request headers.
                                      Example: {"Accept":"application/json",
                                      "Authorization":"Bearer <access-token>"}
    --body <json-object>              Optional JSON object request body. Sent as
                                      application/json.
    --max-429-retries <number>        Maximum HTTP 429 retries. Default: 3.
    --base-retry-delay-seconds <num>  Base delay for exponential fallback.
                                      Default: 2.
    --debug                           Print debug messages to stderr.
    --help                            Show this help text.
`.trim());
}

function parseArguments(argv) {
    const options = {
        uri: null,
        method: 'GET',
        headers: null,
        body: null,
        max429Retries: 3,
        baseRetryDelaySeconds: 2,
        debug: false,
        help: false,
    };

    const argumentMap = {
        '--uri': 'uri',
        '--method': 'method',
        '--headers': 'headers',
        '--body': 'body',
        '--max-429-retries': 'max429Retries',
        '--base-retry-delay-seconds': 'baseRetryDelaySeconds',
    };

    for (let index = 0; index < argv.length; index += 1) {
        const argument = argv[index];

        if (argument === '--debug') {
            options.debug = true;
            continue;
        }

        if (argument === '--help' || argument === '-h') {
            options.help = true;
            continue;
        }

        const optionName = argumentMap[argument];
        if (!optionName) {
            throw new Error(`Unknown argument: ${argument}`);
        }

        const value = argv[index + 1];
        if (value === undefined || value.startsWith('--')) {
            throw new Error(`${argument} requires a value.`);
        }

        options[optionName] = value;
        index += 1;
    }

    if (options.help) {
        return options;
    }

    if (!options.uri || !options.uri.trim()) {
        throw new Error('--uri is required and must not be empty.');
    }

    options.method = String(options.method).toUpperCase();
    if (!HTTP_METHODS.has(options.method)) {
        throw new Error('--method must be one of GET, POST, PUT, PATCH, DELETE.');
    }

    options.max429Retries = parseIntegerInRange(
        options.max429Retries,
        '--max-429-retries',
        0,
        20,
    );
    options.baseRetryDelaySeconds = parseIntegerInRange(
        options.baseRetryDelaySeconds,
        '--base-retry-delay-seconds',
        1,
        3600,
    );

    return options;
}

function parseIntegerInRange(rawValue, argumentName, minimum, maximum) {
    const parsedValue = Number.parseInt(String(rawValue), 10);

    if (!Number.isInteger(parsedValue) || String(parsedValue) !== String(rawValue)) {
        throw new Error(`${argumentName} must be an integer.`);
    }

    if (parsedValue < minimum || parsedValue > maximum) {
        throw new Error(`${argumentName} must be between ${minimum} and ${maximum}.`);
    }

    return parsedValue;
}

function parseJsonObject(rawValue, argumentName) {
    if (rawValue === null || rawValue === undefined) {
        return null;
    }

    if (!String(rawValue).trim()) {
        throw new Error(`${argumentName} must not be empty when supplied.`);
    }

    let parsedValue;
    try {
        parsedValue = JSON.parse(rawValue);
    } catch (error) {
        throw new Error(`${argumentName} must be valid JSON: ${error.message}`);
    }

    if (parsedValue === null) {
        return null;
    }

    if (!isPlainObject(parsedValue)) {
        throw new Error(`${argumentName} must be a JSON object.`);
    }

    return parsedValue;
}

function isPlainObject(value) {
    return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

function normalizeHeaders(headers) {
    if (!headers) {
        return {};
    }

    return Object.fromEntries(
        Object.entries(headers).map(([name, value]) => {
            if (!name || !String(name).trim()) {
                throw new Error('Header names must not be empty.');
            }

            if (value === null || value === undefined) {
                throw new Error(`Header '${name}' must not be null.`);
            }

            return [name, String(value)];
        }),
    );
}

function getJsonPropertyValue(jsonContent, propertyName, debugEnabled) {
    if (!jsonContent || !String(jsonContent).trim()) {
        return null;
    }

    let jsonObject;
    try {
        jsonObject = JSON.parse(jsonContent);
    } catch (error) {
        writeExampleDebug(`Response content is not valid JSON: ${error.message}`, debugEnabled);
        return null;
    }

    if (!isPlainObject(jsonObject)) {
        writeExampleDebug('Skipping JSON response because it is not an object.', debugEnabled);
        return null;
    }

    if (!propertyName || !String(propertyName).trim()) {
        writeExampleDebug('Cannot validate JSON response because a property name is empty.', debugEnabled);
        return null;
    }

    if (!Object.prototype.hasOwnProperty.call(jsonObject, propertyName)) {
        writeExampleDebug(
            `Skipping JSON response because property '${propertyName}' is absent.`,
            debugEnabled,
        );
        return null;
    }

    return jsonObject[propertyName];
}

function get429RetryDelay(errorDetails, retryCount, baseRetryDelaySeconds, debugEnabled) {
    if (isPlainObject(errorDetails) &&
        Object.prototype.hasOwnProperty.call(errorDetails, 'retry_after')) {
        const retryAfter = Number.parseInt(String(errorDetails.retry_after), 10);

        if (Number.isInteger(retryAfter) && retryAfter > 0) {
            return retryAfter;
        }

        writeExampleDebug(
            'Ignoring details.retry_after because it is not a positive integer.',
            debugEnabled,
        );
    }

    return (2 ** retryCount) * baseRetryDelaySeconds;
}

function sleep(seconds) {
    return new Promise((resolve) => {
        setTimeout(resolve, seconds * 1000);
    });
}

async function invokeRequestWith429Retry(parameters) {
    const {
        uri,
        method,
        headers,
        body,
        max429Retries,
        baseRetryDelaySeconds,
        debugEnabled,
    } = parameters;

    let retry429Count = 0;

    while (true) {
        writeExampleDebug(`Sending ${method} request to ${uri}.`, debugEnabled);

        const response = await sendRequest(uri, method, headers, body);
        const responseContent = await response.text();

        if (response.ok) {
            writeExampleDebug(
                `Success response code ${response.status} for ${method} request to ${uri}.`,
                debugEnabled,
            );
            return responseContent;
        }

        const errorDetails = getJsonPropertyValue(responseContent, 'details', debugEnabled);
        const displayContent = responseContent.trim() || '<empty response content>';
        writeExampleDebug(
            `Failed response code ${response.status} for ${method} request to ${uri}. ` +
            `Response: ${displayContent}`,
            debugEnabled,
        );

        if (response.status === 429) {
            if (retry429Count >= max429Retries) {
                throw new Error(
                    `HTTP 429 retry limit reached after ${retry429Count} retry attempt(s).`,
                );
            }

            const retryTimeout = get429RetryDelay(
                errorDetails,
                retry429Count,
                baseRetryDelaySeconds,
                debugEnabled,
            );
            retry429Count += 1;

            writeExampleDebug(
                `429 received. Retry #${retry429Count}. ` +
                `Sleeping ${retryTimeout} second(s).`,
                debugEnabled,
            );

            await sleep(retryTimeout);
            continue;
        }

        throw new Error(
            `HTTP request failed with status ${response.status}: ${displayContent}`,
        );
    }
}

async function sendRequest(uri, method, headers, body) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), DEFAULT_REQUEST_TIMEOUT_MS);

    const requestOptions = {
        method,
        headers: { ...headers },
        signal: controller.signal,
    };

    if (body !== null && body !== undefined) {
        requestOptions.body = JSON.stringify(body);

        if (!hasHeader(requestOptions.headers, 'content-type')) {
            requestOptions.headers['Content-Type'] = 'application/json; charset=utf-8';
        }
    }

    try {
        return await fetch(uri, requestOptions);
    } finally {
        clearTimeout(timeout);
    }
}

function hasHeader(headers, headerName) {
    const expectedName = headerName.toLowerCase();
    return Object.keys(headers).some((name) => name.toLowerCase() === expectedName);
}

async function main() {
    const options = parseArguments(process.argv.slice(2));

    if (options.help) {
        showHelp();
        return 0;
    }

    const headers = normalizeHeaders(parseJsonObject(options.headers, '--headers'));
    const body = parseJsonObject(options.body, '--body');
    const responseContent = await invokeRequestWith429Retry({
        uri: options.uri,
        method: options.method,
        headers,
        body,
        max429Retries: options.max429Retries,
        baseRetryDelaySeconds: options.baseRetryDelaySeconds,
        debugEnabled: options.debug,
    });

    console.log(responseContent);
    return 0;
}

main().then((exitCode) => {
    process.exitCode = exitCode;
}).catch((error) => {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
});
