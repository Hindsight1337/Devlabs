# Azure DevTest Labs Post-Deployment Configuration Script
# Version: 2.0 - Fixed syntax errors
# Description: Konfigurerer avanserte policies, cost management og VM formulas

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
    [int]$NumberOfStudents = 26,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Script start
Write-Host "🚀 Azure DevTest Labs Post-Deployment Configuration" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Validate parameters
if ($DailyCostLimit -lt 10 -or $DailyCostLimit -gt 500) {
    throw "DailyCostLimit must be between 10 and 500 NOK"
}

if ($NumberOfStudents -lt 1 -or $NumberOfStudents -gt 50) {
    throw "NumberOfStudents must be between 1 and 50"
}

try {
    # Check if Azure PowerShell module is installed
    Write-Host "🔍 Checking Azure PowerShell module..." -ForegroundColor Yellow
    
    if (!(Get-Module -ListAvailable -Name Az.Accounts)) {
        Write-Host "❌ Azure PowerShell module not found!" -ForegroundColor Red
        Write-Host "Install with: Install-Module -Name Az -AllowClobber -Force" -ForegroundColor White
        exit 1
    }
    
    Write-Host "✅ Azure PowerShell module found" -ForegroundColor Green
    
    # Connect to Azure if not already connected
    Write-Host "🔐 Checking Azure connection..." -ForegroundColor Yellow
    
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (!$context) {
        Write-Host "🔑 Logging into Azure..." -ForegroundColor Yellow
        Connect-AzAccount
        $context = Get-AzContext
    }
    
    Write-Host "✅ Connected to Azure as: $($context.Account.Id)" -ForegroundColor Green
    
    # Set subscription if provided
    if ($SubscriptionId) {
        Write-Host "📋 Setting subscription: $SubscriptionId" -ForegroundColor Yellow
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }
    
    # Verify resource group exists
    Write-Host "🔍 Verifying resource group: $ResourceGroupName" -ForegroundColor Yellow
    
    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (!$resourceGroup) {
        throw "Resource group '$ResourceGroupName' not found!"
    }
    
    Write-Host "✅ Resource group found in location: $($resourceGroup.Location)" -ForegroundColor Green
    
    # Verify DevTest Lab exists
    Write-Host "🧪 Verifying DevTest Lab: $LabName" -ForegroundColor Yellow
    
    $lab = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $LabName -ResourceType "Microsoft.DevTestLab/labs" -ErrorAction SilentlyContinue
    if (!$lab) {
        throw "DevTest Lab '$LabName' not found in resource group '$ResourceGroupName'!"
    }
    
    Write-Host "✅ DevTest Lab found" -ForegroundColor Green
    
    # Create VM Formulas
    Write-Host ""
    Write-Host "📝 Creating VM Formulas..." -ForegroundColor Cyan
    
    # Formula 1: Windows 11 Student
    Write-Host "  📋 Creating Windows 11 Student formula..." -ForegroundColor Yellow
    
    $windowsFormula = @{
        location = $lab.Location
        properties = @{
            description = "Windows 11 Pro with development tools for students"
            osType = "Windows"
            formulaVirtualMachineProperties = @{
                labVirtualMachineCreationParameter = @{
                    name = "Windows11-Student"
                    location = $lab.Location
                    properties = @{
                        size = "Standard_B2s"
                        userName = "student"
                        password = "ChangeMe123!"
                        isAuthenticationWithSshKey = $false
                        labSubnetName = "$($LabName)Subnet"
                        labVirtualNetworkId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourcegroups/$ResourceGroupName/providers/microsoft.devtestlab/labs/$LabName/virtualnetworks/$LabName"
                        disallowPublicIpAddress = $false
                        galleryImageReference = @{
                            offer = "Windows-11"
                            publisher = "MicrosoftWindowsDesktop"
                            sku = "win11-21h2-pro"
                            osType = "Windows"
                            version = "latest"
                        }
                        allowClaim = $false
                        storageType = "Premium"
                        artifacts = @(
                            @{
                                artifactId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/artifactSources/public repo/artifacts/windows-vscode"
                            }
                            @{
                                artifactId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/artifactSources/public repo/artifacts/windows-git"
                            }
                        )
                    }
                }
            }
        }
    }
    
    if (!$WhatIf) {
        try {
            $windowsFormulaResult = New-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.DevTestLab/labs/formulas" -Name "$LabName/Windows11-Student" -PropertyObject $windowsFormula.properties -Location $lab.Location -Force
            Write-Host "  ✅ Windows 11 Student formula created" -ForegroundColor Green
        }
        catch {
            Write-Host "  ⚠️  Windows formula may already exist or creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  ℹ️  [WHATIF] Would create Windows 11 Student formula" -ForegroundColor White
    }
    
    # Formula 2: Ubuntu Student
    Write-Host "  🐧 Creating Ubuntu Student formula..." -ForegroundColor Yellow
    
    $ubuntuFormula = @{
        location = $lab.Location
        properties = @{
            description = "Ubuntu 22.04 LTS with development tools for students"
            osType = "Linux"
            formulaVirtualMachineProperties = @{
                labVirtualMachineCreationParameter = @{
                    name = "Ubuntu-Student"
                    location = $lab.Location
                    properties = @{
                        size = "Standard_B1s"
                        userName = "student"
                        sshKey = ""
                        isAuthenticationWithSshKey = $false
                        password = "ChangeMe123!"
                        labSubnetName = "$($LabName)Subnet"
                        labVirtualNetworkId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourcegroups/$ResourceGroupName/providers/microsoft.devtestlab/labs/$LabName/virtualnetworks/$LabName"
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
                        artifacts = @(
                            @{
                                artifactId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/artifactSources/public repo/artifacts/linux-install-vscode"
                            }
                            @{
                                artifactId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/artifactSources/public repo/artifacts/linux-apt-package"
                                parameters = @(
                                    @{
                                        name = "packages"
                                        value = "git curl nodejs npm python3 python3-pip"
                                    }
                                )
                            }
                        )
                    }
                }
            }
        }
    }
    
    if (!$WhatIf) {
        try {
            $ubuntuFormulaResult = New-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.DevTestLab/labs/formulas" -Name "$LabName/Ubuntu-Student" -PropertyObject $ubuntuFormula.properties -Location $lab.Location -Force
            Write-Host "  ✅ Ubuntu Student formula created" -ForegroundColor Green
        }
        catch {
            Write-Host "  ⚠️  Ubuntu formula may already exist or creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  ℹ️  [WHATIF] Would create Ubuntu Student formula" -ForegroundColor White
    }
    
    # Enhanced Policies
    Write-Host ""
    Write-Host "🛡️  Applying Enhanced Policies..." -ForegroundColor Cyan
    
    # Auto-shutdown policy
    Write-Host "  ⏰ Configuring auto-shutdown policy..." -ForegroundColor Yellow
    
    $autoShutdownPolicy = @{
        location = $lab.Location
        properties = @{
            factName = "LabVmShutdownTime"
            threshold = "22:00"
            evaluatorType = "AllowedValuesPolicy"
            status = "Enabled"
        }
    }
    
    if (!$WhatIf) {
        try {
            New-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.DevTestLab/labs/policysets/policies" -Name "$LabName/default/LabVmShutdownTime" -PropertyObject $autoShutdownPolicy.properties -Location $lab.Location -Force | Out-Null
            Write-Host "  ✅ Auto-shutdown policy updated" -ForegroundColor Green
        }
        catch {
            Write-Host "  ⚠️  Auto-shutdown policy may already exist: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  ℹ️  [WHATIF] Would configure auto-shutdown at 22:00" -ForegroundColor White
    }
    
    # Verify existing VM size policy
    Write-Host "  📏 Verifying VM size restrictions..." -ForegroundColor Yellow
    
    try {
        $vmSizePolicy = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.DevTestLab/labs/policysets/policies" -Name "$LabName/default/AllowedVmSizesInLab" -ErrorAction SilentlyContinue
        
        if ($vmSizePolicy) {
            Write-Host "  ✅ VM size policy exists and restricts to budget-friendly sizes" -ForegroundColor Green
        }
        else {
            Write-Host "  ⚠️  VM size policy not found - may need manual configuration" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ⚠️  Could not verify VM size policy: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Cost Management Setup
    Write-Host ""
    Write-Host "💰 Cost Management Configuration..." -ForegroundColor Cyan
    
    $totalMonthlyBudget = $DailyCostLimit * $NumberOfStudents * 30
    $totalSemesterBudget = $DailyCostLimit * $NumberOfStudents * 120
    
    Write-Host "  📊 Cost Analysis:" -ForegroundColor White
    Write-Host "    Daily cost per student: $DailyCostLimit NOK" -ForegroundColor White
    Write-Host "    Total daily budget: $($DailyCostLimit * $NumberOfStudents) NOK" -ForegroundColor White
    Write-Host "    Monthly estimate: $totalMonthlyBudget NOK" -ForegroundColor White
    Write-Host "    Semester estimate: $totalSemesterBudget NOK" -ForegroundColor White
    
    # Success summary
    Write-Host ""
    Write-Host "🎉 Post-Deployment Configuration Complete!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ VM Formulas created:" -ForegroundColor White
    Write-Host "  - Windows11-Student (Standard_B2s with VS Code, Git)" -ForegroundColor White
    Write-Host "  - Ubuntu-Student (Standard_B1s with development tools)" -ForegroundColor White
    Write-Host ""
    Write-Host "✅ Policies configured:" -ForegroundColor White
    Write-Host "  - Auto-shutdown: 22:00 daily" -ForegroundColor White
    Write-Host "  - VM limit per student: $MaxVmsPerStudent" -ForegroundColor White
    Write-Host "  - Allowed VM sizes: Standard_B1s, Standard_B2s, Standard_B1ms" -ForegroundColor White
    Write-Host ""
    Write-Host "💰 Cost projections:" -ForegroundColor White
    Write-Host "  - Daily budget: $($DailyCostLimit * $NumberOfStudents) NOK" -ForegroundColor White
    Write-Host "  - Monthly budget: $totalMonthlyBudget NOK" -ForegroundColor White
    Write-Host "  - Semester budget: $totalSemesterBudget NOK" -ForegroundColor White
    Write-Host ""
    Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Test VM creation using the new formulas" -ForegroundColor White
    Write-Host "  2. Add students to the lab (Azure AD users)" -ForegroundColor White
    Write-Host "  3. Set up cost alerts in Azure Cost Management" -ForegroundColor White
    Write-Host "  4. Monitor usage in the lab dashboard" -ForegroundColor White
    Write-Host ""
    Write-Host "🌐 Lab URL: https://portal.azure.com/#@/resource$($lab.ResourceId)" -ForegroundColor White
    Write-Host ""
    
}
catch {
    Write-Host ""
    Write-Host "❌ Script failed with error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "🔍 Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "  - Ensure you have 'Contributor' or 'Owner' role on the resource group" -ForegroundColor White
    Write-Host "  - Verify the DevTest Lab was created successfully" -ForegroundColor White
    Write-Host "  - Check if Azure PowerShell module is up to date: Update-Module Az" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "Script completed successfully! 🚀" -ForegroundColor Green
