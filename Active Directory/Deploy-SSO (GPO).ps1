$GPOName = 'SSO (SingleSignOn)'
if (-not (Get-GPO -Name $GPOName -ErrorAction SilentlyContinue)) {
    Write-Host 'Policy not found. Creating...' -ForegroundColor Yellow
    $GPO = New-GPO -Name $GPOName
    $regKey = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\microsoftazuread-sso.com\autologon'
    Set-GPPrefRegistryValue -Name ($GPO).DisplayName -Context User -Key $regKey -ValueName 'https' -Type DWord -Value 1 -Action Update
    New-GPLink -Name ($GPO).DisplayName -Domain (Get-ADDomain).DNSRoot -Target (Get-ADDomain).DistinguishedName -LinkEnabled Yes
    Write-Host 'Finished!' -ForegroundColor Green
} else {
    Write-Host 'Policy already exists'
    exit
}
