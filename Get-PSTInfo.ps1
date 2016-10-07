$FilePath = "C:\Users\user\Documents\Outlook Files\test.pst"
$null = Add-type -assembly Microsoft.Office.Interop.Outlook
$olFolders = 'Microsoft.Office.Interop.Outlook.olDefaultFolders' -as [type]  
$outlook = new-object -comobject outlook.application 
$namespace = $outlook.GetNameSpace("MAPI")
$namespace.AddStore($FilePath) 
$PST = $namespace.Stores | ? {$_.FilePath -eq $FilePath}
$Email=$NameSpace.Folders.Item(11).Folders.Item("Inbox").Folders.Item("RISC").Items
$Email | foreach {
  "`"$($_.SentOn)`", `"$($_.SenderEmailAddress)`", `"$($_.To)`"" | out-file "$PSScriptRoot\output.txt" -Append
}
$PSTRoot = $PST.GetRootFolder()
$PSTFolder = $namespace.Folders.Item($PSTRoot.Name)
$namespace.GetType().InvokeMember('RemoveStore',[System.Reflection.BindingFlags]::InvokeMethod,$null,$namespace,($PSTFolder))
