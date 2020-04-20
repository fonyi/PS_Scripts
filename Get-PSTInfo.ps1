<#	
	.NOTES
	===========================================================================
	 Created on:    10-7-2016 2:57 PM
	 Updated on:	08-5-2017 3:00 PM
	 Created by:   	Shane Fonyi
	 Organization: 	The University of Kansas
	 Filename: Get-PSTInfo.ps1    	
	===========================================================================
	 .SYNOPSIS  
     Exports information from emails in PSTs to a CSV for processing/analysis
	.DESCRIPTION
	 This script takes in a directory where some PSTs live.
	 Then it gets each PST from the directory and then hooks into the MAPI account in Outlook and adds the PST data file. 
	 It then goes through the PST and pulls some Header info from each message in the folder. If the PST is from an exchange
	 mailbox then the script will look up the ExchangeDN in AD and pull the address of the user for both sender and recipient.
	 The data from emails in the PST is exported to a CSV with common needed fields for each PST
	.PARAMETER output
	 The CSV of the name of the PST with email fields placed in the Script root folder
	.EXAMPLE
	 ./Get-PSTInfo.ps1
#>
#clear all user variables
$sysvars = get-variable | select -Expand name

function remove-uservars
{
	Get-Variable -Exclude PWD, *Preference | Remove-Variable -EA 0
}
#invoke function
. remove-uservars

try
{
	import-module activedirectory
}
#create AD drive for non-domain joined comp queries
catch
{
	Write-Host "Please enter enter credentials for connecting to AD."
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
$oProc = (Get-Process | where { $_.Name -eq "OUTLOOK" })
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
	#starts an outlook session
	$null = Add-type -assembly Microsoft.Office.Interop.Outlook
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
	$PST = $namespace.Stores | ? { $_.FilePath -eq $FilePath }
	#The kicker: Goes into the newly mounted outlook data file into the Inbox and then into the Folder with a name based on the file name
	function Get-MailboxFolder($folder)
	{
		Write-Host "Now in folder"
		"{0}: {1}" -f $folder.name, $folder.items.count
		if ($folder.items.count -gt 0)
		{
			$count = 0
			$folder.items | Select SentOn, Subject, SenderName, SenderEmailAddress, Recipients | Foreach-Object{
				$count += 1
				$recips = $_.Recipients
				$recipsarray = $null
				#Go through each email and pull the recipeints and add them to an array
				foreach ($recip in $recips)
				{
					if ($recip.Address -like "/*") #Checks for ExchangeDN and attempts to resolve it to an SMTP address
					{
						[string]$temp0 = $recip.Address
						#write-host "not trimmed: $temp0"
						$temp0 = get-aduser -ldapfilter "(legacyExchangeDN=$temp0)" -Properties mail | select-object -Property mail
						try { $temp0 = [regex]::Match($temp0, '=(.*?)}').captures.groups[1].value }
						catch { $temp0 = $recip.Address }
						#write-host "trimed: $temp0"
						if ([string]::IsNullOrEmpty($temp0))
						{
							#write-host "no data: $temp0"
							$recipsarray += $recip.Name
							$recipsarray += " <"
							$recipsarray += $recip.Address
							$recipsarray += "> "
							
						}
						else
						{
							#write-host "data: $temp0"
							$recipsarray += $recip.Name
							$recipsarray += " <"
							$recipsarray += $temp0
							$recipsarray += "> "
						}
						
					}
					elseif ([string]::IsNullOrEmpty($temp0))
					{
						$recipsarray += "No Information"
						$recipsarray += " "
					}
					else
					{
						$recipsarray += $recip.Name
						$recipsarray += " <"
						$recipsarray += $recip.Address
						$recipsarray += "> "
					}
					
				}
				
				$_.Recipients = $recipsarray #overwrites the field for export
				$_
				
				if ($_.SenderEmailAddress -like "/*")
				{
					[string]$temp = $_.SenderEmailAddress
					write-host "not trimmed: $temp"
					$temp = get-aduser -ldapfilter "(legacyExchangeDN=$temp)" -Properties mail | select-object -Property mail
					try { $temp = [regex]::Match($temp, '=(.*?)}').captures.groups[1].value }
					catch { $temp = $_.SenderEmailAddress }
					write-host "trimed: $temp"
					if ([string]::IsNullOrEmpty($temp))
					{
						#write-host "no data: $temp"
						$_.SenderEmailAddress = $_.SenderEmailAddress
						$_
					}
					else
					{
						#write-host "data: $temp"
						$_.SenderEmailAddress = $temp
						$_
					}
					
				}
				elseif ([string]::IsNullOrEmpty($_.SenderEmailAddress))
				{
					$_.SenderEmailAddress = "No Information"
					$_
				}
				else
				{
					$_.SenderEmailAddress = $_.SenderEmailAddress
					$_
				}
				
			} | Export-Csv -NoTypeInformation "$PSScriptRoot\$FileName.csv" -Append
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
