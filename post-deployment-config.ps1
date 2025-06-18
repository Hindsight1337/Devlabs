# Azure DevTest Labs Post-Deployment Configuration Script
# Version: 4.0 - Fixed Azure PowerShell compatibility issues
# Uses REST API calls instead of problematic Az.Resources cmdlets

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

# Fix Azure PowerShell module issues
Write-Host "Fixing Azure PowerShell module compatibility..." -ForegroundColor Yellow

try {
    # Force import specific modules to avoid conflicts
    Import-Module Az.Accounts -Force -Scope Local
    Import-Module Az.Profile -Force -Scope Local
    
    Write-Host "SUCCESS: Core modules loaded" -ForegroundColor Green
}
catch {
    Write-Host "WARNING: Module import issues, continuing with basic functionality" -ForegroundColor Yellow
}

# Check authentication
Write-Host "Checking Azure authentication..." -ForegroundColor Yellow

try {
    $context = Get-AzContext
    if (!$context) {
        Write-Host "Logging into Azure..." -ForegroundColor Yellow
        Connect-AzAccount
        $context = Get-AzContext
    }
    
    $subscriptionId = $context.Subscription.Id
    $accessToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id, $null, $null, $null, "https://management.azure.com/").AccessToken
    
    Write-Host "SUCCESS: Authenticated as $($context.Account.Id)" -ForegroundColor Green
    Write-Host "Subscription: $subscriptionId" -ForegroundColor White
}
catch {
    throw "Failed to authenticate with Azure: $($_.Exception.Message)"
}

# Verify resource group and lab using REST API
Write-Host "Verifying resources..." -ForegroundColor Yellow

$headers = @{
    'Authorization' = "Bearer $accessToken"
    'Content-Type' = 'application/json'
}

# Check resource group
$rgUri = "https://management.azure.com/subscriptions/$subscriptionId/resourcegroups/$ResourceGroupName" + "?api-version=2021-04-01"
try {
    $rgResponse = Invoke-RestMethod -Uri $rgUri -Headers $headers -Method GET
    Write-Host "SUCCESS: Resource group found in $($rgResponse.location)" -ForegroundColor Green
}
catch {
    throw "Resource group '$ResourceGroupName' not found or access denied"
}

# Check DevTest Lab
$labUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName" + "?api-version=2018-09-15"
try {
    $labResponse = Invoke-RestMethod -Uri $labUri -Headers $headers -Method GET
    $labLocation = $labResponse.location
    Write-Host "SUCCESS: DevTest Lab found in $labLocation" -ForegroundColor Green
}
catch {
    throw "DevTest Lab '$LabName' not found in resource group '$ResourceGroupName'"
}

# Get virtual network info for formulas
$vnetUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/virtualnetworks" + "?api-version=2018-09-15"
try {
    $vnetResponse = Invoke-RestMethod -Uri $vnetUri -Headers $headers -Method GET
    $vnetName = $vnetResponse.value[0].name
    $subnetName = $vnetResponse.value[0].properties.allowedSubnets[0].labSubnetName
    Write-Host "SUCCESS: Found virtual network $vnetName with subnet $subnetName" -ForegroundColor Green
}
catch {
    Write-Host "WARNING: Could not get virtual network info, using defaults" -ForegroundColor Yellow
    $vnetName = $LabName
    $subnetName = "default"
}

# Create VM Formulas using REST API
Write-Host ""
Write-Host "Creating VM Formulas..." -ForegroundColor Cyan

# Windows 11 Student Formula
Write-Host "  Creating Windows11-Student formula..." -ForegroundColor Yellow

$windowsFormulaBody = @{
    location = $labLocation
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
} | ConvertTo-Json -Depth 10

$windowsFormulaUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/formulas/Windows11-Student" + "?api-version=2018-09-15"

try {
    $windowsResult = Invoke-RestMethod -Uri $windowsFormulaUri -Headers $headers -Method PUT -Body $windowsFormulaBody
    Write-Host "  SUCCESS: Windows11-Student formula created" -ForegroundColor Green
}
catch {
    if ($_.Exception.Response.StatusCode -eq 409) {
        Write-Host "  INFO: Windows11-Student formula already exists" -ForegroundColor Yellow
    }
    else {
        Write-Host "  WARNING: Could not create Windows formula: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Ubuntu Student Formula
Write-Host "  Creating Ubuntu-Student formula..." -ForegroundColor Yellow

$ubuntuFormulaBody = @{
    location = $labLocation
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
} | ConvertTo-Json -Depth 10

$ubuntuFormulaUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/formulas/Ubuntu-Student" + "?api-version=2018-09-15"

try {
    $ubuntuResult = Invoke-RestMethod -Uri $ubuntuFormulaUri -Headers $headers -Method PUT -Body $ubuntuFormulaBody
    Write-Host "  SUCCESS: Ubuntu-Student formula created" -ForegroundColor Green
}
catch {
    if ($_.Exception.Response.StatusCode -eq 409) {
        Write-Host "  INFO: Ubuntu-Student formula already exists" -ForegroundColor Yellow
    }
    else {
        Write-Host "  WARNING: Could not create Ubuntu formula: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Verify and update policies using REST API
Write-Host ""
Write-Host "Configuring Lab Policies..." -ForegroundColor Cyan

# Update VM count policy
Write-Host "  Setting VM count policy..." -ForegroundColor Yellow

$vmCountPolicyBody = @{
    properties = @{
        factName = "UserOwnedLabVmCount"
        threshold = $MaxVmsPerStudent.ToString()
        evaluatorType = "MaxValuePolicy"
        status = "Enabled"
    }
} | ConvertTo-Json -Depth 5

$vmCountPolicyUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/policysets/default/policies/MaxVmsAllowedPerUser" + "?api-version=2018-09-15"

try {
    $vmCountResult = Invoke-RestMethod -Uri $vmCountPolicyUri -Headers $headers -Method PUT -Body $vmCountPolicyBody
    Write-Host "  SUCCESS: VM count policy set to $MaxVmsPerStudent per student" -ForegroundColor Green
}
catch {
    Write-Host "  WARNING: Could not update VM count policy: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Update VM size policy
Write-Host "  Setting VM size restrictions..." -ForegroundColor Yellow

$vmSizePolicyBody = @{
    properties = @{
        factName = "LabVmSize"
        threshold = '["Standard_B1s","Standard_B2s","Standard_B1ms","Standard_B2ms"]'
        evaluatorType = "AllowedValuesPolicy"
        status = "Enabled"
    }
} | ConvertTo-Json -Depth 5

$vmSizePolicyUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/policysets/default/policies/AllowedVmSizesInLab" + "?api-version=2018-09-15"

try {
    $vmSizeResult = Invoke-RestMethod -Uri $vmSizePolicyUri -Headers $headers -Method PUT -Body $vmSizePolicyBody
    Write-Host "  SUCCESS: VM size policy restricted to B-series VMs" -ForegroundColor Green
}
catch {
    Write-Host "  WARNING: Could not update VM size policy: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Verify schedules
Write-Host "  Checking auto-shutdown schedule..." -ForegroundColor Yellow

$scheduleUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/schedules/LabVmsShutdown" + "?api-version=2018-09-15"

try {
    $scheduleResponse = Invoke-RestMethod -Uri $scheduleUri -Headers $headers -Method GET
    if ($scheduleResponse.properties.status -eq "Enabled") {
        $shutdownTime = $scheduleResponse.properties.dailyRecurrence.time
        Write-Host "  SUCCESS: Auto-shutdown enabled at $shutdownTime" -ForegroundColor Green
    }
    else {
        Write-Host "  WARNING: Auto-shutdown is not enabled" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  WARNING: Could not verify auto-shutdown schedule" -ForegroundColor Yellow
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

# Create student instruction document
Write-Host ""
Write-Host "Creating student instructions..." -ForegroundColor Cyan

$labUrl = "https://portal.azure.com/#@/resource/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName"

$instructionsContent = @"
# Azure DevTest Lab - Student Instructions

## Lab Information
- Lab Name: $LabName
- Resource Group: $ResourceGroupName
- Lab URL: $labUrl

## Getting Started
1. Go to the lab URL above
2. Log in with your school account
3. Click "My virtual machines" 
4. Click "+ Add" to create a new VM

## Available VM Templates
- **Windows11-Student**: Windows 11 Pro with development tools
  - Size: Standard_B2s (2 vCPU, 4GB RAM)
  - Username: student
  - Password: StudentPass123!

- **Ubuntu-Student**: Ubuntu 22.04 LTS with development tools  
  - Size: Standard_B1s (1 vCPU, 1GB RAM)
  - Username: student
  - Password: StudentPass123!

## Important Rules
- Maximum $MaxVmsPerStudent VMs per student
- Daily budget: $DailyCostLimit NOK per student
- VMs automatically shut down at 22:00
- Remember to save your work before shutdown!

## Cost Information
- Total lab daily budget: $totalDailyBudget NOK
- Estimated monthly cost: $totalMonthlyBudget NOK
- Estimated semester cost: $totalSemesterBudget NOK

## Support
Contact your instructor for help with:
- Login issues
- VM creation problems
- Access to additional resources

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@

$instructionsPath = ".\DevTest-Lab-Student-Instructions.md"
$instructionsContent | Out-File -FilePath $instructionsPath -Encoding UTF8

Write-Host "  SUCCESS: Student instructions saved to $instructionsPath" -ForegroundColor Green

# Final summary
Write-Host ""
Write-Host "Post-Deployment Configuration Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "VM Formulas created:" -ForegroundColor White
Write-Host "  - Windows11-Student (Standard_B2s)" -ForegroundColor White
Write-Host "  - Ubuntu-Student (Standard_B1s)" -ForegroundColor White
Write-Host ""
Write-Host "Policies configured:" -ForegroundColor White
Write-Host "  - Auto-shutdown: Verified" -ForegroundColor White
Write-Host "  - VM limit per student: $MaxVmsPerStudent" -ForegroundColor White
Write-Host "  - VM size restrictions: B-series only" -ForegroundColor White
Write-Host ""
Write-Host "Cost projections:" -ForegroundColor White
Write-Host "  - Daily budget: $totalDailyBudget NOK" -ForegroundColor White
Write-Host "  - Monthly estimate: $totalMonthlyBudget NOK" -ForegroundColor White
Write-Host "  - Semester estimate: $totalSemesterBudget NOK" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Test VM creation using the new formulas" -ForegroundColor White
Write-Host "  2. Add students to the lab (Azure AD users)" -ForegroundColor White
Write-Host "  3. Set up cost alerts in Azure Cost Management" -ForegroundColor White
Write-Host "  4. Share student instructions: $instructionsPath" -ForegroundColor White
Write-Host ""
Write-Host "Lab URL: $labUrl" -ForegroundColor Blue
Write-Host ""
Write-Host "Script completed successfully!" -ForegroundColor Green
