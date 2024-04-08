function New-AzurePublicIPs {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable[]]$publicIPconfigs
    )

    foreach ($config in $publicIPconfigs) {
        try {
            # Attempt to create the Public IP Address
            $publicIP = New-AzPublicIpAddress -Name $config.Name `
                                              -ResourceGroupName $config.ResourceGroupName `
                                              -Location $config.Location `
                                              -AllocationMethod $config.AllocationMethod `
                                              -ErrorAction Stop
            Write-Output "Successfully created Public IP Address: $($publicIP.Name) in $($publicIP.Location)"
        }
        catch {
            Write-Error "Failed to create Public IP Address: $($config.Name). Error: $_"
        }
    }
}

function New-AzureVMNICs {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable[]]$nicConfigurations
    )

    foreach ($config in $nicConfigurations) {
        try {
            # Retrieve the Public IP Address object
            $publicIP = Get-AzPublicIpAddress -Name $config.PublicIpAddress -ResourceGroupName $config.ResourceGroupName
            if (-not $publicIP) {
                Write-Error "Public IP Address $($config.PublicIpAddress) not found."
                continue
            }

            # Attempt to retrieve the VNet that contains the target subnet
            $subnet = $null
            $vNets = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupNameVNET
            foreach ($vNet in $vNets) {
                $subnet = $vNet.Subnets | Where-Object { $_.Name -eq $config.Subnet }
                if ($subnet) {
                    break
                }
            }

            if (-not $subnet) {
                Write-Error "Subnet $($config.Subnet) not found."
                continue
            }

            # Create the NIC with the associated Public IP Address and Subnet
            $nic = New-AzNetworkInterface -Name $config.Name `
                                          -ResourceGroupName $config.ResourceGroupName `
                                          -Location $config.Location `
                                          -SubnetId $subnet.Id `
                                          -PublicIpAddressId $publicIP.Id `
                                          -ErrorAction Stop
            Write-Output "Successfully created NIC: $($nic.Name) in $($nic.Location)"
        }
        catch {
            Write-Error "Failed to create NIC: $($config.Name). Error: $_"
        }
    }
}


# Variables
$prefix = "tim"
$resourceGroupName = "$prefix-rg-vm-001"
$location = "uksouth"
$resourceGroupNameVNET = "$prefix-rg-network-001"

# Create Resource Group for VMs


# Variables for VMs
$vmName1 = "$prefix-vm-mgmt-prod-uk-001"
$vmName2 = "$prefix-vm-web-prod-uk-001"
$vmName3 = "$prefix-vm-hr-prod-uk-001"
$vmName4 = "$prefix-vm-hrdev-dev-uk-001"

$vmSize = 'Standard_B1s'
$adminUsername = 'tim'
$adminPassword = 'SDfsgl!_DFahS24!fsdf'
$secureAdminPassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
$image = 'debian-11'

# pip names
$publicIPName1 = "$prefix-pip-mgmt-prod-uk-001"
$publicIPName2 = "$prefix-pip-web-prod-uk-001"
$publicIPName3 = "$prefix-pip-hr-prod-uk-001"
$publicIPName4 = "$prefix-pip-hrdev-dev-uk-001"

# Subnet names
$subnetName1 = "$prefix-snet-mgmt-prod-uk-001"
$subnetName2 = "$prefix-snet-web-prod-uk-001"
$subnetName3 = "$prefix-snet-hr-prod-uk-001"
$subnetName4 = "$prefix-snet-hrdev-dev-uk-001"


    

# Public IP configurations
$publicIPconfigs = @( 
    @{
        Name = $publicIPName1
        ResourceGroupName = $resourceGroupName
        Location = $location
        AllocationMethod = 'Static'
    }, 
    @{
        Name = $publicIPName2
        ResourceGroupName = $resourceGroupName
        Location = $location
        AllocationMethod = 'Static'
    }, 
    @{
        Name = $publicIPName3
        ResourceGroupName = $resourceGroupName
        Location = $location
        AllocationMethod = 'Static'
    }, 
    @{
        Name = $publicIPName4
        ResourceGroupName = $resourceGroupName
        Location = $location
        AllocationMethod = 'Static'
    }
)

# NIC configurations
$nicConfigurations = @(
    @{
        Name = $vmName1 + '-nic'
        ResourceGroupName = $resourceGroupName
        Location = $location
        PublicIpAddress = $publicIPName1
        Subnet = $subnetName1
    },
    @{
        Name = $vmName2 + '-nic'
        ResourceGroupName = $resourceGroupName
        Location = $location
        PublicIpAddress = $publicIPName2
        Subnet = $subnetName2
    },
    @{
        Name = $vmName3 + '-nic'
        ResourceGroupName = $resourceGroupName
        Location = $location
        PublicIpAddress = $publicIPName3
        Subnet = $subnetName3
    },
    @{
        Name = $vmName4 + '-nic'
        ResourceGroupName = $resourceGroupName
        Location = $location
        PublicIpAddress = $publicIPName4
        Subnet = $subnetName4
    }
)




# Call the function to create the Public IPs
New-AzurePublicIPs -publicIPconfigs $publicIPconfigs
Start-Sleep -Seconds 30

# Call the funtion to create the NICs
New-AzureVMNICs -nicConfigurations $nicConfigurations




# Create VMs configuration
$vmConfig1 = New-AzVMConfig -VMName $vmName1 -VMSize $vmSize |
            Set-AzVMOperatingSystem -Linux `
            -ComputerName $vmName1 `
            -Credential (New-Object System.Management.Automation.PSCredential ($adminUsername, $secureAdminPassword)) |
            Set-AzVMSourceImage -PublisherName "Debian" -Offer "debian-11" -Skus "11" -Version "latest" |
            Add-AzVMNetworkInterface -Id $nic1.Id

$vmConfig2 = New-AzVMConfig -VMName $vmName2 -VMSize $vmSize |
            Set-AzVMOperatingSystem -Linux `
            -ComputerName $vmName2 `
            -Credential (New-Object System.Management.Automation.PSCredential ($adminUsername, $secureAdminPassword)) |
            Set-AzVMSourceImage -PublisherName "Debian" -Offer $image -Skus "11" -Version "latest" |
            Add-AzVMNetworkInterface -Id $nic2.Id


# Create VMs

New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig1 -asJob
New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig2 -asJob

Invoke-AzVMRunCommand `
   -ResourceGroupName $resourceGroupName `
   -Name $vmName1 `
   -CommandId 'RunShellScript' `
   -ScriptString 'sudo apt-get update && sudo apt-get install -y nginx'

Get-AzPublicIpAddress -Name $publicIPName1 -ResourceGroupName $resourceGroupName | Select-Object "IpAddress"