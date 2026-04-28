# Name: EndpointGroupsComparisonCSV.ps1
# Description: script is designed to generate CSV that shows what endpoints are in what groups

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
Install-Module -Name PSAction1
Set-Action1Credentials -APIKey '<your api key>' -Secret '<your secret>'
Set-Action1DefaultOrg -Org_ID '<your org id>'
Set-Action1Region -Region '<Enter Region Here>'

$Exportpath = "<InsertFilePathHere.csv>"

# Initialize other variables
$groupEndpointMapping = @{}

# Fetch all endpoints
$allEndpoints = @()
$endpointsResponse = Get-Action1 -Query Endpoints
$allEndpoints += $endpointsResponse | Select-Object -ExpandProperty name

# Fetch all groups
$allGroups = Get-Action1 -Query EndpointGroups

# Process groups and their members
foreach ($group in $allGroups) {
    $groupMembersResponse = Get-Action1 -Query EndpointGroupMembers -Id $group.id

    $groupMembers = $groupMembersResponse | ForEach-Object { $_.name }
    
    $groupEndpointMapping[$group.name] = $groupMembers
}


# CSV Generation
$csvOutput = @()
foreach ($endpointName in $allEndpoints) {
    $groupsForEndpoint = @()
    foreach ($groupName in $groupEndpointMapping.Keys) {
        if ($endpointName -in $groupEndpointMapping[$groupName]) {
            $groupsForEndpoint += $groupName
        }
    }
    $obj = New-Object PSObject -Property @{
        "Endpoint" = $endpointName
        "Groups"   = if ($groupsForEndpoint.Count -eq 0) { "none" } else { $groupsForEndpoint -join ", " }
    }
    $csvOutput += $obj
}

# Export to CSV
$csvOutput | Select-Object Endpoint, Groups | Export-Csv -Path $Exportpath -NoTypeInformation -Encoding UTF8
