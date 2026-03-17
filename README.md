# Login-AzContext

## Synopsis

Save your Azure context with account and subscription information to a file

## Description

Sometimes life is about the little things, and one little thing that has been bothering me is logging on to Azure in PowerShell using `Connect-AzAccount`. Every time you start PowerShell, you need to log on again and that gets tired quickly, especially with accounts having mandatory 2FA.

It gets even more complicated if you have multiple accounts to manage, for instance, one for testing and another for production. To top it off, you can start over when it turns out that your context has expired, which you will only discover after you actually executed some Az commands.

The standard trick to make this easier is to save your Azure context with account and subscription information to a file (`Save-AzContext`), and to import this file whenever you need (`Import-AzContext`). This script also synchronizes Azure CLI to the same tenant and subscription after the Azure PowerShell context has been restored or refreshed.

## Parameters

### ParentFolder (Required)

A String value for the path to store the Context File

### AccountName (Required)

A String value for the name of account

### TenantId (Required)

A string value for the tenant GUID. Tenant names such as `contoso.onmicrosoft.com` are also accepted and resolved to a tenant ID automatically.

### SubscriptionId

A String value for the guid of a subscription

### AzCliAuthMethod

Controls how Azure CLI authenticates when `-AzureCLI` is used and a CLI login is required.

Allowed values:

- `Default`
- `Browser`
- `DeviceCode`

## Example

Use a PowerShell profile to define a function doing the work.

A profile gets loaded whenever you start PowerShell. There are multiple profiles, but the one we want is for CurrentUser - Allhosts.

The function will load the Azure context from a file. If there is no such file, it should prompt me to log on.

After logging on, the context should be tested for validity because the token may have expired. If the token is expired, prompt for logon again.

If needed, save the new context to a file. To make this work, add this function to the powershell profile: from the Powershell ISE, type ise $profile.CurrentUserAllHosts or VSCode, type code $profile.CurrentUserAllHosts to edit the profile and copy/paste the function definition. 

Suppose I have two Azure accounts that I want to use here, called 'personal' and 'work'. For that I would add the following function definitions to the profile:

``` PowerShell
#
# specific azure logons. Context file is deliberately in a non-synced folder for security reasons.
#

function azure-personal { Connect-Account -ParentFolder "$env:LOCALAPPDATA\Windows Azure PowerShell" -AccountName "personal" -TenantId "9d2426e9-b74a-428e-9065-80f29e416c3e" }
function azure-work { Connect-Account -ParentFolder "$env:LOCALAPPDATA\Windows Azure PowerShell" -AccountName "work" -TenantId "contoso.onmicrosoft.com" -SubscriptionId "9877a694-1b15-4cdc-91d2-7bbfde6bf348" -AzureCLI -AzCliAuthMethod DeviceCode }
```

To log on to 'personal', you simply execute azure-personal. If this is a first logon, I get the usual Azure logon dialog and the resulting context gets saved. The next time, the existing file is loaded and the context tested for validity. From that point on you can switch between accounts whenever you need.

## Notes

| | |
| - | - |
| Version: | 1.5.0 |
| Author: | Willem Kasdorp ([original](https://blogs.technet.microsoft.com/389thoughts/2018/02/11/logging-on-to-azure-for-your-everyday-job/)) |
| Modified: | Paul Towler |
| Creation Date: | 29/10/2018 16:00 |
| Required Modules: | Az |
| Dependencies: | PowerShell 5.1 or PowerShell Core |
| Limitations: | None |
| Supported Platforms * | Windows, macOS <br> *Currently not tested against other platforms |
| Version History: | [29/10/2018 - 0.01 - Paul Towler]: Initial script. [Add fixes as discussed](https://www.bountysource.com/issues/62862211-your-azure-credentials-have-not-been-set-up-or-have-expired-please-run-connect-azurermaccount-to-set-up-your-azure-credentials) |
| | [21/02/2019 - 0.02 - Paul Towler]: Added Check for PowerShell Core |
| | [21/02/2019 - 1.0.0 - Paul Towler]: Full Release - Updated PowerShell Core to enable AzureRm Alias - [New function to get Access Token](https://www.codeisahighway.com/how-to-easily-and-silently-obtain-accesstoken-bearer-from-an-existing-azure-powershell-session/)
| | [26/08/2019 - 1.1.0 - Paul Towler]: Added TenantId parameter to cater for accounts that have access to many Tenants |
| | [12/08/2020 - 1.2.0 - Paul Towler]: Removed AzureRm (Time to move on) |
| | [12/08/2021 - 1.3.0 - Paul Towler]: BUGFIX: Issue with multiple Tenants and the same account name. Also issue using same Subscription Names. Changed to SubscriptionId. |
| | [01/04/2022 - 1.4.0 - Paul Towler]: FEATURE: Added functionality to specify an Azure Environment and the ability to create Azure Stack Hub Environments. |
| | [16/03/2026 - 1.5.0 - Paul Towler]: FEATURE: Added Azure CLI context synchronization, tenant name resolution and remove Azure Stack Hub authentication |
