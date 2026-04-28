# Name: EndpointGroupAutomationComparisonCSV.ps1
# Description: script is designed to generate CSV that shows what endpoints and groups are assigned to automations

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

$GroupExportpath = "<InsertFilePathHere.csv>"
$EndpointExportpath = "<InsertFilePathHere.csv>"

# Initialize hashtables to store the mappings
$groupPolicyMapping = @()
$endpointPolicyMapping = @()

# Fetch All Groups with Paging
$allGroups = Get-Action1 -Query EndpointGroups

# Fetch All Endpoints with Paging
$allEndpoints = Get-Action1 -Query Endpoints

# Fetch All Policies\Automations with Paging
$allPolicies = Get-Action1 -Query Automations

# Create lookup tables for group and endpoint names by their IDs
$groupNames = @{}
$allGroups | ForEach-Object { $groupNames[$_.id] = $_.name }

$endpointNames = @{}
$allEndpoints | ForEach-Object { $endpointNames[$_.id] = $_.name }

# Iterate through all groups and find their corresponding policies\automations
foreach ($group in $allGroups) {
    $policiesForGroup = @()

    foreach ($policy in $allPolicies) {
        $policyEndpoints = $policy.endpoints | Select-Object -ExpandProperty id

        if ($policyEndpoints -contains $group.id) {
            $policiesForGroup += $policy.name
        }
    }

    $groupPolicyMapping += [PSCustomObject]@{
        GroupName = $group.name
        Policies  = if ($policiesForGroup) { $policiesForGroup -join ', ' } else { 'none' }
    }
}

# Handle the "ALL" case for groups
$policiesForAllGroups = @()
foreach ($policy in $allPolicies) {
    $policyEndpoints = $policy.endpoints | Select-Object -ExpandProperty id

    if ($policyEndpoints -contains "ALL") {
        $policiesForAllGroups += $policy.name
    }
}

$groupPolicyMapping += [PSCustomObject]@{
    GroupName = "ALL"
    Policies  = if ($policiesForAllGroups) { $policiesForAllGroups -join ', ' } else { 'none' }
}

# Iterate through all endpoints and find their corresponding policies\automations
foreach ($endpoint in $allEndpoints) {
    $policiesForEndpoint = @()

    foreach ($policy in $allPolicies) {
        $policyEndpoints = $policy.endpoints | Select-Object -ExpandProperty id

        if ($policyEndpoints -contains $endpoint.id) {
            $policiesForEndpoint += $policy.name
        }
    }

    $endpointPolicyMapping += [PSCustomObject]@{
        EndpointName = $endpoint.name
        Policies     = if ($policiesForEndpoint) { $policiesForEndpoint -join ', ' } else { 'none' }
    }
}

# Export the results to two CSV files
$groupPolicyMapping | Export-Csv -Path $GroupExportpath -NoTypeInformation -Encoding UTF8
$endpointPolicyMapping | Export-Csv -Path $EndpointExportpath -NoTypeInformation -Encoding UTF8
