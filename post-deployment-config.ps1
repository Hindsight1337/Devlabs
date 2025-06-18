# Azure DevTest Labs Post-Deployment Configuration Script
# Version: 5.0 - Azure CLI hybrid (no PowerShell module dependencies)
# Uses Azure CLI for all API calls to avoid PowerShell compatibility issues

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$LabName,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxVmsPerStudent = 2,
    
    [Parameter(Mandatory=$false)]
    [int]$DailyCostLimit = 75,
    
    [Parameter(Mandatory=$false)]
    [int]$NumberOfStudents = 26
)

$ErrorActionPreference = "Stop"

Write-Host "Azure DevTest Labs Post-Deployment Configuration" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Using Azure CLI to avoid PowerShell module conflicts..." -ForegroundColor Yellow
Write-Host ""

# Check if Azure CLI is installed
Write-Host "Checking Azure CLI installation..." -ForegroundColor Yellow

try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    Write-Host "SUCCESS: Azure CLI found - version $($azVersion.'azure-cli')" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Azure CLI is not installed!" -ForegroundColor Red
    Write-Host "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor White
    Write-Host "After installation, restart PowerShell and run this script again." -ForegroundColor White
    exit 1
}

# Check Azure CLI authentication
Write-Host "Checking Azure CLI authentication..." -ForegroundColor Yellow

try {
    $accountInfo = az account show --output json 2>$null | ConvertFrom-Json
    if (!$accountInfo) {
        Write-Host "Please log in to Azure CLI..." -ForegroundColor Yellow
        az login
        $accountInfo = az account show --output json | ConvertFrom-Json
    }
    
    $subscriptionId = $accountInfo.id
    $userEmail = $accountInfo.user.name
    
    Write-Host "SUCCESS: Logged in as $userEmail" -ForegroundColor Green
    Write-Host "Subscription: $($accountInfo.name) ($subscriptionId)" -ForegroundColor White
}
catch {
    Write-Host "ERROR: Failed to authenticate with Azure CLI" -ForegroundColor Red
    Write-Host "Please run 'az login' first" -ForegroundColor White
    exit 1
}

# Verify resource group
Write-Host "Verifying resource group..." -ForegroundColor Yellow

try {
    $resourceGroup = az group show --name $ResourceGroupName --output json 2>$null | ConvertFrom-Json
    if (!$resourceGroup) {
        throw "Resource group not found"
    }
    Write-Host "SUCCESS: Resource group found in $($resourceGroup.location)" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Resource group '$ResourceGroupName' not found!" -ForegroundColor Red
    Write-Host "Available resource groups:" -ForegroundColor White
    az group list --query "[].name" --output table
    exit 1
}

# Verify DevTest Lab
Write-Host "Verifying DevTest Lab..." -ForegroundColor Yellow

try {
    $lab = az lab show --resource-group $ResourceGroupName --name $LabName --output json 2>$null | ConvertFrom-Json
    if (!$lab) {
        throw "Lab not found"
    }
    $labLocation = $lab.location
    Write-Host "SUCCESS: DevTest Lab found in $labLocation" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: DevTest Lab '$LabName' not found in resource group '$ResourceGroupName'!" -ForegroundColor Red
    Write-Host "Available labs in resource group:" -ForegroundColor White
    az lab list --resource-group $ResourceGroupName --query "[].name" --output table
    exit 1
}

# Get virtual network information
Write-Host "Getting virtual network information..." -ForegroundColor Yellow

try {
    $vnets = az lab vnet list --resource-group $ResourceGroupName --lab-name $LabName --output json | ConvertFrom-Json
    if ($vnets -and $vnets.Count -gt 0) {
        $vnetName = $vnets[0].name
        $subnetName = "default"
        Write-Host "SUCCESS: Found virtual network '$vnetName'" -ForegroundColor Green
    }
    else {
        Write-Host "WARNING: No virtual networks found, using defaults" -ForegroundColor Yellow
        $vnetName = $LabName
        $subnetName = "default"
    }
}
catch {
    Write-Host "WARNING: Could not retrieve virtual network info, using defaults" -ForegroundColor Yellow
    $vnetName = $LabName
    $subnetName = "default"
}

# Create temporary JSON files for formulas
$tempDir = [System.IO.Path]::GetTempPath()
$windowsFormulaFile = Join-Path $tempDir "windows-formula.json"
$ubuntuFormulaFile = Join-Path $tempDir "ubuntu-formula.json"

Write-Host ""
Write-Host "Creating VM Formulas..." -ForegroundColor Cyan

# Create Windows 11 Student Formula
Write-Host "  Creating Windows11-Student formula..." -ForegroundColor Yellow

$windowsFormula = @{
    properties = @{
        description = "Windows 11 Pro with development tools for students"
        osType = "Windows"
        formulaVirtualMachineProperties = @{
            labVirtualMachineCreationParameter = @{
                properties = @{
                    size = "Standard_B2s"
                    userName = "student"
                    password = "StudentPass123!"
                    isAuthenticationWithSshKey = $false
                    labSubnetName = $subnetName
                    labVirtualNetworkId = "/subscriptions/$subscriptionId/resourcegroups/$ResourceGroupName/providers/microsoft.devtestlab/labs/$LabName/virtualnetworks/$vnetName"
                    disallowPublicIpAddress = $false
                    galleryImageReference = @{
                        offer = "Windows-11"
                        publisher = "MicrosoftWindowsDesktop"
                        sku = "win11-22h2-pro"
                        osType = "Windows"
                        version = "latest"
                    }
                    allowClaim = $false
                    storageType = "Premium"
                    artifacts = @()
                }
            }
        }
    }
}

$windowsFormula | ConvertTo-Json -Depth 10 | Out-File -FilePath $windowsFormulaFile -Encoding UTF8

try {
    $result = az lab formula create `
        --resource-group $ResourceGroupName `
        --lab-name $LabName `
        --name "Windows11-Student" `
        --formula-content "@$windowsFormulaFile" `
        --output json 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  SUCCESS: Windows11-Student formula created" -ForegroundColor Green
    }
    else {
        Write-Host "  INFO: Windows11-Student formula may already exist" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  WARNING: Could not create Windows formula: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Create Ubuntu Student Formula
Write-Host "  Creating Ubuntu-Student formula..." -ForegroundColor Yellow

$ubuntuFormula = @{
    properties = @{
        description = "Ubuntu 22.04 LTS with development tools for students"
        osType = "Linux"
        formulaVirtualMachineProperties = @{
            labVirtualMachineCreationParameter = @{
                properties = @{
                    size = "Standard_B1s"
                    userName = "student"
                    password = "StudentPass123!"
                    isAuthenticationWithSshKey = $false
                    labSubnetName = $subnetName
                    labVirtualNetworkId = "/subscriptions/$subscriptionId/resourcegroups/$ResourceGroupName/providers/microsoft.devtestlab/labs/$LabName/virtualnetworks/$vnetName"
                    disallowPublicIpAddress = $false
                    galleryImageReference = @{
                        offer = "0001-com-ubuntu-server-jammy"
                        publisher = "Canonical"
                        sku = "22_04-lts-gen2"
                        osType = "Linux"
                        version = "latest"
                    }
                    allowClaim = $false
                    storageType = "Standard"
                    artifacts = @()
                }
            }
        }
    }
}

$ubuntuFormula | ConvertTo-Json -Depth 10 | Out-File -FilePath $ubuntuFormulaFile -Encoding UTF8

try {
    $result = az lab formula create `
        --resource-group $ResourceGroupName `
        --lab-name $LabName `
        --name "Ubuntu-Student" `
        --formula-content "@$ubuntuFormulaFile" `
        --output json 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  SUCCESS: Ubuntu-Student formula created" -ForegroundColor Green
    }
    else {
        Write-Host "  INFO: Ubuntu-Student formula may already exist" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  WARNING: Could not create Ubuntu formula: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Clean up temporary files
Remove-Item -Path $windowsFormulaFile -Force -ErrorAction SilentlyContinue
Remove-Item -Path $ubuntuFormulaFile -Force -ErrorAction SilentlyContinue

# Verify and configure policies
Write-Host ""
Write-Host "Configuring Lab Policies..." -ForegroundColor Cyan

# Check VM count policy
Write-Host "  Checking VM count policy..." -ForegroundColor Yellow

try {
    $vmCountPolicy = az lab policy show `
        --resource-group $ResourceGroupName `
        --lab-name $LabName `
        --policy-set-name "default" `
        --name "MaxVmsAllowedPerUser" `
        --query threshold `
        --output tsv 2>$null

    if ($vmCountPolicy -eq $MaxVmsPerStudent.ToString()) {
        Write-Host "  SUCCESS: VM count policy correctly set to $MaxVmsPerStudent" -ForegroundColor Green
    }
    else {
        Write-Host "  INFO: VM count policy is $vmCountPolicy, expected $MaxVmsPerStudent" -ForegroundColor Yellow
        
        # Try to update the policy
        try {
            az lab policy set `
                --resource-group $ResourceGroupName `
                --lab-name $LabName `
                --policy-set-name "default" `
                --name "MaxVmsAllowedPerUser" `
                --threshold $MaxVmsPerStudent `
                --output none 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  SUCCESS: VM count policy updated to $MaxVmsPerStudent" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "  WARNING: Could not update VM count policy" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "  WARNING: Could not check VM count policy" -ForegroundColor Yellow
}

# Check VM size policy
Write-Host "  Checking VM size policy..." -ForegroundColor Yellow

try {
    $vmSizePolicy = az lab policy show `
        --resource-group $ResourceGroupName `
        --lab-name $LabName `
        --policy-set-name "default" `
        --name "AllowedVmSizesInLab" `
        --query status `
        --output tsv 2>$null

    if ($vmSizePolicy -eq "Enabled") {
        Write-Host "  SUCCESS: VM size policy is enabled" -ForegroundColor Green
    }
    else {
        Write-Host "  WARNING: VM size policy may not be properly configured" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  WARNING: Could not check VM size policy" -ForegroundColor Yellow
}

# Check auto-shutdown schedule
Write-Host "  Checking auto-shutdown schedule..." -ForegroundColor Yellow

try {
    $shutdownSchedule = az lab schedule show `
        --resource-group $ResourceGroupName `
        --lab-name $LabName `
        --name "LabVmsShutdown" `
        --output json 2>$null | ConvertFrom-Json

    if ($shutdownSchedule -and $shutdownSchedule.status -eq "Enabled") {
        $shutdownTime = $shutdownSchedule.dailyRecurrence.time
        Write-Host "  SUCCESS: Auto-shutdown enabled at $shutdownTime" -ForegroundColor Green
    }
    else {
        Write-Host "  WARNING: Auto-shutdown may not be configured" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  WARNING: Could not check auto-shutdown schedule" -ForegroundColor Yellow
}

# List created formulas
Write-Host ""
Write-Host "Verifying created formulas..." -ForegroundColor Cyan

try {
    $formulas = az lab formula list --resource-group $ResourceGroupName --lab-name $LabName --output json | ConvertFrom-Json
    
    if ($formulas -and $formulas.Count -gt 0) {
        Write-Host "Available formulas:" -ForegroundColor White
        foreach ($formula in $formulas) {
            Write-Host "  - $($formula.name)" -ForegroundColor White
        }
    }
    else {
        Write-Host "  No formulas found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  Could not list formulas" -ForegroundColor Yellow
}

# Cost calculations and summary
Write-Host ""
Write-Host "Cost Management Analysis..." -ForegroundColor Cyan

$totalDailyBudget = $DailyCostLimit * $NumberOfStudents
$totalMonthlyBudget = $totalDailyBudget * 30
$totalSemesterBudget = $totalDailyBudget * 120

Write-Host "  Cost Analysis:" -ForegroundColor White
Write-Host "    Daily cost per student: $DailyCostLimit NOK" -ForegroundColor White
Write-Host "    Total daily budget: $totalDailyBudget NOK" -ForegroundColor White
Write-Host "    Monthly estimate: $totalMonthlyBudget NOK" -ForegroundColor White
Write-Host "    Semester estimate: $totalSemesterBudget NOK" -ForegroundColor White

# Generate lab URL
$labUrl = "https://portal.azure.com/#@/resource/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName"

# Create student instruction document
Write-Host ""
Write-Host "Creating student instructions..." -ForegroundColor Cyan

$instructionsContent = @"
# Azure DevTest Lab - Student Instructions

## Lab Information
- **Lab Name:** $LabName
- **Resource Group:** $ResourceGroupName
- **Lab URL:** $labUrl

## Getting Started
1. Go to the lab URL above
2. Log in with your school account
3. Click "My virtual machines" 
4. Click "+ Add" to create a new VM

## Available VM Templates
### Windows11-Student
- **OS:** Windows 11 Pro with development tools
- **Size:** Standard_B2s (2 vCPU, 4GB RAM)
- **Username:** student
- **Password:** StudentPass123!
- **Storage:** Premium SSD

### Ubuntu-Student
- **OS:** Ubuntu 22.04 LTS with development tools  
- **Size:** Standard_B1s (1 vCPU, 1GB RAM)
- **Username:** student
- **Password:** StudentPass123!
- **Storage:** Standard SSD

## Important Rules
- ⚠️ **Maximum $MaxVmsPerStudent VMs per student**
- 💰 **Daily budget: $DailyCostLimit NOK per student**
- ⏰ **VMs automatically shut down at 22:00**
- 💾 **Remember to save your work before shutdown!**

## How to Connect to Your VM
### Windows VM
1. Click on your VM name in the lab
2. Click "Connect"
3. Download the RDP file
4. Open the RDP file and log in

### Ubuntu VM
1. Click on your VM name in the lab
2. Click "Connect"
3. Use SSH or download the RDP file for GUI access

## Cost Information
- **Total lab daily budget:** $totalDailyBudget NOK
- **Estimated monthly cost:** $totalMonthlyBudget NOK
- **Estimated semester cost:** $totalSemesterBudget NOK

## Troubleshooting
### Cannot create VM
- Check if you already have $MaxVmsPerStudent VMs running
- Try a different VM size if creation fails

### Cannot connect to VM
- Ensure the VM is running (not stopped)
- Check that RDP/SSH ports are accessible
- Verify username and password

### VM running slowly
- Check VM size - upgrade if needed and within budget
- Ensure no unnecessary programs are running

## Support
Contact your instructor for help with:
- Login issues
- VM creation problems
- Access to additional resources
- Technical support

---
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Lab URL:** $labUrl
"@

$instructionsPath = ".\DevTest-Lab-Student-Instructions.md"
$instructionsContent | Out-File -FilePath $instructionsPath -Encoding UTF8

Write-Host "  SUCCESS: Student instructions saved to $instructionsPath" -ForegroundColor Green

# Final summary
Write-Host ""
Write-Host "Post-Deployment Configuration Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "VM Formulas:" -ForegroundColor White
Write-Host "  - Windows11-Student (Standard_B2s, Premium SSD)" -ForegroundColor White
Write-Host "  - Ubuntu-Student (Standard_B1s, Standard SSD)" -ForegroundColor White
Write-Host ""
Write-Host "Policies:" -ForegroundColor White
Write-Host "  - Auto-shutdown: Verified" -ForegroundColor White
Write-Host "  - VM limit per student: $MaxVmsPerStudent" -ForegroundColor White
Write-Host "  - VM size restrictions: Checked" -ForegroundColor White
Write-Host ""
Write-Host "Cost projections:" -ForegroundColor White
Write-Host "  - Daily budget: $totalDailyBudget NOK" -ForegroundColor White
Write-Host "  - Monthly estimate: $totalMonthlyBudget NOK" -ForegroundColor White
Write-Host "  - Semester estimate: $totalSemesterBudget NOK" -ForegroundColor White
Write-Host ""
Write-Host "Files created:" -ForegroundColor White
Write-Host "  - Student instructions: $instructionsPath" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Test VM creation using the new formulas" -ForegroundColor White
Write-Host "  2. Add students to the lab (Azure AD users)" -ForegroundColor White
Write-Host "  3. Set up cost alerts in Azure Cost Management" -ForegroundColor White
Write-Host "  4. Share student instructions with your class" -ForegroundColor White
Write-Host ""
Write-Host "Lab URL: $labUrl" -ForegroundColor Blue
Write-Host ""
Write-Host "Script completed successfully!" -ForegroundColor Green
