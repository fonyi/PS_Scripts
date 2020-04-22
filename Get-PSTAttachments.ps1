<#	
	.NOTES
	===========================================================================
	 Created on:    04-20-2020
	 Updated on:	04-20-2020
	 Created by:   	Shane Fonyi
	 Filename: Get-PSTAttachments.ps1    	
	===========================================================================
	 .SYNOPSIS  
     Exports attachments from emails in PSTs to a single directory in the PS script root directory.
	.DESCRIPTION
	 This script takes in a directory where some PSTs live.
	 Then it gets each PST from the directory and then hooks into the MAPI for Outlook and adds the PST data file. 
	 It then goes through the PST and pulls attachments from each message in the folder and saves it by file name
	 to a directory named the same as the PST which is created in the root of the PS script directory.
	.INPUTS
	None
	.OUTPUTS
	None
	.EXAMPLE
	 ./Get-PSTAttachments.ps1
#>

#clear all user variables
function remove-uservars
{
	Get-Variable -Exclude PWD, *Preference | Remove-Variable -EA 0
}
#invoke function
. remove-uservars


#Function to get the folder path in question
Function Get-Folder($initialDirectory)
{
	[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | out-null
	
	$foldername = New-Object System.Windows.Forms.FolderBrowserDialog
	$foldername.rootfolder = "MyComputer"
	
	if ($foldername.ShowDialog() -eq "OK")
	{
		$folder += $foldername.SelectedPath
	}
	return $folder
}

$directory = Get-Folder
#if outlook is not running, launch a hidden instance.
$oProc = (Get-Process | Where-Object { $_.Name -eq "OUTLOOK" })
if ($oProc -eq $null) { Start-Process outlook -WindowStyle Hidden; Start-Sleep -Seconds 5 }
#goes through each file in our directory and pulls out the PSTs
Get-ChildItem $directory -Filter *.pst |
#Runs through this loop for each PST
ForEach-Object{
	
	#Grabs the full file path
	$FilePath = $_.FullName
	#Gives us the File name sans the extenstion
	$FileName = [io.path]::GetFileNameWithoutExtension($FilePath)
	write-host "Now starting $filename PST"
	write-host "Creating folder for attachments"
	New-Item $PSScriptRoot\$FileName -ItemType Directory
	#starts an outlook session
	#$null = Add-type -assembly Microsoft.Office.Interop.Outlook
	$olFolders = 'Microsoft.Office.Interop.Outlook.olDefaultFolders' -as [type]
	$outlook = new-object -comobject outlook.application
	#hooks into MAPI profile in Outlook
	$namespace = $outlook.GetNameSpace("MAPI")
	#Adds our PST to the MAPI profile
	$namespace.AddStore($FilePath)
	$outlookfolders = $namespace.folders
	foreach ($name in $outlookfolders)
	{
		if ($name.Name -contains "Outlook Data File")
		{
			$version = "Outlook Data File"
		}
		else
		{
			$version = 	$filename
		}
	}
	#Adds the PST namespace to a variable needed later
	$PST = $namespace.Stores | Where-Object { $_.FilePath -eq $FilePath }
	#The kicker: Goes into the newly mounted outlook data file into the Inbox and then into the Folder with a name based on the file name
	function Get-MailboxFolder($folder)
	{
		Write-Host "Now in folder"
		"{0}: {1}" -f $folder.name, $folder.items.count
		if ($folder.items.count -gt 0)
		{
			$count = 0
			$total = $folder.items.count
			$folder.items | Select-Object SentOn, Subject, SenderName, SenderEmailAddress, Recipients, Attachments | Foreach-Object{
				$count += 1
                Write-Progress -Activity "Evaluating Items in folder $($folder.name)" -PercentComplete ($count/$total*100)
				#$attachmentfolder = "$_.SentOn" + "-" + "$_.Subject"
				#New-Item "$PSScriptRoot\$FileName\$attachmentfolder" -ItemType Directory
				#$targetdir = "$PSScriptRoot\$FileName\$attachmentfolder"
				$targetdir = "$PSScriptRoot\$FileName"
				Foreach($attachment in $_.Attachments){
					$fn = $attachment | Select-Object -ExpandProperty FileName
					$attachment.saveasfile("$targetdir\$fn")
				}
			
			}
		}
		#recursion recursion recursion
		foreach ($f in $folder.folders)
		{
			Get-MailboxFolder $f
		}
	}
	
	foreach ($folder in $NameSpace.Folders.Item($version))
	{
		Get-MailboxFolder $folder
	}
	
	#Then we rip out the pst for the next one
	$PSTRoot = $PST.GetRootFolder()
	$PSTFolder = $namespace.Folders.Item($PSTRoot.Name)
	write-host "Removing PST $filename"
	$namespace.GetType().InvokeMember('RemoveStore', [System.Reflection.BindingFlags]::InvokeMethod, $null, $namespace, ($PSTFolder))
}
#finally we exit because we don't like windows open all the time
write-host "Done"
Read-Host -Prompt "Press `"Enter`" to exit."
exit
