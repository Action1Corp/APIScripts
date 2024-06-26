# Name: PSAction1EndpointGroupPolicyComparisonCSV.ps1
# Description: script is designed to generate CSV that shows what endpoints and groups are assigned to automations
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
