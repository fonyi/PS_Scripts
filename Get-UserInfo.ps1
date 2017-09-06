#Requires –Modules ActiveDirectory
<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2017 v5.4.136
	 Created on:   	8/23/2016 9:26 AM
	 Created by:   	Shane Fonyi
	 Organization: 	The University of Kansas
	 Filename:     	Get-UserInfo.ps1
	===========================================================================
	.DESCRIPTIONs
		This script will perform multiple search queries against AD/LDAP with different perameters
		The options determine the values listed in the text file being uploaded
		The output will be placed in the current working directory with the name outputyyyyMMDDhhmm.csv
		The ouput options determine the values pulled from LDAP and added to the CSV for each user 
	.INPUTS
		File path to the text file with the list of users (First Last; Last, First; email addresses; samaccountname)
	.OUTPUTS
		CSV with selected information named with the date and placed in the PSScriptRoot
	.EXAMPLE
		./Get-UserInfo.ps1
        	./Get-UserInfo.ps1 -path \path\to\inputfile.txt -output \path\to\outputdirectory\
        	./Get-UserInfo.ps1 -path \path\to\inputfile.txt
#>
param(
    [Parameter(Mandatory=$False,Position=1)]
    [string]$path,
    [Parameter(Mandatory=$False)]
    [string]$output
)
Import-Module ActiveDirectory
Add-Type -AssemblyName System.Windows.Forms
Function Get-FileName($initialDirectory)
{
	[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
	
	$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
	$OpenFileDialog.initialDirectory = $initialDirectory
	$OpenFileDialog.filter = "TXT (*.txt)| *.txt"
	$OpenFileDialog.ShowDialog() | Out-Null
	$OpenFileDialog.filename
}
$checkBox6 = New-Object System.Windows.Forms.CheckBox
$checkBox5 = New-Object System.Windows.Forms.CheckBox
$checkBox4 = New-Object System.Windows.Forms.CheckBox
$checkBox3 = New-Object System.Windows.Forms.CheckBox
$checkBox2 = New-Object System.Windows.Forms.CheckBox
$checkBox1 = New-Object System.Windows.Forms.CheckBox
Function GenerateForm
{
	
	[reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
	[reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null
	
	$form1 = New-Object System.Windows.Forms.Form
	$button1 = New-Object System.Windows.Forms.Button
	$listBox1 = New-Object System.Windows.Forms.ListBox
	$InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState
	
	$b1 = $false
	$b2 = $false
	$b3 = $false
	
	#----------------------------------------------
	#Generated Event Script Blocks
	#----------------------------------------------
	
	$handler_button1_Click =
	{
		$listBox1.Items.Clear();
		
		if (!$checkBox1.Checked -and !$checkBox2.Checked -and !$checkBox3.Checked -and !$checkBox4.Checked -and !$checkBox5.Checked -and !$checkBox6.Checked) { $listBox1.Items.Add("No CheckBox selected....") }
		else { $form1.Close() }
	}
	
	$OnLoadForm_StateCorrection =
	{
		#Correct the initial state of the form to prevent the .Net maximized form issue
		$form1.WindowState = $InitialFormWindowState
	}
	
	#----------------------------------------------
	#region Generated Form Code
	$form1.Text = "Output Options"
	$form1.Name = "form1"
	$form1.DataBindings.DefaultDataSourceUpdateMode = 0
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = 450
	$System_Drawing_Size.Height = 236
	$form1.ClientSize = $System_Drawing_Size
	
	$button1.TabIndex = 4
	$button1.Name = "button1"
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = 75
	$System_Drawing_Size.Height = 23
	$button1.Size = $System_Drawing_Size
	$button1.UseVisualStyleBackColor = $True
	
	$button1.Text = "OK"
	
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = 27
	$System_Drawing_Point.Y = 200
	$button1.Location = $System_Drawing_Point
	$button1.DataBindings.DefaultDataSourceUpdateMode = 0
	$button1.add_Click($handler_button1_Click)
	
	$form1.Controls.Add($button1)
	
	$listBox1.FormattingEnabled = $True
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = 301
	$System_Drawing_Size.Height = 212
	$listBox1.Size = $System_Drawing_Size
	$listBox1.DataBindings.DefaultDataSourceUpdateMode = 0
	$listBox1.Name = "listBox1"
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = 137
	$System_Drawing_Point.Y = 13
	$listBox1.Location = $System_Drawing_Point
	$listBox1.TabIndex = 6
	
	$form1.Controls.Add($listBox1)
	
	$checkBox6.UseVisualStyleBackColor = $True
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = 104
	$System_Drawing_Size.Height = 24
	$checkBox6.Size = $System_Drawing_Size
	$checkBox6.TabIndex = 5
	$checkBox6.Text = "Password Last Set"
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = 27
	$System_Drawing_Point.Y = 168
	$checkBox6.Location = $System_Drawing_Point
	$checkBox6.DataBindings.DefaultDataSourceUpdateMode = 0
	$checkBox6.Name = "checkBox6"
	
	$form1.Controls.Add($checkBox6)
	
	$checkBox5.UseVisualStyleBackColor = $True
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = 104
	$System_Drawing_Size.Height = 24
	$checkBox5.Size = $System_Drawing_Size
	$checkBox5.TabIndex = 4
	$checkBox5.Text = "Department"
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = 27
	$System_Drawing_Point.Y = 137
	$checkBox5.Location = $System_Drawing_Point
	$checkBox5.DataBindings.DefaultDataSourceUpdateMode = 0
	$checkBox5.Name = "checkBox5"
	
	$form1.Controls.Add($checkBox5)
	
	$checkBox4.UseVisualStyleBackColor = $True
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = 104
	$System_Drawing_Size.Height = 24
	$checkBox4.Size = $System_Drawing_Size
	$checkBox4.TabIndex = 3
	$checkBox4.Text = "Title"
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = 27
	$System_Drawing_Point.Y = 106
	$checkBox4.Location = $System_Drawing_Point
	$checkBox4.DataBindings.DefaultDataSourceUpdateMode = 0
	$checkBox4.Name = "checkBox4"
	
	$form1.Controls.Add($checkBox4)
	
	
	$checkBox3.UseVisualStyleBackColor = $True
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = 104
	$System_Drawing_Size.Height = 24
	$checkBox3.Size = $System_Drawing_Size
	$checkBox3.TabIndex = 2
	$checkBox3.Text = "DisplayName"
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = 27
	$System_Drawing_Point.Y = 75
	$checkBox3.Location = $System_Drawing_Point
	$checkBox3.DataBindings.DefaultDataSourceUpdateMode = 0
	$checkBox3.Name = "checkBox3"
	
	$form1.Controls.Add($checkBox3)
	
	
	$checkBox2.UseVisualStyleBackColor = $True
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = 104
	$System_Drawing_Size.Height = 24
	$checkBox2.Size = $System_Drawing_Size
	$checkBox2.TabIndex = 1
	$checkBox2.Text = "Email Address"
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = 27
	$System_Drawing_Point.Y = 44
	$checkBox2.Location = $System_Drawing_Point
	$checkBox2.DataBindings.DefaultDataSourceUpdateMode = 0
	$checkBox2.Name = "checkBox2"
	
	$form1.Controls.Add($checkBox2)
	
	
	
	$checkBox1.UseVisualStyleBackColor = $True
	$System_Drawing_Size = New-Object System.Drawing.Size
	$System_Drawing_Size.Width = 104
	$System_Drawing_Size.Height = 24
	$checkBox1.Size = $System_Drawing_Size
	$checkBox1.TabIndex = 0
	$checkBox1.Text = "Username"
	$System_Drawing_Point = New-Object System.Drawing.Point
	$System_Drawing_Point.X = 27
	$System_Drawing_Point.Y = 13
	$checkBox1.Location = $System_Drawing_Point
	$checkBox1.DataBindings.DefaultDataSourceUpdateMode = 0
	$checkBox1.Name = "checkBox1"
	
	$form1.Controls.Add($checkBox1)
	
	
	#Save the initial state of the form
	$InitialFormWindowState = $form1.WindowState
	#Init the OnLoad event to correct the initial state of the form
	$form1.add_Load($OnLoadForm_StateCorrection)
	#Show the Form
	$form1.ShowDialog() | Out-Null
	
} #End Function


$list = Read-Host -Prompt "`n Enter the number for the list type being uploaded `n (1) list of email addresses `n (2) list of usernames `n (3) list of Lastname, Firstname `n (4) list of Fistname Lastname `n"
if([string]::IsNullOrEmpty($path))
{
    $inputfile = Get-FileName "C:\temp"
    $Inputs = Get-Content $inputfile
}
else
{
    $Inputs = Get-Content $path
}
#Call the Function
GenerateForm
$box1 = "samaccountname"
$box2 = "mail"
$box3 = "displayname"
$box4 = "title"
$box5 = "department"
$box6 = "passwordlastset"
$prop = "displayname", "samaccountname", "mail", "title", "department", "passwordlastset"
[System.Collections.ArrayList]$props = $prop
if (!$checkBox1.Checked) { $props.Remove($box1) }
if (!$checkBox2.Checked) { $props.Remove($box2) }
if (!$checkBox3.Checked) { $props.Remove($box3) }
if (!$checkBox4.Checked) { $props.Remove($box4) }
if (!$checkBox5.Checked) { $props.Remove($box5) }
if (!$checkBox6.Checked) { $props.Remove($box6) }
$todaysdate = get-date -date $(get-date).adddays(+ 0) -format yyyyMMddhhmm
if([string]::IsNullOrEmpty($output))
{
    $out_file = "$PSScriptRoot\output$todaysdate.csv"
}
else
{
    $out_file = "$output\output$todaysdate.csv"
}
$result = @()
switch ($list)
{
	1 {
		Foreach ($Input in $Inputs)
		{
			$result += get-aduser -ldapfilter "(mail=$Input)" -Properties (foreach { $props }) | Select-Object -Property (foreach { $props })
		}$result |
		Export-Csv -NoTypeInformation $out_file
	}
	
	2 {
		Foreach ($Input in $Inputs)
		{
			$result += get-aduser -ldapfilter "(samaccountname=$Input)" -Properties (foreach { $props }) | Select-Object -Property (foreach { $props })
		}$result |
		Export-Csv -NoTypeInformation $out_file
	}
	
	3 {
		Foreach ($Input in $Inputs)
		{
			$Lastname, $Firstname = $Input.split(', ', 2)
			$result += get-aduser -filter { sn -like $Lastname -and givenName -like $Firstname } -Properties (foreach { $props }) | Select-Object -Property (foreach { $props })
		}$result |
		Export-Csv -NoTypeInformation $out_file
	}
	
	4 {
		Foreach ($Input in $Inputs)
		{
			$Firstname, $Lastname = $Input.split(' ', 2)
			$result += get-aduser -filter { sn -like $Lastname -and givenName -like $Firstname } -Properties (foreach { $props }) | Select-Object -Property (foreach { $props })
		}$result |
		Export-Csv -NoTypeInformation $out_file
	}
	
	default { write-host "No valid option selected" }
}
exit
