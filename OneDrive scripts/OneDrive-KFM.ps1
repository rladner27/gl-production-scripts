<#
.SYNOPSIS
    A script to create a OneDrive GPO for Known Folder Move and Central Policy Store for AD.
.DESCRIPTION
    This script checks to see if the GPO and/or policy store are missing.
    If neither are found, they will be created. This will also check for OneDrive ADMX/L files
    and create if missing.
.EXAMPLE
    PS C:\> .\OneDrive-KFM.ps1
    Run the script with elevated permissions
.NOTES
    ADMX/ADML files are pulled from Microsoft (latest is Windows 10 May 2020 Update (2004))
#>

$ErrorActionPreference = 'Stop'
$GPOName = 'OneDrive-KFM'
$dnsroot = (Get-ADDomain).DNSRoot
$policypath = "SYSVOL\sysvol\$dnsroot\Policies\PolicyDefinitions\"
$policystore = Join-Path $env:SystemRoot $policypath

function Copy-OneDriveFiles {
    $onedriveURL = 'https://bit.ly/2FugP59'
    $zipfilelocation = "$env:TEMP\OneDriveADMXFiles.zip"
    (New-Object System.Net.WebClient).DownloadFile($onedriveURL, $zipfilelocation)
    Expand-Archive -Path $zipfilelocation -DestinationPath $env:TEMP -Force
    $admfiles = Get-ChildItem -Path $env:Temp -Filter '*.adm*'
    foreach ($file in $admfiles) {
        if ($file.Name -match '.adml' ) {
            Move-Item -Path "$env:TEMP\OneDrive.adml" -Destination (Join-Path $policystore 'en-US') -Force
        } else {
            Move-Item -Path "$env:TEMP\OneDrive.admx" -Destination $policystore -Force
        }
    }
}

function Get-OneDriveFiles {
    if (-not (Test-Path -LiteralPath (Join-Path $policystore 'OneDrive.admx') -PathType Leaf)) {
        return $false
    } else {
        return $true
    }
}

# Create the policy store if it doesn't exist
try {
    if ((Test-Path $policystore)) {
        Write-Host 'Central policy store already in place'
    } else {
        Write-Host 'Central policy store not configured. Creating...'
        $null = New-Item -Path $policystore -ItemType Directory
        $url = 'https://bit.ly/32Bzyo7'
        $installer = "$env:TEMP\AdministrativeTemplates(2004).msi"
        (New-Object System.Net.WebClient).DownloadFile($url, $installer)
        $process = Start-Process cmd -Wait -ArgumentList "/c msiexec /i $installer /qn" -NoNewWindow -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Warning "$_ exited with status code $($process.ExitCode)"
        } else {
            # Copy the 'PolicyDefinitions' folder to SYSVOL (exclude all foreign language folders)
            $exclude = @(
                'cs-cz', 'da-dk', 'de-de', 'el-gr', 'es-es', 'fi-fi', 'fr-fr', 'hu-hu', 'it-it',
                'ja-jp', 'ko-kr', 'nb-no', 'nl-nl', 'pl-pl', 'pt-br', 'pt-pt', 'ru-ru', 'sv-se',
                'tr-tr', 'zh-cn', 'zh-tw'
            )
            Write-Host 'Copying files...'
            $policyPath = "${env:ProgramFiles(x86)}\Microsoft Group Policy\Windows 10 May 2020 Update (2004)\PolicyDefinitions"
            Get-ChildItem -Path $policyPath  | Where-Object {$_.Name -notin $exclude} | Copy-Item -Destination $policystore -Recurse -Force
            Write-Host 'Done'
        }
    }
} catch {
    Write-Error $_.Exception.Message
}

# Test if GPO present
if (-not (Get-GPO -Name $GPOName -ErrorAction SilentlyContinue)) {
    Write-Host 'GPO not found. Creating...' -ForegroundColor Yellow
    $tenantID = Read-Host -Prompt 'Enter Tenant ID'
    New-GPO -Name $GPOName
    Write-Host 'Checking if OneDrive files exist in the store...'
    $result = Get-OneDriveFiles
    if (-not ($result)) {
        Write-Host 'OneDrive files not found! Copying...' -ForegroundColor Yellow
        Copy-OneDriveFiles
    } else {
        Write-Host 'OneDrive files found! Finished!' -ForegroundColor Green
        exit
    }
} else {
    Write-Host "GPO ($GPOName) found. Checking if OneDrive files exist in the store..."
    $result = Get-OneDriveFiles
    if ($result) {
        Write-Host 'OneDrive files found! Fininshed!' -ForegroundColor Green
        exit
    } else {
        Write-Host 'OneDrive files not found! Copying...' -ForegroundColor Yellow
        Copy-OneDriveFiles
        exit
    }
}

# OneDrive 'Computer' values
$keyComputer = 'HKLM\SOFTWARE\Policies\Microsoft\OneDrive'
$computerValues = @{
    KFMBlockOptOut                 = 00000001
    ForcedLocalMassDeleteDetection = 00000001
    GPOSetUpdateRing               = 00000000
    KFMSilentOptInWithNotification = 00000001
    FilesOnDemandEnabled           = 00000001
    SilentAccountConfig            = 00000001
    KFMOptInWithWizard             = $tenantID
    KFMSilentOptIn                 = $tenantID
}

# OneDrive 'User' values
$keyUser = 'HKCU\Software\Policies\Microsoft\OneDrive'
$userValues = @{
    EnableAllOcsiClients       = 00000001
    DisablePauseOnBatterySaver = 00000001
    DisableTutorial            = 00000001
}

# Set 'Computer' registry values
try {
    foreach ($item in $computerValues.GetEnumerator()) {
        # If the following keys match a 'String' type, set the values accordingly
        if (($item.Key -eq 'KFMOptInWithWizard') -or ($item.Key -eq 'KFMSilentOptIn')) {
            $computerParams = @{
                Name      = $GPOName
                Key       = $keyComputer
                Type      = 'String'
                Valuename = $item.Key
                Value     = $tenantID
            }
            $null = Set-GPRegistryValue @computerParams
        } else {
            # The rest of the keys have a 'DWord' type
            $null = Set-GPRegistryValue -Name $GPOName -Key $keyComputer -Type DWord -ValueName $item.Key -Value $item.Value
        }
    }
} catch {
    Write-Error $_.Exception.Message
}

# Set registry value for 'AllowTenantList' key
$null = Set-GPRegistryValue -Name $GPOName -Key (Join-Path $keyComputer 'AllowTenantList') -Type String -ValueName $tenantID -Value $tenantID

# Set 'User' registry values
try {
    foreach ($item in $userValues.GetEnumerator()) {
        $userParams = @{
            Name      = $GPOName
            Key       = $keyUser
            Type      = 'DWord'
            Valuename = $item.Key
            Value     = $item.Value
        }
        $null = Set-GPRegistryValue @userParams
    }
} catch {
    Write-Error $_.Exception.Message
}
Write-Host 'Finished!' -ForegroundColor Green