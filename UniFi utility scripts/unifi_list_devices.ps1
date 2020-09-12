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

$sites = (Invoke-RestMethod -Uri "$UnifiBaseUri/self/sites" -Method Get -WebSession $websession).data

$devices = @();

foreach ($site in $sites) {
    $sitename = $site.name
    $sitedevices = (Invoke-RestMethod -Uri "$UnifiBaseUri/s/$sitename/stat/device-basic" -Method Get -WebSession $websession).data
    foreach ($device in $sitedevices) {
        $devicelist = New-Object -TypeName psobject 
        $devicelist | Add-Member -memberType NoteProperty -Name 'Site Name' -Value $site.desc;
        $devicelist | Add-Member -memberType NoteProperty -Name 'Device Name' -Value $device.name;
        $devicelist | Add-Member -memberType NoteProperty -Name 'Device Type' -Value $device.type;
        $devicelist | Add-Member -memberType NoteProperty -Name 'Device Model' -Value $device.model;
    
        $devices += $devicelist
    }
}

$devices | Export-Csv unifidevices.csv