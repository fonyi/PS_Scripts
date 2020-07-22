$BLVol=BitLockerVolume -MountPoint $env:SystemDrive | Select *
if($BLVol.VolumeStatus -eq "FullyEncrypted"){
    if([string]::IsNullOrEmpty($BLVol.KeyProtector -match 'RecoveryPassword')){
        Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -RecoveryPasswordProtector
        $BLVol=BitLockerVolume -MountPoint $env:SystemDrive | Select *
        BackupToAAD-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId ($BLVol.KeyProtector -match 'RecoveryPassword').KeyProtectorId
    }
    else{
        BackupToAAD-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId ($BLVol.KeyProtector -match 'RecoveryPassword').KeyProtectorId
    }
}
