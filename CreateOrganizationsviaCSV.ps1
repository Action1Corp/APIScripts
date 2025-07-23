# Name: PSAction1CreateOrganizations.ps1﻿
# Description: Script creates new organizations in Action1 using a list of client names from a CSV file.
#              Skips existing orgs. Fallback to hardcoded list is disabled by default.
#              Please Refresh Console after Orgs have been created.
#              API Account must have Manage Organization rights to create orgs - Following least least privilege access please make an account with only these rights to run this script
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

# ------------------------------------------------------------
# Step 0: Import PSAction1 module and authenticate
# ------------------------------------------------------------

Install-Module PSAction1
Set-Action1Credentials -APIKey '<Insert API Key Here>' -Secret '<Insert Secret Here>'
Set-Action1Region -Region 'NorthAmerica'   # Options: NorthAmerica, Europe, Australia

# ------------------------------------------------------------
# Step 1: Load client organizations from CSV - Mandatory headers are Name, Description is Optional and will be autofilled if not included. 
# ------------------------------------------------------------

# CSV format: Name,Description
$csvPath = "Insert CSV File Path Here"

if (-not (Test-Path $csvPath)) {
    Write-Error "CSV file '$csvPath' not found. Please provide a valid input file."
    exit 1
}

$clients = Import-Csv -Path $csvPath
Write-Host "✔ Loaded $($clients.Count) organizations from CSV: $csvPath"

# ------------------------------------------------------------
# Step 2: Get existing organizations to avoid duplicates
# ------------------------------------------------------------

$existingOrgs = Get-Action1 Organizations

# ------------------------------------------------------------
# Step 3: Create organizations if they don't already exist
# ------------------------------------------------------------

foreach ($client in $clients) {
    $orgName = $client.Name
    $orgDescription = $null

    # Use description if available, otherwise set a default
    if ($client.PSObject.Properties['Description'] -and -not [string]::IsNullOrWhiteSpace($client.Description)) {
        $orgDescription = $client.Description
    } else {
        $orgDescription = "Created by automation for $orgName"
    }

    # Check if org already exists
    $exists = $existingOrgs | Where-Object { $_.name -ieq $orgName }

    if ($exists) {
        Write-Host "⚠ Organization '$orgName' already exists. Skipping..."
        continue
    }

    # Create the organization
    $orgPayload = @{
        name        = $orgName
        description = $orgDescription
    }

    try {
        $result = New-Action1 -Item 'Organization' -Data $orgPayload
        Write-Host "✔ Created organization '$orgName' with ID: $($result.id)"
    } catch {
        Write-Host "✖ Failed to create organization '$orgName': $_"
    }
}
