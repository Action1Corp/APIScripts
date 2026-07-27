<#
.SYNOPSIS
Shows a standalone HTTP 429 retry handling pattern.

.DESCRIPTION
This standalone script contains every helper function it uses.

It demonstrates a PowerShell 5.1 behavior that matters for retry logic:
Invoke-WebRequest throws for HTTP error responses when ErrorAction is Stop.
Because of that, HTTP 429 handling belongs in catch, not in a normal
successful-response branch.

The script reads the response body, looks for details.retry_after, sleeps for
that server-provided timeout when present, and otherwise falls back to an
exponential retry delay.

.EXAMPLE
.\Invoke-Http429HandlingExample.ps1 -Uri 'https://example.test/api' -Debug

Runs one GET request against a sample endpoint with debug output enabled.

.EXAMPLE
$headers = @{
    Accept        = 'application/json'
    Authorization = 'Bearer <access-token>'
}

1..100 | ForEach-Object {
    .\Invoke-Http429HandlingExample.ps1 `
        -Uri 'https://app.action1.com/api/3.0/Me' `
        -Method GET `
        -Headers $headers `
        -Max429Retries 3 `
        -Debug
}

Sends 100 GET requests in a row to the /Me endpoint in the North America region.
Replace <access-token> with a valid API access token before running it.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Uri,

    [Parameter()]
    [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
    [string]$Method = 'GET',

    [Parameter()]
    [hashtable]$Headers,

    [Parameter()]
    [object]$Body,

    [Parameter()]
    [ValidateRange(0, 20)]
    [int]$Max429Retries = 3,

    [Parameter()]
    [ValidateRange(1, 3600)]
    [int]$BaseRetryDelaySeconds = 2
)

Set-StrictMode -Version 2.0

$debugLoggingEnabled = $PSBoundParameters.ContainsKey('Debug')

function Write-ExampleDebug {
    <#
    .SYNOPSIS
    Writes debug information for this standalone example.

    .DESCRIPTION
    Uses Write-Information only when the script is called with -Debug.
    Keeping this wrapper small makes the rest of the example easy to follow
    without depending on any module-specific logging function.
    #>
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Message = ''
    )

    if (-not $debugLoggingEnabled) {
        return
    }

    Write-Information -MessageData "DEBUG: $Message" -InformationAction Continue
}

function Test-ExampleObjectProperties {
    <#
    .SYNOPSIS
    Checks whether an object has the expected properties.

    .DESCRIPTION
    Returns false for null objects, empty property names, and absent properties.
    This lets the retry code safely inspect optional JSON fields without
    assuming the server returned the exact shape expected by the example.
    #>
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$PropertyNames,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ObjectName = 'object'
    )

    if ($null -eq $InputObject) {
        Write-ExampleDebug "Skipping $ObjectName because it is null."
        return $false
    }

    if ($null -eq $PropertyNames -or $PropertyNames.Count -eq 0) {
        Write-ExampleDebug (
            "Cannot validate $ObjectName because no property names were supplied."
        )
        return $false
    }

    $availablePropertyNames = @(
        $InputObject.PSObject.Properties | ForEach-Object { $_.Name }
    )

    foreach ($rawPropertyName in $PropertyNames) {
        $propertyName = [string]$rawPropertyName

        if ([string]::IsNullOrWhiteSpace($propertyName)) {
            Write-ExampleDebug (
                "Cannot validate $ObjectName because a property name is empty."
            )
            return $false
        }

        if ($availablePropertyNames -notcontains $propertyName) {
            Write-ExampleDebug (
                "Skipping {0} because property '{1}' is absent." -f
                $ObjectName, $propertyName
            )
            return $false
        }
    }

    return $true
}

function Get-ExampleWebResponseContent {
    <#
    .SYNOPSIS
    Extracts text content from an HTTP error response.

    .DESCRIPTION
    PowerShell 5.1 stores the HTTP response object on the thrown exception.
    This helper first tries to read the response stream, then falls back to
    ErrorDetails.Message because some exception paths leave the stream empty.
    #>
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Response,

        [Parameter()]
        [AllowNull()]
        [object]$ErrorRecord
    )

    $responseContent = $null

    if ($null -ne $Response) {
        if (-not ($Response -is [System.Net.WebResponse])) {
            $responseContent = [string]$Response
        }
        else {
            try {
                $responseStream = $Response.GetResponseStream()

                if ($null -ne $responseStream) {
                    $streamReader = New-Object System.IO.StreamReader($responseStream)

                    try {
                        $responseContent = $streamReader.ReadToEnd()
                    }
                    finally {
                        $streamReader.Dispose()
                    }
                }
            }
            catch {
                $responseContent = $null
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($responseContent) -and $ErrorRecord) {
        if ($ErrorRecord.ErrorDetails) {
            $responseContent = $ErrorRecord.ErrorDetails.Message
        }
    }

    return $responseContent
}

function Get-ExampleJsonPropertyValue {
    <#
    .SYNOPSIS
    Reads one top-level property from a JSON string.

    .DESCRIPTION
    Returns null when the content is empty, invalid JSON, or does not contain
    the requested property. The retry code uses this to read the details object
    before checking whether it includes retry_after.
    #>
    param(
        [Parameter()]
        [AllowNull()]
        [string]$JsonContent,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$PropertyName
    )

    if ([string]::IsNullOrWhiteSpace($JsonContent)) {
        return $null
    }

    try {
        $jsonObject = ConvertFrom-Json -InputObject $JsonContent
    }
    catch {
        Write-ExampleDebug "Response content is not valid JSON: $($_.Exception.Message)"
        return $null
    }

    if (-not (Test-ExampleObjectProperties $jsonObject $PropertyName 'JSON response')) {
        return $null
    }

    return $jsonObject.PSObject.Properties[$PropertyName].Value
}

function Get-Example429RetryDelay {
    <#
    .SYNOPSIS
    Calculates the next retry delay for an HTTP 429 response.

    .DESCRIPTION
    Prefers a positive details.retry_after value from the response JSON.
    When the response does not provide that value, it returns an exponential
    fallback delay based on the retry count and base delay.
    #>
    param(
        [Parameter()]
        [AllowNull()]
        [object]$ErrorDetails,

        [Parameter(Mandatory)]
        [ValidateRange(0, 20)]
        [int]$RetryCount,

        [Parameter(Mandatory)]
        [ValidateRange(1, 3600)]
        [int]$BaseRetryDelaySeconds
    )

    if (Test-ExampleObjectProperties $ErrorDetails 'retry_after' 'error details') {
        $retryAfter = 0
        $parsedRetryAfter = [int]::TryParse(
            [string]$ErrorDetails.retry_after,
            [ref]$retryAfter
        )

        if ($parsedRetryAfter -and $retryAfter -gt 0) {
            return $retryAfter
        }
    }

    return [int]([Math]::Pow(2, $RetryCount) * $BaseRetryDelaySeconds)
}

function Invoke-ExampleRequestWith429Retry {
    <#
    .SYNOPSIS
    Sends an HTTP request and retries when the server returns HTTP 429.

    .DESCRIPTION
    Uses Invoke-WebRequest with ErrorAction Stop. In PowerShell 5.1, that means
    HTTP 429 is caught as an exception. The catch block extracts the status code,
    reads the response body, calculates the retry delay, sleeps, and then retries.
    Non-429 errors are rethrown for the caller to handle.
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method,

        [Parameter()]
        [hashtable]$Headers,

        [Parameter()]
        [AllowNull()]
        [object]$Body,

        [Parameter(Mandatory)]
        [ValidateRange(0, 20)]
        [int]$Max429Retries,

        [Parameter(Mandatory)]
        [ValidateRange(1, 3600)]
        [int]$BaseRetryDelaySeconds
    )

    $invokeWebRequestParams = @{
        Uri             = $Uri
        Method          = $Method
        UseBasicParsing = $true
        ErrorAction     = 'Stop'
    }

    if ($Headers) {
        $invokeWebRequestParams.Headers = $Headers
    }

    if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
        $invokeWebRequestParams.Body = ConvertTo-Json -InputObject $Body -Depth 10
        $invokeWebRequestParams.ContentType = 'application/json; charset=utf-8'
    }

    $retry429Count = 0

    while ($true) {
        try {
            Write-ExampleDebug "Sending $Method request to $Uri."
            $response = Invoke-WebRequest @invokeWebRequestParams

            Write-ExampleDebug (
                "Success response code {0} for {1} request to {2}." -f
                $response.StatusCode, $Method, $Uri
            )

            return $response.Content
        }
        catch {
            $exceptionResponse = $_.Exception.Response
            $statusCode = $null

            if ($exceptionResponse) {
                $statusCode = [int]$exceptionResponse.StatusCode
            }

            $responseContent = Get-ExampleWebResponseContent `
                -Response $exceptionResponse `
                -ErrorRecord $_
            $errorDetails = Get-ExampleJsonPropertyValue `
                -JsonContent $responseContent `
                -PropertyName 'details'

            if ([string]::IsNullOrWhiteSpace($responseContent)) {
                $responseContent = '<empty response content>'
            }

            Write-ExampleDebug (
                "Failed response code {0} for {1} request to {2}. Response: {3}" -f
                $statusCode, $Method, $Uri, $responseContent
            )

            if ($statusCode -eq 429) {
                if ($retry429Count -ge $Max429Retries) {
                    throw (
                        "HTTP 429 retry limit reached after {0} retry attempt(s)." -f
                        $retry429Count
                    )
                }

                $retryTimeout = Get-Example429RetryDelay `
                    -ErrorDetails $errorDetails `
                    -RetryCount $retry429Count `
                    -BaseRetryDelaySeconds $BaseRetryDelaySeconds
                $retry429Count++

                Write-ExampleDebug (
                    "429 received. Retry #{0}. Sleeping {1} second(s)." -f
                    $retry429Count, $retryTimeout
                )

                Start-Sleep -Seconds $retryTimeout
                continue
            }

            throw
        }
    }
}

$requestParams = @{
    Uri                   = $Uri
    Method                = $Method
    Headers               = $Headers
    Body                  = $Body
    Max429Retries         = $Max429Retries
    BaseRetryDelaySeconds = $BaseRetryDelaySeconds
}

Invoke-ExampleRequestWith429Retry @requestParams
