#Requires -Modules AzureAD
<#	
	.NOTES
	===========================================================================
	 Created by:   	Shane Fonyi (shane.fonyi@westpoint.edu)
	 Organization: 	Army Cyber Institute
	 Filename:     	Run-AzureADUserReport.ps1
	===========================================================================
	.DESCRIPTION
		This script is used to run a report of Azure users based on group
        membership. A term to search for groups is requested and a list of
        groups found based on the search are presented as options. An option is
        required and the membership of the group is retreived and users 
        located and exported to a CSV with UPN, AccountEnabled 
	.INPUTS
		NONE
	.OUTPUTS
		CSV File in the current PowerShell working directory
	.EXAMPLE
		./Invoke-AzureADUserReport.ps1
#>
try{
    Connect-AzureAD  | Out-Null
}
catch{
    Write-Warning "Failed to connect to AzureAD `n $_"
}
try{
    Test-Path $PSScriptRoot | out-null
}
catch{
    throw "File Path not accessible `n $_"
}

<#
###This function creates the custom PSObject that will hold the user information in a digestable format.
#>
Function Add-UserItem ($User='Empty',$AccountEnabled = 'Empty') {
    New-Object -TypeName psObject -Property @{User=$user;AccountEnabled=$AccountEnabled}
}

while($true){
$list = Read-Host -Prompt "`n Enter the number for the following options `n (1)AzureAD User Report by Group `n (2) Exit `n `n Option"
$timestamp = Get-Date -Format "yyyy-MM-dd-HH_mm"
$UserInfo=@()

switch ($list){

1{
$azuregrpsrch = Read-Host "Enter Group Search Term"
$azuregrps = Get-AzureADGroup -SearchString $azuregrpsrch
if([string]::IsNullOrEmpty($azuregrps)){
    Write-Warning "No groups found with that search term."
    break
}
else{
 if(($azuregrps | measure).count -gt "1"){
    $menu = @{}
    Write-Host "   Group Name, Description"
    for ($i=1;$i -le ($azuregrps | measure).count; $i++){
        Write-Host "$i. $($azuregrps[$i-1]."DisplayName")`, $($azuregrps[$i-1]."Description")"
        $menu.Add($i,($azuregrps[$i-1]."ObjectId"))
    }

    [int]$ans = Read-Host "Enter Group Selection"

    #trust no one
    while(($ans -lt 1) -or ($ans -ge ($azuregrps | measure).count)){
        [int]$ans = Read-Host "Enter Group Selection"   
    }
    $selection = $menu.Item($ans)
    $selectedgrp  = $azuregrps[$ans-1].DisplayName
    Write-Host $azuregrps[$ans-1].DisplayName
    $Users = Get-AzureADGroupMember -ObjectId $selection
    Foreach ($user in $Users){
        $UserInfo += Add-UserItem -User $user.UserPrincipalName -AccountEnabled $user.AccountEnabled
	}
    $filename = "AzureUserReport-$selectedgrp-$timestamp"
    }
 else{
    $selection = $azuregrps.ObjectId
    $selectedgrp  = $azuregrps.DisplayName
    Write-Host $selection
    $Users = Get-AzureADGroupMember -ObjectId $selection
    Foreach ($user in $Users){
        $UserInfo += Add-UserItem -User $user.UserPrincipalName -AccountEnabled $user.AccountEnabled
	}
    $filename = "AzureUserReport-$selectedgrp-$timestamp"
 }
}
$UserInfo | Export-Csv -Path "$PSScriptroot\$filename.csv" -NoTypeInformation
}


2{
    Disconnect-AzureAD
    Exit
}

default{continue}
}
}



