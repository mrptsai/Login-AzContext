begin
{
    #region Functions
    function Login-AzContext
    {
        param
        (
            [Parameter(Mandatory=$true)]
            [string] $ParentFolder,

            [Parameter(Mandatory=$true)]
            [string] $AccountName
        )

        $validlogon = $false
        $contextfile = Join-Path $parentfolder "$accountname.json"
        $contextEmpty = Join-Path $parentfolder "empty.json"
    
        if (-not (Test-Path $contextEmpty))
        {
            '{
                "DefaultContextKey": "Default",
                "EnvironmentTable": {},
                "Contexts": {},
                "ExtendedProperties": {}
            }' | New-Item -Path $parentfolder -Name "empty.json"
        }
    
        if (-not (Test-Path $contextfile))
        {
            Write-Host "`r`n No existing Azure Context file in:`t$($parentfolder)`n Please log in to Az with account '$($accountname)'" -ForegroundColor Yellow
        } else
        {
            # Cleaning up Profiles
            Clear-AzContext -Confirm:$false -Force
            Disable-AzContextAutosave -Scope Process | Out-Null
            $context = Import-AzContext $contextEmpty -ErrorAction stop
            Get-ChildItem $parentfolder -Filter "Azure*.json" | Remove-Item -Force
          
            # Importing existing context  
            $context = Import-AzContext $contextfile -ErrorAction stop

            # check for token expiration by executing an Azure RM command that should always succeed.
            Write-Host "`r`n Imported Azure context for account '$($accountname)', now checking for validity of the token....." -ForegroundColor Yellow
     
            $validlogon = (Get-AzSubscription -SubscriptionName $context.Context.Subscription.Name -ErrorAction SilentlyContinue) -ne $null
            
            if ($validlogon)
            {
                Write-Host "`r`n Imported Azure context:`t$($contextfile)" -ForegroundColor Yellow 
                Write-Host " Current subscription is:`t$($context.Context.Subscription.Name)`r`n" -ForegroundColor Yellow
            } else
            {
                Write-Host "`r`n Logon for account '$($accountname)' has expired, please log on again.`r`n" -ForegroundColor Yellow
            }
        }

        if (-not $validlogon)
        {
            $account = $null
            $account = Add-AzAccount
            if ($account) 
            {
                Save-AzContext -Path $contextfile -Force
                Write-Host "`r`n SUCCESS! Logged on to Azure with '$($accountname)' successfully!" -ForegroundColor Green
                Write-Host " Context saved to:`t$($contextfile)`r`n" -ForegroundColor Green
            } else 
            {
                Write-Host "`r`n ERROR! Logging on to Azure using account '$($accountname)' failed, please retry.`r`n" -ForegroundColor Red
            }
        }
    }
    #endregion

    #region Variables
    if (!$env:AzContextAutoSave)
    { $env:AzContextAutoSave="true" }
    #endregion
}

process
{
    Import-Module Posh-git
    #region Azure Logons
    function azure-work { Login-AzContext -ParentFolder "$env:HOME/PowerShell" -AccountName "work" }
    function azure-personal { Login-AzContext -ParentFolder "$env:HOME/PowerShell" -AccountName "personal" }
    #endregion
}

end
{}
