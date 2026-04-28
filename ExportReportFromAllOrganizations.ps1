# Name: ExportReportFromAllOrganizations.ps1
# Description: script is designed to generate a unique CSV file for each organization, allows for quick reporting across all orgs.  
# Requires Enterprise Admin rights via API Key to work across all organizations. 
# Report ID can be found in the URL of the report that you are planning to export. 
# Example:  https://app.action1.com/console/reports/installed_software_1635264799139/summary?details=no&from=0&limit=50&live_only=no&org=ae4c8042-5a59-c0a4-1499-421f94b9c797 - installed_software_1635264799139 is the report id

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


