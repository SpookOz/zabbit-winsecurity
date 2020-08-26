# Powershell script for Zabbix agents.

# Version 2.1 - for Zabbix agent 5x

## This script will collect some information about the security status of Windows Desktop clients and report them to Zabbix.

#### Check https://github.com/SpookOz/zabbit-winsecurity for the latest version of this script

# ------------------------------------------------------------------------- #
# Variables
# ------------------------------------------------------------------------- #

# Change $ZabbixInstallPath to wherever your Zabbix Agent is installed

$ZabbixInstallPath = "$Env:Programfiles\Zabbix Agent"
$ZabbixConfFile = "$Env:Programdata\zabbix"

# Do not change the following variables unless you know what you are doing

$Sender = "$ZabbixInstallPath\zabbix_sender.exe"
$Senderarg1 = '-vv'
$Senderarg2 = '-c'
$Senderarg3 = "$ZabbixConfFile\zabbix_agentd.conf"
$Senderarg4 = '-i'
$SenderSecurityStatus = '\securitystatus.txt'


# ------------------------------------------------------------------------- #
# This part gets the inventory data and writes it to a temp file
# ------------------------------------------------------------------------- #

# Get Antivirus Information

function Get-AntivirusName { 
[cmdletBinding()]     
param ( 
[string]$ComputerName = "$env:computername" , 
$Credential 
) 
    $wmiQuery = "SELECT * FROM AntiVirusProduct" 
    $AntivirusProduct = Get-WmiObject -Namespace "root\SecurityCenter2" -Query $wmiQuery  @psboundparameters         
    [array]$AntivirusNames = $AntivirusProduct.displayName       
    Switch($AntivirusNames) {
        {$AntivirusNames.Count -eq 0}{"Anti-Virus is NOT installed!";Continue}
        {$AntivirusNames.Count -eq 1 -and $_ -eq "Windows Defender"} {"ONLY Windows Defender is installed!";Continue}
		 {$_ -ne "Windows Defender"} {"$_, "}
   }
}

function Get-AntivirusCount { 
[cmdletBinding()]     
param ( 
[string]$ComputerName = "$env:computername" , 
$Credential 
) 
    $wmiQuery = "SELECT * FROM AntiVirusProduct" 
    $AntivirusProduct = Get-WmiObject -Namespace "root\SecurityCenter2" -Query $wmiQuery  @psboundparameters         
    [array]$AntivirusNames = $AntivirusProduct.displayName       

	if ($AntivirusNames.Count -gt 1 -and $AntivirusNames -eq "Windows Defender") {
	$AntivirusNames.Count - 1
	}
	else {$AntivirusNames.Count
	}


}

## Antivirus Variables

$winav = Get-AntivirusName
$winavcnt = Get-AntivirusCount

$outputav1 = "- Win.Antivirusname "
$outputav1 += '"'
$outputav1 += "$($winav)"
$outputav1 += '"'

$outputav2 = "- Win.Antivirusnum "
$outputav2 += "$($winavcnt)"

Write-Output $outputav1 | Out-File -Encoding "ASCII" -FilePath $env:temp$SenderSecurityStatus
Add-Content $env:temp$SenderSecurityStatus $outputav2


# Get Windows Security Center (WSC) information

$wscDefinition = @"
        // WSC_SECURITY_PROVIDER as defined in Wscapi.h or http://msdn.microsoft.com/en-us/library/bb432509(v=vs.85).aspx
		[Flags]
        public enum WSC_SECURITY_PROVIDER : int
        {
            WSC_SECURITY_PROVIDER_FIREWALL = 1,				// The aggregation of all firewalls for this computer.
            WSC_SECURITY_PROVIDER_AUTOUPDATE_SETTINGS = 2,	// The automatic update settings for this computer.
            WSC_SECURITY_PROVIDER_ANTIVIRUS = 4,			// The aggregation of all antivirus products for this computer.
            WSC_SECURITY_PROVIDER_ANTISPYWARE = 8,			// The aggregation of all anti-spyware products for this computer.
            WSC_SECURITY_PROVIDER_INTERNET_SETTINGS = 16,	// The settings that restrict the access of web sites in each of the Internet zones for this computer.
            WSC_SECURITY_PROVIDER_USER_ACCOUNT_CONTROL = 32,	// The User Account Control (UAC) settings for this computer.
            WSC_SECURITY_PROVIDER_SERVICE = 64,				// The running state of the WSC service on this computer.
            WSC_SECURITY_PROVIDER_NONE = 0,					// None of the items that WSC monitors.
			
			// All of the items that the WSC monitors.
            WSC_SECURITY_PROVIDER_ALL = WSC_SECURITY_PROVIDER_FIREWALL | WSC_SECURITY_PROVIDER_AUTOUPDATE_SETTINGS | WSC_SECURITY_PROVIDER_ANTIVIRUS |
            WSC_SECURITY_PROVIDER_ANTISPYWARE | WSC_SECURITY_PROVIDER_INTERNET_SETTINGS | WSC_SECURITY_PROVIDER_USER_ACCOUNT_CONTROL |
            WSC_SECURITY_PROVIDER_SERVICE | WSC_SECURITY_PROVIDER_NONE
        }

        [Flags]
        public enum WSC_SECURITY_PROVIDER_HEALTH : int
        {
            WSC_SECURITY_PROVIDER_HEALTH_GOOD, 			// The status of the security provider category is good and does not need user attention.
            WSC_SECURITY_PROVIDER_HEALTH_NOTMONITORED,	// The status of the security provider category is not monitored by WSC. 
            WSC_SECURITY_PROVIDER_HEALTH_POOR, 			// The status of the security provider category is poor and the computer may be at risk.
            WSC_SECURITY_PROVIDER_HEALTH_SNOOZE, 		// The security provider category is in snooze state. Snooze indicates that WSC is not actively protecting the computer.
            WSC_SECURITY_PROVIDER_HEALTH_UNKNOWN
        }

		// as defined in http://msdn.microsoft.com/en-us/library/bb432506(v=vs.85).aspx
        [DllImport("wscapi.dll")]
        private static extern int WscGetSecurityProviderHealth(int inValue, ref int outValue);

		// code to call our interop function and return the relevant result based on what input value we provide
        public static WSC_SECURITY_PROVIDER_HEALTH GetSecurityProviderHealth(WSC_SECURITY_PROVIDER inputValue)
        {
            int inValue = (int)inputValue;
            int outValue = -1;

            int result = WscGetSecurityProviderHealth(inValue, ref outValue);

            foreach (WSC_SECURITY_PROVIDER_HEALTH wsph in Enum.GetValues(typeof(WSC_SECURITY_PROVIDER_HEALTH)))
                if ((int)wsph == outValue) return wsph;

            return WSC_SECURITY_PROVIDER_HEALTH.WSC_SECURITY_PROVIDER_HEALTH_UNKNOWN;
        }
"@

$wscType=Add-Type -memberDefinition $wscDefinition -name "wscType" -UsingNamespace "System.Reflection","System.Diagnostics" -PassThru

"            Firewall: " + $wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_FIREWALL)
"         Auto-Update: " + $wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_AUTOUPDATE_SETTINGS)
"          Anti-Virus: " + $wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_ANTIVIRUS)
"        Anti-Spyware: " + $wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_ANTISPYWARE)
"   Internet Settings: " + $wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_INTERNET_SETTINGS)
"User Account Control: " + $wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_USER_ACCOUNT_CONTROL)
"         WSC Service: " + $wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_SERVICE)


if ($wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_FIREWALL) -eq $wscType[2]::WSC_SECURITY_PROVIDER_HEALTH_POOR)
{
	    Add-Content $env:temp$SenderSecurityStatus "- Win.Firewall BAD"
}

if ($wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_FIREWALL) -eq $wscType[2]::WSC_SECURITY_PROVIDER_HEALTH_GOOD)
{
	    Add-Content $env:temp$SenderSecurityStatus "- Win.Firewall OK"
}

if ($wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_ANTIVIRUS) -eq $wscType[2]::WSC_SECURITY_PROVIDER_HEALTH_POOR)
{
	Add-Content $env:temp$SenderSecurityStatus "- Win.Antivirus BAD"
}

if ($wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_ANTIVIRUS) -eq $wscType[2]::WSC_SECURITY_PROVIDER_HEALTH_GOOD)
{
	Add-Content $env:temp$SenderSecurityStatus "- Win.Antivirus OK"
}

if ($wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_ANTISPYWARE) -eq $wscType[2]::WSC_SECURITY_PROVIDER_HEALTH_POOR)
{
	Add-Content $env:temp$SenderSecurityStatus "- Win.Antispyware BAD"
}

if ($wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_ANTISPYWARE) -eq $wscType[2]::WSC_SECURITY_PROVIDER_HEALTH_GOOD)
{
	Add-Content $env:temp$SenderSecurityStatus "- Win.Antispyware OK"
}

if ($wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_AUTOUPDATE_SETTINGS) -eq $wscType[2]::WSC_SECURITY_PROVIDER_HEALTH_POOR)
{
	Add-Content $env:temp$SenderSecurityStatus "- Win.Autoupdate BAD"
}
if ($wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_AUTOUPDATE_SETTINGS) -eq $wscType[2]::WSC_SECURITY_PROVIDER_HEALTH_GOOD)
{
	Add-Content $env:temp$SenderSecurityStatus "- Win.Autoupdate OK"
}

if ($wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_SERVICE) -eq $wscType[2]::WSC_SECURITY_PROVIDER_HEALTH_POOR)
{
	Add-Content $env:temp$SenderSecurityStatus "- Win.SecurityCenter BAD"
}
if ($wscType[0]::GetSecurityProviderHealth($wscType[1]::WSC_SECURITY_PROVIDER_SERVICE) -eq $wscType[2]::WSC_SECURITY_PROVIDER_HEALTH_GOOD)
{
	Add-Content $env:temp$SenderSecurityStatus "- Win.SecurityCenter OK"
}

# ------------------------------------------------------------------------- #
# This part sends the information in the temp file to Zabbix
# ------------------------------------------------------------------------- #

& $Sender $Senderarg1 $Senderarg2 $Senderarg3 $Senderarg4 $env:temp$SenderSecurityStatus -s "$env:computername"