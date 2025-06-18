# =======================================
# Post-Deployment Lab Configuration
# Kjør dette ETTER ARM template deployment
# =======================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$LabName,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxVmsPerStudent = 2,
    
    [Parameter(Mandatory = $false)]
    [int]$DailyCostLimit = 75,
    
    [Parameter(Mandatory = $false)]
    [int]$NumberOfStudents = 26
)

Write-Host "=== POST-DEPLOYMENT LAB CONFIGURATION ===" -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Lab Name: $LabName" -ForegroundColor Yellow
Write-Host "Max VMs per student: $MaxVmsPerStudent" -ForegroundColor Yellow
Write-Host "Daily cost limit: $DailyCostLimit NOK" -ForegroundColor Yellow
Write-Host "Number of students: $NumberOfStudents" -ForegroundColor Yellow

# Ensure we're logged in
try {
    $context = Get-AzContext
    if (!$context) {
        Write-Host "Logging into Azure..." -ForegroundColor Yellow
        Connect-AzAccount
    }
    Write-Host "✓ Connected to Azure" -ForegroundColor Green
    Write-Host "  Subscription: $($context.Subscription.Name)" -ForegroundColor White
    Write-Host "  Account: $($context.Account.Id)" -ForegroundColor White
}
catch {
    Write-Error "Failed to connect to Azure: $($_.Exception.Message)"
    Write-Host "Please run 'Connect-AzAccount' manually and try again." -ForegroundColor Red
    exit 1
}

# Get access token and subscription info
$subscriptionId = (Get-AzContext).Subscription.Id
$accessToken = (Get-AzAccessToken).Token

$headers = @{
    'Authorization' = "Bearer $accessToken"
    'Content-Type' = 'application/json'
}

$baseUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName"

Write-Host "`n🔍 Validating lab exists..." -ForegroundColor Green
try {
    $lab = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceName $LabName -ResourceType "Microsoft.DevTestLab/labs" -ErrorAction Stop
    Write-Host "✓ Lab found and accessible" -ForegroundColor Green
    Write-Host "  Lab ID: $($lab.ResourceId)" -ForegroundColor White
}
catch {
    Write-Error "❌ Could not find lab '$LabName' in resource group '$ResourceGroupName'"
    Write-Host "Please verify the lab was deployed successfully and try again." -ForegroundColor Red
    exit 1
}

# ==================
# CONFIGURE LAB POLICIES VIA REST API
# ==================
Write-Host "`n🛡️ Configuring lab policies..." -ForegroundColor Green

# Policy 1: Max VMs per user
Write-Host "  Setting VM count policy..." -ForegroundColor Yellow
$vmCountPolicyUri = "$baseUri/policysets/default/policies/MaxVmsAllowedPerUser?api-version=2018-09-15"
$vmCountPolicy = @{
    properties = @{
        factName = "UserOwnedLabVmCount"
        threshold = $MaxVmsPerStudent.ToString()
        evaluatorType = "MaxValuePolicy"
        status = "Enabled"
    }
} | ConvertTo-Json -Depth 3

try {
    $response = Invoke-RestMethod -Uri $vmCountPolicyUri -Method PUT -Headers $headers -Body $vmCountPolicy
    Write-Host "  ✓ VM count policy set successfully" -ForegroundColor Green
}
catch {
    Write-Warning "  ⚠️ Failed to set VM count policy: $($_.Exception.Message)"
}

# Policy 2: Allowed VM sizes
Write-Host "  Setting VM size policy..." -ForegroundColor Yellow
$vmSizePolicyUri = "$baseUri/policysets/default/policies/AllowedVmSizesInLab?api-version=2018-09-15"
$allowedSizes = @("Standard_B1s", "Standard_B2s", "Standard_B1ms", "Standard_B2ms")
$vmSizePolicy = @{
    properties = @{
        factName = "LabVmSize"
        threshold = ($allowedSizes | ConvertTo-Json -Compress)
        evaluatorType = "AllowedValuesPolicy"
        status = "Enabled"
    }
} | ConvertTo-Json -Depth 3

try {
    $response = Invoke-RestMethod -Uri $vmSizePolicyUri -Method PUT -Headers $headers -Body $vmSizePolicy
    Write-Host "  ✓ VM size policy set successfully" -ForegroundColor Green
}
catch {
    Write-Warning "  ⚠️ Failed to set VM size policy: $($_.Exception.Message)"
}

# Policy 3: Allowed gallery images
Write-Host "  Setting gallery image policy..." -ForegroundColor Yellow
$imagePolicyUri = "$baseUri/policysets/default/policies/GalleryImage?api-version=2018-09-15"
$allowedImages = @(
    @{
        offer = "Windows-11"
        publisher = "MicrosoftWindowsDesktop"
        sku = "win11-22h2-pro"
        osType = "Windows"
        version = "latest"
    },
    @{
        offer = "WindowsServer"
        publisher = "MicrosoftWindowsServer"
        sku = "2022-datacenter-azure-edition"
        osType = "Windows"
        version = "latest"
    },
    @{
        offer = "0001-com-ubuntu-server-focal"
        publisher = "Canonical"
        sku = "20_04-lts-gen2"
        osType = "Linux"
        version = "latest"
    }
)

$imagePolicy = @{
    properties = @{
        factName = "GalleryImage"
        threshold = ($allowedImages | ConvertTo-Json -Compress)
        evaluatorType = "AllowedValuesPolicy"
        status = "Enabled"
    }
} | ConvertTo-Json -Depth 3

try {
    $response = Invoke-RestMethod -Uri $imagePolicyUri -Method PUT -Headers $headers -Body $imagePolicy
    Write-Host "  ✓ Gallery image policy set successfully" -ForegroundColor Green
}
catch {
    Write-Warning "  ⚠️ Failed to set gallery image policy: $($_.Exception.Message)"
}

# ==================
# CREATE VM FORMULAS
# ==================
Write-Host "`n🧪 Creating VM formulas..." -ForegroundColor Green

# Windows 11 Formula
Write-Host "  Creating Windows 11 formula..." -ForegroundColor Yellow
$formulaUri = "$baseUri/formulas/Windows11-Student?api-version=2018-09-15"
$formula = @{
    properties = @{
        description = "Standard Windows 11 for students"
        osType = "Windows"
        formulaContent = @{
            properties = @{
                size = "Standard_B2s"
                userName = "student"
                isAuthenticationWithSshKey = $false
                labSubnetName = "default"
                disallowPublicIpAddress = $false
                galleryImageReference = @{
                    offer = "Windows-11"
                    publisher = "MicrosoftWindowsDesktop"
                    sku = "win11-22h2-pro"
                    osType = "Windows"
                    version = "latest"
                }
                artifacts = @()
            }
        }
    }
} | ConvertTo-Json -Depth 5

try {
    $response = Invoke-RestMethod -Uri $formulaUri -Method PUT -Headers $headers -Body $formula
    Write-Host "  ✓ Windows 11 formula created successfully" -ForegroundColor Green
}
catch {
    Write-Warning "  ⚠️ Failed to create Windows 11 formula: $($_.Exception.Message)"
}

# Ubuntu Formula
Write-Host "  Creating Ubuntu formula..." -ForegroundColor Yellow
$ubuntuFormulaUri = "$baseUri/formulas/Ubuntu-Student?api-version=2018-09-15"
$ubuntuFormula = @{
    properties = @{
        description = "Standard Ubuntu 20.04 LTS for students"
        osType = "Linux"
        formulaContent = @{
            properties = @{
                size = "Standard_B2s"
                userName = "student"
                isAuthenticationWithSshKey = $true
                labSubnetName = "default"
                disallowPublicIpAddress = $false
                galleryImageReference = @{
                    offer = "0001-com-ubuntu-server-focal"
                    publisher = "Canonical"
                    sku = "20_04-lts-gen2"
                    osType = "Linux"
                    version = "latest"
                }
                artifacts = @()
            }
        }
    }
} | ConvertTo-Json -Depth 5

try {
    $response = Invoke-RestMethod -Uri $ubuntuFormulaUri -Method PUT -Headers $headers -Body $ubuntuFormula
    Write-Host "  ✓ Ubuntu formula created successfully" -ForegroundColor Green
}
catch {
    Write-Warning "  ⚠️ Failed to create Ubuntu formula: $($_.Exception.Message)"
}

# ==================
# SET COST MANAGEMENT
# ==================
Write-Host "`n💰 Setting up cost management..." -ForegroundColor Green

$costUri = "$baseUri/costs/targetCost?api-version=2018-09-15"
$totalBudget = $DailyCostLimit * $NumberOfStudents
$cost = @{
    properties = @{
        targetCost = @{
            status = "Enabled"
            target = $totalBudget
            costThresholds = @(
                @{
                    thresholdId = [System.Guid]::NewGuid().ToString()
                    percentageThreshold = @{
                        thresholdValue = 50
                    }
                    displayOnChart = "Enabled"
                    sendNotificationWhenExceeded = "Enabled"
                    notificationSent = ""
                },
                @{
                    thresholdId = [System.Guid]::NewGuid().ToString()
                    percentageThreshold = @{
                        thresholdValue = 80
                    }
                    displayOnChart = "Enabled"
                    sendNotificationWhenExceeded = "Enabled"
                    notificationSent = ""
                },
                @{
                    thresholdId = [System.Guid]::NewGuid().ToString()
                    percentageThreshold = @{
                        thresholdValue = 100
                    }
                    displayOnChart = "Enabled"
                    sendNotificationWhenExceeded = "Enabled"
                    notificationSent = ""
                }
            )
        }
    }
} | ConvertTo-Json -Depth 5

try {
    $response = Invoke-RestMethod -Uri $costUri -Method PUT -Headers $headers -Body $cost
    Write-Host "  ✓ Cost management configured successfully" -ForegroundColor Green
    Write-Host "    Daily budget: $DailyCostLimit NOK per student" -ForegroundColor White
    Write-Host "    Total daily budget: $totalBudget NOK" -ForegroundColor White
    Write-Host "    Monthly estimate: $($totalBudget * 30) NOK" -ForegroundColor White
}
catch {
    Write-Warning "  ⚠️ Failed to set cost management: $($_.Exception.Message)"
}

# ==================
# VALIDATION AND TESTING
# ==================
Write-Host "`n🔍 Validating configuration..." -ForegroundColor Green

# Test lab accessibility
try {
    $labDetails = Get-AzResource -ResourceId $lab.ResourceId -ExpandProperties
    Write-Host "  ✓ Lab is accessible and configured" -ForegroundColor Green
    
    # Check if policies are applied
    Write-Host "  Checking policies..." -ForegroundColor Yellow
    $policiesUri = "$baseUri/policysets/default/policies?api-version=2018-09-15"
    $policies = Invoke-RestMethod -Uri $policiesUri -Method GET -Headers $headers
    
    $vmCountPolicyExists = $policies.value | Where-Object { $_.name -like "*MaxVmsAllowedPerUser*" }
    $vmSizePolicyExists = $policies.value | Where-Object { $_.name -like "*AllowedVmSizesInLab*" }
    
    if ($vmCountPolicyExists) {
        Write-Host "    ✓ VM count policy is active" -ForegroundColor Green
    } else {
        Write-Host "    ⚠️ VM count policy not found" -ForegroundColor Yellow
    }
    
    if ($vmSizePolicyExists) {
        Write-Host "    ✓ VM size policy is active" -ForegroundColor Green
    } else {
        Write-Host "    ⚠️ VM size policy not found" -ForegroundColor Yellow
    }
}
catch {
    Write-Warning "  ⚠️ Could not fully validate configuration: $($_.Exception.Message)"
}

# ==================
# GENERATE COMPREHENSIVE SUMMARY
# ==================
Write-Host "`n=== CONFIGURATION SUMMARY ===" -ForegroundColor Cyan
Write-Host "Lab Name: $LabName" -ForegroundColor White
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "Subscription: $((Get-AzContext).Subscription.Name)" -ForegroundColor White
Write-Host ""
Write-Host "Student Limits:" -ForegroundColor Yellow
Write-Host "  Max VMs per student: $MaxVmsPerStudent" -ForegroundColor White
Write-Host "  Number of students: $NumberOfStudents" -ForegroundColor White
Write-Host "  Total max VMs: $($MaxVmsPerStudent * $NumberOfStudents)" -ForegroundColor White
Write-Host ""
Write-Host "Cost Management:" -ForegroundColor Yellow
Write-Host "  Daily limit per student: $DailyCostLimit NOK" -ForegroundColor White
Write-Host "  Total daily budget: $($DailyCostLimit * $NumberOfStudents) NOK" -ForegroundColor White
Write-Host "  Monthly estimate: $($DailyCostLimit * $NumberOfStudents * 30) NOK" -ForegroundColor White
Write-Host "  Semester estimate (4 months): $($DailyCostLimit * $NumberOfStudents * 30 * 4) NOK" -ForegroundColor White
Write-Host ""
Write-Host "Allowed VM Sizes:" -ForegroundColor Yellow
Write-Host "  - Standard_B1s (1 vCPU, 1 GB RAM)" -ForegroundColor White
Write-Host "  - Standard_B2s (2 vCPU, 4 GB RAM)" -ForegroundColor White
Write-Host "  - Standard_B1ms (1 vCPU, 2 GB RAM)" -ForegroundColor White
Write-Host "  - Standard_B2ms (2 vCPU, 8 GB RAM)" -ForegroundColor White
Write-Host ""
Write-Host "Available Images:" -ForegroundColor Yellow
Write-Host "  - Windows 11 Pro" -ForegroundColor White
Write-Host "  - Windows Server 2022" -ForegroundColor White
Write-Host "  - Ubuntu 20.04 LTS" -ForegroundColor White
Write-Host ""
Write-Host "VM Formulas Created:" -ForegroundColor Yellow
Write-Host "  - Windows11-Student (Windows 11, B2s)" -ForegroundColor White
Write-Host "  - Ubuntu-Student (Ubuntu 20.04, B2s)" -ForegroundColor White

$labUrl = "https://portal.azure.com/#@/resource/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName"
$costUrl = "https://portal.azure.com/#@/blade/Microsoft_Azure_CostManagement/Menu/overview"

Write-Host "`n=== IMPORTANT LINKS ===" -ForegroundColor Cyan
Write-Host "Lab Management: $labUrl" -ForegroundColor Blue
Write-Host "Cost Management: $costUrl" -ForegroundColor Blue

# ==================
# NEXT STEPS FOR TEACHERS
# ==================
Write-Host "`n=== NEXT STEPS FOR TEACHERS ===" -ForegroundColor Yellow
Write-Host "1. 👥 Create student Azure AD accounts" -ForegroundColor White
Write-Host "2. 🔑 Assign students to the lab using the custom role" -ForegroundColor White
Write-Host "3. 📧 Send lab access instructions to students" -ForegroundColor White
Write-Host "4. 📊 Monitor costs daily via Cost Management" -ForegroundColor White
Write-Host "5. 🛠️ Test VM creation with formulas" -ForegroundColor White
Write-Host "6. 📋 Set up email notifications for cost alerts" -ForegroundColor White

Write-Host "`n=== STUDENT ACCESS INSTRUCTIONS ===" -ForegroundColor Yellow
Write-Host "Students should:" -ForegroundColor White
Write-Host "1. Go to: $labUrl" -ForegroundColor White
Write-Host "2. Log in with their Azure AD account" -ForegroundColor White
Write-Host "3. Click '+ Add' to create new VM" -ForegroundColor White
Write-Host "4. Choose from available formulas (Windows11-Student or Ubuntu-Student)" -ForegroundColor White
Write-Host "5. Remember to shut down VMs when finished!" -ForegroundColor White

Write-Host "`n=== TROUBLESHOOTING ===" -ForegroundColor Yellow
Write-Host "If students can't access the lab:" -ForegroundColor White
Write-Host "- Verify they have Azure AD accounts" -ForegroundColor White
Write-Host "- Check role assignments in Access Control (IAM)" -ForegroundColor White
Write-Host "- Ensure lab policies are not blocking access" -ForegroundColor White
Write-Host ""
Write-Host "If costs are too high:" -ForegroundColor White
Write-Host "- Check auto-shutdown is working (22:00 daily)" -ForegroundColor White
Write-Host "- Review VM sizes being used" -ForegroundColor White
Write-Host "- Consider lowering daily budget limits" -ForegroundColor White

Write-Host "`nPost-deployment configuration completed successfully! 🎉" -ForegroundColor Green
Write-Host "The DevTest Lab is now ready for educational use." -ForegroundColor Green
