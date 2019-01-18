function Get-NetworkIpPoolInfo {
    <#
    .SYNOPSIS
        Get Network Information for IPPool Provisioning
    
    .DESCRIPTION
        Get Network Information for IPPool Provisioning based on IP Address and Subnet Mask
        It will provide first IP, Last IP (Broadcast for Azure Stack), and Network ID for AddressPrefix
    
    .PARAMETER IPAddress
        IP Address that you want to provision to Azure Stack

    .PARAMETER SubnetMask
        Subnet Mask of your IP Address that you want to provision to Azure Stack

    .EXAMPLE
        Get-NetworkIpPoolInfo -IPAddress "57.139.61.192" -SubnetMask "255.255.255.192"

    .EXAMPLE
        Get-NetworkIpPoolInfo -IPAddress "10.0.0.0" -SubnetMask "255.255.255.0"
    
    .LINK
        http://www.itadmintools.com/2011/08/calculating-tcpip-subnets-with.html

    #>
    [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = "High")]
    param
    (
        [ValidateScript( {$_ -match [IPAddress]$_ })] 
        $IPAddress,
        [ValidateScript( {$_ -match [IPAddress]$_ })] 
        $SubnetMask # = "custom*script*extension"
    )
    function toBinary ($dottedDecimal) {
        $dottedDecimal.split(".") | % {$binary = $binary + $([convert]::toString($_, 2).padleft(8, "0"))}
        return $binary
    }
    function toDottedDecimal ($binary) {
        do {$dottedDecimal += "." + [string]$([convert]::toInt32($binary.substring($i, 8), 2)); $i += 8 } while ($i -le 24)
        return $dottedDecimal.substring(1)
    }
    #read args and convert to binary
    #if ($args.count -ne 2) { "`nUsage: .\subnetCalc.ps1 <ipaddress> <subnetmask>`n"; Exit }
    $ipBinary = toBinary $IPAddress
    $smBinary = toBinary $SubnetMask
    #how many bits are the network ID
    $netBits = $smBinary.indexOf("0")
    #validate the subnet mask
    if (($smBinary.length -ne 32) -or ($smBinary.substring($netBits).contains("1") -eq $true)) {
        Write-Warning "Subnet Mask is invalid!"
        Exit
    }
    #validate that the IP address
    if (($ipBinary.length -ne 32) -or ($ipBinary.substring($netBits) -eq "00000000") -or ($ipBinary.substring($netBits) -eq "11111111")) {
        Write-Warning "IP Address is invalid!"
        Exit
    }
    #identify subnet boundaries
    $networkID = toDottedDecimal $($ipBinary.substring(0, $netBits).padright(32, "0"))
    $firstAddress = toDottedDecimal $($ipBinary.substring(0, $netBits).padright(31, "0") + "1")
    $lastAddress = toDottedDecimal $($ipBinary.substring(0, $netBits).padright(31, "1") + "0")
    $broadCast = toDottedDecimal $($ipBinary.substring(0, $netBits).padright(32, "1"))
    #write output
    "`n   Network ID:`t$networkID/$netBits"
    "First Address:`t$firstAddress  <-- typically the default gateway"
    " Last Address:`t$lastAddress"
    "    Broadcast:`t$broadCast`n"

    # Create custom array so we can use the output in another function
    $ArrayOut = @()
    $ourObject = [PSCustomObject]@{
        NetworkID    = "$networkID/$netBits"
        FirstAddress = $firstAddress
        LastAddress  = $lastAddress
        Broadcast    = $broadCast
    }
    $ArrayOut += $ourObject
    return $ArrayOut
}
Function New-AzsPublicIpPool {
    <#
    .SYNOPSIS
        Provision new Public IP Pool to Azure Stack
    
    .DESCRIPTION
        Provision new Public IP Pool to Azure Stack using  Get-NetworkIpPoolInfo function to calculate the FirstIP, LastIP, and AddressPrefix

    .PARAMETER IPAddress
        IP Address that you want to provision to Azure Stack

    .PARAMETER SubnetMask
        Subnet Mask of your IP Address that you want to provision to Azure Stack
    
    .PARAMETER IPPoolName
        Name of Public IP Pool that you want to provision to Azure Stack

    .EXAMPLE
        New-AzsPublicIpPool -IPAddress "57.139.61.192" -SubnetMask "255.255.255.192" -IPPoolName "PublicIpPoolExtension-1"

    .EXAMPLE
        New-AzsPublicIpPool -IPAddress "57.139.61.192" -SubnetMask "255.255.255.192" -IPPoolName "PublicIpPoolExtension-1" -Confirm:$true -Force -WhatIf 

    .EXAMPLE
        New-AzsPublicIpPool -IPAddress "57.139.61.192" -SubnetMask "255.255.255.192" -IPPoolName "PublicIpPoolExtension-1" -Verbose
    
    .NOTES
        EndIpAddress is being defined as Broadcast as Azure Stack seems to be able to utilise that IP and that is how it has been configured for all Pools thus far

    #>
    [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = "High")]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {$_ -match [IPAddress]$_ })] 
        $IPAddress,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {$_ -match [IPAddress]$_ })] 
        $SubnetMask,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $IPPoolName,
        [switch]$Force
    )
 
    begin {
        Try {
            Get-AzsLocation | Out-Null
            Write-Verbose -Message "Checking if user is logged in to Azure Stack"
        }
        Catch {
            Write-Error "Run Login-AzureRmAccount to login before running this command." 
            Break 
        }
    }
    process {
        # Get Network Information
        $NetworkInfo = Get-NetworkIpPoolInfo -IPAddress $IPAddress -SubnetMask $SubnetMask
        Write-Verbose -Message "$($IPPoolName)"
        Write-Verbose -Message "$($NetworkInfo.NetworkID)"
        Write-Verbose -Message "$($NetworkInfo.FirstAddress)"
        Write-Verbose -Message "$($NetworkInfo.Broadcast)"
        

        # Provision New IP Pool
        If ($PSCmdlet.ShouldProcess($NetworkInfo.NetworkID, 'Create a new Ip Pool')) {
            if ($Force -or $PSCmdlet.ShouldContinue("Are you sure you want to create new IP Pool $($IPPoolName)?", $null)) {
                New-AzsIpPool -Name $IPPoolName -StartIpAddress $($NetworkInfo.FirstAddress) -EndIpAddress  $($NetworkInfo.Broadcast) -AddressPrefix  $($NetworkInfo.NetworkID)
            }
        }
    }
}

