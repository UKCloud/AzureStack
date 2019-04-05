function Get-AzureStackInvoiceEstimate {
    <#
    .SYNOPSIS
        Returns an estimate of your Azure Stack Invoice based on Azure Stack API metrics.

    .DESCRIPTION
        Compile Azure Stack Billing Data based on Azure Stack API metrics. It is using the meter translation table from AzureStack-Tools.
        THis function will create a CSV file containing an estimate for your invoice for the specified time period.

    .PARAMETER Destination
        Destination folder location. If not specified the pricing estimate will only be printed to the PowerShell console.
        Note:
        It will check if the folder exists and will create it if it does not.
        Example: "C:\AzureStack-Invoice-December-2018"

    .PARAMETER FileName
        Destination file name. Defaults to "AzureStack-Invoice.csv"

    .PARAMETER StartDate
        The start of the time period to retrieve billing info for in american format. Example: "12/01/2018" (1st December 2018)

    .PARAMETER EndDate
        The end of the time period to retrieve billing info for in american format.  Example: "01/01/2019" (1st January 2018)

    .PARAMETER SQLFilePath
        File path of csv file containing SQL VM details. See links for example CSV file. Example: "C:\AzureStack\SQLVMs.csv"

    .EXAMPLE
        Get-AzureStackInvoiceEstimate -StartDate "03/01/2019" -EndDate "04/01/2019"

    .EXAMPLE
        Get-AzureStackInvoiceEstimate -StartDate "03/01/2019" -EndDate "04/01/2019" -Destination "C:\AzureStack-Invoice-March-2019"

    .EXAMPLE
        Get-AzureStackInvoiceEstimate -StartDate "03/01/2019" -EndDate "04/01/2019" -Destination "C:\AzureStack-Invoice-March-2019" -FileName "AzureStack-Invoice.csv"

    .EXAMPLE
        Get-AzureStackInvoiceEstimate -StartDate "03/01/2019" -EndDate "04/01/2019" -Destination "C:\AzureStack-Invoice-March-2019" -FileName "AzureStack-Invoice.csv" -SQLFilePath "C:\AzureStack\SQLVMs.csv"

    .NOTES
        This cmdlet retrieves data directly from Azure Stack. The invoice estimate provided may not be 100% accurate.
        This cmdlet requires you to be logged into Azure Stack to run successfully.

    .LINK
        https://github.com/UKCloud/AzureStack/tree/master/Users/PowerShell/UKCloud%20for%20Microsoft%20Azure%20Invoice%20Estimate

    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateScript({ if (-not (Test-Path -Path $_)) { New-Item -ItemType Directory -Path $_ -Force } else { $true } })]
        [String]
        $Destination,
        [Parameter(Mandatory = $false)]
        [String]
        $FileName = "AzureStack-Invoice.csv",
        [Parameter(Mandatory = $true)]
        [DateTime]
        $StartDate,
        [Parameter(Mandatory = $true)]
        [DateTime]
        $EndDate,
        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -Path $_ })]
        [String]
        $SQLFilePath
    )
    begin {
        try {
            # Azure Powershell way
            [Microsoft.Azure.Commands.Common.Authentication.Abstractions.IAzureContext]$Context = Get-AzureRmContext
            if ($Context.Environment.ResourceManagerUrl -like "*https://management.azure.com*") {
                Write-Error -Message 'You are currently logged into public Azure. Please login to Azure Stack to continue.' -ErrorId 'AzureRmContextError'
                break
            }
        }
        catch {
            if (-not $Context -or -not $Context.Account) {
                Write-Error -Message 'Run Connect-AzureRmAccount to login.' -ErrorId 'AzureRmContextError'
                break
            }
        }
    }
    process {
        # Declare Variables
        # Get subscription details
        $Sub = Get-AzureRmSubscription

        # Get location from Azure Resource Manager context
        $Location = ($Context.Environment.StorageEndpointSuffix).Split(".")[0]

        # Import SQLFile if required
        if ($SQLFilePath) {
            $SQLVMArray = Import-Csv -Path $SQLFilePath

            # Declare SQL hash table
            [HashTable]$SQLEntVMs = @{}

            # Check whether CSV data is in correct format
            $IncorrectSQLVersion = $SQLVMArray | Where-Object { $_.SQLVersion -notlike "STD" -and $_.SQLVersion -notlike "ENT" }

            if ($IncorrectSQLVersion) {
                Write-Warning -Message "WARNING! SQL CSV contained the following incorrect SQL versions. Please ensure that hhe version is either 'STD' (standard) or 'ENT' (enterprise)."
                $IncorrectSQLVersion | Format-Table -AutoSize
            }
        }

        # Create an array of meter IDs to be used for translation
        $Meters = @{
            'F271A8A388C44D93956A063E1D2FA80B'     = 'Static IP Address Usage'
            '9E2739BA86744796B465F64674B822BA'     = 'Dynamic IP Address Usage'
            'B4438D5D-453B-4EE1-B42A-DC72E377F1E4' = 'TableCapacity'
            'B5C15376-6C94-4FDD-B655-1A69D138ACA3' = 'PageBlobCapacity'
            'B03C6AE7-B080-4BFA-84A3-22C800F315C6' = 'QueueCapacity'
            '09F8879E-87E9-4305-A572-4B7BE209F857' = 'BlockBlobCapacity'
            'B9FF3CD0-28AA-4762-84BB-FF8FBAEA6A90' = 'TableTransactions'
            '50A1AEAF-8ECA-48A0-8973-A5B3077FEE0D' = 'TableDataTransIn'
            '1B8C1DEC-EE42-414B-AA36-6229CF199370' = 'TableDataTransOut'
            '43DAF82B-4618-444A-B994-40C23F7CD438' = 'BlobTransactions'
            '9764F92C-E44A-498E-8DC1-AAD66587A810' = 'BlobDataTransIn'
            '3023FEF4-ECA5-4D7B-87B3-CFBC061931E8' = 'BlobDataTransOut'
            'EB43DD12-1AA6-4C4B-872C-FAF15A6785EA' = 'QueueTransactions'
            'E518E809-E369-4A45-9274-2017B29FFF25' = 'QueueDataTransIn'
            'DD0A10BA-A5D6-4CB6-88C0-7D585CEF9FC2' = 'QueueDataTransOut'
            'FAB6EB84-500B-4A09-A8CA-7358F8BBAEA5' = 'Base VM Size Hours'
            '9CD92D4C-BAFD-4492-B278-BEDC2DE8232A' = 'Windows VM Size Hours'
            '6DAB500F-A4FD-49C4-956D-229BB9C8C793' = 'VM size hours'
            '190c935e-9ada-48ff-9ab8-56ea1cf9adaa' = 'App Service Virtual core hours'
            '957e9f36-2c14-45a1-b6a1-1723ef71a01d' = 'Shared App Service Hours'
            '539cdec7-b4f5-49f6-aac4-1f15cff0eda9' = 'Free App Service Hours'
            'db658d61-ef2d-4888-9843-72f5c774fd3c' = 'Small Basic App Service Hours'
            '27b01104-e0df-4f30-a171-f1b00ecb76b3' = 'Medium Basic App Service Hours'
            '50db6a92-5dff-4c9b-8238-8ea5fb1be107' = 'Large Basic App Service Hours'
            '88039d51-a206-3a89-e9de-c5117e2d10a6' = 'Small Standard App Service Hours'
            '83a2a13e-4788-78dd-5d55-2831b68ed825' = 'Medium Standard App Service Hours'
            '1083b9db-e9bb-24be-a5e9-d6fdd0ddefe6' = 'Large Standard App Service Hours'
            '26bd6580-c3bd-4e7e-8092-58b28eb1bb94' = 'Small Premium App Service Hours'
            'a1cba406-e83e-45c3-bd36-485191c215d9' = 'Medium Premium App Service Hours'
            'a2104a9d-5a78-4f8f-a2df-034bd43d602d' = 'Large Premium App Service Hours'
            'a91eed6c-dbbc-4532-859c-86de776433a4' = 'Extra Large Premium App Service Hours'
            '73215a6c-fa54-4284-b9c1-7e8ec871cc5b' = 'Web Process'
            '5887d39b-0253-4e12-83c7-03e1a93dffd9' = 'External Egress Bandwidth'
            '264acb47-ad38-47f8-add3-47f01dc4f473' = 'SNI SSL'
            '60b42d72-dc1c-472c-9895-6c516277edb4' = 'IP SSL'
            'd1d04836-075c-4f27-bf65-0a1130ec60ed' = 'Functions Compute'
            '67cc4afc-0691-48e1-a4b8-d744d1fedbde' = 'Functions Requests'
            'CBCFEF9A-B91F-4597-A4D3-01FE334BED82' = 'DatabaseSizeHourSqlMeter'
            'E6D8CFCD-7734-495E-B1CC-5AB0B9C24BD3' = 'DatabaseSizeHourMySqlMeter'
            'EBF13B9F-B3EA-46FE-BF54-396E93D48AB4' = 'Key Vault transactions'
            '2C354225-B2FE-42E5-AD89-14F0EA302C87' = 'Advanced keys transactions'
            '380874f9-300c-48e0-95a0-d2d9a21ade8f' = 'Managed Disk S4 (Disk * Month)'
            '1b77d90f-427b-4435-b4f1-d78adec53222' = 'Managed Disk S6 (Disk * Month)'
            'd5f7731b-f639-404a-89d0-e46186e22c8d' = 'Managed Disk S10 (Disk * Month)'
            'ff85ef31-da5b-4eac-95dd-a69d6f97b18a' = 'Managed Disk S15 (Disk * Month)'
            '88ea9228-457a-4091-adc9-ad5194f30b6e' = 'Managed Disk S20 (Disk * Month)'
            '5b1db88a-8596-4002-8052-347947c26940' = 'Managed Disk S30 (Disk * Month)'
            '14496322-39cb-4d33-b67d-39b0c2de0c8e' = 'Managed Disk S40 (Disk * Month)'
            '8c003d25-afb4-4f21-b1fa-86a5b0f001c7' = 'Managed Disk S50 (Disk * Month)'
            '7660b45b-b29d-49cb-b816-59f30fbab011' = 'Managed Disk P4 (Disk * Month)'
            '817007fd-a077-477f-bc01-b876f27205fd' = 'Managed Disk P6 (Disk * Month)'
            'e554b6bc-96cd-4938-a5b5-0da990278519' = 'Managed Disk P10 (Disk * Month)'
            'cdc0f53a-62a9-4472-a06c-e99a23b02907' = 'Managed Disk P15 (Disk * Month)'
            'b9cb2d1a-84c2-4275-aa8b-70d2145d59aa' = 'Managed Disk P20 (Disk * Month)'
            '06bde724-9f94-43c0-84c3-d0fc54538369' = 'Managed Disk P30 (Disk * Month)'
            'eecb2657-e7e6-47f9-9b00-7f58fa8839cb' = 'Managed Disk P40 (Disk * Month)'
            '43626c21-849b-40fe-8c01-e19666059c38' = 'Managed Disk P50 (Disk * Month)'
            '7ba084ec-ef9c-4d64-a179-7732c6cb5e28' = 'Managed Disk ActualStandardDiskSize (GB * Month)'
            'daef389a-06e5-4684-a7f7-8813d9f792d5' = 'Managed Disk ActualPremiumDiskSize (GB * Month)'
            '75d4b707-1027-4403-9986-6ec7c05579c8' = 'Managed Disk ActualStandardSnapshotSize (GB * Month)'
            '5ca1cbb9-6f14-4e76-8be8-1ca91547965e' = 'Managed Disk ActualPremiumSnapshotSize (GB * Month)'
            '5d76e09f-4567-452a-94cc-7d1f097761f0' = 'Managed Disk S4 (Disk * Hour) (Deprecated)'
            'dc9fc6a9-0782-432a-b8dc-978130457494' = 'Managed Disk S6 (Disk * Hour) (Deprecated)'
            'e5572fce-9f58-49d7-840c-b168c0f01fff' = 'Managed Disk S10 (Disk * Hour) (Deprecated)'
            '9a8caedd-1195-4cd5-80b4-a4c22f9302b8' = 'Managed Disk S15 (Disk * Hour) (Deprecated)'
            '5938f8da-0ecd-4c48-8d5a-c7c6c23546be' = 'Managed Disk S20 (Disk * Hour) (Deprecated)'
            '7705a158-bd8b-4b2b-b4c2-0782343b81e6' = 'Managed Disk S30 (Disk * Hour) (Deprecated)'
            'd9aac1eb-a5d1-42f2-b617-9e3ea94fed88' = 'Managed Disk S40 (Disk * Hour) (Deprecated)'
            'a54899dd-458e-4a40-9abd-f57cafd936a7' = 'Managed Disk S50 (Disk * Hour) (Deprecated)'
            '5c105f5f-cbdf-435c-b49b-3c7174856dcc' = 'Managed Disk P4 (Disk * Hour) (Deprecated)'
            '518b412b-1927-4f25-985f-4aea24e55c4f' = 'Managed Disk P6 (Disk * Hour) (Deprecated)'
            '5cfb1fed-0902-49e3-8217-9add946fd624' = 'Managed Disk P10 (Disk * Hour) (Deprecated)'
            '8de91c94-f740-4d9a-b665-bd5974fa08d4' = 'Managed Disk P15 (Disk * Hour) (Deprecated)'
            'c7e7839c-293b-4761-ae4c-848eda91130b' = 'Managed Disk P20 (Disk * Hour) (Deprecated)'
            '9f502103-adf4-4488-b494-456c95d23a9f' = 'Managed Disk P30 (Disk * Hour) (Deprecated)'
            '043757fc-049f-4e8b-8379-45bb203c36b1' = 'Managed Disk P40 (Disk * Hour) (Deprecated)'
            'c0342c6f-810b-4942-85d3-6eaa561b6570' = 'Managed Disk P50 (Disk * Hour) (Deprecated)'
            '8a409390-1913-40ae-917b-08d0f16f3c38' = 'Managed Disk ActualStandardDiskSize (Byte * Hour) (Deprecated)'
            '1273b16f-8458-4c34-8ce2-a515de551ef6' = 'Managed Disk ActualPremiumDiskSize (Byte * Hour) (Deprecated)'
            '89009682-df7f-44fe-aeb1-63fba3ddbf4c' = 'Managed Disk ActualStandardSnapshotSize (Byte * Hour) (Deprecated)'
            '95b0c03f-8a82-4524-8961-ccfbf575f536' = 'Managed Disk ActualPremiumSnapshotSize (Byte * Hour) (Deprecated)'
        }

        # Create an array for UKCloud Pricing
        # Full pricing can be found here: https://assets.digitalmarketplace.service.gov.uk/g-cloud-10/documents/92406/113527390782629-pricing-document-2018-11-14-1427.pdf
        $UKCloudPricing = [PSCustomObject]@{
            '£/vCPU/hour'                                   = 0.03
            '£/RAM/hour'                                    = 0.013
            'Additional-Storage-(All variants)-£/GiB/month' = 0.10
            'Microsoft-WindowsOSServer-£/vCPU/hour'         = 0.035
            'Microsoft-SQL-Std-0-to-4-vCPUs-£/hour'         = 0.31
            'Microsoft-SQL-Std-5+-vCPUs-£/hour'             = 0.58
            'Microsoft-SQL-Ent-0-to-4-vCPUs-£/month'        = 825
            'Microsoft-SQL-Ent-5+-vCPUs-£/month'            = 1650
        }

        # Create a list of sizes to compare against
        $VMSizes = Get-AzureRmVMSize -Location $Location | Select-Object -Property Name, NumberOfCores, @{Name = 'MemoryInGB'; Expression = { ( $_.MemoryInMB / 1024) } }

        Write-Output -InputObject "Retrieving usage"
        Write-Output -InputObject "Please wait, this may take a while..."

        # Retrieve usage data from Azure Stack
        $UsageSummary = @()
        $StartLine = [Console]::CursorTop
        do {
            $Result = Get-UsageAggregates -ReportedStartTime $StartDate -ReportedEndTime $EndDate -ContinuationToken $Result.ContinuationToken
            $Result.UsageAggregations.Properties | ForEach-Object {
                $Record = New-Object -TypeName System.Object
                $ResourceInfo = ($_.InstanceData | ConvertFrom-Json).'Microsoft.Resources'
                $ResourceText = $ResourceInfo.ResourceUri
                $Subscription = $ResourceText.Split('/')[2]
                $ResourceType = $ResourceText.Split('/')[7]
                $ResourceGroup = $ResourceText.Split('/')[4]
                $ResourceName = $ResourceText.Split('/')[8]
                $record | Add-Member -Name UsageStartTime -MemberType NoteProperty -Value $_.UsageStartTime
                $record | Add-Member -Name UsageEndTime -MemberType NoteProperty -Value $_.UsageEndTime
                $record | Add-Member -Name MeterName -MemberType NoteProperty -Value $Meters[$_.MeterId]
                $record | Add-Member -Name Quantity -MemberType NoteProperty -Value $_.Quantity
                $record | Add-Member -Name ResourceType -MemberType NoteProperty -Value $ResourceType
                $record | Add-Member -Name Location -MemberType NoteProperty -Value $ResourceInfo.Location
                $record | Add-Member -Name ResourceGroup -MemberType NoteProperty -Value $ResourceGroup
                $record | Add-Member -Name ResourceName -MemberType NoteProperty -Value $ResourceName
                $record | Add-Member -Name Tags -MemberType NoteProperty -Value $ResourceInfo.Tags
                $record | Add-Member -Name MeterId -MemberType NoteProperty -Value $_.MeterId
                $record | Add-Member -Name AdditionalInfo -MemberType NoteProperty -Value $ResourceInfo.AdditionalInfo
                $record | Add-Member -Name Subscription -MemberType NoteProperty -Value $Subscription
                $record | Add-Member -Name ResourceUri -MemberType NoteProperty -Value $ResourceText
                if ($Record.ResourceType -like "*virtualmachine*") {
                    $Record | Add-Member -Name VMSize -MemberType NoteProperty -Value ($Record.AdditionalInfo.Split('"'))[3]
                    foreach ($VMSize in $VMSizes) {
                        if ($VMSize.Name -eq $Record.VMSize) {
                            $Record | Add-Member -Name RAMinGB -MemberType NoteProperty -Value ($VMSize.MemoryInGB)
                            $Record | Add-Member -Name RAMinGBHours -MemberType NoteProperty -Value (($Record.RAMInGB * $Record.Quantity) / $VMSize.NumberOfCores)
                            $Record | Add-Member -Name NumberOfCores -MemberType NoteProperty -Value $VMSize.NumberOfCores
                        }
                    }
                    # Figure out SQL licensing
                    if ($SQLVMArray.VMName -contains $ResourceName) {
                        $SQLVM = $SQLVMArray | Where-Object { $_.VMName -like $ResourceName }
                        $Record | Add-Member -Name SQLVersion -MemberType NoteProperty -Value $SQLVM.SQLVersion
                        if ($SQLVM.SQLVersion -like "ENT") {
                            $SQLVM | Add-Member -Name NumberOfCores -MemberType NoteProperty -Value $Record.NumberOfCores
                            if (-not $SQLEntVMs[$SQLVM.VMName]) {
                                $SQLEntVMs.Add($SQLVM.VMName, $SQLVM)
                            }
                            elseif ($SQLEntVMs[$SQLVM.VMName].NumberOfCores -lt $SQLVM.NumberOfCores) {
                                $SQLEntVMs[$SQLVM.VMName].NumberOfCores = $SQLVM.NumberOfCores
                            }
                        }
                    }
                }
                $UsageSummary += $Record
            }
            [Console]::CursorTop = $StartLine
            Write-Output -InputObject "Retrieved $($UsageSummary.Count) records so far"
        } while ($Result.ContinuationToken)

        # Summate usage from individual objects
        $WinVMCount, $LinuxVMCount, $RamCount, $StorageCount, $SQLStdSmall, $SQLStdLarge, $SQLEntSmall, $SQLEntLarge = 0, 0, 0, 0, 0, 0, 0, 0
        foreach ($Usage in $UsageSummary) {
            if ($Usage.MeterName -like "Windows VM Size Hours") {
                $WinVMCount += $Usage.Quantity
                $RamCount += $Usage.RAMinGBHours
            }
            if ($Usage.MeterName -like "Base VM Size Hours") {
                $LinuxVMCount += $Usage.Quantity
                $RamCount += $Usage.RAMinGBHours
            }
            if ($Usage.MeterName -like "PageBlobCapacity" -or $Usage.MeterName -like "Managed Disk ActualStandardDiskSize (GB * Month)" -or $Usage.MeterName -like "Managed Disk ActualPremiumDiskSize  (GB * Month)" -or $Usage.MeterName -like "Managed Disk ActualStandardSnapshotSize (GB * Month)" -or $Usage.MeterName -like "Managed Disk ActualPremiumSnapshotSize (GB * Month)") {
                $StorageCount += $Usage.Quantity
            }
            if ($Usage.SQLVersion -like "STD" -and $Usage.MeterName -like "VM size hours" ) {
                if ($Usage.NumberOfCores -lt 5) {
                    $SQLStdSmall += $Usage.Quantity
                }
                else {
                    $SQLStdLarge += $Usage.Quantity
                }
            }
        }

        # SQL Enterprise
        foreach ($Value in $SubSQLEntVMs.Values) {
            if ($Usage.NumberOfCores -lt 5) {
                $SQLEntSmall += 1
            }
            else {
                $SQLEntLarge += 1
            }
        }

        # Calculate cost from usage UKCloud Pricing
        $StorageCost = $StorageCount * $UKCloudPricing.'Additional-Storage-(All variants)-£/GiB/month' / 24 / (365 / 12)
        $VirtualCpuCost = ($WinVMCount + $LinuxVMCount) * $UKCloudPricing.'£/vCPU/hour'
        $WindowsLicenceCost = ($WinVMCount * $UKCloudPricing.'Microsoft-WindowsOSServer-£/vCPU/hour')
        $RamCost = $RamCount * $UKCloudPricing.'£/RAM/hour'
        $SQLStdSmallCost = $SQLStdSmall * $UKCloudPricing.'Microsoft-SQL-Std-0-to-4-vCPUs-£/hour'
        $SQLStdLargeCost = $SQLStdLarge * $UKCloudPricing.'Microsoft-SQL-Std-5+-vCPUs-£/hour'
        $SQLEntSmallCost = $SQLEntSmall * $UKCloudPricing.'Microsoft-SQL-Ent-0-to-4-vCPUs-£/month'
        $SQLEntLargeCost = $SQLEntLarge * $UKCloudPricing.'Microsoft-SQL-Ent-5+-vCPUs-£/month'
        $TotalCost = $RamCost + $VirtualCpuCost + $StorageCost + $WindowsLicenceCost + $SQLStdSmallCost + $SQLStdLargeCost + $SQLEntSmallCost + $SQLEntLargeCost

        # Write total usage
        Write-Output -InputObject ""
        Write-Output -InputObject "USAGE:"
        Write-Output -InputObject "Total Windows vCPU usage (core/hour): $($WinVMCount)"
        Write-Output -InputObject "Total Linux vCPU usage (core/hour): $($LinuxVMCount)"
        Write-Output -InputObject "Total RAM usage (GB/hour): $($RamCount)"
        Write-Output -InputObject "Total Storage usage (GB/hour): $($StorageCount)"
        if ($SQLVMArray) {
            Write-Output -InputObject "Total SQL Std (0-4 vCPU) hours: $($SQLStdSmall)"
            Write-Output -InputObject "Total SQL Std (5+ vCPU) hours: $($SQLStdLarge)"
            Write-Output -InputObject "Total SQL Ent (0-4 vCPU) licences: $($SQLEntSmall)"
            Write-Output -InputObject "Total SQL Ent (5+ vCPU) licences: $($SQLEntLarge)"
        }
        Write-Output -InputObject ""

        # Output the cost
        Write-Output -InputObject "Total vCPU cost: £$($VirtualCpuCost)"
        Write-Output -InputObject "Total RAM cost: £$($RamCost)"
        Write-Output -InputObject "Total Storage cost: £$($StorageCost)"
        Write-Output -InputObject "Total Windows Licence cost: £$($WindowsLicenceCost)"
        if ($SQLVMArray) {
            Write-Output -InputObject "Total SQL Std (0-4 vCPU) cost: $($SQLStdSmallCost)"
            Write-Output -InputObject "Total SQL Std (5+ vCPU) cost: $($SQLStdLargeCost)"
            Write-Output -InputObject "Total SQL Ent (0-4 vCPU) cost: $($SQLEntSmallCost)"
            Write-Output -InputObject "Total SQL Ent (5+ vCPU) cost: $($SQLEntLargeCost)"
        }

        # Write total cost in green
        ## Save current colour
        $StartColour = $Host.UI.RawUI.ForegroundColor
        ## Set new colour
        $Host.UI.RawUI.ForegroundColor = "Green"
        ## Write total cost
        Write-Output -InputObject "Invoice Total: £$($TotalCost)"
        ## Set colour back to original
        $Host.UI.RawUI.ForegroundColor = $StartColour

        if ($Destination) {
            $InvoiceObject = [PSCustomObject]@{
                'SubscriptionDisplayName'              = $($Sub.Name)
                'SubscriptionID'                       = $($Sub.SubscriptionId)
                'Total-Windows-vCPU-usage(Core/Hour)'  = $WinVMCount
                'Total-Linux-vCPU-usage(Core/Hour)'    = $LinuxVMCount
                'Total-RAM-usage(GB/Hour)'             = $RamCount
                'Total-Storage-usage(GB/hour)'         = $StorageCount
                'Total-SQL-Std-(0-4-vCPU)-hours'       = $SQLStdSmall
                'Total-SQL-Std-(5+-vCPU)-hours'        = $SQLStdLarge
                'Total-SQL-Ent-(0-4-vCPU)-licences'    = $SQLEntSmall
                'Total-SQL-Ent-(5+-vCPU)-licences'     = $SQLEntLarge
                'Total-vCPU-cost(£)'                   = $([Math]::Round($VirtualCpuCost, 2))
                'Total-RAM-cost(£)'                    = $([Math]::Round($RamCost, 2))
                'Total-Storage-cost(£)'                = $([Math]::Round($StorageCost, 2))
                'Total-Windows-Licence-cost(£)'        = $([Math]::Round($WindowsLicenceCost, 2))
                'Total-SQL-Std-(0-4-vCPU)-cost(£)'     = $([Math]::Round($SQLStdSmallCost, 2))
                'Total-SQL-Std-(5+-vCPU)-cost(£)'      = $([Math]::Round($SQLStdLargeCost, 2))
                'Total-SQL-Ent-(0-4-vCPU)-cost(£)'     = $([Math]::Round($SQLEntSmallCost, 2))
                'Total-SQL-Ent-(5+-vCPU)-cost(£)'      = $([Math]::Round($SQLEntLargeCost, 2))
                'Invoice-Total(£)'                     = $([Math]::Round($TotalCost, 2))
            }

            if (-not $SQLVMArray) {
                $InvoiceObject = $InvoiceObject | Select-Object -Property * -ExcludeProperty Total-SQL*
            }

            $InvoiceObject | Export-Csv -Path (Join-Path -Path $Destination -ChildPath $FileName) -NoTypeInformation -Force -Encoding Default
            Write-Output -InputObject ""
            Write-Output -InputObject "CSV file saved to $(Join-Path -Path $Destination -ChildPath $FileName)"
        }
    }
}
