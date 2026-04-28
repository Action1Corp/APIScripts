# Name: AdToAction1Attributes.ps1
# Description: This script will query an attribute for each computer object in a domain and update its corresponding attribute in Aciton1.

# Documentation: https://www.action1.com/documentation/add-custom-packages-to-app-store/
# Use Action1 Roadmap system (https://roadmap.action1.com/) to submit feedback or enhancement requests.

# Action1 Public Repository Material
# Subject to TERMS_OF_USE.md
# Provided AS IS
# Use at your own risk
# Review and test before production deployment
# © Action1 Corporation

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