#!/usr/bin/env python
"""
Shows a standalone HTTP 429 retry handling pattern in Python.

Prerequisites:
    Python 3.8 or newer
    requests package

Install prerequisites:
    py -m pip install requests

On systems where the Python launcher is unavailable, use:
    python -m pip install requests

Examples:
    python Invoke-Http429HandlingExample.py --uri https://example.test/api --debug

    python Invoke-Http429HandlingExample.py ^
        --uri https://app.action1.com/api/3.0/Me ^
        --method GET ^
        --headers "{\"Accept\":\"application/json\",\"Authorization\":\"Bearer <access-token>\"}" ^
        --max-429-retries 3 ^
        --debug

    The second example sends one GET request to the /Me endpoint in the North
    America region. Replace <access-token> with a valid API access token before
    running it.

    To send 100 requests in a row from cmd.exe:
        for /L %i in (1,1,100) do python Invoke-Http429HandlingExample.py ^
            --uri https://app.action1.com/api/3.0/Me ^
            --method GET ^
            --headers "{\"Accept\":\"application/json\",\"Authorization\":\"Bearer <access-token>\"}" ^
            --max-429-retries 3 ^
            --debug

This script uses requests.Response.raise_for_status() so HTTP error responses
are handled through requests.exceptions.HTTPError. For HTTP 429, the exception
still contains the response object, so the retry logic can read the status code
and response body before deciding whether to sleep and retry.
"""

import argparse
import json
import sys
import time
from typing import Any, Dict, Optional

try:
    import requests
except ImportError:
    requests = None
    HANDLED_REQUEST_EXCEPTIONS = ()
else:
    HANDLED_REQUEST_EXCEPTIONS = (requests.exceptions.RequestException,)


HTTP_METHODS = ("GET", "POST", "PUT", "PATCH", "DELETE")


def write_example_debug(message: str, debug_enabled: bool) -> None:
    """Writes debug information for this standalone example."""
    if not debug_enabled:
        return

    print(f"DEBUG: {message}", file=sys.stderr)


def parse_json_object(raw_value: Optional[str], argument_name: str) -> Optional[Dict[str, Any]]:
    """Parses an optional JSON object argument."""
    if raw_value is None:
        return None

    if not raw_value.strip():
        raise ValueError(f"{argument_name} must not be empty when supplied.")

    try:
        parsed_value = json.loads(raw_value)
    except json.JSONDecodeError as error:
        raise ValueError(f"{argument_name} must be valid JSON: {error}") from error

    if parsed_value is None:
        return None

    if not isinstance(parsed_value, dict):
        raise ValueError(f"{argument_name} must be a JSON object.")

    return parsed_value


def get_json_property_value(
    json_content: Optional[str],
    property_name: str,
    debug_enabled: bool,
) -> Optional[Any]:
    """Reads one top-level property from a JSON string."""
    if not json_content or not json_content.strip():
        return None

    try:
        json_object = json.loads(json_content)
    except json.JSONDecodeError as error:
        write_example_debug(f"Response content is not valid JSON: {error}", debug_enabled)
        return None

    if not isinstance(json_object, dict):
        write_example_debug("Skipping JSON response because it is not an object.", debug_enabled)
        return None

    if not property_name:
        write_example_debug("Cannot validate JSON response because a property name is empty.", debug_enabled)
        return None

    if property_name not in json_object:
        write_example_debug(
            f"Skipping JSON response because property '{property_name}' is absent.",
            debug_enabled,
        )
        return None

    return json_object[property_name]


def get_429_retry_delay(
    error_details: Optional[Any],
    retry_count: int,
    base_retry_delay_seconds: int,
    debug_enabled: bool,
) -> int:
    """
    Calculates the next retry delay for an HTTP 429 response.

    A positive details.retry_after value from the response JSON is preferred.
    If that value is absent or invalid, an exponential fallback delay is used.
    """
    if isinstance(error_details, dict) and "retry_after" in error_details:
        try:
            retry_after = int(str(error_details["retry_after"]))
        except (TypeError, ValueError):
            retry_after = 0

        if retry_after > 0:
            return retry_after

        write_example_debug(
            "Ignoring details.retry_after because it is not a positive integer.",
            debug_enabled,
        )

    return (2 ** retry_count) * base_retry_delay_seconds


def invoke_request_with_429_retry(
    uri: str,
    method: str,
    headers: Optional[Dict[str, Any]],
    body: Optional[Dict[str, Any]],
    max_429_retries: int,
    base_retry_delay_seconds: int,
    debug_enabled: bool,
) -> str:
    """Sends an HTTP request and retries when the server returns HTTP 429."""
    retry_429_count = 0

    while True:
        try:
            write_example_debug(f"Sending {method} request to {uri}.", debug_enabled)

            response = requests.request(
                method=method,
                url=uri,
                headers=headers,
                json=body,
                timeout=60,
            )
            response.raise_for_status()

            write_example_debug(
                f"Success response code {response.status_code} for {method} request to {uri}.",
                debug_enabled,
            )
            return response.text
        except requests.exceptions.HTTPError as error:
            response = error.response
            status_code = response.status_code if response is not None else None
            response_content = response.text if response is not None else ""
            error_details = get_json_property_value(
                response_content,
                "details",
                debug_enabled,
            )

            display_content = response_content.strip() or "<empty response content>"
            write_example_debug(
                (
                    f"Failed response code {status_code} for {method} request to "
                    f"{uri}. Response: {display_content}"
                ),
                debug_enabled,
            )

            if status_code == 429:
                if retry_429_count >= max_429_retries:
                    raise RuntimeError(
                        "HTTP 429 retry limit reached after "
                        f"{retry_429_count} retry attempt(s)."
                    ) from error

                retry_timeout = get_429_retry_delay(
                    error_details,
                    retry_429_count,
                    base_retry_delay_seconds,
                    debug_enabled,
                )
                retry_429_count += 1

                write_example_debug(
                    (
                        f"429 received. Retry #{retry_429_count}. "
                        f"Sleeping {retry_timeout} second(s)."
                    ),
                    debug_enabled,
                )

                time.sleep(retry_timeout)
                continue

            raise


def parse_arguments() -> argparse.Namespace:
    """Parses and validates command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Send an HTTP request and retry when HTTP 429 is returned.",
    )
    parser.add_argument("--uri", required=True, help="Request URI.")
    parser.add_argument(
        "--method",
        choices=HTTP_METHODS,
        default="GET",
        help="HTTP method. Default: GET.",
    )
    parser.add_argument(
        "--headers",
        help=(
            'Optional JSON object of request headers, for example '
            '{"Accept":"application/json","Authorization":"Bearer <access-token>"}.'
        ),
    )
    parser.add_argument(
        "--body",
        help="Optional JSON object request body. Sent as application/json.",
    )
    parser.add_argument(
        "--max-429-retries",
        type=int,
        default=3,
        help="Maximum number of retries for HTTP 429 responses. Default: 3.",
    )
    parser.add_argument(
        "--base-retry-delay-seconds",
        type=int,
        default=2,
        help="Base delay for exponential fallback retries. Default: 2.",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Print debug messages to stderr.",
    )

    arguments = parser.parse_args()

    if not arguments.uri.strip():
        parser.error("--uri must not be empty.")

    if not 0 <= arguments.max_429_retries <= 20:
        parser.error("--max-429-retries must be between 0 and 20.")

    if not 1 <= arguments.base_retry_delay_seconds <= 3600:
        parser.error("--base-retry-delay-seconds must be between 1 and 3600.")

    return arguments


def main() -> int:
    """Runs the command-line example."""
    arguments = parse_arguments()
    handled_exceptions = (ValueError, RuntimeError) + HANDLED_REQUEST_EXCEPTIONS

    try:
        if requests is None:
            raise RuntimeError(
                "The requests package is required. Install it with: "
                "py -m pip install requests"
            )

        headers = parse_json_object(arguments.headers, "--headers")
        body = parse_json_object(arguments.body, "--body")

        response_content = invoke_request_with_429_retry(
            uri=arguments.uri,
            method=arguments.method,
            headers=headers,
            body=body,
            max_429_retries=arguments.max_429_retries,
            base_retry_delay_seconds=arguments.base_retry_delay_seconds,
            debug_enabled=arguments.debug,
        )
    except handled_exceptions as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(response_content)
    return 0


if __name__ == "__main__":
    sys.exit(main())
