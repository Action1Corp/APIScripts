# Name: UpdateGroupbyReport.ps1
# Description: Script is designed to compare report endpoint information and update group based on what endpoints are found (or not found) in a report.  
# NOTE BEFORE RUNNING:  You will need to create a report in "Simple Report" in Action1 via Custom Reports that has Endpoint names as the primary sorting function.
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
Set-Action1Credentials -APIKey '<Insert API Key Here>' -Secret '<Insert Secret Here>'
Set-Action1DefaultOrg -Org_ID '<Insert Org_ID here>'
Set-Action1Region -Region '<Enter Region Here>'

# Fetch report data and extract endpoint IDs/names
$reportId = '<Insert Report ID Here>'
$reportEndpointNames = Get-Action1 ReportData -Id $reportId | ForEach-Object { $_.fields.'Endpoint Name' }

# Dictionary for Name/ID lookup.
$Endpoints = @{}
Get-Action1 Endpoints | ForEach-Object {$Endpoints[$_.name] = $_.id}

# Fetch current members of the group
$groupId = '<Insert Group ID Here>' # Adjust to the correct group ID
$group = Get-Action1 Settings -For EndpointGroup -Clone $groupId
$group.ClearIncludeFilter()
$group.ClearExcludeFilter()

$reportEndpointNames | ForEach-Object{
    $group.AddIncludeFilter('id',$($Endpoints[$_]))
}

Update-Action1 Modify EndpointGroup -Id $groupID -Data $group
