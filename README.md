# Login-AzContext

## Synopis <br>
Save your Azure RM context with account and subscription information to a file

## Description <br>
Sometimes life is about the little things, and one little thing that has been bothering me is logging on to Azure RM in Powershell using Add-AzAccount. Every time you start Powershell, you need to log on again and that gets tired quickly, especially with accounts having mandatory 2FA.

It gets even more complicated if you have multiple accounts to manage, for instance, one for testing and another for production. To top it off, you can start over when it turns out that your context has expired, which you will only discover after you actually executed some AzureRM commands.

The standard trick to make this easier is to save your Azure RM context with account and subscription information to a file (Save-AzContext), and to import this file whenever you need (Import-AzContext). But we can do a little bit better than that.

## Parameters <br> 
### ParentFolder <br>
A String value for the path to store the Context File

### AccountName <br>
A String value for the name of account

## Example <br>    
Use a PowerShell profile to define a function doing the work. 
    
A profile gets loaded whenever you start PowerShell. There are multiple profiles, but the one we want is for CurrentUser - Allhosts.
    
The function will load the AzureRM context from a file. If there is no such file, it should prompt me to log on.
    
After logging on, the context should be tested for validity because the token may have expired. If the token is expired, prompt for logon again.

If needed, save the new context to a file. To make this work, add this function to the powershell profile: from the Powershell ISE, type ise $profile.CurrentUserAllHosts or VSCode, type code $profile.CurrentUserAllHosts to edit the profile and copy/paste the function definition. 

Suppose I have two Azure RM accounts that I want to use here, called 'foo' and 'bar'. For that I would add the following function definitions to the profile:
``` PowerShell
#
# specific azure logons. Context file is deliberately in a non-synced folder for security reasons.
#
    
function azure-foo { Login-AzureContext -Parentfolder "$env:APPDATA\Windows Azure PowerShell" -accountname "foo" }
Function azure-bar { Login-AzureContext -Parentfolder "$env:APPDATA\Windows Azure PowerShell" -accountname "bar" }
```
To log on to 'foo', you simply execute azure-foo. If this is a first logon, I get the usual Azure logon dialog and the resulting context gets saved. The next time, the existing file is loaded and the context tested for validity. From that point on you can switch between accounts whenever you need.

## Notes <br>
<table>
    <tr><td>Version:</td><td>0.01</td></tr>
    <tr><td>Author:</td><td>Willem Kasdorp (original https://blogs.technet.microsoft.com/389thoughts/2018/02/11/logging-on-to-azure-for-your-everyday-job/)</td></tr>
    <tr><td>Modified:</td><td>Paul Towler</td></tr>
    <tr><td>Creation Date:</td><td>29/10/2018 16:00</td></tr>
    <tr><td>Purpose/Change:</td><td>Initial script development</td></tr>
    <tr><td>Required Modules:</td><td>Az</td></tr>
    <tr><td>Dependencies:</td><td>PowerShell Core</td></tr>
    <tr><td>Limitations:</td><td>None</td></tr>
    <tr><td>Supported Platforms *</td><td>Windows, macOs <br> *Currently not tested against other platforms</td></tr>
    <tr><td>Version History:</td><td>[29/10/2018 - 0.01 - Paul Towler]: Initial script. Add fixes as discussed here: <br> https://www.bountysource.com/issues/62862211-your-azure-credentials-have-not-been-set-up-or-have-expired-please-run-connect-azurermaccount-to-set-up-your-azure-credentials</td></tr>
</table>
