# The script provided below is an example script. Carefully read it and consider executing it on a test enviroment first.
# Action1 Corporation holds no liability for any damages directly or indirectly caused by running this script.
# script is designed to generate CSV that shows what endpoints are in what groups

# Comment out below import/set-action1credentials if not needed, or preformed prior
Install-Module -Name PSAction1
Set-Action1Credentials -APIKey '<your api key>' -Secret '<your secret>'
Set-Action1DefaultOrg -Org_ID '<your org id>'

$Exportpath = "<InsertFilePathHere.csv"

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
