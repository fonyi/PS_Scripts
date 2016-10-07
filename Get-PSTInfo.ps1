#This script takes in a directory where some PSTs live and that can be changed by changing the path for Get-Child Item
#Then it gets each PST from the directory and then hooks into the MAPI account in Outlook and adds the PST data file
#It then goes through the PST and pulls some Header info from each message in the folder. 
#In theory, it should work all the time. 
#For some reason this wasn't easy to do
#Created by Shane Fonyi 10-7-2016
Get-ChildItem "C:\Users\user\Documents\Outlook Files" -Filter *.pst |
ForEach-Object{
$FilePath = $_.FullName
$FileName = [io.path]::GetFileNameWithoutExtension($FilePath)
$null = Add-type -assembly Microsoft.Office.Interop.Outlook
$olFolders = 'Microsoft.Office.Interop.Outlook.olDefaultFolders' -as [type]  
$outlook = new-object -comobject outlook.application 
$namespace = $outlook.GetNameSpace("MAPI")
$namespace.AddStore($FilePath) 
$PST = $namespace.Stores | ? {$_.FilePath -eq $FilePath}
$Email=$NameSpace.Folders.Item('outlook data file').Folders.Item("Inbox").Folders.Item($FileName).Items
$Email | foreach {
  "`"$($_.SentOn)`", `"$($_.SenderEmailAddress)`", `"$($_.To)`"" | out-file "$PSScriptRoot\$FileName.csv" -Append
}
$PSTRoot = $PST.GetRootFolder()
$PSTFolder = $namespace.Folders.Item($PSTRoot.Name)
$namespace.GetType().InvokeMember('RemoveStore',[System.Reflection.BindingFlags]::InvokeMethod,$null,$namespace,($PSTFolder))
}
