# Name: PSAction1DeleteDuplicateEndpoints.ps1
# Description: Script is designed to look for duplicate endpoints in your console and delete all but the newest example of said endpoint.
# Copyright (C) 2024 Action1 Corporation
# Documentation: https://github.com/Action1Corp/PSAction1/
# Use Action1 Roadmap system (https://roadmap.action1.com/) to submit feedback or enhancement requests.

# WARNING: Carefully study the provided scripts and components before using them. Test in your non-production lab first.

# LIMITATION OF LIABILITY. IN NO EVENT SHALL ACTION1 OR ITS SUPPLIERS, OR THEIR RESPECTIVE 
# OFFICERS, DIRECTORS, EMPLOYEES, OR AGENTS BE LIABLE WITH RESPECT TO THE WEBSITE OR
# THE COMPONENTS OR THE SERVICES UNDER ANY CONTRACT, NEGLIGENCE, TORT, STRICT 
# LIABILITY OR OTHER LEGAL OR EQUITABLE THEORY (I)FOR ANY AMOUNT IN THE AGGREGATE IN
# EXCESS OF THE GREATER OF FEES PAID BY YOU THEREFOR OR $100; (II) FOR ANY INDIRECT,
# INCIDENTAL, PUNITIVE, OR CONSEQUENTIAL DAMAGES OF ANY KIND WHATSOEVER; (III) FOR
# DATA LOSS OR COST OF PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; OR (IV) FOR ANY
# MATTER BEYOND ACTION1’S REASONABLE CONTROL. SOME STATES DO NOT ALLOW THE
# EXCLUSION OR LIMITATION OF INCIDENTAL OR CONSEQUENTIAL DAMAGES, SO THE ABOVE
# LIMITATIONS AND EXCLUSIONS MAY NOT APPLY TO YOU.

# Comment out below import/set-action1credentials if not needed, or preformed prior
# Install-Module -Name PSAction1
# Set-Action1Credentials -APIKey '<Insert API Key Here>' -Secret '<Insert Secret Here>'
# Set-Action1DefaultOrg -Org_ID '<Insert Org_ID here>'
# Set-Action1Region -Region '<Enter Region Here>'

$check = @{} # Hash table
$dupe = New-Object System.Collections.ArrayList # Initialize as an ArrayList

$endpoints = Get-Action1 Endpoints
$endpoints | ForEach-Object {
    # Parse object time to true datetime.
    $TimeParsed = $_.last_seen -split '_'
    $TimeParsed = [datetime]([string]::Format("{0} {1}", $TimeParsed[0], $TimeParsed[1].Replace('-',':')))
    if ($check.ContainsKey($_.mac)) {
        # This MAC has been seen, determine who the stale one is based on timestamp.
        if ($TimeParsed -gt $check[$_.mac]['last_seen']) {
            # Evaluated duplicate is newer, add previous comparator value to the remove array.
            $null = $dupe.Add($check[$_.mac])
            # Remove previous comparator from the check hash table.
            $check.Remove($_.mac)
            # Add this new instance as the new comparator.
            $check.Add($_.mac, @{id=$_.id; name=$_.name; mac=$_.mac; serial=$_.serial; last_seen=$TimeParsed})
        } else {
            # This is a duplicate and older than the previous found.
            $null = $dupe.Add(@{id=$_.id; name=$_.name; mac=$_.mac; serial=$_.serial; last_seen=$TimeParsed})
        }
    } else {
        # This MAC is not present, add it as comparator.
        $check.Add($_.mac, @{id=$_.id; name=$_.name; mac=$_.mac; serial=$_.serial; last_seen=$TimeParsed})
    }
}

# Convert $dupe ArrayList into custom objects for better readability and further processing
$customDupeObjects = $dupe | ForEach-Object {
    New-Object psobject -Property $_
}

# Delete the duplicate endpoints
$customDupeObjects | Out-GridView -Title "Duplicate Endpoints" -PassThru | ForEach-Object {
    $endpointId = $_.id
    Write-Host "Deleting endpoint with ID: $endpointId" -ForegroundColor Yellow
    Update-Action1 -Action 'Delete' -Type 'Endpoint' -Id $endpointId #-force #- Uncomment -force to skip prompt "Are you sure you want to Delete Endpoint"
}

