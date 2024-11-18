# Name: CustomAttributeUpdateGroupsAllOrgs.ps1
# Description: script is designed to update the Custom Attribute renamed "Groups" with the 
#   groups each endpoint is a member of. By default, this script will go through all of the organizations in 
#   your Enterprise and check for the groups each endpoint is a memnber of.  If you only want one organization 
#   checked, create API credentials for that one organization and use those in script below.
#
# To use this script,  please edit the script and update the following:
#   1) uncomment the Install module try/catch section if needed in your environment
#   2) Update the API_Key with your API key.   
#   3) Update the Set-Action1Credentials line with your secret
#   4) Update the log directory with your desired location for logging file 
#      *** NOTE this file is restarted on each run,  if you want to append file to see multiple runs,  comment out the Remove-Item line below.
#   5) Update Set-Action1Region to your region if you are not in NorthAmerica (Europe)
# 
# In Action1 console, go to Advanced->Endpoint Custom Attributes
#   1) Update one of the Custom Attribute names to match "Groups" Spelling, Capitalization and Spacing count
#
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


# NOTE:   Uncomment following try/catch lines if Action1 Powershell Module is not loaded

#try {
#    Install-Module -Name PSAction1
#}
#catch {
#    Write-Host "ERROR: Unable to install Action1 PSAction1 Powershell integration module"
#    Exit
#}
 
$ErrorActionPreference = "Stop"
#
# NOTE:  You must enter your enterprise wide apikey, secret and region in the sections below
#

$api_Key = "api-key-YourKeyHere@action1.com"
$api_secret = "123YourSecretHere321"
$api_Region = "NorthAmerica"  # or Europe / Australia

# Define the log file location
$logFile = "C:\tmp\UpdateGroupCustomAttribute.log"

# Delete log file to only log this session
if ( Test-Path -path $logFile ) {
    Remove-Item -Path $logFile
}

# Function to write messages to the log file with timestamps
function Write-Log {
    param (
        [string]$message,
        [string]$type = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$type] $message"
    # Append the log entry to the file
    Add-Content -Path $logFile -Value $logEntry
}

# Start of script - log initiation
Write-Log "****** : Starting update Custom Attribute Groups ."


try {
    Set-Action1Credentials -APIKey $api_Key -Secret $api_secret
}
catch {
    Write-Host "ERROR: Unable to get credentials for for $api_Key "
    Write-Log "ERROR: Unable to get credentials for for $api_Key " "ERROR"
    Exit
}

try {
    Set-Action1Region -Region $api_Region
}
catch {
    Write-Host "ERROR: Unable to set Action1 Region $api_Region "
    Write-Log "ERROR: Unable to set Action1 Region $api_Region " "ERROR"
    Exit
}

try {
	$orgData = Get-Action1 Organizations
}
catch {
    Write-Host "ERROR: Unable to retrieve organizations for API Key $api_Key "
    Write-Host " Check key, secret value and region definition "
    Write-Log "ERROR: Unable to retrieve organizations for API Key $api_Key " "ERROR"
    Write-Log " Check key, secret value and region definition " "ERROR"
    Exit
}

foreach ($org in $orgData) {
   
    Write-Host "Processing Organization : $($org.name)"
    Write-Log "Processing Organization : $($org.name)"

    try {
        Set-Action1DefaultOrg -Org_ID $org.id
    }
    catch {
        Write-Host "ERROR: Unable to set Org_ID $($org.name)"
        Write-Log "ERROR: Unable to set Org_ID $($org.name)" "ERROR"
    }
    
    $groupEndpointMapping = @{}
    
    try {
        $allEps = Get-Action1 -Query Endpoints
    }
    catch {
        Write-Host "ERROR: Unable to query endpoints for organization $($org.name)"
        Write-Log "ERROR: Unable to query endpoints for organization $($org.name)" "ERROR"
    }

    if (-not $allEps -or $allEps.total_items -eq 0) {
        Write-Host "No Endpoints in Organization $($org.name) "
        Write-Log "ORGANIZATION : $($org.name) Has No Endpoints" "WARNING"
    } else {
        Write-Host "Processing Endpoints in $($org.name) "
        Write-Log "ORGANIZATION : $($org.name) "
      
# Fetch all groups
        
        try {
            $allGroups = Get-Action1 -Query EndpointGroups
        }
        catch {
            Write-Host "ERROR: Unable to query endpoint groups from organization $($org.name)"
            Write-Log "ORGANIZATION : $($org.name) Has No Groups" "WARNING"
        
        }
       
# Process groups and their members
        foreach ($group in $allGroups) {
            try {
                $groupMembersResponse = Get-Action1 -Query EndpointGroupMembers -Id $group.id
            }
            catch {
                Write-Host "ERROR: Unable to query endpoint group members from Group $($group.name)"
                Write-Log "ERROR: Unable to query endpoint group members from Group $($group.name)" "ERROR"
            }
            $groupMembers = $groupMembersResponse | ForEach-Object { $_.name }
    
            $groupEndpointMapping[$($group.name)] = $groupMembers
    
        }

        Foreach ($endpointName in $allEps) {
            
            $groupsforEndpoint = @()
            Write-Host " " $($endpointName.name) 
            # Write-Log " $($endpointName.name) "
            foreach ($groupName in $groupEndpointMapping.Keys) {
                if ($($endpointName.name) -in $groupEndpointMapping[$groupName]) {
                    $groupsForEndpoint += $groupName + ","
                } 
            }
            $glen = $groupsForEndpoint.Count
            if ($glen -ne 0) {
                $gname = $groupsForEndpoint[$glen-1]
                $gname = $gname.Substring(0,$gname.Length-1)  # Remove comma from last group in array
                $groupsForEndpoint[$glen-1]=$gname
            }
            Write-Log "$($endpointName.name) in groups $groupsForEndpoint "
    
#
# NOTE:  One of the Custom Attribute names must be changed to "Groups"
# Use the Groups attribute to filter reports, etc   
#
            try {
                Update-Action1 Modify CustomAttribute -Id "$($endpointName.id)" -AttributeName "Groups" -AttributeValue "$groupsForEndpoint"
            }
            catch {
                Write-Host "ERROR: Unable to update Group custom attribute on endpoint $($endpointName.name)"
                Write-Log "ERROR: Unable to update Group custom attribute on endpoint $($endpointName.name)" "ERROR"
            }
            
        }
    }
}
Write-Host "Script completed - Exit "
Write-Log "****** : Script completed : Exit "
