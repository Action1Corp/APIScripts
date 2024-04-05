# Name: PSAction1ReportByGroup.ps1
# Description: script is designed to generate CSV files that show what data is applicable for each endpoint in a certain group. This script as built is designed to work with the Missing Third-Party & Windows Updates and to only Show endpoint name and Update Name - This can be edited below
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

# PSAction1 PowerShell Script for Group Report Analysis
# Comment out below import/set-action1credentials if not needed, or preformed prior
Install-Module -Name PSAction1
Set-Action1Credentials -APIKey '<your api key>' -Secret '<your secret>'
Set-Action1DefaultOrg -Org_ID '<your org id>'
Set-Action1Region -Region '<Enter Region Here>'

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

