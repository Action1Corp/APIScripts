'use strict';

/*
Core HTTP 429 retry logic for Node.js fetch.

fetch resolves HTTP 429 responses, so retry handling checks response.status.
Expected response JSON: { "details": { "retry_after": 5 } }

Default values below call the /me endpoint.
Replace <TOKEN> with a valid API access token before running the snippet.
The URL is only an example. Build it as: <region base URL> + <endpoint path>.

Region base URL examples:
NorthAmerica   https://app.action1.com/api/3.0
NorthAmerica-2 https://app.na-2.action1.com/api/3.0
Europe         https://app.eu.action1.com/api/3.0
Australia      https://app.au.action1.com/api/3.0

Values to replace or tune:
<TOKEN>                 API access token.
baseUrl                 Region-specific Action1 API base URL.
endpointPath            Final API endpoint path to call.
requestUrl              Full API URL passed to fetch.
requestOptions          fetch options for the API call.
max429Retries           Maximum number of 429 retry attempts before throwing.
baseRetryDelaySeconds   Fallback retry delay seed when retry_after is missing.
*/

function sleep(seconds) {
    return new Promise((resolve) => {
        setTimeout(resolve, seconds * 1000);
    });
}

async function invokeWith429Retry(
    requestUrl,
    requestOptions,
    max429Retries,
    baseRetryDelaySeconds,
) {
    let retry429Count = 0;

    while (true) {
        const response = await fetch(requestUrl, requestOptions);
        const responseText = await response.text();

        if (response.ok) {
            return responseText;
        }

        if (response.status !== 429) {
            throw new Error(
                `HTTP request failed with status ${response.status}: ${responseText}`,
            );
        }

        if (retry429Count >= max429Retries) {
            throw new Error(
                `HTTP 429 retry limit reached after ${retry429Count} retries.`,
            );
        }

        let details = {};

        try {
            const responseBody = JSON.parse(responseText);

            if (responseBody && typeof responseBody === 'object') {
                details = responseBody.details || {};
            }
        } catch {
            // Keep empty details so fallback retry timing is used.
        }

        const retryAfter = Number.parseInt(String(details.retry_after || ''), 10);
        let retryAfterSeconds = retryAfter;

        // Prefer details.retry_after seconds; otherwise use exponential fallback.
        if (!Number.isInteger(retryAfterSeconds) || retryAfterSeconds < 1) {
            retryAfterSeconds = (2 ** retry429Count) * baseRetryDelaySeconds;
        }

        retry429Count += 1;
        await sleep(retryAfterSeconds);
    }
}

const accessToken = '<TOKEN>';
const baseUrl = 'https://app.action1.com/api/3.0';
const endpointPath = '/me';
const requestUrl = `${baseUrl}${endpointPath}`;
const requestOptions = {
    method: 'GET',
    headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${accessToken}`,
    },
};

const max429Retries = 3;
const baseRetryDelaySeconds = 2;

// Usage:
// const responseText = await invokeWith429Retry(
//     requestUrl,
//     requestOptions,
//     max429Retries,
//     baseRetryDelaySeconds,
// );
