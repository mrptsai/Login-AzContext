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
    to a file (Save-AzContext), and to import this file whenever you need
    (Import-AzContext). But we can do a little bit better than that.

.PARAMETER ParentFolder
    A String value for the path to store the Context File (Required)

.PARAMETER AccountName
    A String value for the name of account (Required)

.PARAMETER TenantId
    A String value for the guid of a Tenant (Required)

.PARAMETER SubscriptionId
    A String value for the guid of a subscription

.PARAMETER EnvironmentName
    A String value for the name of an Azure Environment e.g. AzureCloud, AzureStackAdmin etc.

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

        function azure-work { Connect-Account -ParentFolder "$env:HOME/PowerShell" -AccountName "work" -TenantId "9d2426e9-b74a-428e-9065-80f29e416c3e"}
        function azure-customer { Connect-Account -ParentFolder "$env:HOME/PowerShell" -AccountName "customer" -TenantId "8dbf3853-c31f-400d-b3fb-b54168b2603f" -SubscriptionId "9877a694-1b15-4cdc-91d2-7bbfde6bf348"}
        function azure-personal { Connect-Account -ParentFolder "$env:HOME/PowerShell" -AccountName "personal" -TenantId "565aa719-38f8-4fa4-9275-94f2312fbb3c" -SubscriptionId "18e4b8ac-b35e-4acc-8f00-a040d99bad43"}
        function azurestack-work-admin { Connect-Account -ParentFolder "$env:HOME/PowerShell" -AccountName "work-stack-admin" -TenantId "9d2426e9-b74a-428e-9065-80f29e416c3e" -EnvironmentName "AzureStackAdmin"}
        function azurestack-work-user { Connect-Account -ParentFolder "$env:HOME/PowerShell" -AccountName "work-stack-user" -TenantId "9d2426e9-b74a-428e-9065-80f29e416c3e" -EnvironmentName "AzureStackUser"}

    To log on to 'personal', you simply execute azure-personal.  If this is a first logon, I get the usual Azure logon
    dialog and the resulting context gets saved.

    The next time, the existing file is loaded and the context tested for validity. From that point on you can
    switch between accounts whenever you need.

.NOTES
    Version:                1.5.0
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
                            [01/04/2022 - 1.4.0 - Paul Towler]: FEATURE: Added functionality to specify an Azure Environment and the ability to create Azure Stack Hub Environments.
                            [16/03/2026 - 1.5.0 - Paul Towler]: FEATURE: Added functionality to login to Azure CLI in the same context as Azure PowerShell.
#>

#region Functions
function Write-ContextBanner
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Title,

        [Parameter(Mandatory = $false)]
        [ConsoleColor] $Color = [ConsoleColor]::Cyan
    )

    Write-Host ""
    Write-Host ("== {0} ==" -f $Title) -ForegroundColor $Color
}

function Write-ContextItem
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Label,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string] $Value,

        [Parameter(Mandatory = $false)]
        [ConsoleColor] $Color = [ConsoleColor]::White
    )

    if ([string]::IsNullOrWhiteSpace($Value))
    {
        return
    }

    Write-Host ("   {0,-18} : " -f $Label) -ForegroundColor $Color -NoNewline
    Write-Host ("{0}" -f $Value) -ForegroundColor White
}

function Write-AzureContextSummary
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Title,

        [Parameter(Mandatory = $true)]
        [psobject] $Context,

        [Parameter(Mandatory = $false)]
        [string] $ContextFile,

        [Parameter(Mandatory = $false)]
        [ConsoleColor] $Color = [ConsoleColor]::White
    )

    Write-ContextBanner -Title $Title -Color $Color

    if ($ContextFile)
    {
        Write-ContextItem -Label "Context File" -Value $ContextFile -Color $Color
    }

    Write-ContextItem -Label "Account" -Value $Context.Account.Id -Color $Color
    Write-ContextItem -Label "Environment" -Value $Context.Environment.Name -Color $Color
    Write-ContextItem -Label "Tenant" -Value $Context.Tenant.Id -Color $Color
    Write-ContextItem -Label "Subscription" -Value $Context.Subscription.Name -Color $Color
    Write-ContextItem -Label "Subscription Id" -Value $Context.Subscription.Id -Color $Color
}

function Connect-Account
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $ParentFolder,

        [Parameter(Mandatory = $true)]
        [string] $AccountName,

        [Parameter(Mandatory = $true)]
        [Alias("TenantName")]
        [string] $TenantId,

        [Parameter(Mandatory = $false)]
        [string] $SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string] $EnvironmentName = "AzureCloud",

        [Parameter(Mandatory = $false)]
        [switch] $AzureCLI,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Default", "Browser", "DeviceCode")]
        [string] $AzCliAuthMethod = "Default"
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

    $resolvedTenantId = $TenantId
    $parsedTenantId = [guid]::Empty
    if (-not [guid]::TryParse($TenantId, [ref]$parsedTenantId))
    {
        $environment = Get-AzEnvironment -Name $EnvironmentName -ErrorAction Stop
        $authEndPoint = $environment.ActiveDirectoryAuthority.TrimEnd('/')
        $resolvedTenantId = (Invoke-RestMethod "$($authEndPoint)/$($TenantId)/.well-known/openid-configuration").issuer.TrimEnd('/').Split('/')[-1]
    }

    if (-not (Test-Path $contextfile -ErrorAction SilentlyContinue))
    {
        Write-ContextBanner -Title "Azure PowerShell" -Color Cyan
        Write-Host ("   No saved context found for '{0}'. Starting interactive login." -f $AccountName) -ForegroundColor Cyan
    }
    else
    {
        $context = (Import-AzContext $contextEmpty).Context
        Get-ChildItem $ParentFolder -Filter "Azure*.json" | Remove-Item -Force

        # Importing existing context
        $context = (Import-AzContext $contextfile).Context

        if ($SubscriptionId -and $context.Subscription.Id -ne $SubscriptionId)
        {
            $context = Set-AzContext -Tenant $resolvedTenantId -SubscriptionId $SubscriptionId
            Save-AzContext -Path $contextfile -Force
        }

        if ($EnvironmentName -and $context.Environment.Name -ne $EnvironmentName)
        {
            Write-ContextBanner -Title "Azure PowerShell" -Color Yellow
            Write-Host ("   Saved context environment '{0}' does not match requested '{1}'." -f $context.Environment.Name, $EnvironmentName) -ForegroundColor Yellow
            Write-Host "   Refreshing login." -ForegroundColor Yellow
            $validlogon = $false
        }
        else
        {
            # check for token expiration by executing an Azure command that should always succeed.
            Write-ContextBanner -Title "Azure PowerShell" -Color Yellow
            Write-Host ("   Loaded saved context for '{0}'. Validating token." -f $AccountName) -ForegroundColor White

            # Validating
            switch ($SubscriptionId)
            {
                { $PSItem }
                { $validlogon = $null -ne (Get-AzSubscription -TenantId $resolvedTenantId -SubscriptionId $context.Subscription.Id -ErrorAction SilentlyContinue) }

                default
                { $validlogon = $null -ne (Get-AzSubscription -TenantId $resolvedTenantId -ErrorAction SilentlyContinue) }
            }
        }

        if ($validlogon)
        {
            Write-AzureContextSummary -Title "Azure PowerShell Context Restored" -Context $context -ContextFile $contextFile -Color Green
        }
        else
        {
            # Getting Token
            $token = Get-AzAccessToken -ResourceUrl "https://management.core.windows.net/" -ErrorAction SilentlyContinue
            if ($token)
            {
                $validlogon = $true

                Write-ContextBanner -Title "Azure PowerShell" -Color Green
                Write-Host "   Token validation succeeded." -ForegroundColor Green
                Write-AzureContextSummary -Title "Azure PowerShell Context Active" -Context $context -ContextFile $contextFile
            }
            else
            {
                Write-ContextBanner -Title "Azure PowerShell" -Color Red
                Write-Host ("   Saved login for '{0}' has expired. Interactive login is required." -f $AccountName) -ForegroundColor Red
            }
        }
    }

    if (-not $validlogon)
    {
        $context = $null

        if ($resolvedTenantId -and !$SubscriptionId -and !$EnvironmentName)
        { 
            $null = Connect-AzAccount -TenantId $resolvedTenantId
            Save-AzContext -Path $contextfile -Force 
        }

        if ($resolvedTenantId -and !$SubscriptionId -and $EnvironmentName)
        { 
            $null = Connect-AzAccount -TenantId $resolvedTenantId -Environment $EnvironmentName
            Save-AzContext -Path $contextfile -Force 
        }

        if ($resolvedTenantId -and $SubscriptionId -and !$EnvironmentName)
        { 
            $null = Connect-AzAccount -TenantId $resolvedTenantId -Subscription $SubscriptionId
            Save-AzContext -Path $contextfile -Force
        }

        if ($resolvedTenantId -and $SubscriptionId -and $EnvironmentName)
        { 
            $null = Connect-AzAccount -TenantId $resolvedTenantId -Subscription $SubscriptionId -Environment $EnvironmentName
            Save-AzContext -Path $contextfile -Force 
        }

        $context = (Import-AzContext -Path $contextfile).Context

        if ($context)
        {
            Write-AzureContextSummary -Title "Azure PowerShell Login Succeeded" -Context $context -ContextFile $contextFile -Color Green
        } 
        else
        { throw "ERROR! Login for '$($environmentName)' failed, please retry." }
    }

    if ($context -and $AzureCLI)
    {
        Sync-AzCliContext -Context $context -AuthMethod $AzCliAuthMethod
    }
}

function Sync-AzCliContext
{
    param
    (
        [Parameter(Mandatory = $true)]
        [psobject] $Context,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Default", "Browser", "DeviceCode")]
        [string] $AuthMethod = "Default"
    )

    $azCommand = Get-Command -Name "az" -ErrorAction SilentlyContinue
    if (-not $azCommand)
    {
        Write-ContextBanner -Title "Azure CLI" -Color DarkYellow
        Write-Host "   Azure CLI is not installed. Skipping CLI sync." -ForegroundColor Gray
        return
    }

    $cliCloudName = switch ($Context.Environment.Name)
    {
        "AzureCloud" { "AzureCloud" }
        "AzureUSGovernment" { "AzureUSGovernment" }
        "AzureChinaCloud" { "AzureChinaCloud" }
        "AzureGermanCloud" { "AzureGermanCloud" }
        default { $null }
    }

    if (-not $cliCloudName)
    {
        Write-ContextBanner -Title "Azure CLI" -Color DarkYellow
        Write-Host ("   Environment '{0}' is not supported for CLI sync. Skipping." -f $Context.Environment.Name) -ForegroundColor Gray
        return
    }

    Write-ContextBanner -Title "Azure CLI" -Color Yellow
    Write-Host "   Synchronising CLI cloud, tenant, and subscription." -ForegroundColor White
    $null = az cloud set --name $cliCloudName --only-show-errors

    $azAccount = $null
    try
    {
        $azAccountJson = az account show --output json --only-show-errors 2>$null
        if ($azAccountJson)
        {
            $azAccount = $azAccountJson | ConvertFrom-Json
        }
    }
    catch
    {
        $azAccount = $null
    }

    $targetSubscriptionId = $Context.Subscription.Id
    $requiresCliLogin = `
    (-not $azAccount) -or `
    ($azAccount.tenantId -ne $Context.Tenant.Id) -or `
    ($targetSubscriptionId -and $azAccount.id -ne $targetSubscriptionId)

    if ($requiresCliLogin)
    {
        Write-Host "   Azure CLI login is required to match the Azure PowerShell context." -ForegroundColor White

        if ($AuthMethod -eq "Browser")
        {
            Write-Host "   Using browser authentication with Windows broker disabled for this login." -ForegroundColor Gray
            $env:AZURE_CORE_ENABLE_BROKER_ON_WINDOWS = "false"
        }

        $loginArgs = @("login", "--tenant", $Context.Tenant.Id, "--output", "none", "--only-show-errors")
        if (-not $targetSubscriptionId)
        {
            $loginArgs += "--allow-no-subscriptions"
        }

        switch ($AuthMethod)
        {
            "DeviceCode"
            {
                Write-Host "   Using device code authentication." -ForegroundColor Gray
                $loginArgs += "--use-device-code"
            }
            "Browser"
            {
                Write-Host "   Using browser authentication." -ForegroundColor Gray
            }
            default
            {
                Write-Host "   Using default Azure CLI authentication." -ForegroundColor Gray
            }
        }

        try
        {
            & az @loginArgs | Out-Null
        }
        finally
        {
            if ($AuthMethod -eq "Browser")
            {
                Remove-Item Env:AZURE_CORE_ENABLE_BROKER_ON_WINDOWS -ErrorAction SilentlyContinue
            }
        }
    }

    if ($targetSubscriptionId)
    {
        $null = az account set --subscription $targetSubscriptionId --only-show-errors
    }

    $syncedAzAccount = $null
    try
    {
        $syncedAzAccountJson = az account show --output json --only-show-errors 2>$null
        if ($syncedAzAccountJson)
        {
            $syncedAzAccount = $syncedAzAccountJson | ConvertFrom-Json
        }
    }
    catch
    {
        $syncedAzAccount = $null
    }

    if ($syncedAzAccount -and $syncedAzAccount.tenantId -eq $Context.Tenant.Id -and ((-not $targetSubscriptionId) -or $syncedAzAccount.id -eq $targetSubscriptionId))
    {
        Write-ContextBanner -Title "Azure CLI Synced" -Color Green
        Write-ContextItem -Label "Cloud" -Value $cliCloudName -Color Green
        Write-ContextItem -Label "Tenant" -Value $syncedAzAccount.tenantId -Color Green
        Write-ContextItem -Label "Subscription" -Value $syncedAzAccount.name -Color Green
        Write-ContextItem -Label "Subscription Id" -Value $syncedAzAccount.id -Color Green
    }
    else
    {
        Write-ContextBanner -Title "Azure CLI" -Color DarkYellow
        Write-Host "   CLI sync completed, but the final context could not be verified." -ForegroundColor DarkYellow
    }
}
#endregion

#region Variables
$ErrorActionPreference = "Stop"
$autoSave = Get-AzContextAutosaveSetting -Scope CurrentUser
if ($autoSave.Mode -eq "Process")
{ Enable-AzContextAutosave | Out-Null }

$parentFolder = "$($home)/PowerShell"
#endregion

#region Example Azure Logons - **** EXAMPLES ONLY ****
try
{
    function azure-work { Connect-Account -ParentFolder $parentFolder -AccountName "work" -TenantId "9d2426e9-b74a-428e-9065-80f29e416c3e" }
    function azure-customer { Connect-Account -ParentFolder $parentFolder -AccountName "customer" -TenantId "8dbf3853-c31f-400d-b3fb-b54168b2603f" -SubscriptionId "9877a694-1b15-4cdc-91d2-7bbfde6bf348" }
    function azure-personal { Connect-Account -ParentFolder $parentFolder -AccountName "personal" -TenantId "565aa719-38f8-4fa4-9275-94f2312fbb3c" -SubscriptionId "18e4b8ac-b35e-4acc-8f00-a040d99bad43" }
}
catch
{ $_ }
#endregion
