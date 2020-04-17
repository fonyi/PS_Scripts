<#	
	.NOTES
	===========================================================================
	 Created by:   	Shane Fonyi (shane.fonyi@westpoint.edu)
	 Organization: 	Army Cyber Institute
	 Filename:     	Invoke-NewlyCreatedDomainCheck.ps1
	===========================================================================
	.DESCRIPTION
        This script downloads the prior day new domain registrations from 
        whoisds.com and unzips the archive. It then injests the txt file with
        the domains and performs a regex search looking for possible typo-
        squatting and other possible nefarious domains related to the organization.
	.INPUTS
		NONE
	.OUTPUTS
		CSV File in the current PowerShell working directory
	.EXAMPLE
		./Invoke-NewlyCreatedDomainCheck.ps1
#>
#########################################################################################################
$listdate = ((Get-Date).AddDays(-1)|Get-Date -format yyyy-MM-dd)
$date = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($listdate+".zip")) 
$url = "https://whoisds.com//whois-database/newly-registered-domains/$date/nrd"
$output = "$PSScriptRoot\domain-names-$date.zip"
(New-Object System.Net.WebClient).DownloadFile($url,$output)
Expand-Archive -Path $output -DestinationPath "$PSScriptRoot\" -Force
$domains = Get-Content "$PSScriptRoot\domain-names.txt"
$regex = '.*' #CHANGEME
$possibledomains = @()
$possibledomains += "Domains registered $($listdate)"
ForEach($domain in $domains){
        if($domain -match $regex){
            $possibledomains += $domain
        }
}
$possibledomains | Out-File -FilePath "$PSScriptRoot\SuspiciousDomains-$(Get-Date -format yyyy-MM-dd).csv" -Encoding UTF8
