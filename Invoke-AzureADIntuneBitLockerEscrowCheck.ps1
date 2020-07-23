#Requires -Modules AzureAD,ImportExcel
<#	
	.NOTES
	===========================================================================
	 Created by:   	Shane Fonyi (shane.fonyi@westpoint.edu)
	 Organization: 	United States Military Academy
	 Filename:     	Invoke-AzureADIntuneBitLockerEscrowCheck.ps1
	===========================================================================
	.DESCRIPTION
		This script is used to search in Microsoft Graph for
        all InTune MDM Windows devices and their Encryption status. The
        information returns TRUE/FALSE and the AzureAD Object ID. AzureAD is
	queried for recovery key information. The recovery key is not exposed
	by default. The data is then combined to show which devices are encrypted
	but not escrowing a key. The Excel sheet can be filtered by column R for
	TRUE and then column C for FALSE to get the list of items that are encrypted
	and not escrowed. The remediation script Create-BitLockerRecoveryPassword.ps1
	can be pushed in InTune to create and/or send the recovery password to AzureAD.
	Takes about 15-20 minutes to run.

	.INPUTS
		NONE
	.OUTPUTS
		XLSX File in the current PowerShell working directory
	.EXAMPLE
		./Invoke-AzureADIntuneBitLockerEscrowCheck.ps1
#>

####################################################
 function get-bitlockerEscrowStatusForAzureADDevices{
    <#
      .SYNOPSIS
      Retrieves bitlocker key upload status for all azure ad devices
      .DESCRIPTION
      Use this report to determine which of your devices have backed up their bitlocker key to AzureAD (and find those that haven't and are at risk of data loss!).
      Report will be stored in current folder.
      .EXAMPLE
      get-bitlockerEscrowStatusForAzureADDevices
      .PARAMETER Credential
      Optional, pass a credential object to automatically sign in to Azure AD. Global Admin permissions required
      .PARAMETER showBitlockerKeysInReport
      Switch, is supplied, will show the actual recovery keys in the report. Be careful where you distribute the report to if you use this
      .PARAMETER showAllOSTypesInReport
      By default, only the Windows OS is reported on, if for some reason you like the additional information this report gives you about devices in general, you can add this switch to show all OS types
      .NOTES
      filename: get-bitlockerEscrowStatusForAzureADDevices.ps1
      author: Jos Lieben
      blog: www.lieben.nu
      created: 9/4/2019
    #>
    [cmdletbinding()]
    Param(
        $Credential,
        [Switch]$showBitlockerKeysInReport,
        [Switch]$showAllOSTypesInReport
    )

    Import-Module AzureRM.Profile
    if (Get-Module -Name "AzureADPreview" -ListAvailable) {
        Import-Module AzureADPreview
    } elseif (Get-Module -Name "AzureAD" -ListAvailable) {
        Import-Module AzureAD
    }
 
    if ($Credential) {
        Try {
            Connect-AzureAD -Credential $Credential -ErrorAction Stop | Out-Null
        } Catch {
            Write-Warning "Couldn't connect to Azure AD non-interactively, trying interactively."
            Connect-AzureAD -TenantId $(($Credential.UserName.Split("@"))[1]) -ErrorAction Stop | Out-Null
        }
 
        Try {
            Login-AzureRmAccount -Credential $Credential -ErrorAction Stop | Out-Null
        } Catch {
            Write-Warning "Couldn't connect to Azure RM non-interactively, trying interactively."
            Login-AzureRmAccount -TenantId $(($Credential.UserName.Split("@"))[1]) -ErrorAction Stop | Out-Null
        }
    } else {
        Login-AzureRmAccount -ErrorAction Stop | Out-Null
    }
    $context = Get-AzureRmContext
    $tenantId = $context.Tenant.Id
    $refreshToken = @($context.TokenCache.ReadItems() | where {$_.tenantId -eq $tenantId -and $_.ExpiresOn -gt (Get-Date)})[0].RefreshToken
    $body = "grant_type=refresh_token&refresh_token=$($refreshToken)&resource=74658136-14ec-4630-ad9b-26e160ff0fc6"
    $apiToken = Invoke-RestMethod "https://login.windows.net/$tenantId/oauth2/token" -Method POST -Body $body -ContentType 'application/x-www-form-urlencoded'
    $restHeader = @{
        'Authorization' = 'Bearer ' + $apiToken.access_token
        'X-Requested-With'= 'XMLHttpRequest'
        'x-ms-client-request-id'= [guid]::NewGuid()
        'x-ms-correlation-id' = [guid]::NewGuid()
    }
    Write-Verbose "Connected, retrieving devices..."
    $restResult = Invoke-RestMethod -Method GET -UseBasicParsing -Uri "https://main.iam.ad.ext.azure.com/api/Devices?nextLink=&queryParams=%7B%22searchText%22%3A%22%22%7D&top=15" -Headers $restHeader
    $allDevices = @()
    $allDevices += $restResult.value
    while($restResult.nextLink){
        Write-Progress -Activity "Retreiving AD Devices" -Status "$($restResult.nextLink)"
        $restResult = Invoke-RestMethod -Method GET -UseBasicParsing -Uri "https://main.iam.ad.ext.azure.com/api/Devices?nextLink=$([System.Web.HttpUtility]::UrlEncode($restResult.nextLink))&queryParams=%7B%22searchText%22%3A%22%22%7D&top=15" -Headers $restHeader
        $allDevices += $restResult.value
    }

    Write-Verbose "Retrieved $($allDevices.Count) devices from AzureAD, processing information..."

    $csvEntries = @()
    foreach($device in $allDevices){
        if(!$showAllOSTypesInReport -and $device.deviceOSType -notlike "Windows*"){
            Continue
        }
        $keysKnownToAzure = $False
        $osDriveEncrypted = $False
        $lastKeyUploadDate = $Null
        if($device.deviceOSType -eq "Windows" -and $device.bitLockerKey.Count -gt 0){
            $keysKnownToAzure = $True
            $keys = $device.bitLockerKey | Sort-Object -Property creationTime -Descending
            if($keys.driveType -contains "Operating system drive"){
                $osDriveEncrypted = $True
            }
            $lastKeyUploadDate = $keys[0].creationTime
            if($showBitlockerKeysInReport){
                $bitlockerKeys = ""
                foreach($key in $device.bitlockerKey){
                    $bitlockerKeys += "$($key.creationTime)|$($key.driveType)|$($key.recoveryKey)|"
                }
            }else{
                $bitlockerKeys = "HIDDEN FROM REPORT: READ INSTRUCTIONS TO REVEAL KEYS"
            }
        }else{
            $bitlockerKeys = "NOT UPLOADED YET OR N/A"
        }

        $csvEntries += [PSCustomObject]@{"DeviceID"=$device.deviceId;"Name"=$device.displayName;"BitlockerKeysUploadedToAzureAD"=$keysKnownToAzure;"OS Drive encrypted"=$osDriveEncrypted;"lastKeyUploadDate"=$lastKeyUploadDate;"DeviceAccountEnabled"=$device.accountEnabled;"managed"=$device.isManaged;"ManagedBy"=$device.managedBy;"lastLogon"=$device.approximateLastLogonTimeStamp;"Owner"=$device.Owner.userPrincipalName;"bitlockerKeys"=$bitlockerKeys;"OS"=$device.deviceOSType;"OSVersion"=$device.deviceOSVersion;"Trust Type"=$device.deviceTrustType;"dirSynced"=$device.dirSyncEnabled;"Compliant"=$device.isCompliant}
    }
    
    return $csvEntries
}
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

Function Get-IntuneDevice(){
[cmdletbinding()]
 
$graphApiVersion = "beta"
$Resource = "deviceManagement/managedDevices"
$QueryParams = "?`$select=azureADDeviceId,isEncrypted"
 
try {
 
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)$QueryParams"
    $ADDevResponse = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
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
# Return the data
$ADDeviceResponse = $ADDevResponse
$ADDevices = $ADDeviceResponse.Value
$NextLink = $ADDeviceResponse.'@odata.nextLink'
# Need to loop the requests because only 100 results are returned each time
while ($NextLink -ne $null)
{
    Write-Progress -Activity "Retreiving InTune Devices" -Status "$($NextLink)"
    $ADDeviceResponse = Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get
    $NextLink = $ADDeviceResponse.'@odata.nextLink'
    $ADDevices += $ADDeviceResponse.Value
}
 
return $ADDevices

}


#region Authentication
<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
#>
write-host
#?
# Checking if authToken exists before running authentication
if($global:authToken){

    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

        if($TokenExpires -le 0){

        write-host "Authentication Token expired" $TokenExpires "minutes ago" -ForegroundColor Yellow
        write-host

            # Defining User Principal Name if not present

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

$timestamp = Get-Date -Format "yyyy-MM-dd-HH_mm"
$filename = "BitLockerEscrowReport-$timestamp"


$dcount = 0
$IntuneDevices = Get-IntuneDevice
$AzureADDevices = get-bitlockerEscrowStatusForAzureADDevices
foreach($device in $AzureADDevices){
    $dcount++
    $intuneStatus = $IntuneDevices | Where-Object {$_.azureaddeviceid -eq $device.DeviceId}
    $device | Add-Member -MemberType NoteProperty -Name "Intune Encryption Enabled" -Value $intuneStatus.isEncrypted
    Write-Progress -Activity "Updating List AzureAD with InTune Encryption Status" -PercentComplete ($dcount/$AzureADDevices.count*100)
}
$AzureADDevices | Export-Excel -workSheetName "BitlockerReport" -path "$PSScriptRoot\$filename" -ClearSheet -TableName "BitlockerReport" -AutoSize -Verbose
