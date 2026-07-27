$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", "application/json")
$headers.Add("Authorization", "Bearer <TOKEN>")

$response = Invoke-RestMethod 'https://app.action1.com/api/3.0/me' -Method 'GET' -Headers $headers
$response | ConvertTo-Json