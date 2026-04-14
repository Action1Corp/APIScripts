<#
.SYNOPSIS
Exports Action1 grouped endpoint's software to CSV.

.DESCRIPTION
Retrieves endpoints, their group membership, and installed software.
Supports filtering by endpoint group name.

Copyright (C) 2026 Action1 Corporation
Documentation: https://github.com/Action1Corp/PSAction1/
Use Action1 Roadmap system (https://roadmap.action1.com/) to submit feedback or enhancement requests.

WARNING: Carefully study the provided scripts and components before using them. Test in your non-production lab first.

LIMITATION OF LIABILITY. IN NO EVENT SHALL ACTION1 OR ITS SUPPLIERS, OR THEIR RESPECTIVE 
OFFICERS, DIRECTORS, EMPLOYEES, OR AGENTS BE LIABLE WITH RESPECT TO THE WEBSITE OR
THE COMPONENTS OR THE SERVICES UNDER ANY CONTRACT, NEGLIGENCE, TORT, STRICT 
LIABILITY OR OTHER LEGAL OR EQUITABLE THEORY (I)FOR ANY AMOUNT IN THE AGGREGATE IN
EXCESS OF THE GREATER OF FEES PAID BY YOU THEREFOR OR $100; (II) FOR ANY INDIRECT,
INCIDENTAL, PUNITIVE, OR CONSEQUENTIAL DAMAGES OF ANY KIND WHATSOEVER; (III) FOR
DATA LOSS OR COST OF PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; OR (IV) FOR ANY
MATTER BEYOND ACTION1’S REASONABLE CONTROL. SOME STATES DO NOT ALLOW THE
EXCLUSION OR LIMITATION OF INCIDENTAL OR CONSEQUENTIAL DAMAGES, SO THE ABOVE
LIMITATIONS AND EXCLUSIONS MAY NOT APPLY TO YOU.

.PARAMETER ApiKey
API key for authentication.

.PARAMETER Secret
API secret.

.PARAMETER Region
API region.

.PARAMETER OrgName
Organization name (resolved to OrgId).

.PARAMETER CSVExportPath
Output CSV file path.

.PARAMETER GroupNames
Optional list of endpoint group names to filter.

.NOTES
Minimum PowerShell version: 5.1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ApiKey,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Secret,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Region,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OrgName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$CSVExportPath,

    [string[]]$GroupNames
)

Install-Module -Name PSAction1 -Force
Set-Action1Credentials -APIKey $ApiKey -Secret $Secret
Set-Action1Region -Region $Region

function Get-OrgIdByName {
    param([string]$Name)

    $orgs = Get-Action1 -Query Organizations
    $org  = $orgs | Where-Object { $_.name -eq $Name }

    if (-not $org) {
        throw "Organization '$Name' not found."
    }

    return $org.id
}

Set-Action1DefaultOrg -Org_ID (Get-OrgIdByName -Name $OrgName)

$endpointGroups = Get-Action1 -Query EndpointGroups

if (-not $endpointGroups) {
    throw "Failed to retrieve endpoint groups from API."
}

$validGroupNames = New-Object "System.Collections.Hashtable" ([StringComparer]::Ordinal)
foreach ($endpointGroup in $endpointGroups) {
    $validGroupNames[$endpointGroup.name] = $endpointGroup.id
}


if ($GroupNames -and $GroupNames.Count -gt 0) {

    $invalidGroups = @()
    $allowedGroupIds = @{}

    foreach ($name in $GroupNames) {
        if (-not $validGroupNames.ContainsKey($name)) {
            $invalidGroups += $name
            continue
        }
        $allowedGroupIds[$validGroupNames[$name]] = $true
    }

    if ($invalidGroups.Count -gt 0) {
        Write-Error "Invalid group name(s): $($invalidGroups -join ', ')"
        exit 1
    }
    $filterByGroups = $true
} else {
    $filterByGroups = $false
}

try {
    $endpoints = Get-Action1 -Query Endpoints

    if (-not $endpoints) {
         Write-Error "No endpoints retrieved."
    }
}
catch {
    throw "Failed to retrieve endpoints: $_"
}

if ($filterByGroups) {

    $endpointsToProcess = foreach ($endpoint in $endpoints) {

        $match = $false

        foreach ($endpointGroup in $endpoint.group_membership) {
            if ($allowedGroupIds.ContainsKey($endpointGroup.id)) {
                $match = $true
                break
            }
        }

        if ($match) {
            $endpoint
        }
    }
}
else {
    $endpointsToProcess = $endpoints
}


if (Test-Path $CSVExportPath) {
    Remove-Item $CSVExportPath -Force
}

$firstWrite = $true

function Write-CsvRow {
    param($Object)

    if ($firstWrite) {
        $Object | Export-Csv -Path $CSVExportPath -NoTypeInformation -Encoding UTF8
        $script:firstWrite = $false
    }
    else {
        $Object | Export-Csv -Path $CSVExportPath -NoTypeInformation -Encoding UTF8 -Append
    }
}


$totalEndpointsToProcess = $endpointsToProcess.Count
$endpointCounter = 0

foreach ($endpoint in $endpointsToProcess) {

    $endpointCounter++

    Write-Progress `
        -Activity "Exporting endpoint software..." `
        -Status "$endpointCounter / $totalEndpointsToProcess ($($endpoint.name))" `
        -PercentComplete (($endpointCounter / $totalEndpointsToProcess) * 100)

    try {
        $groups = $endpoint.group_membership
        if (-not $groups) { continue }

        $endpointApps = Get-Action1 -Query EndpointApps -Id $endpoint.id

        if ($endpointApps -and $endpointApps.Fields) {
            $apps = $endpointApps.Fields
        }
        else {
            $apps = @()
        }
    }
    catch {
        Write-Warning "Failed to get endpoint apps or group membership $($endpoint.name): $_"
        continue
    }

    foreach ($group in $groups) {

        if (-not $apps -or $apps.Count -eq 0) {

            Write-CsvRow ([PSCustomObject]@{
                "Endpoint Name"       = $endpoint.name
                "Endpoint Id"         = $endpoint.id
                "Endpoint Group Name" = $group.name
                "Endpoint Group Id"   = $group.id
                "Name"                = $null
                "Version"             = $null
                "Install Location"    = $null
                "Installed For"       = $null
                "Install Date"        = $null
                "Vendor"              = $null
                "Install Type"        = $null
                "Update Status"       = $null
                "Platform"            = $null
            })

            continue
        }

        foreach ($app in $apps) {

            Write-CsvRow ([PSCustomObject]@{
                "Endpoint Name"       = $endpoint.name
                "Endpoint Id"         = $endpoint.id
                "Endpoint Group Name" = $group.name
                "Endpoint Group Id"   = $group.id
                "Name"                = $app.Name
                "Version"             = $app.Version
                "Install Location"    = $app.'Install Location'
                "Installed For"       = $app.'Installed For'
                "Install Date"        = $app.'Install Date'
                "Vendor"              = $app.Vendor
                "Install Type"        = $app.'Install Type'
                "Update Status"       = $app.'Update Status'
                "Platform"            = $app.Platform
            })
        }
    }
}

Write-Host "Export completed: $CSVExportPath"