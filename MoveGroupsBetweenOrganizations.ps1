# Name: Move_Endpoints_Between_Orgs_by_Group.ps1
# Description: This script moves Action1 endpoints from a specified group in one organization to another after user confirmation.
# Requires -Modules PSAction1

#------------------------------------------------------------------------------------
# --- CONFIGURATION ---
# The script will prompt you to enter the necessary information.
#------------------------------------------------------------------------------------
$ApiClientID = Read-Host -Prompt "Enter your Action1 API Client ID"
$ApiClientSecret = Read-Host -Prompt "Enter your Action1 API Client Secret"
$Region = Read-Host -Prompt "Enter your Action1 Region (e.g., NorthAmerica, Europe)"
$OrgIdToMoveFrom = Read-Host -Prompt "Enter the Organization ID to MOVE COMPUTERS FROM"
$OrgIdToMoveTo = Read-Host -Prompt "Enter the Organization ID to MOVE COMPUTERS TO"
$GroupName = Read-Host -Prompt "Enter the exact display name of the group whose members you want to move"

# --- Automation Settings ---
$MaxRetries = 3
$ApiTimeoutSeconds = 10

#------------------------------------------------------------------------------------
# --- SCRIPT BODY ---
#------------------------------------------------------------------------------------

try {
    # --- SETUP AND AUTHENTICATION ---
    Write-Host "INFO: Importing modules and authenticating with Action1..."
    Import-Module PSAction1 -Force
    Set-Action1Region -Region $Region
    Set-Action1Credentials -APIKey $ApiClientID -Secret $ApiClientSecret
    Set-Action1DefaultOrg -Org_ID $OrgIdToMoveFrom
    Write-Host "SUCCESS: Authentication successful. Context set to source organization."
    Write-Host "------------------------------------------------------------"


    # --- INFORMATION GATHERING ---
    Write-Host "INFO: Gathering information... (no changes made yet)"
    $allOrgs = Get-Action1 -Query Organizations
    $sourceOrgName = ($allOrgs | Where-Object { $_.id -eq $OrgIdToMoveFrom }).name
    $targetOrgName = ($allOrgs | Where-Object { $_.id -eq $OrgIdToMoveTo }).name
    if (-not $sourceOrgName -or -not $targetOrgName) { throw "Could not find source or target organization." }

    Write-Host "INFO: Searching for group '$GroupName' in organization '$sourceOrgName'..."
    $targetGroup = (Get-Action1 -Query EndpointGroups) | Where-Object { $_.name -eq $GroupName }
    if (-not $targetGroup) { throw "Group '$GroupName' not found in organization '$sourceOrgName'." }
    
    $targetGroupId = $targetGroup.id
    Write-Host "SUCCESS: Found group '$GroupName' with ID '$targetGroupId'."

    $endpointsToMove = Get-Action1 -Query EndpointGroupMembers -Id $targetGroupId
    if (-not $endpointsToMove) {
        Write-Host "WARNING: The group '$GroupName' is empty. No endpoints to move."
        return
    }
    $endpointCount = ($endpointsToMove | Measure-Object).Count
    Write-Host "SUCCESS: Found $endpointCount endpoint(s) in group '$GroupName'."
    Write-Host "------------------------------------------------------------"


    # --- USER CONFIRMATION ---
    Write-Host "ACTION REQUIRED: Please confirm the move operation."
    Write-Host "You are about to move" -NoNewline; Write-Host " $endpointCount " -NoNewline; Write-Host "endpoint(s)."
    Write-Host "FROM Organization: '$sourceOrgName' ($OrgIdToMoveFrom)"
    Write-Host "TO   Organization: '$targetOrgName' ($OrgIdToMoveTo)"
    Write-Host "FROM Group:        '$GroupName'"
    Write-Host
    $confirmation = Read-Host -Prompt "==> Are you sure you want to proceed? Type 'yes' to continue"
    if ($confirmation.ToLower() -ne 'yes') {
        Write-Host "CANCELLED: Move operation was cancelled by the user."
        return
    }
    Write-Host "CONFIRMED: User approved the move. Proceeding with execution..."
    Write-Host "------------------------------------------------------------"


    # --- EXECUTION PHASE ---
    $movedCount = 0
    $errorCount = 0

    # Get Auth Token
    Write-Host "INFO: Requesting a dedicated access token for the move operation..."
    $tokenUri = "https://app.action1.com/api/3.0/oauth2/token"
    $tokenBody = @{ client_id = $ApiClientID; client_secret = $ApiClientSecret } | ConvertTo-Json
    $tokenResponse = Invoke-RestMethod -Uri $tokenUri -Method Post -Body $tokenBody -ContentType 'application/json' -TimeoutSec $ApiTimeoutSeconds
    $AccessToken = $tokenResponse.access_token
    if (-not $AccessToken) { throw "FATAL: Could not obtain an access token." }
    Write-Host "SUCCESS: Access token obtained."

    $headers = @{ "Authorization" = "Bearer $AccessToken"; "Content-Type"  = "application/json" }

    # Loop through each endpoint
    foreach ($endpoint in $endpointsToMove) {
        $endpointId = $endpoint.id
        $endpointName = $endpoint.name
        Write-Host "INFO: Processing endpoint '$endpointName' (ID: $endpointId)..."

        $moveSuccessful = $false
        for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
            try {
                # Execute the move request with a timeout
                $moveUri = "https://app.action1.com/api/3.0/endpoints/managed/$OrgIdToMoveFrom/$endpointId/move"
                $moveBody = @{ "target_organization_id" = $OrgIdToMoveTo } | ConvertTo-Json
                $null = Invoke-RestMethod -Uri $moveUri -Method Post -Headers $headers -Body $moveBody -ErrorAction Stop -TimeoutSec $ApiTimeoutSeconds
                
                Write-Host "  -> SUCCESS: Moved '$endpointName' on attempt $attempt."
                $movedCount++
                $moveSuccessful = $true
                break # Exit the retry loop for this endpoint
            }
            catch {
                # Handle the error from the API call
                $errorMessage = "An unknown error occurred."
                if ($_.Exception.Message -like "*The operation has timed out*") { $errorMessage = "The request timed out after $ApiTimeoutSeconds seconds." }
                elseif ($_.Exception.Response) {
                    $errorResponseStream = $_.Exception.Response.GetResponseStream()
                    $streamReader = New-Object System.IO.StreamReader($errorResponseStream)
                    $apiError = $streamReader.ReadToEnd() | ConvertFrom-Json
                    if ($apiError.user_message) { $errorMessage = $apiError.user_message }
                } else { $errorMessage = $_.Exception.Message }

                Write-Host "  -> FAILED (Attempt $attempt/$MaxRetries): $errorMessage"

                if ($attempt -lt $MaxRetries) {
                    $delaySeconds = [math]::Pow(2, $attempt)
                    $jitterMilliseconds = Get-Random -Minimum 250 -Maximum 1000
                    $totalWait = $delaySeconds + ($jitterMilliseconds / 1000.0)
                    Write-Host "     Retrying in $($totalWait.ToString("F1")) seconds..."
                    Start-Sleep -Seconds $totalWait
                }
            }
        } # End of retry loop

        if (-not $moveSuccessful) {
            Write-Host "  -> ERROR: Failed to move '$endpointName' after $MaxRetries attempts."
            $errorCount++
        }
    } # End of foreach endpoint loop

    Write-Host "------------------------------------------------------------"
    Write-Host "MOVE OPERATION COMPLETE"
    Write-Host "Successfully moved: $movedCount endpoint(s)."
    Write-Host "Failed to move:   $errorCount endpoint(s)."
}
catch {
    $fatalErrorMessage = $_.Exception.Message
    Write-Host "FATAL SCRIPT ERROR: $fatalErrorMessage"
    Write-Host "------------------------------------------------------------"
}