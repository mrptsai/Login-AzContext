<#
.SYNOPSIS
     Save your Azure context with account and subscription information to a file
 
.DESCRIPTION
    Sometimes life is about the little things, and one little thing that has been bothering me is
    logging on to Azure in Powershell using Connect-AzAccount. Every time you start Powershell,
    you need to log on again and that gets tired quickly, especially with accounts having mandatory 2FA.
 
    It gets even more complicated if you have multiple accounts to manage, for instance, one for testing
    and another for production. To top it off, you can start over when it turns out that your context
    has expired, which you will only discover after you actually executed some Az commands.
 
    The standard trick to make this easier is to save your Azure context with account and subscription information
    to a file (Save-AzContext or Save-AzContext), and to import this file whenever you need
    (Import-AzContext or Import-AzContext). But we can do a little bit better than that.
 
.PARAMETER ParentFolder
    A String value for the path to store the Context File (Required)
 
.PARAMETER AccountName
    A String value for the name of account (Required)
 
.PARAMETER TenantId
    A String value for the guid of a Tenant (Required)
 
.PARAMETER Subscription
    A String value for the name of a subscription

.PARAMETER Environment Name
    A String value for the name of an Azure Enviroment e.g. AzureCloud, AzureStackAdmin etc.
 
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
        function azure-customer { New-AzureContext -ParentFolder "$env:HOME/PowerShell" -AccountName "customer" -TenantId "8dbf3853-c31f-400d-b3fb-b54168b2603f" -SubscriptionId "9877a694-1b15-4cdc-91d2-7bbfde6bf348"}
        function azure-personal { New-AzureContext -ParentFolder "$env:HOME/PowerShell" -AccountName "personal" -TenantId "565aa719-38f8-4fa4-9275-94f2312fbb3c" -SubscriptionId "18e4b8ac-b35e-4acc-8f00-a040d99bad43"}
        function azurestack-work-admin { New-AzureContext -ParentFolder "$env:HOME/PowerShell" -AccountName "work-stack-admin" -TenantId "9d2426e9-b74a-428e-9065-80f29e416c3e" -Environment "AzureStackAdmin"}
        function azurestack-work-user { New-AzureContext -ParentFolder "$env:HOME/PowerShell" -AccountName "work-stack-user" -TenantId "9d2426e9-b74a-428e-9065-80f29e416c3e" -Environment "AzureStackUser"}
    
    To log on to 'personal', you simply execute azure-personal.  If this is a first logon, I get the usual Azure logon
    dialog and the resulting context gets saved.
 
    The next time, the existing file is loaded and the context tested for validity. From that point on you can
    switch between accounts whenever you need.
 
.NOTES
    Version:                1.4.0
    Author:                 Willem Kasdorp (original https://blogs.technet.microsoft.com/389thoughts/2018/02/11/logging-on-to-azure-for-your-everyday-job/)
    Modified:               Paul Towler (Data#3)
    Creation Date:          29/10/2018 16:00
    Purpose/Change:         Initial script development
    Required Modules:       Az
    Dependencies:           none
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
                            [12/08/2020 - 1.2.0 - Paul Towler]: Removed AzureRm (Time to move on)
                            [12/08/2021 - 1.3.0 - Paul Towler]: BUGFIX: Issue with multiple Tenants and the same account name. Also issue using same Subscription Names. Changed to SubscriptionId.
                            [01/04/2022 - 1.4.0 - Paul Towler]: FEATURE: Added functionality to specify and Azure Environment and the ability to create Azure Stuck Hub Environments.
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
 
        [Parameter(Mandatory=$true)]
        [string] $TenantId,
 
        [Parameter(Mandatory=$false)]
        [string] $SubscriptionId,

        [Parameter(Mandatory=$false)]
        [string] $EnvironmentName
    )
 
    $validlogon = $false
    $contextfile = Join-Path $ParentFolder "$AccountName.json"
    $contextEmpty = Join-Path $ParentFolder "empty.json"

    # Clean Up
    Clear-AzContext -Force
 
    if (-not (Test-Path $ParentFolder -ErrorAction SilentlyContinue))
    { New-Item -ItemType Directory -Path $ParentFolder }
 
    if (-not (Test-Path $contextEmpty -ErrorAction SilentlyContinue))
    {
        '{
            "DefaultContextKey": "Default",
            "EnvironmentTable": {},
            "Contexts": {},
            "ExtendedProperties": {}
        }' | New-Item -Path $ParentFolder -Name "empty.json"
    }
    
    $Environments = Get-AzEnvironment

    if ("AzureStackAdmin" -notin $Environments.Name -or "AzureStackUser" -notin $Environments.Name)
    {
        switch ($EnvironmentName)
        {
            "AzureStackAdmin"
            {
                # Register an Azure Resource Manager environment that targets your Azure Stack Hub instance. Get your Azure Resource Manager endpoint value from your service provider.     
                Add-AzEnvironment -Name $environment_name `
                    -ArmEndpoint "https://adminmanagement.local.azurestack.external" `
                    -AzureKeyVaultDnsSuffix adminvault.local.azurestack.external `
                    -AzureKeyVaultServiceEndpointResourceId https://adminvault.local.azurestack.external
            }

            default # AzureStackUser 
            {
                # Register an Azure Resource Manager environment that targets your Azure Stack Hub instance. Get your Azure Resource Manager endpoint value from your service provider.     
                Add-AzEnvironment -Name $environment_name `
                    -ArmEndpoint "https://management.local.azurestack.external" `
                    -AzureKeyVaultDnsSuffix vault.local.azurestack.external `
                    -AzureKeyVaultServiceEndpointResourceId https://vault.local.azurestack.external
            }
        }
    }

    if (-not (Test-Path $contextfile -ErrorAction SilentlyContinue))
    {
        Write-Host "`r`n No Azure Context file exists. Please log in to Azure for account '$($AccountName)'" -ForegroundColor Yellow
    } else
    {
        $context = (Import-AzContext $contextEmpty).Context
        Get-ChildItem $ParentFolder -Filter "Azure*.json" | Remove-Item -Force
 
        # Importing existing context
        $context = (Import-AzContext $contextfile).Context

        if ($SubscriptionId -and $context.Subscription.Id -ne $SubscriptionId)
        {
            $context = Set-AzContext -Tenant $TenantId -SubscriptionName $SubscriptionId
            Save-AzContext -Path $contextfile -Force
        }
 
        # check for token expiration by executing an Azure command that should always succeed.
        Write-Host "`r`n Imported Azure context for account '$($AccountName)', now checking for validity of the token....." -ForegroundColor Yellow
 
        # Validating
        $validlogon = $null -ne (Get-AzSubscription -TenantId $TenantId -SubscriptionId $context.Subscription.Id -ErrorAction SilentlyContinue)
 
        if ($validlogon)
        {
            Write-Host "`r`n Imported Azure context:`t$($contextfile)" -ForegroundColor Yellow
            Write-Host "`r`n Current User Account is:`t$($context.Account.Id)" -ForegroundColor Yellow
            Write-Host " Current Environment is:`t$($context.Environment)" -ForegroundColor Yellow
            Write-Host " Current TenantId is:`t`t$($context.Tenant.Id)" -ForegroundColor Yellow
            Write-Host " Current Subscription Name is:`t$($context.Subscription.Name)" -ForegroundColor Yellow
            Write-Host " Current Subscription Id is:`t$($context.Subscription.Id)`r`n" -ForegroundColor Yellow
        } else
        {
            # Getting Token
            $token = Get-AzCachedAccessToken
            if ($token)
            {
                $validlogon = $true

                Write-Host "`r`n Token is Valid!" -ForegroundColor Yellow
                Write-Host "`r`n Current User Account is:`t$($context.Account.Id)" -ForegroundColor Yellow
                Write-Host " Current Environment is:`t$($context.Environment)" -ForegroundColor Yellow
                Write-Host " Current TenantId is:`t`t$($context.Tenant.Id)" -ForegroundColor Yellow
                Write-Host " Current Subscription Name is:`t$($context.Subscription.Name)" -ForegroundColor Yellow
                Write-Host " Current Subscription Id is:`t$($context.Subscription.Id)`r`n" -ForegroundColor Yellow
            } else
            {   Write-Host "`r`n Logon for account '$($AccountName)' has expired, please log on again.`r`n" -ForegroundColor Yellow }
        }
    }
 
    if (-not $validlogon)
    {
        $context = $null
 
        if ($TenantId -and !$SubscriptionId -and !$EnvironmentName)
        { 
            $null = Connect-AzAccount -TenantId $TenantId
            Save-AzContext -Path $contextfile -Force 
        }

        if ($TenantId -and !$SubscriptionId -and $EnvironmentName)
        { 
            $null = Connect-AzAccount -TenantId $TenantId -Environment $EnvironmentName
            Save-AzContext -Path $contextfile -Force 
        }
 
        if ($TenantId -and $SubscriptionId -and !$EnvironmentName)
        { 
            $null = Connect-AzAccount -TenantId $TenantId -Subscription $SubscriptionId
            Save-AzContext -Path $contextfile -Force 
        }

        if ($TenantId -and $SubscriptionId -and $EnvironmentName)
        { 
            $null = Connect-AzAccount -TenantId $TenantId -Subscription $SubscriptionId -Environment $EnvironmentName
            Save-AzContext -Path $contextfile -Force 
        }
 
        $context = (Import-AzContext -Path $contextfile).Context
 
        if ($context)
        {
            Write-Host "`r`n SUCCESS! Logged on to Azure with '$($AccountName)' successfully!" -ForegroundColor Green
            Write-Host "`r`n Context saved to:`t`t$($contextfile)" -ForegroundColor Green
            Write-Host " Current User Account is:`t$($context.Account.Id)" -ForegroundColor Green
            Write-Host " Current Environment is:`t$($context.Environment)" -ForegroundColor Green
            Write-Host " Current TenantId is:`t`t$($context.Tenant.Id)" -ForegroundColor Green
            Write-Host " Current Subscription Name is:`t$($context.Subscription.Name)" -ForegroundColor Green
            Write-Host " Current Subscription Id is:`t$($context.Subscription.Id)`r`n" -ForegroundColor Green
        } else
        {
            Write-Host "`r`n ERROR! Log on to Azure for account '$($AccountName)' failed, please retry.`n" -ForegroundColor Red
        }
    }

    if ($Modules = Get-Module -ListAvailable AzureAD*)
    {
        if ($IsMacOS -or $IsLinux)
        {
            #Nothing
        } else
        {
            Switch ($Modules = Get-Module -ListAvailable AzureAD*)
            {
                {$PSItem.Name -contains "AzureADPreview"}
                {$Module = "AzureADPreview"}
    
                Default
                {$Module = "AzureAD"}
            }

            Write-Host "`r`n Logging into Azure AD...." -ForegroundColor Yellow
            if ($psversiontable.PSVersion.Major -eq 5)
            {   Import-Module -Name $Module -Force   } else
            {   Import-Module -Name $Module -Force -UseWindowsPowerShell    }
            Write-Host " Imported $($Module)" -ForegroundColor Gray
    
            $AzureAD = Connect-AzureAD -TenantId $Context.Tenant.Id -AccountId $Context.Account.Id
            Write-Host " SUCCESS! Logged on to AzureAD Domain '$($AzureAD.TenantDomain)' successfully!`n" -ForegroundColor Green
        }
    }
}
 
function Get-AzCachedAccessToken()
{
    $context = (Get-AzContext -ErrorAction SilentlyContinue | Select-Object -First 1)
 
    if ([string]::IsNullOrEmpty($context)) {
        $null = Connect-AzAccount
        $context = (Get-AzContext | Select-Object -First 1)
    }
    $ErrorActionPreference = "SilentlyContinue"
    $token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id, $null, "Never", $null, "74658136-14ec-4630-ad9b-26e160ff0fc6")
    $token.AccessToken
    $ErrorActionPreference = "Stop"
}
#endregion
 
#region Variables
$ErrorActionPreference = "Stop"
$autoSave = Get-AzContextAutosaveSetting -Scope CurrentUser
if ($autoSave.Mode -eq "Process")
{ Enable-AzContextAutosave | Out-Null   }
 
$parentFolder = "$($home)/PowerShell"
#endregion

#region Example Azure Logons - **** EXAMPLES ONLY ****
try
{
    #region Azure Logons
    function azure-work { New-AzureContext -ParentFolder "$env:HOME/PowerShell" -AccountName "work" -TenantId "9d2426e9-b74a-428e-9065-80f29e416c3e"}
    function azure-customer { New-AzureContext -ParentFolder "$env:HOME/PowerShell" -AccountName "customer" -TenantId "8dbf3853-c31f-400d-b3fb-b54168b2603f" -SubscriptionId "9877a694-1b15-4cdc-91d2-7bbfde6bf348"}
    function azure-personal { New-AzureContext -ParentFolder "$env:HOME/PowerShell" -AccountName "personal" -TenantId "565aa719-38f8-4fa4-9275-94f2312fbb3c" -SubscriptionId "18e4b8ac-b35e-4acc-8f00-a040d99bad43"}
    function azurestack-work-admin { New-AzureContext -ParentFolder "$env:HOME/PowerShell" -AccountName "work-stack-admin" -TenantId "9d2426e9-b74a-428e-9065-80f29e416c3e" -Environment "AzureStackAdmin"}
    function azurestack-work-user { New-AzureContext -ParentFolder "$env:HOME/PowerShell" -AccountName "work-stack-user" -TenantId "9d2426e9-b74a-428e-9065-80f29e416c3e" -Environment "AzureStackUser"}
    #endregion
} catch
{ $_ }
#endregion

