<#
.SYNOPSIS
     Save your Azure context with account and subscription information to a file

.DESCRIPTION 
    Sometimes life is about the little things, and one little thing that has been bothering me is 
    logging on to Azure in Powershell using Add-AzureRmAccount or Add-AzAccount. Every time you start Powershell, 
    you need to log on again and that gets tired quickly, especially with accounts having mandatory 2FA.

    It gets even more complicated if you have multiple accounts to manage, for instance, one for testing 
    and another for production. To top it off, you can start over when it turns out that your context
    has expired, which you will only discover after you actually executed some AzureRm or Az commands.

    The standard trick to make this easier is to save your Azure context with account and subscription information
    to a file (Save-AzureRmContext or Save-AzContext), and to import this file whenever you need 
    (Import-AzureRmContext or Import-AzContext). But we can do a little bit better than that.

.PARAMETER ParentFolder
    A String value for the path to store the Context File (Required)

.PARAMETER AccountName
    A String value for the name of account (Required)

.PARAMETER Version
    An Integer value for the major version of PowerShell.

.PARAMETER TenantId
    A String value for the guid of a Tenant

.PARAMETER Subscription
    A String value for the name of a subscription

.EXAMPLE
    
    Use a PowerShell profile to define a function doing the work. 
    
    A profile gets loaded whenever you start PowerShell. There are multiple profiles, but the one we want 
    is for CurrentUser - Allhosts.
    
    The function will load the Azure context from a file. If there is no such file, it should prompt me to log on.
    
    After logging on, the context should be tested for validity because the token may have expired.

    If the token is expired, prompt for logon again.

    If needed, save the new context to a file.

    To make this work, add this function to the powershell profile: from the Powershell ISE, 
    type ise $profile.CurrentUserAllHosts or VSCode, type code $profile.CurrentUserAllHosts to edit the profile
    and copy/paste the function definition. 

    Suppose I have two Azure accounts that I want to use here, called 'personal' and 'work'. For that I would add the
    following function definitions to the profile:
   
        function azure-work { New-AzureContext -ParentFolder "$env:HOME/PowerShell" -AccountName "work" -TenantId "9d2426e9-b74a-428e-9065-80f29e416c3e"}
        function azure-customer { New-AzureContext -ParentFolder "$env:HOME/PowerShell" -AccountName "customer" -TenantId "8dbf3853-c31f-400d-b3fb-b54168b2603f" -Subscription "Staging"}
        function azure-personal { New-AzureContext -ParentFolder "$env:HOME/PowerShell" -AccountName "personal"}

    To log on to 'personal', you simply execute azure-personal.  If this is a first logon, I get the usual Azure logon 
    dialog and the resulting context gets saved. 

    The next time, the existing file is loaded and the context tested for validity. From that point on you can 
    switch between accounts whenever you need.

.NOTES
    Version:				1.1.0
    Author:					Willem Kasdorp (original https://blogs.technet.microsoft.com/389thoughts/2018/02/11/logging-on-to-azure-for-your-everyday-job/)
    Modified:               Paul Towler (Data#3)
    Creation Date:			29/10/2018 16:00
    Purpose/Change:			Initial script development
    Required Modules:       AzureRm or Az
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
                            [26/08/2019 - 1.1.0 - Paul Towler]: Added TenantId parameter to cater for accounts that have access to many Tenants
#>
							

#region Functions
function New-AzureContext
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $ParentFolder,

        [Parameter(Mandatory=$true)]
        [string] $AccountName,

        [Parameter(Mandatory=$false)]
        [int] $Version = $psversiontable.PSVersion.Major,

        [Parameter(Mandatory=$false)]
        [string] $TenantId,

        [Parameter(Mandatory=$false)]
        [string] $Subscription
    )

    $validlogon = $false
    $contextfile = Join-Path $parentfolder "$accountname.json"
    $contextEmpty = Join-Path $parentfolder "empty.json"
    if ($Version -ge 6) 
    {   Enable-AzureRmAlias -Scope CurrentUser    }

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

        if (!$TenantId -and !$Subscription)
        { $account = Add-AzureRmAccount }

        if ($TenantId -and !$Subscription)
        { $account = Add-AzureRmAccount -TenantId $TenantId }
        
        if ($TenantId -and $Subscription)
        { $account = Add-AzureRmAccount -TenantId $TenantId -Subscription $Subscription }
 
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

switch ($psversiontable.PSVersion.Major)
{   
    5 { $parentFolder = "$($home)/Windows PowerShell"  }
    6 { $parentFolder = "$($home)/PowerShell"  } 
}
#endregion

#region Example Azure Logons
try
{
    #region Azure Logons
    function azure-work { New-AzureContext -ParentFolder $parentFolder -AccountName "work" -TenantId "9d2426e9-b74a-428e-9065-80f29e416c3e"}
    function azure-customer { New-AzureContext -ParentFolder $parentFolder -AccountName "customer" -TenantId "8dbf3853-c31f-400d-b3fb-b54168b2603f" -Subscription "Staging"}
    function azure-personal { New-AzureContext -ParentFolder $parentFolder -AccountName "personal"}
    #endregion
} catch
{ $_ }
#endregion