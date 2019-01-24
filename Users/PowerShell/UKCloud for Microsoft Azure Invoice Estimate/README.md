# Azure Stack Invoice Estimate Module

This guide is intended to provide a reference on how to use the **Azure Stack Invoice Estimate** module for PowerShell.

Includes functions:

    - Get-AzureStackInvoiceEstimate

## Prerequisites

Prerequisites from a Windows-based external client.

* PowerShell 5.1

* Azure Stack PowerShell Modules 1.6.0 -> [Azure Stack Modules Install Guide](https://docs.ukcloud.com/articles/azure/azs-how-configure-powershell-users.html)

## How to install it:

There is a installmodules.ps1 script that will install your modules.

## How to use it

Once it is installed you can just invoke the commands and PowerShell will load them for you.

> [!IMPORTANT]
> **You need to log in to Azure Stack first before you can execute the commands as they will fail otherwise.**.

### Examples

* Return an estimate of your Azure Stack Invoice for December 2018 based on Azure Stack API metrics:

    ```powershell
    Get-AzureStackInvoiceEstimate -StartDate 12/01/2018 -EndDate 01/01/2019
    ```

* Return an estimate of your Azure Stack Invoice for December 2018 based on Azure Stack API metrics and saves a report called "AzureStack-Invoice.csv" to the specified folder:

    ```powershell
    Get-AzureStackInvoiceEstimate -StartDate 12/01/2018 -EndDate 01/01/2019 -Destination "C:\AzureStack-Invoice-December-2018"
    ```

* Return an estimate of your Azure Stack Invoice for December 2018 based on Azure Stack API metrics and saves a report with the specified name to the specified folder:

    ```powershell
    Get-AzureStackInvoiceEstimate -StartDate 12/01/2018 -EndDate 01/01/2019 -Destination "C:\AzureStack-Invoice-December-2018" -FileName "AzureStack-Invoice.csv" -Location "frn00006"
    ```

> [!TIP]
> There are more examples of usage inside the functions in the module itself.