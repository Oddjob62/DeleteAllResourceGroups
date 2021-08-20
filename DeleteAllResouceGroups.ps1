Import-Module Az.Accounts
$ignoreGroups = "Admin","cloud-shell-storage-westeurope","NetworkWatcherRG","AB_DEMO_NETWORK","DNS"

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Connect-AzAccount `
        -ServicePrincipal `
        -Tenant $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$subscriptionIds = (Get-AzSubscription).id

foreach ($subscriptionId in $subscriptionIds){
    #Get all ARM resources from all resource groups
    Set-AzContext -Subscription $subscriptionId
    Write-Output ("Deleting from " + (Get-AzSubscription -SubscriptionId $subscriptionId).Name)
    $ResourceGroups = Get-AzResourceGroup 
    
    $deletableRG = $true

    do {
        $deletableRG = $false
        foreach ($ResourceGroup in $ResourceGroups)
        {   
            if($ignoreGroups -contains $ResourceGroup.ResourceGroupName){continue}
            Write-Output ("Deleting " + $ResourceGroup.ResourceGroupName)
            try{
                $ResourceGroup | Remove-AzResourceGroup -verbose -force
                $deletableRG = $true
                $ResourceGroups = Get-AzResourceGroup 
            }catch{
                Write-Error ("Failed to delete " + $ResourceGroup.ResourceGroupName)
            }
        } 
        Start-Sleep -Second 60
    } until ($deletableRG -eq $false)

    Write-Output ("Resource Groups Remaining:")
    $ResourceGroups.ResourceGroupName
}
