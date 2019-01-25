function Install-CustomModule {
    <#
    .SYNOPSIS
        Creates modules manifest psd1 files.

    .DESCRIPTION
        Creates modules manifest psd1 files so that we can convert psm1 files to proper PowerShell modules.

    .PARAMETER LocalRepoPath
        Path to your Local Repository you want to convert modules folder to proper structure

    .EXAMPLE
        Install-CustomModule

    .EXAMPLE
        Install-CustomModule -LocalRepoPath <path to your local repo> 

    #>
    [cmdletbinding(SupportsShouldProcess=$True)]
    param(
        # Local Repository Path with validation whether it exists
        [Parameter(HelpMessage="Path to local repository that contains modules folder",Mandatory=$false)]
        [ValidateScript({(Test-Path $_)})]
        [String]$LocalRepoPath
    )
    
    # Set Local Repository Path to be current path's parent directory
    if (!$LocalRepoPath) {
        $LocalRepoPath = "..\"
    }

    # Declare Arrays for installed and not installed modules
    $ModulesInstalled = @()
    $ModulesNotInstalled = @()

    # Find modules directory in local repository
    $GetModuleDirectory = Get-ChildItem -Path $LocalRepoPath | Where-Object {$_.Name -like "modules"}
    $GetModuleDirectory

    # Find each module folder in modules directory
    $GetModuleFolders = $GetModuleDirectory | Get-ChildItem -Directory -Recurse 
    $GetModuleFolders
       
       foreach ($ModuleFolder in $GetModuleFolders) {
           # Declare variables
           $PSMFile = $ModuleFolder | Get-ChildItem -Recurse -Filter "*.psm1"

           # Check if psm1 file exist
           if(!$PSMFile) {
               Write-Host -ForegroundColor Red "Your psm1 file does not exist in folder $($ModuleFolder.FullName)"
               Write-Error -Message "Your module will not be installed correctly" -ErrorAction Continue
               $ModulesNotInstalled += $ModuleFolder.Name
           }
           else {
               # Copy module folder to PSModule Path directory so it can be imported
               $DestinationFolder = ($env:PSModulePath-split [System.io.path]::PathSeparator)[2]
               Copy-Item $ModuleFolder.FullName  -Destination $DestinationFolder -Force -Recurse

               # Check if module can be imported
               $CheckModule = Get-Module -ListAvailable $ModuleFolder.Name

                   if ([string]::IsNullOrWhiteSpace($CheckModule)) {
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
