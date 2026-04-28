# Name: CreateOrganizationsviaCSV.ps1
# Description: Script creates new organizations in Action1 using a list of client names from a CSV file.
#              Skips existing orgs. Fallback to hardcoded list is disabled by default.
#              Please Refresh Console after Orgs have been created.
#              API Account must have Manage Organization rights to create orgs - Following least least privilege access please make an account with only these rights to run this script

# Documentation: https://github.com/Action1Corp/PSAction1/
# Use Action1 Roadmap system (https://roadmap.action1.com/) to submit feedback or enhancement requests.

# WARNING: Carefully study the provided scripts and components before using them. Test in your non-production lab first.

# Action1 Public Repository Material
# Subject to TERMS_OF_USE.md
# Provided AS IS
# Use at your own risk
# Review and test before production deployment
# © Action1 Corporation

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
