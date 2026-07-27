<#
Core HTTP 429 retry logic for PowerShell 5.1.

Invoke-WebRequest must use ErrorAction = 'Stop', so HTTP 429 is handled in catch.
Expected response JSON: { "details": { "retry_after": 5 } }

Default values below call the /me endpoint from Example/Invoke-MeGetRequest.ps1.
Replace <TOKEN> with a valid API access token before running the snippet.
The Uri is only an example. Build it as: <region base Uri> + <endpoint path>.

Region base Uri examples:
NorthAmerica   https://app.action1.com/api/3.0
NorthAmerica-2 https://app.na-2.action1.com/api/3.0
Europe         https://app.eu.action1.com/api/3.0
Australia      https://app.au.action1.com/api/3.0

Values to replace or tune:
<TOKEN>                API access token.
$baseUri               Region-specific Action1 API base Uri.
$endpointPath          Final API endpoint path to call.
$max429Retries         Maximum number of 429 retry attempts before throwing.
$baseRetryDelaySeconds Fallback retry delay seed when retry_after is missing.
#>

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", "application/json")
$headers.Add("Authorization", "Bearer <TOKEN>")

$baseUri = 'https://app.action1.com/api/3.0'
$endpointPath = '/me'

$invokeWebRequestParams = @{
    Uri             = "$baseUri$endpointPath"
    Method          = 'GET'
    Headers         = $headers
    UseBasicParsing = $true
    ErrorAction     = 'Stop'
}

$max429Retries = 3
$baseRetryDelaySeconds = 2
$retry429Count = 0

while ($true) {
    try {
        return (Invoke-WebRequest @invokeWebRequestParams).Content
    }
    catch {
        $response = $_.Exception.Response

        if (-not $response -or [int]$response.StatusCode -ne 429) {
            throw
        }

        if ($retry429Count -ge $max429Retries) {
            throw "HTTP 429 retry limit reached after $retry429Count retries."
        }

        # Parse JSON response body. ErrorDetails.Message is the fallback source.
        $responseBody = $_.ErrorDetails.Message
        $reader = $null

        try {
            $stream = $response.GetResponseStream()

            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $streamBody = $reader.ReadToEnd()

                if (-not [string]::IsNullOrWhiteSpace($streamBody)) {
                    $responseBody = $streamBody
                }
            }
        }
        finally {
            if ($reader) {
                $reader.Dispose()
            }
        }

        $retryAfterSeconds = $null

        try {
            $details = (ConvertFrom-Json -InputObject $responseBody).details

            if ($details -and $details.PSObject.Properties['retry_after']) {
                $retryAfterSeconds = $details.retry_after -as [int]
            }
        }
        catch {
            $retryAfterSeconds = $null
        }

        if (-not $retryAfterSeconds -or $retryAfterSeconds -lt 1) {
            $retryAfterSeconds = [int](
                [Math]::Pow(2, $retry429Count) * $baseRetryDelaySeconds
            )
        }

        $retry429Count++
        Start-Sleep -Seconds $retryAfterSeconds
    }
}
