# Name: AD_Attributes_to_Action1_Attributes.ps1
# Description: This script will query an attribute for each computer object in a domain and update its corresponding attribute in Aciton1.
# Copyright (C) 2024 Action1 Corporation
# Documentation: https://www.action1.com/documentation/add-custom-packages-to-app-store/

# Use Action1 Roadmap system (https://roadmap.action1.com/) to submit feedback or enhancement requests.

# WARNING: Carefully study the provided scripts and components before using them. Test in your non-production lab first.

# LIMITATION OF LIABILITY. IN NO EVENT SHALL ACTION1 OR ITS SUPPLIERS, OR THEIR RESPECTIVE
# OFFICERS, DIRECTORS, EMPLOYEES, OR AGENTS BE LIABLE WITH RESPECT TO THE WEBSITE OR
# THE COMPONENTS OR THE SERVICES UNDER ANY CONTRACT, NEGLIGENCE, TORT, STRICT
# LIABILITY OR OTHER LEGAL OR EQUITABLE THEORY (I)FOR ANY AMOUNT IN THE AGGREGATE IN
# EXCESS OF THE GREATER OF FEES PAID BY YOU THEREFOR OR $100; (II) FOR ANY INDIRECT,
# INCIDENTAL, PUNITIVE, OR CONSEQUENTIAL DAMAGES OF ANY KIND WHATSOEVER; (III) FOR
# DATA LOSS OR COST OF PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; OR (IV) FOR ANY
# MATTER BEYOND ACTION1'S REASONABLE CONTROL. SOME STATES DO NOT ALLOW THE
# EXCLUSION OR LIMITATION OF INCIDENTAL OR CONSEQUENTIAL DAMAGES, SO THE ABOVE
# LIMITATIONS AND EXCLUSIONS MAY NOT APPLY TO YOU.

Set-Action1Credentials -APIKey '<your API key>' -Secret '<your secret>'
Set-Action1DefaultOrg -Org_ID '<your org id>'
Set-Action1Region -Region NorthAmerica
Set-Action1Debug $true

#create and populate a dictionary object to perform name/id lookups.
$A1EndPoints = New-Object 'System.Collections.Generic.Dictionary[System.String, System.String]'
Get-Action1 Endpoints | Select Name, ID | ForEach-Object { $A1EndPoints.Add($_.Name,$_.ID)}

Get-ADComputer -Filter * -Properties Location | ForEach-Object{
    if($A1EndPoints.ContainsKey($_.DNSHostName)){
        if(-not [string]::IsNullOrEmpty($_.Location)){Update-Action1 Modify CustomAttribute -Id $($A1EndPoints[$_.DNSHostName]) -AttributeName "Location" -AttributeValue $_.Location}
    }
}