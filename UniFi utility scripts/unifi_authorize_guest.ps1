$MacToAuthorize = Read-Host("Enter the MAC address to authorize")
$site_name = Read-Host("Enter the UniFi `"Site Name`" to use")
$cred = Get-Credential -Message "Give UniFi portal Admin creds:"

# UniFi Details
$UniFiFqdn = "unifi.server.com"
$UnifiBaseUri = "https://" + $UniFiFqdn + ":8443/api"
$UnifiCredentials = @{
    username = $cred.UserName
    password = $cred.GetNetworkCredential().password
    remember = $true
} | ConvertTo-Json

#may be necessary to negotiate to TLS1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#login to UniFi to start a session
Invoke-RestMethod -Uri "$UnifiBaseUri/login" -Method POST -Body $UnifiCredentials -SessionVariable websession

#authorize the MAC address
Invoke-RestMethod -Uri "$UnifiBaseUri/s/$site_name/cmd/stamgr" -Method "POST"  -WebSession $websession  -Body "{`"mac`" : `"$MacToAuthorize`", `"cmd`" : `"authorize-guest`"}"