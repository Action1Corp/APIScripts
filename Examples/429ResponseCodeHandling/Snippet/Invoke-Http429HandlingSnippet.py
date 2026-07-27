"""
Core HTTP 429 retry logic for Python requests.

requests.Response.raise_for_status() raises HTTPError for 429 responses.
Expected response JSON: {"details": {"retry_after": 5}}

Default values below call the /me endpoint.
Replace <TOKEN> with a valid API access token before running the snippet.
The URL is only an example. Build it as: <region base URL> + <endpoint path>.

Region base URL examples:
NorthAmerica   https://app.action1.com/api/3.0
NorthAmerica-2 https://app.na-2.action1.com/api/3.0
Europe         https://app.eu.action1.com/api/3.0
Australia      https://app.au.action1.com/api/3.0

Values to replace or tune:
<TOKEN>                  API access token.
base_url                 Region-specific Action1 API base URL.
endpoint_path            Final API endpoint path to call.
request_kwargs           requests.request arguments for the API call.
max_429_retries          Maximum number of 429 retry attempts before raising.
base_retry_delay_seconds Fallback retry delay seed when retry_after is missing.
"""

import time

import requests


access_token = "<TOKEN>"
base_url = "https://app.action1.com/api/3.0"
endpoint_path = "/me"

request_kwargs = {
    "method": "GET",
    "url": f"{base_url}{endpoint_path}",
    "headers": {
        "Accept": "application/json",
        "Authorization": f"Bearer {access_token}",
    },
    "timeout": 60,
}

max_429_retries = 3
base_retry_delay_seconds = 2
retry_429_count = 0

while True:
    try:
        response = requests.request(**request_kwargs)
        response.raise_for_status()
        break
    except requests.exceptions.HTTPError as error:
        response = error.response

        if response is None or response.status_code != 429:
            raise

        if retry_429_count >= max_429_retries:
            raise RuntimeError(
                f"HTTP 429 retry limit reached after {retry_429_count} retries."
            ) from error

        details = {}

        try:
            response_body = response.json()

            if isinstance(response_body, dict):
                details = response_body.get("details") or {}
        except ValueError:
            # Keep empty details so fallback retry timing is used.
            pass

        try:
            retry_after_seconds = int(str(details.get("retry_after", "")))
        except (AttributeError, TypeError, ValueError):
            retry_after_seconds = 0

        # Prefer details.retry_after seconds; otherwise use exponential fallback.
        if retry_after_seconds < 1:
            retry_after_seconds = (
                (2 ** retry_429_count) * base_retry_delay_seconds
            )

        retry_429_count += 1
        time.sleep(retry_after_seconds)
