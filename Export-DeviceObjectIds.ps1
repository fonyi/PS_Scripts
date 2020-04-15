#Requires -Modules AzureAD
<#	
	.NOTES
	===========================================================================
	 Created by:   	Shane Fonyi (shane.fonyi@westpoint.edu)
	 Organization: 	Army Cyber Institute
	 Filename:     	Export-DeviceObjectIds.ps1
	===========================================================================
	.DESCRIPTION
	Takes in the exported CSV from ATP after drilling down to machines with
  vulnerable software then outputs in a CSV format for ingestion into AzureAD group
	creation.

	.PARAMETER path
	(Optional) Path to CSV exported from ATP
	.OUTPUTS
	CSV File in the current PowerShell working directory
	.EXAMPLE
		./Export-DeviceObjectIds.ps1
  .EXAMPLE
    ./Export-DeviceObjectIds.ps1 -path C:\location\to\file.csv
#>

####################################################
param(
[string]$path

)
try{
Connect-AzureAD | Out-Null
}
catch{
    Write-Host $_
    exit
}

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
Write-Host "Please upload CSV with computer names"
$path = Get-FileName "C:\temp"
}
$hosts = @()
try{
    $csv = Import-Csv $path | Select -Skip 1
    }
catch{
    Write-Warning "Unable to Import the CSV"
    $_
    exit
    }
$hosts += "version:v1.0"
$hosts += "Member object ID or user principal name [memberObjectIdOrUpn] Required"
$count = 0
foreach ($object in $csv."Assets Export"){
    $count ++
    Write-Progress -Activity "Getting Object ID" -CurrentOperation $object -PercentComplete ($count/$csv.count*100)
    $id = (Get-AzureADDevice -SearchString $object).ObjectId
    if (![string]::IsNullOrEmpty($id)){
        $hosts += $id
    }
}
$filename = [System.IO.Path]::GetFileNameWithoutExtension($path)
$hosts | Out-File "$PSScriptRoot\$filename-list.csv"
