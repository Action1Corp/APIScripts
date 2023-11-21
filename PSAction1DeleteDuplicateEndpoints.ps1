# The script provided below is an example script. Carefully read it and consider executing it on a test enviroment first.
# Action1 Corporation holds no liability for any damages directly or indirectly caused by running this script.
# Script is designed to look for duplicate endpoints in your console and delete all but the newest example of said endpoint.

# Comment out below import/set-action1credentials if not needed, or preformed prior
Install-Module -Name PSAction1
Set-Action1Credentials -APIKey '<Insert API Key Here>' -Secret '<Insert Secret Here>'
Set-Action1DefaultOrg -Org_ID '<Insert Org_ID here>'

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

