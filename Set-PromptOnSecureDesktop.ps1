<#	
	.NOTES
	===========================================================================
	 Created by:   	Shane Fonyi (shane.fonyi@westpoint.edu)
	 Organization: 	Army Cyber Institute
	 Filename:     	Set-PromptOnSecureDesktop.ps1
	===========================================================================
	.DESCRIPTION
        This script allows for the enabling and disabling of the Secure Desktop
        feature of Windows 10. This feature prevents UAC prompts during Quick
        Assist sessions and Teams desktop sharing sessions. The scripts updates
        the registry value "PromptOnSecureDesktop" located in key 
        HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System. Once 
        this value is updated, the UAC prompts will be available in Quick Assist
        and in Teams. 
	.INPUTS
        NONE
    .PARAMETER enable
        Sets the PromptOnSecureDesktop Registry Value to 1
    .PARAMETER disable
        Sets the PromptOnSecureDeskotp Registy Value to 0
	.OUTPUTS
		NONE
	.EXAMPLE
        ./Set-PromptOnSecureDesktop.ps1 -enable
    .EXAMPLE
        ./Set-PromptOnSecureDesktop.ps1 -disable
#>
#########################################################################################################
param(
[switch]$enable = $false,
[switch]$disable = $false
)

if($enable -xor $disable){
    $PromptOnSecureDesktop = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System).PromptOnSecureDesktop
    if($enable){
        if($PromptOnSecureDesktop -ne 1){
            try{
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\" -Name "PromptOnSecureDesktop" -Value "1" -ErrorAction Stop
                Write-Host "Registry value was successfully updated"
            }
            catch{
                Write-Error "Failed to update registry value"
                Write-Error $_
                exit "-1"
            }
        }
        else{
            Write-Host "The registry value is already set to enable"
        }
    }
    if($disable){
        if($PromptOnSecureDesktop -ne 0){
            try{
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\" -Name "PromptOnSecureDesktop" -Value "0" -ErrorAction Stop
                Write-Host "Registry value was successfully updated"
            }
            catch{
                Write-Error "Failed to update registry value"
                Write-Error $_
                exit "-1"
            }
        }
        else{
            Write-Host "The registry value is already set to disable"
        }
    }
}
else{
    Write-Warning "A flag to enable or disable is required"
    exit
}
