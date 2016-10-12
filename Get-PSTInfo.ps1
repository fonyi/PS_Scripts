#This script takes in a directory where some PSTs live
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
    $foldername.rootfolder = "Documents"

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
      #Get the items in the folder and select the properties we want then sends the objects 
      $folder.items|Select SentOn,SenderEmailAddress,To,CC,BCC |Foreach-Object{
      #go into the pipline and send SenderEmailAddress for the current item in the pipe
        #determine if the address is in X500 format for legacy exchange and query AD for the address
        if ($_.SenderEmailAddress -like "/O=*"){
            [string]$temp=$_.SenderEmailAddress
            $temp = get-aduser -ldapfilter "(legacyExchangeDN=$temp)" -Properties mail | select-object -Property mail
            $temp = $temp -replace ‘[{mail=}]’
            $temp = $temp.trimstart("@")
            $_.SenderEmailAddress =$temp
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
      
      }|Export-Csv -NoTypeInformation "$PSScriptRoot\$FileName.csv"
#recurse into folders      
foreach ($f in $folder.folders) {
Get-MailboxFolder $f
}
}
#assumes your version of outlook names inmported PSTs as 'outlook data file' otherwise change it to $filename
foreach ($folder in $NameSpace.Folders.Item('outlook data file')) {
Get-MailboxFolder $folder
}
#Then we rip out the pst for the next one
$PSTRoot = $PST.GetRootFolder()
$PSTFolder = $namespace.Folders.Item($PSTRoot.Name)
$namespace.GetType().InvokeMember('RemoveStore',[System.Reflection.BindingFlags]::InvokeMethod,$null,$namespace,($PSTFolder))
}
#finally we exit because we don't like windows open all the time
exit
