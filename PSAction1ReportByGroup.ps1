# The script provided below is an example script. Carefully read it and consider executing it on a test enviroment first.
# Action1 Corporation holds no liability for any damages directly or indirectly caused by running this script.
# script is designed to generate CSV files that show what data is applicable for each endpoint in a certain group. This script as built is designed to work with the Missing Third-Party & Windows Updates and to only Show endpoint name and Update Name - This can be edited below

# PSAction1 PowerShell Script for Group Report Analysis
# Comment out below import/set-action1credentials if not needed, or preformed prior
Install-Module -Name PSAction1
Set-Action1Credentials -APIKey '<your api key>' -Secret '<your secret>'
Set-Action1DefaultOrg -Org_ID '<your org id>'

$csvFileDirectory = "<Insert Directory Here>"
$reportData = Get-Action1 ReportData -Id "<Insert Report ID Here>"  #Please create report by cloning report and turning into simple report that sorts by endpoint

# Step 1: Retrieve Endpoint Groups
$endpointGroups = Get-Action1 EndpointGroups

# Step 2: Retrieve all endpoints in each group and store in a hashtable for quick lookup
$groupEndpointsHashtable = @{}
foreach ($group in $endpointGroups) {
    $groupEndpoints = Get-Action1 EndpointGroupMembers -ID $group.id
    $groupEndpointsHashtable[$group.id] = $groupEndpoints
}

# Step 3 & 4: Filter Report Data for Each Group and Export to CSV
foreach ($group in $endpointGroups) {
    # Retrieve endpoints for current group from hashtable
    $currentGroupEndpoints = $groupEndpointsHashtable[$group.id]

    # Filter report data based on current group endpoints
    $filteredReportData = foreach ($data in $reportData) {
        $endpointName = $data.fields.'Endpoint Name'
        if ($currentGroupEndpoints.name -contains $endpointName) {
            # Create custom object for each record that matches the group - Note can be adjusted to show different report fields to work with different reports
            [PSCustomObject]@{
                EndpointName = $endpointName
                UpdateName   = $data.fields.'Update Name'
            }
        }
    }

    # Export the filtered data to a CSV file
    $csvFileName = "$csvFileDirectory\ReportData_Group_" + $group.name + ".csv"
    $filteredReportData | Export-Csv -Path $csvFileName -NoTypeInformation
}

