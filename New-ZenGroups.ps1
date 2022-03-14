<#
Template from https://gist.github.com/9to5IT/9620683
.SYNOPSIS
  Generates Security Groups and assigns the corresponding AD users to them.
.DESCRIPTION
  The script creates Security Groups based on an array of existing OUs in the domain. The script then adds users from OUs to their corresponding Groups.
  Some Groups' membership consists of other groups (Sales Users, Design Users, All Employees).
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Adam Pumphrey
  Creation Date:  March 14, 2022
  Purpose/Change: Initial script for Zen Security Group creation and assignment.
  
.EXAMPLE
  .\New-ZenGroups.ps1
#>
$domain, $suffix = $env:USERDNSDOMAIN.Split('.')

$ZenDesignOUs = @("Animators", "Content Experts", "DB Engineers", "Programmers", "UI Experts")
$ZenSalesOUs = @("East Sales Team", "International Sales Team", "North Sales Team", "Sales Accounts Team", "South Sales Team", "West Sales Team")
$ZenOUs = @("IT", "HR", "Finance", "Executive Staff")

New-ADOrganizationalUnit -Name "Zen Security Groups" -Path "DC=$domain,DC=$suffix" -ProtectedFromAccidentalDeletion $False
New-ADGroup -Name "Zen Sales Users" -SamAccountName "Zen Sales Users" -GroupCategory "Security" -GroupScope "Global" -DisplayName "Zen Sales Users" -Path "OU=Zen Security Groups,DC=$domain,DC=$suffix"
New-ADGroup -Name "Zen Design Users" -SamAccountName "Zen Design Users" -GroupCategory "Security" -GroupScope "Global" -DisplayName "Zen Design Users" -Path "OU=Zen Security Groups,DC=$domain,DC=$suffix"

foreach ($OU in $ZenDesignOUs) {
    if ($OU -eq "Animators") {
        $name = "Zen Animation Users"
    } else {
        $name = "Zen $OU"
    }
    New-ADGroup -Name $name -SamAccountName $name -GroupCategory "Security" -GroupScope "Global" -DisplayName $name -Path "OU=Zen Security Groups,DC=$domain,DC=$suffix"
    Get-ADUser -Filter * -SearchBase "OU=$OU,OU=Design,DC=$domain,DC=$suffix" | % { Add-ADGroupMember -Identity $name -Members $_ }
    Add-ADGroupMember -Identity "Zen Design Users" -Members $name
}

foreach ($OU in $ZenSalesOUs) {
    $name = "Zen $OU"
    New-ADGroup -Name $name -SamAccountName $name -GroupCategory "Security" -GroupScope "Global" -DisplayName $name -Path "OU=Zen Security Groups,DC=$domain,DC=$suffix"
    Get-ADUser -Filter * -SearchBase "OU=$OU,OU=Sales,DC=$domain,DC=$suffix" | % { Add-ADGroupMember -Identity $name -Members $_ }
    Add-ADGroupMember -Identity "Zen Sales Users" -Members $name
}

New-ADGroup -Name "Zen All Employees" -SamAccountName "Zen All Employees" -GroupCategory "Security" -GroupScope "Global" -DisplayName "Zen All Employees" -Path "OU=Zen Security Groups,DC=$domain,DC=$suffix"
Add-ADGroupMember -Identity "Zen All Employees" -Members "Zen Sales Users", "Zen Design Users"

foreach ($OU in $ZenOUs) {
    if ($OU -eq "Executive Staff") {
        $name = "Zen $OU"
    } else {
        $name = "Zen $OU Users"
    }
    New-ADGroup -Name $name -SamAccountName $name -GroupCategory "Security" -GroupScope "Global" -DisplayName $name -Path "OU=Zen Security Groups,DC=$domain,DC=$suffix"
    Get-ADUser -Filter * -SearchBase "OU=$OU,DC=$domain,DC=$suffix" | % { Add-ADGroupMember -Identity $name -Members $_ }
    Add-ADGroupMember -Identity "Zen All Employees" -Members $name
}