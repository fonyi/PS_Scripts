#Requires -Modules AzureAD
<#	
	.NOTES
	===========================================================================
	 Created by:   	Shane Fonyi (shane.fonyi@westpoint.edu)
	 Organization: 	Army Cyber Institute
	 Filename:     	Run-IntuneDeviceReport.ps1
	===========================================================================
	.DESCRIPTION
		This script is used to search in AzureAD and Microsoft InTune for
        Windows devices. The lists are then compared to determine which devices
        are in AzureAD but NOT in InTune. The list is exported as a CSV in the
        directory the PS script lives in. The list is deduplicated based off of
        machine display name, so there is a chance that devices that are
        reimaged are given a new name and have a stale record in Azure AD. The 
        list includes On-Prem AD joined, AAD Joined, and AAD Regsitered. The 
        trustType propery has three values. AzureAd which mean AzureAD Joined,
        Workplace which means Azure AD Registered, and ServerAD which means
        on-prem AD joined. For more information on the properties, go to
        https://docs.microsoft.com/en-us/graph/api/resources/device?view=graph-rest-1.0#properties

	.INPUTS
		NONE
	.OUTPUTS
		CSV File in the current PowerShell working directory
	.EXAMPLE
		./Invoke-IntuneDeviceReport.ps1
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

Function Get-IntuneDevices(){

<#
.SYNOPSIS
This function is used to get Intune Managed Devices from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any Intune Managed Device
.EXAMPLE
Get-ManagedDevices
Returns all managed devices but excludes EAS devices registered within the Intune Service
.EXAMPLE
Get-ManagedDevices -IncludeEAS
Returns all managed devices including EAS devices registered within the Intune Service
.NOTES
NAME: Get-ManagedDevices
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
#>

[cmdletbinding()]

param
(
    [switch]$IncludeEAS,
    [switch]$ExcludeMDM
)

# Defining Variables
$graphApiVersion = "beta"
$Resource = "deviceManagement/managedDevices"

try {

    $Count_Params = 0

    if($IncludeEAS.IsPresent){ $Count_Params++ }
    if($ExcludeMDM.IsPresent){ $Count_Params++ }
        
        if($Count_Params -gt 1){

        write-warning "Multiple parameters set, specify a single parameter -IncludeEAS, -ExcludeMDM or no parameter against the function"
        Write-Host
        break

        }
        
        elseif($IncludeEAS){

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"

        }

        elseif($ExcludeMDM){

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?`$filter=managementAgent eq 'eas'"

        }
        
        else {
    
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?`$filter=managementAgent eq 'mdm' and managementAgent eq 'easmdm'"
        Write-Warning "EAS Devices are excluded by default, please use -IncludeEAS if you want to include those devices"
        Write-Host

        }

        $IntuneResponse = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
        $IntuneDevices = $IntuneResponse.value

        $IntuneNextLink = $IntuneResponse."@odata.nextLink"

        while ($IntuneNextLink -ne $null){
            Write-Progress -Activity "Retreiving Intune Devices" -Status "$($IntuneNextLink)"
            $IntuneResponse = (Invoke-RestMethod -Uri $IntuneNextLink -Headers $authToken -Method Get)
            $IntuneNextLink = $IntuneResponse."@odata.nextLink"
            $IntuneDevices += $IntuneResponse.value
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
    return $IntuneDevices
}

####################################################

Function Get-ManagedDeviceUser(){

<#
.SYNOPSIS
This function is used to get a Managed Device username from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets a managed device users registered with Intune MDM
.EXAMPLE
Get-ManagedDeviceUser -DeviceID $DeviceID
Returns a managed device user registered in Intune
.NOTES
NAME: Get-ManagedDeviceUser
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true,HelpMessage="DeviceID (guid) for the device on must be specified:")]
    $DeviceID
)

# Defining Variables
$graphApiVersion = "beta"
$Resource = "deviceManagement/manageddevices('$DeviceID')?`$select=userId"

    try {

    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
    Write-Verbose $uri
    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).userId

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
Function Get-AzureADDevices(){
[cmdletbinding()]
 
$graphApiVersion = "v1.0"
$Resource = "devices"
$QueryParams = ""
 
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
    Write-Progress -Activity "Retreiving AD Devices" -Status "$($NextLink)"
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
$filename = "AADMachinesMissingMDM-$timestamp"

$InTuneDevices = Get-IntuneDevices -IncludeEAS
$AzureDevices = Get-AzureADDevices
$WindowsAzureDevices = $AzureDevices | Select * | where {$_.operatingsystem -eq "Windows"}
$WindowsAADMissingMDM = $WindowsAzureDevices | where {$InTuneDevices.azureADDeviceId -notcontains $_.deviceid}
$MissingMDMDedupe = $WindowsAADMissingMDM | Sort-Object -Property displayName -Unique

#$DeviceType = $AzureDevices.operatingSystem | group -NoElement | Select -ExpandProperty Name

Write-Progress -Activity "Writing Output to CSV"
$MissingMDMDedupe | Select id, deletedDateTime,accountEnabled,approximateLastSignInDateTime,deviceId,deviceVersion,displayName,isCompliant,isManaged,manufacturer,mdmAppId,model,onPremisesLastSyncDateTime,onPremisesSyncEnabled,operatingSystem,operatingSystemVersion,@{Name='physicalIds';Expression={[string]::join(";",($_.physicalIds))}},profileType,trustType | Export-Csv -Path "$PSScriptroot\$filename.csv" -NoTypeInformation -Encoding UTF8
#$IntuneDevices | Select "id","userId","deviceName","ownerType","managedDeviceOwnerType","managementState","enrolledDateTime","lastSyncDateTime","chassisType","operatingSystem","deviceType","complianceState","jailBroken","managementAgent","osVersion","easActivated","easDeviceId","easActivationDateTime","aadRegistered","azureADRegistered","deviceEnrollmentType","lostModeState","activationLockBypassCode","emailAddress","azureActiveDirectoryDeviceId","azureADDeviceId","deviceRegistrationState","deviceCategoryDisplayName","isSupervised","exchangeLastSuccessfulSyncDateTime","exchangeAccessState","exchangeAccessStateReason","remoteAssistanceSessionUrl","remoteAssistanceSessionErrorDetails","isEncrypted","userPrincipalName","model","manufacturer","imei","complianceGracePeriodExpirationDateTime","serialNumber","phoneNumber","androidSecurityPatchLevel","userDisplayName","configurationManagerClientEnabledFeatures","wiFiMacAddress","deviceHealthAttestationState","subscriberCarrier","meid","totalStorageSpaceInBytes","freeStorageSpaceInBytes","managedDeviceName","partnerReportedThreatState","retireAfterDateTime","preferMdmOverGroupPolicyAppliedDateTime","autopilotEnrolled","requireUserEnrollmentApproval","managementCertificateExpirationDate","iccid","udid",@{Name='physicalIds';Expression={[string]::join(";",($_.roleScopeTagIds))}},"windowsActiveMalwareCount","windowsRemediatedMalwareCount","notes","configurationManagerClientHealthState","configurationManagerClientInformation","ethernetMacAddress","physicalMemoryInBytes","processorArchitecture","hardwareInformation",@{Name='deviceActionResults';Expression={[string]::join(";",($_.deviceActionResults))}},@{Name='usersLoggedOn';Expression={[string]::join(";",($_.usersLoggedOn))}} | Export-Csv -Path 'C:\Users\sfonyi\OneDrive - West Point\Scripts\IntuneDevices.csv' -NoTypeInformation -Encoding UTF8
