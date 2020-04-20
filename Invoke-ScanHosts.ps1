#Requires -Version 7
<#
	.NOTES
	===========================================================================
	 Filename:     	Invoke-ScanHosts.ps1
	===========================================================================
	.DESCRIPTION
	This script is a simple port scanner that takes command line arguments. It 
	uses the updated Test-Connection cmdlet that is availabe in Powershell 7 for
	maximum cross compatability. 
	.PARAMETER hosts
	(Required) takes IP addresses(es) of host(s) in CIDR format
	.PARAMETER ports
	(Required) takes an integer value or multiple values seprated by commas or a range
	.OUTPUTS
	NONE
	.INPUTS
	NONE
	.EXAMPLE
	./Invoke-ScanHosts.ps1 -hosts 192.168.1.1/32 -ports 80
    .EXAMPLE
    ./Invoke-ScanHosts.ps1 -hosts 192.168.1.1/24 -ports 80,443,20-22
#>
param(
    [Parameter(Mandatory=$true)]
    $hosts,
    [Parameter(Mandatory=$true)]
    $ports

)
###############################################################
function Test-Port{
    param(
        $machine,
        [int]$port
    )
    If (Test-Connection $machine -TcpPort $port) 
    {
        Write-Host $machine $port -Separator " *** " -ForegroundColor Green 
    } 
    else {
        Write-Host $machine $port -Separator " !!! " -ForegroundColor Red
    }
}
###############################################################
function Get-IpRange{
    <# 
  .SYNOPSIS  
    Get the IP addresses in a range 
  .EXAMPLE 
   Get-IPrange -ip 192.168.8.3 -cidr 24 
  .NOTES
   This Function is Adapted from https://gallery.technet.microsoft.com/scriptcenter/List-the-IP-addresses-in-a-60c5bb6b by BarryCWT
    #>
    param(
        $ip,
        $cidr
    )
function Convert-IPtoINT64 () { 
  param ($ip) 
 
  $octets = $ip.split(".") 
  return [int64]([int64]$octets[0]*16777216 +[int64]$octets[1]*65536 +[int64]$octets[2]*256 +[int64]$octets[3]) 
} 
 
function Convert-INT64toIP() { 
  param ([int64]$int) 

  return (([math]::truncate($int/16777216)).tostring()+"."+([math]::truncate(($int%16777216)/65536)).tostring()+"."+([math]::truncate(($int%65536)/256)).tostring()+"."+([math]::truncate($int%256)).tostring() )
} 

$ipaddr = [Net.IPAddress]::Parse($ip)
$maskaddr = [Net.IPAddress]::Parse((Convert-INT64toIP -int ([convert]::ToInt64(("1"*$cidr+"0"*(32-$cidr)),2)))) 
$networkaddr = new-object net.ipaddress ($maskaddr.address -band $ipaddr.address)
$broadcastaddr = new-object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $maskaddr.address -bor $networkaddr.address))
$startaddr = Convert-IPtoINT64 -ip $networkaddr.ipaddresstostring 
$endaddr = Convert-IPtoINT64 -ip $broadcastaddr.ipaddresstostring
$iprange = @()
for ($i = $startaddr+1; $i -lt $endaddr; $i++) 
{ 
  $iprange += Convert-INT64toIP -int $i 
}
return $iprange
}
###############################################################
if(!$hosts.Contains("/")){
    Write-Warning "IP address requires CIDR notation (i.e. 192.168.1.1/32)"
    exit
}
$network = $hosts.Split('/')
$ip = $network[0]
$cidr = $network[1]

if([string]::IsNullOrEmpty($cidr)){
    Write-Warning "CIDR notation is required (i.e. 192.168.1.1/32)"
    exit
}

$iprange = Get-IpRange -ip $ip -cidr $cidr

if($cidr -eq 32){
    foreach ($port in $ports){
            if ($port -isnot [int]){
                $range = $port.Split("-")
                $range[0]..$range[1] | ForEach-Object {Test-Port -machine $ip -port $_}
            }
            else{
                Test-Port -machine $ip -port $port
            }   
    }
}
else{
    foreach ($item in $iprange){
        foreach ($port in $ports){
            if ($port -isnot [int]){
                $range = $port.Split("-")
                $range[0]..$range[1] | ForEach-Object {Test-Port -machine $item -port $_}
            }
            else{
                Test-Port -machine $item -port $port
            }
        }
    }
}
