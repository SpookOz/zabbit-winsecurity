# zabbix-winsecurity

This is a Zabbix template to monitor and report on Windows security status for active Windows agents. It has been tested on Zabbix 4.4.8 with Windows 81. and 10. Currently needs testing with other Windows versions and other Zabbix versions.


## Features

- Works with active agents (behind NAT - so perfect remote sites).
- Checked the WIndows Security Center for current status of:
	- The Firewall
	- Windows Auto-Update
	- Antivirus Status
	- Antispyware Status
	- Secuirty Center
- Reports the name of the currently active antivirus application
- Reports (and gives a warning) if there are more than one AV products active	
- It can also (optionally) auto-update the Powershell template with a newer verion


## Requirements

- Has only been tested with Zabbix active agents. It will need tweaking to work with passive agents.
- At this stage it has only been tested on Windows 8.1 and 10.
- You MUST have EnableRemoteCommands=1 in your conf file (so it can run the PS script).
- This script assumes the Zabbix client is installed in the Program Files directory. You will need to modify the Powershell script if it is not.
- This only works on Windows desktop OS. It does not work on Windows Server as the Server doesn't use Security Center


## Files Included

- winsecurity.xml: Template to import into Zabbix.
- check-sec2020.ps1: Powershell script. Must be placed in a "plugins" directory under your Zabbix Agent install folder (eg: C:\Program Files\Zabbix Agent\plugins).


## Installing

1. Ensure your Windows hosts have the agent installed and configured correctly and they are communicating with the Zabbix server.
2. Make sure you have edited the zabbix_agentd.conf file to include the line: EnableRemoteCommands=1.
3. Download winsecurity.xml template from Github and import the template in Zabbix and apply it to one or more Windows Hosts.

### Option 1 - Deploy Powershell Script Manually

Choose this option if you want to make any changes to the PowerShell script. You may want to change the report path, or you may need to change the agent install path if you don't have a default install (C:\Program Files\Zabbix Agent).


1. Create a sub-folder called "plugins" in your Zabbix Agent install folder (eg: C:\Program Files\Zabbix Agent\plugins).
2. Download check-sec2020.ps1 from Github and make any changes you need to it. Check the .ps file for instructions on making changes.
3. Copy check-sec2020.ps1 to the plugins directory.

### Option 2 - Automatic Deployment of the Powershell script

This is a good option if you have a number of hosts you want to monitor but don't have an easy way to deploy the PS script to them all.

1. Edit the template in Zabbix (Configuration / Templates / WinUpdates).
2. Go to the "Items" tab.
3. You will see a disabled item called "Update Security Template". Click on it to edit it.
4. Click the button to enable the item and click "Update".
5. Once all hosts have received the script, disable this item again, or it will re-download the script every day!

The item has a 1d update interval, so it may take up to a day for the PowerShell script to download. You can shorten this if you like.

### Dashboard

You can add a widget to your Dashboard by choosing type: Data overview and application "Win-Security-Panel".