<#
Template from https://gist.github.com/9to5IT/9620683
.SYNOPSIS
  Creates OUs for the domain.
.DESCRIPTION
  The script gets the environment's domain and domain suffix, and then creates the declared OUs and sub OUs.
.INPUTS
  None
.OUTPUTS
  Log file stored in C:\Windows\DMIT2590_Logs\New-CWSOUs.log
.NOTES
  Version:        1.0
  Author:         Adam Pumphrey
  Creation Date:  January 27, 2022
  Purpose/Change: Initial script for CWS OU creation.
  
.EXAMPLE
  .\New-CWSOUs.ps1
#>

function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

# get domain and suffix:
$domain, $suffix = $env:USERDNSDOMAIN.Split('.')

# set log location, create log file if not exists:
$logFolder = "C:\Windows\DMIT2590_Logs"
$logPath = "C:\Windows\DMIT2590_Logs\New-CWSOUs.log"
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

# Company1 OUs:
$company1OUs = @("Sales", "HR", "Finance", "IT", "Executive Staff")
$OUPath = "DC=$domain,DC=$suffix"

# IT sub-OU FQDN portion:
$ITOU = "IT"
$ITOUPath = "OU=$ITOU,DC=$domain,DC=$suffix"

# Company1 IT sub OUs:
$company1SubOUs = @("Server Support", "Networking Support", "Application Support", "Programming", "Administration", "Tech Support")

# create OUs
"$(Get-TimeStamp): Starting OU Creation" | Out-File -FilePath $logPath -Append
Write-Host "Creating OUs..."
try{
    foreach ($OU in $company1OUs) {
        New-ADOrganizationalUnit -Name $OU -Path $OUPath -ProtectedFromAccidentalDeletion $False
        "$(Get-TimeStamp): New OU created: $OU at $OUPath" | Out-File -FilePath $logPath -Append
        if ($OU -eq $ITOU) {
            foreach ($subOU in $company1SubOUs) {
                New-ADOrganizationalUnit -Name $subOU -Path $ITOUPath -ProtectedFromAccidentalDeletion $False
                "$(Get-TimeStamp): New Sub-OU created: $subOU at $ITOUPath" | Out-File -FilePath $logPath -Append
            }
        }
    }
} catch {
    Write-Error $_
    $exception = "$(Get-TimeStamp): Exception caught: $($_)"
    Out-File -FilePath $logPath -Append -InputObject $exception
}
"$(Get-TimeStamp): Script Complete" | Out-File -FilePath $logPath -Append
Write-Host "Script complete"
Read-Host "`nPress enter to exit program"
