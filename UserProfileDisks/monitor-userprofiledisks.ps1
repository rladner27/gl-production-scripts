# adapted from https://www.cyberdrain.com/monitoring-with-powershell-monitoring-rds-upd-size/
# if running locally, make sure to RunAsAdministrator

$DisksInWarning = @()
$VHDs = get-disk | Where-Object {$_.Location -match "VHD"}
foreach($VHD in $VHDs){
    $SID = [io.path]::GetFileNameWithoutExtension("$($VHD.Location)").TrimStart("UVHD-") #at least for OMC these all have "UVHD-" at the beginning of the file name. Alternatively could regex match to the standard SID format.
    $SIDObject = New-Object System.Security.Principal.SecurityIdentifier ($SID) 
    $Username = $SIDObject.Translate([System.Security.Principal.NTAccount])
    $Volume = $VHD | Get-Partition | Get-Volume
    if($Volume.SizeRemaining -lt $volume.Size * 0.10 ){ $DisksInWarning += "$($Username.Value) UPD Less than 10% remaining. SID: $($SID)"}
}
Write-Output $DisksInWarning