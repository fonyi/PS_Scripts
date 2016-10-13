#This script takes in a directory where some PSTs live
#Then it gets each PST from the directory and then hooks into the MAPI account in Outlook and adds the PST data file
#It then goes through the PST and pulls some Header info from each message in the folder. 
#In theory, it should work all the time. 
#For some reason this wasn't easy to do
#Created by Shane Fonyi 10-7-2016

import-module activedirectory
#clear all user variables
$sysvars = get-variable | select -Expand name

  function remove-uservars {
     Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0
    }
#invoke function
. remove-uservars
#create AD drive for non-domain joined comp queries 
if (-not(Get-PSDrive AD)) {
$creds = Get-Credential
$adserv = Read-Host "Please enter FQDN for domain controller"
 New-PSDrive `
    -Name AD `
    -PSProvider ActiveDirectory `
    -Server $adserv `
    -Credential $creds `
    -Root "//RootDSE/" `
    -Scope Global
}
else{
 "Drive already exists"
 }

#Function to get the folder path in question
Function Get-Folder($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | out-null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.rootfolder = "MyComputer"

    if($foldername.ShowDialog() -eq "OK")
    {
        $folder += $foldername.SelectedPath
    }
    return $folder
}
$directory=Get-Folder
#if outlook is not running, launch a hidden instance.
$oProc = ( Get-Process | where { $_.Name -eq "OUTLOOK" } )
if ( $oProc -eq $null ) { Start-Process outlook -WindowStyle Hidden; Start-Sleep -Seconds 5 }
#goes through each file in our directory and pulls out the PSTs
Get-ChildItem $directory -Filter *.pst |
#Runs through this loop for each PST
ForEach-Object{

#Grabs the full file path
$FilePath = $_.FullName
#Gives us the File name sans the extenstion 
$FileName = [io.path]::GetFileNameWithoutExtension($FilePath)
write-host "Now starting $filename PST"
#starts an outlook session
$null = Add-type -assembly Microsoft.Office.Interop.Outlook
$olFolders = 'Microsoft.Office.Interop.Outlook.olDefaultFolders' -as [type]  
$outlook = new-object -comobject outlook.application
#hooks into MAPI profile in Outlook
$namespace = $outlook.GetNameSpace("MAPI")
#Adds our PST to the MAPI profile
$namespace.AddStore($FilePath) 
#Adds the PST namespace to a variable needed later
$PST = $namespace.Stores | ? {$_.FilePath -eq $FilePath}
#The kicker: Goes into the newly mounted outlook data file into the Inbox and then into the Folder with a name based on the file name
function Get-MailboxFolder($folder){
      Write-Host "Now in folder"
      "{0}: {1}" -f $folder.name, $folder.items.count
      $folder.items|Select SentOn,SenderName,SenderEmailAddress,To,CC,BCC |Foreach-Object{
        if ($_.SenderEmailAddress -like "/*"){
            [string]$temp=$_.SenderEmailAddress
            $temp = get-aduser -ldapfilter "(legacyExchangeDN=$temp)" -Properties mail | select-object -Property mail
            $temp = $temp -replace '^(@{mail=)'
            $temp = $temp.trim("}")
            if ($temp -ne '*'){
            $_.SenderEmailAddress =$_.SenderEmailAddress
            }
            else{
            $_.SenderEmailAddress = $temp
            }
            $_
        }
        elseif ($_.SenderEmailAddress -eq $null){
            $_.SenderEmailAddress="No Information"
            $_
        }
        else{
            $_.SenderEmailAddress=$_.SenderEmailAddress
            $_        
        } 
      
      }|Export-Csv -NoTypeInformation "$PSScriptRoot\$FileName.csv" -Append
      
foreach ($f in $folder.folders) {
Get-MailboxFolder $f
}
}

foreach ($folder in $NameSpace.Folders.Item('outlook data file')) {
Get-MailboxFolder $folder
}
#Then we rip out the pst for the next one
$PSTRoot = $PST.GetRootFolder()
$PSTFolder = $namespace.Folders.Item($PSTRoot.Name)
write-host "Removing PST $filename"
$namespace.GetType().InvokeMember('RemoveStore',[System.Reflection.BindingFlags]::InvokeMethod,$null,$namespace,($PSTFolder))
}
#finally we exit because we don't like windows open all the time
write-host "Done"
exit
