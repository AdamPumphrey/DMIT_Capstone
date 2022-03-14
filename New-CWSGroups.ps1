<#
Template from https://gist.github.com/9to5IT/9620683
.SYNOPSIS
  Generates Security Groups and assigns the corresponding AD users to them.
.DESCRIPTION
  The script creates Security Groups based on an array of existing OUs in the domain. The script then adds users from OUs to their corresponding Groups.
  Some Groups' membership consists of other groups (IT Users, All Employees).
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Adam Pumphrey
  Creation Date:  March 14, 2022
  Purpose/Change: Initial script for CWS Security Group creation and assignment.
  
.EXAMPLE
  .\New-CWSGroups.ps1
#>
$domain, $suffix = $env:USERDNSDOMAIN.Split('.')

$CWSITOUs = @("Tech Support", "Server Support", "Programming", "Networking Support", "Application Support", "Administration")
$CWSOUs = @("Sales", "HR", "Finance", "Executive Staff")

New-ADOrganizationalUnit -Name "CWS Security Groups" -Path "DC=$domain,DC=$suffix" -ProtectedFromAccidentalDeletion $False
New-ADGroup -Name "CWS IT Users" -SamAccountName "CWS IT Users" -GroupCategory "Security" -GroupScope "Global" -DisplayName "CWS IT Users" -Path "OU=CWS Security Groups,DC=$domain,DC=$suffix"

foreach ($OU in $CWSITOUs) {
    New-ADGroup -Name "CWS IT $OU Users" -SamAccountName "CWS IT $OU Users" -GroupCategory "Security" -GroupScope "Global" -DisplayName "CWS IT $OU Users" -Path "OU=CWS Security Groups,DC=$domain,DC=$suffix"
    Get-ADUser -Filter * -SearchBase "OU=$OU,OU=IT,DC=$domain,DC=$suffix" | % { Add-ADGroupMember -Identity "CWS IT $OU Users" -Members $_ }
    Add-ADGroupMember -Identity "CWS IT Users" -Members "CWS IT $OU Users"
}

New-ADGroup -Name "CWS All Employees" -SamAccountName "CWS All Employees" -GroupCategory "Security" -GroupScope "Global" -DisplayName "CWS All Employees" -Path "OU=CWS Security Groups,DC=$domain,DC=$suffix"
Add-ADGroupMember -Identity "CWS All Employees" -Members "CWS IT Users"

foreach ($OU in $CWSOUs) {
    if ($OU -eq "Executive Staff") {
        $name = "CWS $OU"
    } else {
        $name = "CWS $OU Users"
    }
    New-ADGroup -Name $name -SamAccountName $name -GroupCategory "Security" -GroupScope "Global" -DisplayName $name -Path "OU=CWS Security Groups,DC=$domain,DC=$suffix"
    Get-ADUser -Filter * -SearchBase "OU=$OU,DC=$domain,DC=$suffix" | % { Add-ADGroupMember -Identity $name -Members $_ }
    Add-ADGroupMember -Identity "CWS All Employees" -Members $name
}