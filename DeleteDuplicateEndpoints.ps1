# Name: DeleteDuplicateEndpoints.ps1
# Description: Script is designed to look for duplicate endpoints in your console and delete all but the newest example of said endpoint.

# Documentation: https://github.com/Action1Corp/PSAction1/
# Use Action1 Roadmap system (https://roadmap.action1.com/) to submit feedback or enhancement requests.

# WARNING: Carefully study the provided scripts and components before using them. Test in your non-production lab first.

# Action1 Public Repository Material
# Subject to TERMS_OF_USE.md
# Provided AS IS
# Use at your own risk
# Review and test before production deployment
# © Action1 Corporation

# Comment out below import/set-action1credentials if not needed, or preformed prior
Install-Module -Name PSAction1 -Force
Set-Action1Credentials -APIKey '<Insert API Key Here>' -Secret '<Insert Secret Here>'
Set-Action1DefaultOrg -Org_ID '<Insert Org_ID here>'
Set-Action1Region -Region '<Enter Region Here>'

try {
    Write-Host "[INFO] Starting endpoint processing..."
    
    $endpointsToCheck = @{}
    $duplicatedEndpoints = New-Object -TypeName System.Collections.ArrayList

    $endpoints = Get-Action1 -Query Endpoints

    if (-not $endpoints) {
        throw "[ERROR] No any endpoints returned"
    }

    $endpoints | ForEach-Object {
        try {
            $currentEndpoint = $_
            if (-not $currentEndpoint) {
                Write-Host "[WARN] Skipping null endpoint object" -ForegroundColor Yellow
                continue
            }
            
            $macKey = $currentEndpoint.mac
            if (-not $macKey) {
                Write-Host "[WARN] Skipping object due to missing MAC for Endpoint: $($currentEndpoint.Id)" -ForegroundColor Yellow
                continue
            }
            
            $last_seen = $currentEndpoint.last_seen
            if (-not $last_seen) {
                Write-Host "[WARN] Skipping object due to missing last_seen for Endpoint: $($currentEndpoint.Id)" -ForegroundColor Yellow
                continue
            }

            try {

                $parts = $last_seen -split '_'

                if ($parts.Count -lt 2) {
                    throw "Invalid last_seen format for Endpoint: $($currentEndpoint.Id)"
                }

                $datePart = $parts[0]
                $timePart = $parts[1] -replace '-', ':'

                $dateString = "$datePart $timePart"

                $TimeParsed = [datetime]::MinValue

                $format = 'yyyy-MM-dd HH:mm:ss'

                if (-not [datetime]::TryParseExact($dateString, $format, $null, [System.Globalization.DateTimeStyles]::None, [ref]$TimeParsed)) {
                    throw "Failed to parse datetime: $dateString"
                }
            }
            catch {
                Write-Host "[ERROR] last_seen Date parsing failed for Endpoint: $($currentEndpoint.Id)"
                continue
            }

            # Ensure MAC key is valid
            if ([string]::IsNullOrWhiteSpace($macKey)) {
                Write-Host "[WARN] Empty MAC detected, skipping Endpoint $($currentEndpoint.Id) processing." -ForegroundColor Yellow
                continue
            }

            $currentEndpointObject = [PSCustomObject]@{
                id        = $currentEndpoint.id
                name      = $currentEndpoint.name
                mac       = $currentEndpoint.mac
                serial    = $currentEndpoint.serial
                last_seen = $TimeParsed
            }

            if ($endpointsToCheck.ContainsKey($macKey)) {

                $existing = $endpointsToCheck[$macKey]

                if (-not $existing -or -not ($existing.last_seen -is [datetime])) {
                    Write-Host "[WARN] Existing record invalid for MAC $macKey, overwriting..."
                    $endpointsToCheck[$macKey] = $currentEndpointObject
                    continue
                }

                # Newer object found
                if ($TimeParsed -gt $existing.last_seen) {

                    try {
                        [void]$duplicatedEndpoints.Add($existing)
                    } catch {
                        Write-Host "[ERROR] Failed adding existing duplicate for MAC $macKey : $_"
                    }

                    $endpointsToCheck[$macKey] = $currentEndpointObject
                    Write-Host "[INFO] Updated newer endpoint for MAC $macKey"
                }
                # Older duplicate found
                else {

                    try {
                        [void]$duplicatedEndpoints.Add($currentEndpointObject)
                    } catch {
                        Write-Host "[ERROR] Failed add duplicate for MAC $macKey : $_"
                    }

                    Write-Host "[INFO] Found older duplicate for MAC $macKey"
                }
            }
            else {
                $endpointsToCheck[$macKey] = $currentEndpointObject
                Write-Host "[INFO] Added new endpoint for MAC $macKey"
            }

        }
        catch {
            Write-Host "[ERROR] Failed processing Endpoint: $($currentEndpoint.Id).  Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host "[INFO] Endpoints processing is complete. Total duplicates found: $($duplicatedEndpoints.Count)" -ForegroundColor Green
}
catch {
    Write-Host "[FATAL] Script execution failed: $_" -ForegroundColor Red
}

if ($duplicatedEndpoints.Count -ge 1){

    $endpointsToDelete = New-Object System.Collections.ArrayList

    Write-Host "`n[INFO] The following $($duplicatedEndpoints.Count) duplicated endpoints detected:" -ForegroundColor Cyan
    $duplicatedEndpoints | Format-Table id, name, mac, last_seen -AutoSize

    $applyToAll = $false

    foreach ($endpoint in $duplicatedEndpoints) {

        if (-not $endpoint) { continue }

        $endpointId = $endpoint.id
        if (-not $endpointId) { continue }

        Write-Host "`nEndpoint--------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "ID        : $($endpoint.id)"
        Write-Host "Name      : $($endpoint.name)"
        Write-Host "MAC       : $($endpoint.mac)"
        Write-Host "Last Seen : $($endpoint.last_seen)"
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

        if (-not $applyToAll) {
            $userInput = Read-Host "Delete this endpoint? (A=Yes to All, Y=Yes, N=No, Enter=Yes)"
        }
        else {
            $userInput = 'y'
        }

        # Default to Yes if Enter pressed
        if ([string]::IsNullOrWhiteSpace($userInput)) { $userInput = 'y' }

        switch ($userInput.ToLower()) {
            'a' {
                $applyToAll = $true
                Write-Host "[INFO] 'Yes to All' selected. This one and all remaining endpoints will be deleted." -ForegroundColor Cyan
                $null = $endpointsToDelete.Add($endpoint)
                Write-Host "[INFO] Marked endpoint ID $endpointId for deletion" -ForegroundColor Yellow
            }
            'y' {
                $null = $endpointsToDelete.Add($endpoint)
                Write-Host "[INFO] Marked endpoint ID $endpointId for deletion" -ForegroundColor Yellow
            }
            'n' {
                Write-Host "[INFO] Skipped endpoint ID $endpointId" -ForegroundColor Gray
            }
            default {
                Write-Host "[WARN] Invalid input '$userInput' → defaulting to YES" -ForegroundColor Yellow
                $null = $endpointsToDelete.Add($endpoint)
            }
        }
    }


    if ($null -ne $endpointsToDelete -and $endpointsToDelete.Count -ge 1){
        #Processing safe force delete
        Write-Host "`n[INFO] Processing deletion of $($endpointsToDelete.Count) endpoints..." -ForegroundColor Cyan

        foreach ($endpoint in $endpointsToDelete) {
            $endpointId = $endpoint.id

            try {
                Write-Host "[INFO] Deleting endpoint with ID: $endpointId" -ForegroundColor Yellow
        
                #No confirmation here because of explicit confirmation above.
                $deleteResponse = Update-Action1 -Action 'Delete' -Type 'Endpoint' -Id $endpointId -Force

                if($null -ne $deleteResponse){
                    Write-Host "[SUCCESS] Deleted endpoint with ID: $endpointId" -ForegroundColor Green
                }
                else{
                    Write-Host "[WARN] No response returned while deleting endpoint with ID: $endpointId" -ForegroundColor DarkYellow
                }
            }
            catch {
                Write-Host "[ERROR] Failed to delete endpoint ID: $endpointId | Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        Write-Host "[INFO] Duplicated Endpoints deleting is complete. Total duplicates removed: $($endpointsToDelete.Count)" -ForegroundColor Green
    }
    else{
        Write-Host "[INFO] No duplicated endpoints of $($duplicatedEndpoints.Count) found were selected to delete. Script execution completed." -ForegroundColor Green   
    }
}
else{
    Write-Host "[INFO] No any duplicated Endpoints found. Script execution completed" -ForegroundColor Yellow
}