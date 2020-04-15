#Requires -Modules ExchangeOnlineManagement
<#
	.NOTES
	===========================================================================
	 Created by:   	Shane Fonyi (shane.fonyi@westpoint.edu)
	 Organization: 	Army Cyber Institute
	 Filename:     	Update-AtpPolicyBlockUrlsFromCsv.ps1
	===========================================================================
	.DESCRIPTION
		This script uses the ExchangeOnlineManagement module to connect to the
        tenant Exchange instance to update the BlockUrls field for the default
        ATP Policy. This policy dictates what URLs are blocked in Emails and
        other Microsoft365 services using SafeLink. A CSV is required to have
        a column named "Value" where the URLs or domain names are. This script
        had the ability to both add items from a CSV to the BlockUrls list and
        remove items from the BlockUrls list.
	.INPUTS
    None
  .PARAMETER path
    path to CSV with URLs or Domain Names in a column named "Value"
  .PARAMTER add
    Adds items in the CSV to the BlockUrls list
  .PARAMETER remove
    Removes items in the CSV from the BlockUrls list
	.OUTPUTS
		None
	.EXAMPLE
		./Edit-AtpPolicyBlockUrlsFromCsv.ps1 -add -path C:\test.csv
  .EXAMPLE  
    ./Edit-AtpPolicyBlockUrlsFromCsv.ps1 -remove -path C:\test.csv

#>

param(
[switch]$add = $false,
[switch]$remove = $false,
[string]$path
)

<#
#Not required with V2 of the Online Exchange Module
$winrm = winrm get winrm/config/client/auth
$winrmcheck = $winrm | Select-String Basic | Select-String true
if([string]::IsNullOrEmpty($winrmcheck)){
    Write-Warning "WINRM Client is currently not set to allow Basic Auth. WINRM must be set to allow basic auth."
    Write-Host "To enable WINRM Client Basic Auth, please run `"winrm set winrm/config/client/auth @{Basic=`"true`"}`" in an elevated cmd prmopt" -ForegroundColor Cyan
    exit
}
#>

if($add -xor $remove){ #check if one of the switches was supplied or both switches were supplied

Import-Module ExchangeOnlineManagement | Out-Null

try{
Connect-ExchangeOnline | Out-Null
}
catch{
    Write-Host $_
    exit
}

<#
    This function calls the system dialog box for the user to browse for a CSV and collects the path
#>
Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "CSV (*.CSV)| *.CSV"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
} 

if([string]::IsNullOrWhiteSpace($path)){
Write-Host "Please upload CSV with domains"
$path = Get-FileName "C:\temp"
}
$URLs = @()
try{
    $URLs = Import-Csv $path
    }
catch{
    Write-Warning "Unable to Import the CSV"
    $_
    exit
    }
try{
    $ATPUrls = (Get-AtpPolicyForO365).BlockUrls
    }
catch{
    Write-Warning "Unable to get the ATP policy for the tenant."
    $_
    exit
    }

#Write-Host "Current Blocked URLs:"
#(Get-AtpPolicyForO365).BlockUrls

if($add){
    foreach($url in $ATPUrls){ #We need to add the current list to the new list since there is no real add function
        $URLs += New-Object -TypeName psObject -Property @{Value=$url}
    }
    $URLs = $URLs.Value | Select -Unique #Duplicate values breaks the cmdlet to update the list
    try{
        Set-AtpPolicyForO365 -BlockUrls $URLs
        }
    catch{
        Write-Warning "Failed to Update ATP Policy"
        $_
        exit
    }
}


if($remove){
    $NewList = $ATPUrls | Where-Object {$URLs.Value -notcontains $_} #Checks if items in the current ATP list exist in the CSV list
    try{
        Set-AtpPolicyForO365 -BlockUrls $NewList
        }
    catch{
        Write-Warning "Failed to Update ATP Policy"
        $_
        exit
        }

}

#Write-Host ""
#Write-Host "New Blocked URLs:"
#(Get-AtpPolicyForO365).BlockUrls

}
else{
    Write-Warning "A flag to add or remove must be supplied"
    exit
}
