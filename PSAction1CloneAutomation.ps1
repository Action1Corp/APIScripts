# Name: PSAction1CloneAutomation.ps1
# Description: Script is designed to allow for cloning of automations via a simple to use wizard.  
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
# Install-Module -Name PSAction1
# Set-Action1Credentials -APIKey '<Insert API Key Here>' -Secret '<Insert Secret Here>'
# Set-Action1DefaultOrg -Org_ID '<Insert Org_ID here>'
# Set-Action1Region -Region '<Enter Region Here>'

# Step 1: Select Source Organization for Cloning
$orgData = Get-Action1 Organizations
$orgData = [array]$orgData
for ($i = 0; $i -lt $orgData.Count; $i++) {
    Write-Host "$($i + 1): $($orgData[$i].name)"
}
$orgSelection = Read-Host "Enter the number of the org you want to select for cloning the automation"
$sourceOrgIndex = [int]$orgSelection.Trim() - 1
$sourceOrg = $orgData[$sourceOrgIndex]
Write-Host "Selected Source Organization: $($sourceOrg.name) with ID: $($sourceOrg.id)"
$sourceOrgID = $sourceOrg.id

# Step 2: Select Automation to Clone
Set-Action1DefaultOrg -Org_ID $sourceOrgID
$automationData = Get-Action1 Automations
if ($automationData.id -eq 1 -and $automationData.total_items -eq 0) {
    Write-Host "No automations available to clone in the selected organization."
    return
}
for ($i = 0; $i -lt $automationData.Count; $i++) {
    Write-Host "$($i + 1): $($automationData[$i].name)"
}
$automationSelection = Read-Host "Enter the number of the automation you want to clone"
$automationIndex = [int]$automationSelection.Trim() - 1
if ($automationIndex -lt 0 -or $automationIndex -ge $automationData.Count) {
    Write-Host "Invalid selection. Exiting script."
    return
}
$selectedAutomation = $automationData[$automationIndex]
Write-Host "Selected Automation for Cloning: $($selectedAutomation.name) with ID: $($selectedAutomation.id)"
$AutomationID = $selectedAutomation.id
$clonedAutomation = Get-Action1 Settings -For Automation -Clone $AutomationID

# Step 3: Select Target Organizations for Cloning
$orgData = Get-Action1 Organizations
for ($i = 0; $i -lt $orgData.Count; $i++) {
    Write-Host "$($i + 1): $($orgData[$i].name)"
}
$orgSelection = Read-Host "Enter the numbers of the orgs you want to clone to, separated by commas, or enter 'All' for all organizations except the source"
if ($orgSelection -eq "All") {
    # Filter out the source organization from the list of target organizations
    $targetOrgs = $orgData | Where-Object { $_.id -ne $sourceOrgID }
} else {
    $targetOrgIndices = $orgSelection -split ','
    $targetOrgs = @()
    foreach ($index in $targetOrgIndices) {
        $i = [int]$index.Trim() - 1
        if ($i -ge 0 -and $i -lt $orgData.Count) {
            $targetOrgs += $orgData[$i]
        }
    }
}
$targetOrgs | ForEach-Object { Write-Host "Selected Target Org: $($_.name) with ID: $($_.id)" }

# Step 4: Clone Automation to Target Organizations and Capture New IDs
$clonedAutomations = @{}
foreach ($targetOrg in $targetOrgs) {
    Set-Action1DefaultOrg -Org_ID $targetOrg.id
    $cloned = New-Action1 -Item 'Automation' -Data $clonedAutomation
    Write-Host "Cloned Automation to $($targetOrg.name)"
    $clonedAutomations[$targetOrg.id] = $cloned.id
}

# Steps 5 to 7: Add Groups and Update Cloned Automations in Each Target Organization
foreach ($targetOrg in $targetOrgs) {
    Set-Action1DefaultOrg -Org_ID $targetOrg.id
    $groupData = Get-Action1 EndpointGroups
    $selectedGroups = @()

    # Ensure $groupData is always treated as an array
    $groupData = @(Get-Action1 EndpointGroups)

    if ($groupData.Count -eq 0) {
        Write-Host "No groups available to add in organization $($targetOrg.name)."
        $userChoice = Read-Host "Do you want to leave the group section empty (Enter 'Empty') or apply to 'All' endpoints? (Enter 'All')"
        if ($userChoice -eq "All") {
            $selectedGroups = @(@{id="ALL"; type="EndpointGroup"})
        } elseif ($userChoice -eq "Empty") {
            Write-Host "Proceeding without specifying groups."
        } else {
            Write-Host "Invalid input. Exiting script."
            return
        }
    } else {
        # Display the groups, handling single or multiple group objects
        for ($i = 0; $i -lt $groupData.Count; $i++) {
            Write-Host "$($i + 1): $($groupData[$i].name)"
        }
        $groupSelection = Read-Host "Enter the number of the group you want to add to the automation in $($targetOrg.name), or enter 'All' for all Endpoints"
        if ($groupSelection -eq "All") {
            $selectedGroups = @(@{id="ALL"; type="EndpointGroup"})
        } else {
            $groupIndices = $groupSelection -split ','
            foreach ($index in $groupIndices) {
                $i = [int]$index.Trim() - 1
                if ($i -ge 0 -and $i -lt $groupData.Count) {
                    $groupID = $groupData[$i].id
                    $selectedGroups += New-Object PSObject -Property @{id=$groupID; type='EndpointGroup'}
                }
            }
        }
    }

    $newAutomationID = $clonedAutomations[$targetOrg.id]
    $clonedAutomation.endpoints = $selectedGroups

    Update-Action1 Modify -Type Automation -Id $newAutomationID -Data $clonedAutomation
    Write-Host "Updated Cloned Automation in $($targetOrg.name) with selected endpoints/groups."
}
