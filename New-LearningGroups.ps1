<#
Template from https://gist.github.com/9to5IT/9620683
.SYNOPSIS
  Generates Security Groups and assigns the corresponding AD users to them.
.DESCRIPTION
  The script creates Security Groups based on an array of existing OUs in the domain. The script then adds users from OUs to their corresponding Groups.
  Some Groups' membership consists of other groups (All Users).
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Adam Pumphrey
  Creation Date:  March 14, 2022
  Purpose/Change: Initial script for Zen Learning Security Group creation and assignment.
  
.EXAMPLE
  .\New-LearningGroups.ps1
#>
$subdomain, $domain, $suffix = $env:USERDNSDOMAIN.Split('.')

$LearningOUs = @("Students", "Teachers", "Design")

New-ADOrganizationalUnit -Name "Learning Security Groups" -Path "DC=$subdomain,DC=$domain,DC=$suffix" -ProtectedFromAccidentalDeletion $False

New-ADGroup -Name "Learning All Users" -SamAccountName "Learning All Users" -GroupCategory "Security" -GroupScope "Global" -DisplayName "Learning All Users" -Path "OU=Learning Security Groups,DC=$subdomain,DC=$domain,DC=$suffix"

foreach ($OU in $LearningOUs) {
    if ($OU -eq "Design") {
        $name = "Learning $OU Users"
    } else {
        $name = "Learning $OU"
    }
    New-ADGroup -Name $name -SamAccountName $name -GroupCategory "Security" -GroupScope "Global" -DisplayName $name -Path "OU=Learning Security Groups,DC=$subdomain,DC=$domain,DC=$suffix"
    Get-ADUser -Filter * -SearchBase "OU=$OU,DC=$subdomain,DC=$domain,DC=$suffix" | % { Add-ADGroupMember -Identity $name -Members $_ }
    Add-ADGroupMember -Identity "Learning All Users" -Members $name
}