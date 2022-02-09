<#
Template from https://gist.github.com/9to5IT/9620683
.SYNOPSIS
  Creates OUs for the subdomain.
.DESCRIPTION
  The script gets the environment's domain and domain suffix, and then creates the declared OUs.
.INPUTS
  None
.OUTPUTS
  Log file stored in C:\Windows\DMIT2590_Logs\New-LearningOUs.log
.NOTES
  Version:        1.0
  Author:         Adam Pumphrey
  Creation Date:  January 31, 2022
  Purpose/Change: Initial script for Zen Learning OU creation.
  
.EXAMPLE
  .\New-LearningOUs.ps1
#>

function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

# get domain and suffix:
$subdomain, $domain, $suffix = $env:USERDNSDOMAIN.Split('.')

# set log location, create log file if not exists:
$logFolder = "C:\Windows\DMIT2590_Logs"
$logPath = "C:\Windows\DMIT2590_Logs\New-LearningOUs.log"
try {
    if (!(Test-Path $logPath)) {
        if (!(Test-Path $logFolder)) {
            New-Item -ItemType Directory -Path $logFolder -Force -ErrorAction Stop > $null
        }
        New-Item -ItemType File -Path $logPath -Force -ErrorAction Stop > $null
    }
} catch {
    Write-Error $_
}

# Learning OUs:
$company2OUs = @("Teachers", "Students", "Design")
$OUPath = "DC=$subdomain,DC=$domain,DC=$suffix"

# create OUs
"$(Get-TimeStamp): Starting OU Creation" | Out-File -FilePath $logPath -Append
Write-Host "Creating OUs..."
try{
    foreach ($OU in $company2OUs) {
        New-ADOrganizationalUnit -Name $OU -Path $OUPath -ProtectedFromAccidentalDeletion $False
        "$(Get-TimeStamp): New OU created: $OU at $OUPath" | Out-File -FilePath $logPath -Append
    }
} catch {
    Write-Error $_
    $exception = "$(Get-TimeStamp): Exception caught: $($_)"
    Out-File -FilePath $logPath -Append -InputObject $exception
}
"$(Get-TimeStamp): Script Complete" | Out-File -FilePath $logPath -Append
Write-Host "Script complete"
Read-Host "`nPress enter to exit program"
