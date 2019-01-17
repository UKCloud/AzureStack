param (
    [string]$VaultName = $(throw "-VaultName is required."),
    [string]$Username = $(throw "-Username is required."),  
    [string]$Password = $(Read-Host "Input password" -AsSecureString -Force),
)

$Credentials = New-Object System.Management.Automation.PSCredential ($Username, $Password) 
Login-AzureRmAccount -Credential $Credentials

# Retrieve the vault information
$VaultVar = Get-AzureRmRecoveryServicesVault -Name $VaultName
Set-AzureRmRecoveryServicesAsrVaultContext -Vault $VaultVar
$FabricVar = Get-AzureRmRecoveryServicesAsrFabric
$ContainerVar = Get-AzureRmRecoveryServicesAsrProtectionContainer -Fabric $FabricVar
$ProtectedVMs = Get-AzureRmRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $ContainerVar
Write-Host "VMs to test failover: $($ProtectedVMs.Name)" -ForegroundColor Green

# Start test failover
$FailoverJobs = @()
foreach ($VM in $ProtectedVMs) {
    $FailoverJob = Start-AzureRmRecoveryServicesAsrTestFailoverJob -Direction PrimaryToRecovery -ReplicationProtectedItem $VM -AzureVMNetworkId $VM.SelectedRecoveryAzureNetworkId
    $FailoverJobs += $FailoverJob
}

# Check test failover status
$FailureTest = $false
$NumJobsComplete = 0
While ($FailoverJobs.Count -ne $NumJobsComplete) {
    $NumJobsComplete = 0
    $FailoverStatii = @()
    foreach ($Job in $FailoverJobs) {
        $JobStatus = Get-AzureRmRecoveryServicesAsrJob -Job $Job
        $FailoverStatus = New-Object -TypeName System.Object
        $FailoverStatus | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
        $FailoverStatus | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
        $FailoverStatii += $FailoverStatus
    }
    Write-Host ""
    Write-Host "$(Get-Date -DisplayHint Time)"
    ($FailoverStatii | Format-Table | Out-String).split("`n")[1..2]
    $FailoverStatii | Out-String -Stream | ForEach-Object {
        if ($_ -clike "* Succeeded*") {
            Write-Host "$($_)" -ForegroundColor Green
            $NumJobsComplete += 1
        }
        elseif ($_ -clike "* Failed*") {
            Write-Host "$($_)" -ForegroundColor Red
            $NumJobsComplete += 1
            $FailureTest = $true
        }
        elseif ($_ -clike "* InProgress*") {
            Write-Host "$($_)"
        }
    }
    if ($FailoverJobs.Count -ne $NumJobsComplete) {
        Start-Sleep -Seconds 30
    }
}

# Start test failover clean-up
Write-Host "Starting test failover clean-up"
$CleanupJobs = @()
foreach ($VM in $ProtectedVMs) {
    $CleanupJob = Start-AzureRmRecoveryServicesAsrTestFailoverCleanupJob -ReplicationProtectedItem $VM 
    $CleanupJobs += $CleanupJob
}

# Check status of clean-up jobs
$CleanupFailureTest = $false
$NumJobsComplete = 0
While ($CleanupJobs.Count -ne $NumJobsComplete) {
    $NumJobsComplete = 0
    $CleanupStatii = @()
    foreach ($Job in $CleanupJobs) {
        $JobStatus = Get-AzureRmRecoveryServicesAsrJob -Job $Job
        $CleanupStatus = New-Object -TypeName System.Object
        $CleanupStatus | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
        $CleanupStatus | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
        $CleanupStatii += $CleanupStatus
    }
    Write-Host ""
    Write-Host "$(Get-Date -DisplayHint Time)"
    ($CleanupStatii | Format-Table | Out-String).split("`n")[1..2]
    $CleanupStatii | Out-String -Stream | ForEach-Object {
        if ($_ -clike "* Succeeded*") {
            Write-Host "$($_)" -ForegroundColor Green
            $NumJobsComplete += 1
        }
        elseif ($_ -clike "* Failed*") {
            Write-Host "$($_)" -ForegroundColor Red
            $NumJobsComplete += 1
            $CleanupFailureTest = $true
        }
        elseif ($_ -clike "* InProgress*") {
            Write-Host "$($_)"
        }
    }
    if ($CleanupJobs.Count -ne $NumJobsComplete) {
        Start-Sleep -Seconds 30
    }
}

# Ask user if they want to continue if one or more test failover jobs fail
$valid = $false
while ($valid -eq $false -and $FailureTest -eq $true) {
    if ($FailureTest -eq $true) {
        $YesNo = Read-Host -Prompt "One or more of the VMs failed during test failover. Are you sure you want to proceed? (y/n)"
        if ($YesNo -like "*n*") {
            Write-Host "Exiting..."
            break 
        }
        elseif ($YesNo -notlike "*y*") {
            Write-Host ""
            Write-Host "Please enter a valid option (E.G. y or n)"
        } 
        else {
            Write-Host "Proceeding..."
            $valid = $true   
        }
    }
}
if ($YesNo -like "*n*") {
    break
}

# Ask user if they want to continue if one or more cleanup jobs fail
$valid = $false
while ($valid -eq $false -and $CleanupFailureTest -eq $true) {
    if ($CleanupFailureTest -eq $true) {
        $YesNo = Read-Host -Prompt "One or more of the VMs failed during test failover clean-up. Are you sure you want to proceed? (y/n)"
        if ($YesNo -like "*n*") {
            Write-Host "Exiting..."
            break 
        }
        elseif ($YesNo -notlike "*y*") {
            Write-Host ""
            Write-Host "Please enter a valid option (E.G. y or n)"
        } 
        else {
            Write-Host "Proceeding..."
            $valid = $true   
        }
    }
}
if ($YesNo -like "*n*") {
    break
}

# Start actual failover
Write-Host "Starting failover..."
$FailoverJobs = @()
foreach ($VM in $ProtectedVMs) {
    $FailoverJob = Start-AzureRmRecoveryServicesAsrUnplannedFailoverJob -Direction PrimaryToRecovery -ReplicationProtectedItem $VM
    $FailoverJobs += $FailoverJob
}

# Checking failover status
$Failure = $false
$FailoverErrors = @()
$NumJobsComplete = 0
While ($FailoverJobs.Count -ne $NumJobsComplete) {
    $NumJobsComplete = 0
    $FailoverStatii = @()
    foreach ($Job in $FailoverJobs) {
        $JobStatus = Get-AzureRmRecoveryServicesAsrJob -Job $Job
        $FailoverStatus = New-Object -TypeName System.Object
        $FailoverStatus | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
        $FailoverStatus | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
        $FailoverStatii += $FailoverStatus
        if ($JobStatus.State -like "Failed") {
            $FailoverError = New-Object -TypeName System.Object
            $FailoverError | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
            $FailoverError | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
            $FailoverError | Add-Member -Name Errors -MemberType NoteProperty -Value $JobStatus.Errors
            $FailoverErrors += $FailoverError
        }
    }
    Write-Host ""
    Write-Host "$(Get-Date -DisplayHint Time)"
    ($FailoverStatii | Format-Table | Out-String).split("`n")[1..2]
    $FailoverStatii | Out-String -Stream | ForEach-Object {
        if ($_ -clike "* Succeeded*") {
            Write-Host "$($_)" -ForegroundColor Green
            $NumJobsComplete += 1
        }
        elseif ($_ -clike "* Failed*") {
            Write-Host "$($_)" -ForegroundColor Red
            $NumJobsComplete += 1
            $Failure = $true
        }
        elseif ($_ -clike "* InProgress*") {
            Write-Host "$($_)"
        }
    }
    if ($FailoverJobs.Count -ne $NumJobsComplete) {
        Start-Sleep -Seconds 30
    }
}

if ($Failure -eq $true) {
    Write-Host "One or more VMs failed to failover:"
    $FailoverErrors | Format-Table
}
else {
    Write-Host "Committing replicated VMs..."
    $CommitJobs = @()
    foreach ($VM in $ProtectedVMs) {
        $CommitJob = Start-AzureRmRecoveryServicesAsrCommitFailoverJob -ReplicationProtectedItem $VM
        $CommitJobs += $CommitJob
    }
}

# Check Commit status
$CommitFailure = $false
$NumJobsComplete = 0
$CommitErrors = @()
While ($CommitJobs.Count -ne $NumJobsComplete) {
    $NumJobsComplete = 0
    $CommitStatii = @()
    foreach ($Job in $CommitJobs) {
        $JobStatus = Get-AzureRmRecoveryServicesAsrJob -Job $Job
        $CommitStatus = New-Object -TypeName System.Object
        $CommitStatus | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
        $CommitStatus | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
        $CommitStatii += $CommitStatus
        if ($JobStatus.State -like "Failed") {
            $CommitError = New-Object -TypeName System.Object
            $CommitError | Add-Member -Name ProtectedItem -MemberType NoteProperty -Value $JobStatus.TargetObjectName
            $CommitError | Add-Member -Name Status -MemberType NoteProperty -Value $JobStatus.State
            $CommitError | Add-Member -Name Errors -MemberType NoteProperty -Value $JobStatus.Errors
            $CommitErrors += $CommitError
        }
    }
    Write-Host ""
    Write-Host "$(Get-Date -DisplayHint Time)"
    ($CommitStatii | Format-Table | Out-String).split("`n")[1..2]
    $CommitStatii | Out-String -Stream | ForEach-Object {
        if ($_ -clike "* Succeeded*") {
            Write-Host "$($_)" -ForegroundColor Green
            $NumJobsComplete += 1
        }
        elseif ($_ -clike "* Failed*") {
            Write-Host "$($_)" -ForegroundColor Red
            $NumJobsComplete += 1
            $CommitFailure = $true
        }
        elseif ($_ -clike "* InProgress*") {
            Write-Host "$($_)"
        }
    }
    if ($CommitJobs.Count -ne $NumJobsComplete) {
        Start-Sleep -Seconds 30
    }
}

if ($CommitFailure -eq $true) {
    Write-Host "One or more VMs failed to commit:"
    $FailoverErrors | Format-Table
}
else {
    Write-Host "Failover completed successfully" -ForegroundColor Green
}