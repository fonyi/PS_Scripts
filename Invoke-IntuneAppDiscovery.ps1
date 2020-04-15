
<#
	.NOTES
	===========================================================================
	 Created by:   	Shane Fonyi (shane.fonyi@westpoint.edu)
	 Organization: 	Army Cyber Institute
	 Filename:     	Run-IntuneAppDiscovery.ps1
	===========================================================================
	.DESCRIPTION
		This script is used to run a report of applications discovered by Intune.
        The script utilizes Microsoft Graph to query discovered applications and
        then queries the devices that have the software installed. The user is
        able to input a number that will be used to filter out apps that have
        been installed the number of devices higher than the input. The script
        also has the capability to filter out apps from a text file to futher
        reduce the noise. The file needs to be in the same directory and be named
        appwhitelist.txt with an app ID separated by carriage returns. 
	.INPUTS
		NONE
	.OUTPUTS
		CSV File in the current PowerShell working directory
	.EXAMPLE
		./Invoke-IntuneAppDiscovery.ps1

   
    

#>

####################################################

function Get-AuthToken {

<#
.SYNOPSIS
This function is used to authenticate with the Graph API REST interface
.DESCRIPTION
The function authenticate with the Graph API Interface with the tenant name
.EXAMPLE
Get-AuthToken
Authenticates you with the Graph API interface
.NOTES
NAME: Get-AuthToken
.COPYRIGHT
  Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    $User
)

$userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User

$tenant = $userUpn.Host

Write-Host "Checking for AzureAD module..."

    $AadModule = Get-Module -Name "AzureAD" -ListAvailable

    if ($AadModule -eq $null) {

        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable

    }

    if ($AadModule -eq $null) {
        write-host
        write-host "AzureAD Powershell module not installed..." -f Red
        write-host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
        write-host "Script can't continue..." -f Red
        write-host
        exit
    }

# Getting path to ActiveDirectory Assemblies
# If the module count is greater than 1 find the latest version

    if($AadModule.count -gt 1){

        $Latest_Version = ($AadModule | select version | Sort-Object)[-1]

        $aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }

            # Checking if there are multiple versions of the same module found

            if($AadModule.count -gt 1){

            $aadModule = $AadModule | select -Unique

            }

        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

    }

    else {

        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

    }

[System.Reflection.Assembly]::LoadFrom($adal) | Out-Null

[System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

$clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"

$redirectUri = "urn:ietf:wg:oauth:2.0:oob"

$resourceAppIdURI = "https://graph.microsoft.com"

$authority = "https://login.microsoftonline.com/$Tenant"

    try {

    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority

    # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
    # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession

    $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"

    $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")

    $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result

        # If the accesstoken is valid then create the authentication header

        if($authResult.AccessToken){

        # Creating header for Authorization token

        $authHeader = @{
            'Content-Type'='application/json'
            'Authorization'="Bearer " + $authResult.AccessToken
            'ExpiresOn'=$authResult.ExpiresOn
            }

        return $authHeader

        }

        else {

        Write-Host
        Write-Host "Authorization Access Token is null, please re-run authentication..." -ForegroundColor Red
        Write-Host
        break

        }

    }

    catch {

    write-host $_.Exception.Message -f Red
    write-host $_.Exception.ItemName -f Red
    write-host
    break

    }

}

####################################################

Function Get-AADUser(){

<#
.SYNOPSIS
This function is used to get AAD Users from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any users registered with AAD
.EXAMPLE
Get-AADUser
Returns all users registered with Azure AD
.EXAMPLE
Get-AADUser -userPrincipleName user@domain.com
Returns specific user by UserPrincipalName registered with Azure AD
.NOTES
NAME: Get-AADUser
.COPYRIGHT
  Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
#>

[cmdletbinding()]

param
(
    $userPrincipalName,
    $Property
)

# Defining Variables
$graphApiVersion = "v1.0"
$User_resource = "users"

    try {

        if($userPrincipalName -eq "" -or $userPrincipalName -eq $null){

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

        }

        else {

            if($Property -eq "" -or $Property -eq $null){

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)/$userPrincipalName"
            Write-Verbose $uri
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get

            }

            else {

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)/$userPrincipalName/$Property"
            Write-Verbose $uri
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

            }

        }

    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}

####################################################

Function Get-DiscoveredAppsPaging(){

<#
.SYNOPSIS
This function is used to get Discovered Apps from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets Discovered Apps using paging
.EXAMPLE
Get-DiscoveredAppsPaging
Returns ALL Discovered Apps configured in Intune
.NOTES
NAME: Get-DiscoveredAppsPaging
#>

[cmdletbinding()]

$graphApiVersion = "beta"
$Resource = "deviceManagement/detectedapps"

    try {

    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

    $AppsResponse = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)

    $Apps = $AppsResponse.value

    $AppsNextLink = $AppsResponse."@odata.nextLink"

        while ($AppsNextLink -ne $null){
            Write-Progress -Activity "Collecting Detected Apps" -Status "$AppsNextLink"
            $AppsResponse = (Invoke-RestMethod -Uri $AppsNextLink -Headers $authToken -Method Get)
            $AppsNextLink = $AppsResponse."@odata.nextLink"
            $Apps += $AppsResponse.value

        }

    return $Apps

    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}
####################################################

<#
#region Authentication
.COPYRIGHT
  Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
#>

# Checking if authToken exists before running authentication
if($global:authToken){

    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

        if($TokenExpires -le 0){

        write-host "Authentication Token expired" $TokenExpires "minutes ago" -ForegroundColor Yellow
        write-host

            # Defining Azure AD tenant name, this is the name of your Azure Active Directory (do not use the verified domain name)

            if($User -eq $null -or $User -eq ""){

            $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
            Write-Host

            }

        $global:authToken = Get-AuthToken -User $User

        }
}

# Authentication doesn't exist, calling Get-AuthToken function

else {

    if($User -eq $null -or $User -eq ""){

    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host

    }

# Getting the authorization token
$global:authToken = Get-AuthToken -User $User

}

#endregion

####################################################

<#
###This function creates the custom PSObject that will hold the computer information in a digestable format.
#>
Function Add-AppItem ($ID='Empty',$displayName='Empty',$version='Empty',$deviceName='Empty',$deviceid='Empty',$appCount='Empty') {
    New-Object -TypeName psObject -Property @{displayName=$displayName;version=$version;deviceName=$deviceName;deviceID=$deviceid;appCount=$appCount;appID=$ID}
}
####################################################

try{
[int]$limit = Read-Host -Prompt "Enter the max number of devices an app can be installed on to report"
}
catch{
    #default to 1 if there is a problem.
    $limit = 1
}
$timestamp = Get-Date -Format "yyyy-MM-dd-HH_mm"
$Apps = Get-DiscoveredAppsPaging

if($Apps){

    $Results = @()
    $count = 0
    Write-Host "$($Apps.Count) found."

    if(Test-Path "$PSScriptRoot\appwhitelist.txt"){
       $whitelist = Get-Content "$PSScriptRoot\appwhitelist.txt"
           foreach($App in $Apps){
            $count++
            Write-Progress -Activity "Collecting InTune App Information" -Status "Progress:" -PercentComplete ($count/$Apps.Count*100)
    
            $AppID = $App.id

            if($App.DeviceCount -le $limit -and -not ($AppID -iin $whitelist)){

            $uri = "https://graph.microsoft.com/beta/deviceManagement/detectedApps('$AppID')/manageddevices"
            $Response = Invoke-RestMethod -Uri $uri  -Method Get -Headers $authToken
            $DetectedDevices = $Response.Value
            $Results += Add-AppItem -id $app.id -displayName $app.displayName -version $app.version -deviceName ($DetectedDevices.devicename -join ',') -deviceid ($DetectedDevices.id -join ',') -appCount $Response."@odata.count"

            }

        }
    }
    else{
    foreach($App in $Apps){
        $count++
        Write-Progress -Activity "Collecting InTune App Information" -Status "Progress:" -PercentComplete ($count/$Apps.Count*100)
    
        $AppID = $App.id

            if($App.DeviceCount -le $limit){

            $uri = "https://graph.microsoft.com/beta/deviceManagement/detectedApps('$AppID')/manageddevices"
            $Response = Invoke-RestMethod -Uri $uri  -Method Get -Headers $authToken
            $DetectedDevices = $Response.Value
            $Results += Add-AppItem -id $app.id -displayName $app.displayName -version $app.version -deviceName ($DetectedDevices.devicename -join ',') -deviceid ($DetectedDevices.id -join ',') -appCount $Response."@odata.count"

            }

        }
    }
    $Results | Export-Csv -Path "$PSScriptRoot\DetectedApps-$timestamp.csv" -NoTypeInformation -Encoding UTF8
}

else {

write-host "No Intune Discovered Apps found..." -f green
Write-Host

}
