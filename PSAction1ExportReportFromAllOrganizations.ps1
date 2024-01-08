# The script provided below is an example script. Carefully read it and consider executing it on a test enviroment first.
# Action1 Corporation holds no liability for any damages directly or indirectly caused by running this script.
# script is designed to generate a unique CSV file for each organization, allows for quick reporting across all orgs.
# Report ID can be found in the URL of the report that you are planning to export. example:  https://app.action1.com/console/reports/installed_software_1635264799139/summary?details=no&from=0&limit=50&live_only=no&org=ae4c8042-5a59-c0a4-1499-421f94b9c797 - installed_software_1635264799139 is the report id

# Import the PSAction1 module
Import-Module PSAction1

# Set Directory for CSV Export - Please note area below that completes the directory
$csvFileDirectory = "Insert Directory Here - Example: C:\test"

# Prompt for the report ID - Adjust to match what is shown in Action1 GUI URL
$reportId = Read-Host -Prompt "Enter the Report ID"

# Fetch all organizations
$organizations = Get-Action1 Organizations

# Loop through each organization
foreach ($org in $organizations) {
    # Set the current organization context
    Set-Action1DefaultOrg -Org_ID $org.id

    # Fetch report data for the current organization
    $reportData = Get-Action1 ReportData -Id $reportId 

    # Export the filtered data to a CSV file
    $csvFileName = "$csvFileDirectory\ReportData_Org_" + $org.name + ".csv"
    $reportData | Export-Csv -Path $csvFileName -NoTypeInformation
}


