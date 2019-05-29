<#
.SYNOPSIS
     Save your Azure RM context with account and subscription information to a file

.DESCRIPTION
    Sometimes life is about the little things, and one little thing that has been bothering me is 
    logging on to Azure RM in Powershell using Add-AzureRMAccount. Every time you start Powershell, 
    you need to log on again and that gets tired quickly, especially with accounts having mandatory 2FA.

    It gets even more complicated if you have multiple accounts to manage, for instance, one for testing 
    and another for production. To top it off, you can start over when it turns out that your context
    has expired, which you will only discover after you actually executed some AzureRM commands.

    The standard trick to make this easier is to save your Azure RM context with account and subscription 
    information to a file (Save-AzureRMContext), and to import this file whenever you need 
    (Import-AzureRMContext). But we can do a little bit better than that.

.PARAMETER ParentFolder
    A String Paramater for the path to the CSV File.

.PARAMETER AccountName

.EXAMPLE
    
    Use a PowerShell profile to define a function doing the work. 
    
    A profile gets loaded whenever you start PowerShell. There are multiple profiles, but the one we want 
    is for CurrentUser - Allhosts.
    
    The function will load the AzureRM context from a file. If there is no such file, it should prompt me to log on.
    
    After logging on, the context should be tested for validity because the token may have expired.

    If the token is expired, prompt for logon again.

    If needed, save the new context to a file.

    To make this work, add this function to the powershell profile: from the Powershell ISE, 
    type ise $profile.CurrentUserAllHosts or VSCode, type code $profile.CurrentUserAllHosts to edit the profile
    and copy/paste the function definition. 

    Suppose I have two Azure RM accounts that I want to use here, called 'foo' and 'bar'. For that I would add the
    following function definitions to the profile:

        #
        # specific azure logons. Context file is deliberately in a non-synced folder for security reasons.
        #
    
        function azure-foo { Login-AzureContext -Parentfolder "$env:APPDATA\Windows Azure PowerShell" -accountname "foo" }
        function azure-bar { Login-AzureContext -Parentfolder "$env:APPDATA\Windows Azure PowerShell" -accountname "bar" }

    To log on to 'foo', you simply execute azure-foo. If this is a first logon, I get the usual AzureRM logon 
    dialog and the resulting context gets saved. 

    The next time, the existing file is loaded and the context tested for validity. From that point on you can 
    switch between accounts whenever you need.

.NOTES
    Version:				1.00
    Author:					Willem Kasdorp (original https://blogs.technet.microsoft.com/389thoughts/2018/02/11/logging-on-to-azure-for-your-everyday-job/)
    Modified:               Paul Towler (Data#3)
    Creation Date:			29/10/2018 16:00
    Purpose/Change:			Initial script development
    Required Modules:       AzureRm
    Dependencies:			none
    Limitations:            none
    Supported Platforms*:   Windows
                            *Currently not tested against other platforms
    Version History:        [29/10/2018 - 0.01 - Paul Towler]: Initial script. Add fixes as discussed here:
                            https://www.bountysource.com/issues/62862211-your-azure-credentials-have-not-been-set-up-or-have-expired-please-run-connect-azurermaccount-to-set-up-your-azure-credentials
                            [21/02/2019 - 0.02 - Paul Towler]: Added Check for PowerShell Core
                            [29/05/2019 - 1.00 - Paul Towler]: Full Release
                            Updated PowerShell Core to enable AzureRm Alias and a New function to get Access Token from:
                            https://www.codeisahighway.com/how-to-easily-and-silently-obtain-accesstoken-bearer-from-an-existing-azure-powershell-session/ 
#>
							

#region Functions
function Login-AzureContext
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $ParentFolder,

        [Parameter(Mandatory=$true)]
        [string] $AccountName,

        [Parameter(Mandatory=$true)]
        [int] $Version
    )

    $validlogon = $false
    $contextfile = Join-Path $parentfolder "$accountname.json"
    $contextEmpty = Join-Path $parentfolder "empty.json"
    
	if (-not (Test-Path $parentfolder -ErrorAction SilentlyContinue))
	{ New-Item -ItemType Directory -Path $parentfolder }

    if (-not (Test-Path $contextEmpty -ErrorAction SilentlyContinue))
    {
        '{
            "DefaultContextKey": "Default",
            "EnvironmentTable": {},
            "Contexts": {},
            "ExtendedProperties": {}
        }' | New-Item -Path $parentfolder -Name "empty.json"
    }
    
    if (-not (Test-Path $contextfile -ErrorAction SilentlyContinue))
    {
        Write-Host "`r`n No existing Azure Context file in:`t$($parentfolder)`n Please log in to Azure with account '$($accountname)'" -ForegroundColor Yellow
    } else
    {        
        if ($Version -ge 6) 
        { 
            Enable-AzureRmAlias -Scope CurrentUser
        }
               
        $context = Import-AzureRmContext $contextEmpty -ErrorAction stop
        Get-ChildItem $parentfolder -Filter "Azure*.json" | Remove-Item -Force
          
        # Importing existing context  
        $context = Import-AzureRmContext $contextfile -ErrorAction stop
        
        # check for token expiration by executing an Azure command that should always succeed.
        Write-Host "`r`n Imported Azure context for account '$($accountname)', now checking for validity of the token....." -ForegroundColor Yellow
                              
        # Validating
        $validlogon = $null -ne (Get-AzureRmSubscription -SubscriptionName $context.Context.Subscription.Name -ErrorAction SilentlyContinue)
        
        if ($validlogon)
        {
            Write-Host "`r`n Imported Azure context:`t$($contextfile)" -ForegroundColor Yellow 
            Write-Host " Current subscription is:`t$($context.Context.Subscription.Name)`r`n" -ForegroundColor Yellow
        } else
        {
            # Getting Token
            $token = Get-AzCachedAccessToken
            if ($token)
            { 
                $validlogon = $true
            } else
            {
                Write-Host "`r`n Logon for account '$($accountname)' has expired, please log on again.`r`n" -ForegroundColor Yellow
            }
        }
    }
    
    if (-not $validlogon)
    {
        $account = $null
        $account = Add-AzureRmAccount
        if ($account) 
        {
            Save-AzureRmContext -Path $contextfile -Force
            Write-Host "`r`n SUCCESS! Logged on to Azure with '$($accountname)' successfully!" -ForegroundColor Green
            Write-Host " Context saved to:`t$($contextfile)`r`n" -ForegroundColor Green

            $context = Import-AzureRmContext $contextfile -ErrorAction stop
        } else 
        {
            Write-Host "`r`n ERROR! Log on to Azure for account '$($accountname)' failed, please retry.`n" -ForegroundColor Red
        }
    }
        
    if (Get-Module -ListAvailable AzureAD)
    {
        Write-Host "`r`n Logging into Azure AD...." -ForegroundColor Yellow
        $AzureAD = Connect-AzureAD -TenantId $Context.Context.Tenant.Id -AccountId $Context.Context.Account.Id
        Write-Host " SUCCESS! Logged on to AzureAD Domain '$($AzureAD.TenantDomain)' successfully!`n" -ForegroundColor Green
    }
}

function Get-AzCachedAccessToken()
{
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."    
    }
  
    $currentAzureContext = Get-AzureRmContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}
#endregion

#region Variables
if (!$env:AzureRmContextAutoSave)
{ $env:AzureRmContextAutoSave="true" }

$Version = $psversiontable.PSVersion.Major
#endregion

#region Azure Logons
try
{
	function azure-work { Login-AzureContext -ParentFolder "$env:APPDATA\Windows Azure PowerShell" -AccountName "work" -Version $Version }
	function azure-personal { Login-AzureContext -ParentFolder "$env:APPDATA\Windows Azure PowerShell" -AccountName "personal" -Version $Version }
} catch
{ $_ }
#endregion

#Begin Azure PowerShell alias import
Import-Module Az.Accounts -ErrorAction SilentlyContinue -ErrorVariable importError
if ($importerror.Count -eq 0) { 
    Enable-AzureRmAlias -Module Az.Accounts, Az.Aks, Az.AnalysisServices, Az.ApiManagement, Az.ApplicationInsights, Az.Automation, Az.Backup, Az.Batch, Az.Billing, Az.Cdn, Az.CognitiveServices, Az.Compute, Az.Compute.ManagedService, Az.ContainerInstance, Az.ContainerRegistry, Az.DataFactory, Az.DataLakeAnalytics, Az.DataLakeStore, Az.DataMigration, Az.DeviceProvisioningServices, Az.DevSpaces, Az.Dns, Az.EventGrid, Az.EventHub, Az.FrontDoor, Az.HDInsight, Az.IotCentral, Az.IotHub, Az.KeyVault, Az.LogicApp, Az.MachineLearning, Az.ManagedServiceIdentity, Az.ManagementPartner, Az.Maps, Az.MarketplaceOrdering, Az.Media, Az.Monitor, Az.Network, Az.NotificationHubs, Az.OperationalInsights, Az.PolicyInsights, Az.PowerBIEmbedded, Az.RecoveryServices, Az.RedisCache, Az.Relay, Az.Reservations, Az.ResourceGraph, Az.Resources, Az.Scheduler, Az.Search, Az.Security, Az.ServiceBus, Az.ServiceFabric, Az.SignalR, Az.Sql, Az.Storage, Az.StorageSync, Az.StreamAnalytics, Az.Subscription, Az.TrafficManager, Az.Websites -ErrorAction SilentlyContinue; 
}
#End Azure PowerShell alias import
