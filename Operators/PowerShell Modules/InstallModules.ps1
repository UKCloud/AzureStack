function Install-CustomModule {
    <#
    .SYNOPSIS
        Installs PowerShell modules.

    .DESCRIPTION
        Installs all PowerShell modules contained in a folder.

    .PARAMETER LocalRepoPath
        Path to the local repository containing the modules you want to install. Example: "C:\PowerShellModules"

    .EXAMPLE
        InstallModules.ps1

    .EXAMPLE
        InstallModules.ps1 -LocalRepoPath "C:\PowerShellModules"

    .NOTES
        Works in PowerShell on Windows and Linux.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Path to local repository that contains modules folder")]
        [ValidateScript({ (Test-Path $_) })]
        [String]
        $LocalRepoPath = "..\"
    )

    # Declare Arrays for installed and not installed modules
    $ModulesInstalled = @()
    $ModulesNotInstalled = @()

    # Find modules directory in local repository
    $GetModuleDirectory = Get-ChildItem -Path $LocalRepoPath | Where-Object { $_.Name -like "*modules*" }
    $GetModuleDirectory

    # Find each module folder in modules directory
    $GetModuleFolders = $GetModuleDirectory | Get-ChildItem -Directory -Recurse
    $GetModuleFolders

    foreach ($ModuleFolder in $GetModuleFolders) {
        # Declare variables
        $PsmFile = $ModuleFolder | Get-ChildItem -Recurse -Filter "*.psm1"

        # Check if psm1 file exist
        if (-not $PsmFile) {
            Write-Host -ForegroundColor Red "Your psm1 file does not exist in folder $($ModuleFolder.FullName)"
            Write-Error -Message "Your module will not be installed correctly" -ErrorAction Continue
            $ModulesNotInstalled += $ModuleFolder.Name
        }
        else {
            # Copy module folder to PSModule Path directory so it can be imported
            $DestinationFolder = ($env:PSModulePath -split [System.IO.Path]::PathSeparator)[2]
            Copy-Item -Path $ModuleFolder.FullName -Destination $DestinationFolder -Force -Recurse

            # Check if module can be imported
            $CheckModule = Get-Module -Name $ModuleFolder.Name -ListAvailable

            if ([String]::IsNullOrWhiteSpace($CheckModule)) {
                Write-Error -Message "Your module: $($ModuleFolder.Name) was not installed correctly" -ErrorAction Continue
                $ModulesNotInstalled += $ModuleFolder.Name
            }
            else {
                $ModulesInstalled += $CheckModule.Name
            }
        }
    }

    Write-Host -ForegroundColor Green "List of installed modules is: $ModulesInstalled"
    Write-Host -ForegroundColor Red "List of not installed modules is: $ModulesNotInstalled"
}

Install-CustomModule
