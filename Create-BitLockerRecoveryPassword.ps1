#Requires -RunAsAdministrator
 <#	
	.NOTES
	===========================================================================
	 Created by:   	Shane Fonyi (shane.fonyi@westpoint.edu)
	 Organization: 	United States Military Academy
	 Filename:     	Create-BitLockerRecoveryPassword.ps1
	===========================================================================
	.DESCRIPTION
		This script is used to check for a Recovery Password protector for a
        BitLocker Encrypted Drive and create a random 48 digit Recovery Password
        if one does not exist. Then it sends it to AzureAD for escrow.
	.INPUTS
		NONE
	.OUTPUTS
		NONE
	.EXAMPLE
		./Create-BitLockerRecoveryPassword.ps1
#>
 $BLVol = Get-BitLockerVolume -MountPoint $env:SystemDrive | Select *
if($BLVol.VolumeStatus -eq "FullyEncrypted"){
    if([string]::IsNullOrEmpty($BLVol.KeyProtector -match 'RecoveryPassword')){
        Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -RecoveryPasswordProtector
        $BLVol = Get-BitLockerVolume -MountPoint $env:SystemDrive | Select *
        BackupToAAD-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId ($BLVol.KeyProtector -match 'RecoveryPassword').KeyProtectorId
    }
    else{
        BackupToAAD-BitLockerKeyProtector -MountPoint $env:SystemDrive -KeyProtectorId ($BLVol.KeyProtector -match 'RecoveryPassword').KeyProtectorId
    }
}
