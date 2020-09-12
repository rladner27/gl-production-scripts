#this script copies permission for users holding the Administrator role on the "default" site to all other sites

$cred = Get-Credential -Message "Give UniFi portal SuperAdmin creds:"

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

#Get list of all admins
$admins = (Invoke-RestMethod -Uri "$UnifiBaseUri/stat/admin" -Method Get -WebSession $websession).data

$sites = (Invoke-RestMethod -Uri "$UnifiBaseUri/self/sites" -Method Get -WebSession $websession).data

foreach ($admin in $admins) {
    #we'll get the permissions assigned on the default site
    $default_role = $admin.roles | ? { $_.site_name -eq "default"}
    $default_permissions = $default_role.permissions | ConvertTo-Json
    # We're just working with the Administrator role here (Super Admins already have access to all sites); and they have to have permissions on the default site--client admins will still return on the admins list but their $default_permissions will be $null.
    # For my purposes I don't care about the "Read Only" role
    if (($admin.is_super -eq $false) -and ($null -ne $default_permissions) -and ($default_role.role -eq "admin")) {

        $admin_id = $admin._id

        #and then run through all the sites
        foreach ($site in $sites) {
            $site_name = $site.name

            #Adds them to the site (if necessary) and updates permissions as needed
            Invoke-RestMethod -Uri "$UnifiBaseUri/s/$site_name/cmd/sitemgr" -Method "POST"  -WebSession $websession  -Body "{`"admin`":`"$admin_id`",`"cmd`":`"grant-admin`",`"role`":`"admin`",`"permissions`":$default_permissions}}"
        }
    }
}