#This script takes in a directory where some PSTs live and that can be changed by changing the path for Get-Child Item
#Then it gets each PST from the directory and then hooks into the MAPI account in Outlook and adds the PST data file
#It then goes through the PST and pulls some Header info from each message in the folder. 
#In theory, it should work all the time. 
#For some reason this wasn't easy to do
#Created by Shane Fonyi 10-7-2016

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
#goes through each file in our directory and pulls out the PSTs
Get-ChildItem $directory -Filter *.pst |
#Runs through this loop for each PST
ForEach-Object{
#Grabs the full file path
$FilePath = $_.FullName
#Gives us the File name sans the extenstion 
$FileName = [io.path]::GetFileNameWithoutExtension($FilePath)
#starts and outlook session
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
$Email=$NameSpace.Folders.Item('outlook data file').Folders.Item("Inbox").Folders.Item($FileName).Items
#Gets us the Sent On date and time, the Sender email address and the To of each email in that folder
$Email | foreach {
  "`"$($_.SentOn)`", `"$($_.SenderEmailAddress)`", `"$($_.To)`"" | out-file "$PSScriptRoot\$FileName.csv" -Append
}
#Then we rip out the pst for the next one
$PSTRoot = $PST.GetRootFolder()
$PSTFolder = $namespace.Folders.Item($PSTRoot.Name)
$namespace.GetType().InvokeMember('RemoveStore',[System.Reflection.BindingFlags]::InvokeMethod,$null,$namespace,($PSTFolder))
}
#finally we exit because we don't like windows open all the time
exit
