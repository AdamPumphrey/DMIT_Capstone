<#
Template from https://gist.github.com/9to5IT/9620683
.SYNOPSIS
  Randomly generates users for the domain based on the OU structure.
.DESCRIPTION
  The script randomly generates AD users, using a list of random masculine and feminine first names and last names to generate random names. User details for the following attributes are generated:
  GivenName, FirstName, Surname, Name, DisplayName, samAccountName, AccountPassword (using a default password), OfficePhone, MobilePhone (randomly generated), UserPrincipalName, EmailAddress,
  Path, Title, City, Company, PostalCode, StreetAddress, State, HomePage, Department, Office, Manager (some users are generated as managers, others assigned under managers), Country, Description

.INPUTS
  None
.OUTPUTS
  Log file stored in C:\Windows\DMIT2590_Logs\New-ZenRandomUser.log
  Log of generated usernames stored in C:\Windows\DMIT2590_Logs\generatedUsernames.csv
  Log of generated cellphone numbers stored in C:\Windows\DMIT2590_Logs\generatedCellphones.csv
  Users are generated into AD and enabled upon generation.
.NOTES
  Version:        1.0
  Author:         Adam Pumphrey
  Creation Date:  January 30, 2022
  Purpose/Change: Initial script for Zen AD user generation.
  
.EXAMPLE
  .\New-ZenRandomUser.ps1
#>

function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

function New-UsernameLog {
    param (
        $UsernameLogPath,
        $GeneratedUsernames
    )
    Clear-Content $usernameLogPath
    "Username" | Out-File -Append $usernameLogPath
    $GeneratedUsernames.Username | Out-File -Append $usernameLogPath
}

function New-CellphoneLog {
    param (
        $CellphoneLogPath,
        $GeneratedCellphones
    )
    Clear-Content $cellphoneLogPath
    "Cellphone" | Out-File -Append $cellphoneLogPath
    $GeneratedCellphones.Cellphone | Out-File -Append $cellphoneLogPath
}

function Get-LastName {
    $lastName = $l_names[(Get-Random -Minimum 0 -Maximum 150)]
    return $lastName
}

function Get-FemaleFirstName {
    $firstName = $f_names[(Get-Random -Minimum 0 -Maximum 75)]
    return $firstName
}

function Get-MaleFirstName {
    $firstName = $m_names[(Get-Random -Minimum 0 -Maximum 75)]
    return $firstName
}

function New-RandomUser {
    $femaleOrMaleName = Get-Random -Minimum 0 -Maximum 2
    if ($femaleOrMaleName) { # if femaleOrMaleName = 1, choose female name
        $firstName = Get-FemaleFirstName
        $lastName = Get-LastName
    } else { # if femaleOrMaleName = 0, choose male name
        $firstName = Get-MaleFirstName
        $lastName = Get-LastName
    }
    $username = "$($firstname[0])$lastname"
    $checked = $False
    $usernameCount = 1
    while (!($checked)) {
        if ($username -in $generatedUsernames.Username) {
            if ($username.Substring($username.Length-1,1) -match "^\d+$") {
                $username = $username.Substring(0,$username.Length-1) + "$usernameCount"
            } else {
                $username += "$usernameCount"
            }
            $usernameCount++
        } elseif ("$firstName $lastName" -in (Get-ADUser -Filter * | Select-Object name).name) { # returns array of hash tables in name="Full Name" format
            $newUser = New-RandomUser
            return $newUser
        } else {
            $checked = $True
            $username = $username.ToLower()
        }
    }
    $userPrincipalName = "$username@$env:USERDNSDOMAIN"
    return @{
        FirstName = $firstName;
        LastName = $lastName;
        FullName = "$firstName $lastName";
        SAMAccountName = $username;
        UserPrincipalName = $userPrincipalName;
    }
}

function New-Cellphone {
    param (
        [String[]]$GeneratedCellPhones
    )
    $checked = $False
    while (!($checked)) {
        $mobilePhone = "780$(Get-Random -Minimum 1111111 -Maximum 10000000)"
        if (!($mobilePhone -in $GeneratedCellPhones.Cellphone)) {
            $checked = $True
        }        
    }
    return $mobilePhone
}

function New-UserSetup {
    param (
        $generatedUsernames,
        $generatedCellphones
    )
    $newUser = New-RandomUser
    "$(Get-TimeStamp): New name generated. Full Name: $($newUser.FullName) Username: $($newUser.SAMAccountName)" | Out-File -FilePath $logPath -Append
    $generatedUsernames[-1].Username += $newUser.SAMAccountName
    $emailAddress = $newUser.UserPrincipalName
    $displayName = $newUser.FullName
    $mobilePhone = New-Cellphone -GeneratedCellphones $generatedCellphones
    $generatedCellphones[-1].Cellphone += $mobilePhone
    $path = "OU=$department,DC=$domain,DC=$suffix"
    return @{
        NewUser = $newUser;
        GeneratedUsernames = $generatedUsernames;
        EmailAddress = $emailAddress;
        DisplayName = $displayName;
        MobilePhone = $mobilePhone;
        GeneratedCellphones = $generatedCellphones;
        Path = $path
    }
}

function New-SalesUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        # 1, 16, 31, 46, 61 are sales team managers
        [int[]]$managerCounts = 1,16,31,46,61,76
        # 76 is sales accounts team manager
        $seniorManager = $manager
        $managerSet = [System.Collections.Generic.HashSet[int]]::new($managerCounts)
        "$(Get-TimeStamp): Starting Grande Prairie Sales department generation" | Out-File -FilePath $logPath -Append
        $teamCount = 1
        while ($staffCount -le $maxStaff) {
            $checked = $True
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            if ($managerSet.Contains($staffCount)) {
                switch ($teamCount) {
                    1 { $team = "West "; $path = "OU=$westTeam,OU=$department,DC=$domain,DC=$suffix"}
                    2 { $team = "East "; $path = "OU=$eastTeam,OU=$department,DC=$domain,DC=$suffix" }
                    3 { $team = "North "; $path = "OU=$northTeam,OU=$department,DC=$domain,DC=$suffix" }
                    4 { $team = "South "; $path = "OU=$southTeam,OU=$department,DC=$domain,DC=$suffix" }
                    5 { $team = "International "; $path = "OU=$internationalTeam,OU=$department,DC=$domain,DC=$suffix" }
                    6 { $path = "OU=$accountsTeam,OU=$department,DC=$domain,DC=$suffix"}
                    Default {$team = ""; $checked = $False}
                }
                if ($staffCount -eq 76) {
                    $title = "Sales Accounts Team Manager"
                } else {
                    $title = "$($team)Sales Team Manager"
                    $teamStaff = 1
                }
                $manager = $seniorManager
                $newManager = $True
                $teamCount++
            } elseif ($teamStaff -ge 2 -and $teamStaff -le 7) {
                $title = "Senior Sales Associate"
                if ($newManager) {
                    $newManager = $False                    
                }
            } elseif ($teamStaff -ge 8 -and $teamStaff -le 12) {
                $title = "Intermediate Sales Associate"
            } elseif ($teamStaff -ge 13 -and $teamStaff -le 15) {
                $title = "Junior Sales Associate"
                if ($staffCount -ge 75) {
                    $teamstaff = 9999999
                }
            } else {
                $title = "Sales Account Manager"
                if ($newManager) {
                    $newManager = $False                    
                }
            }
            if ($checked) {
                New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            } else {
                New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            }
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
            $teamStaff++
            if ($newManager) {
                $manager = $newUser.NewUser.SAMAccountName
            }
        }
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Error "`nError: User account already exists`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "`nError: User account already exists in another OU`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch {
        Write-Error $_
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    }
    "$(Get-TimeStamp): Grande Prairie Sales department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-HRUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Grande Prairie HR department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            if ($staffCount -eq 1) {
                $title = "HR Manager"
                $newManager = $True
            } elseif ($staffCount -ge 2 -and $staffCount -le 4) {
                $title = "HR Specialist"
                if ($newManager) {
                    $newManager = $False                    
                }
            } elseif ($staffCount -ge 5 -and $staffCount -le 6) {
                $title = "Payroll Specialist"
            } else {
                $title = "Recruiter"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
            if ($newManager) {
                $manager = $newUser.NewUser.SAMAccountName
            }
        }
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Error "`nError: User account already exists`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "`nError: User account already exists in another OU`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch {
        Write-Error $_
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    }
    "$(Get-TimeStamp): Grande Prairie HR department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-FinanceUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Grande Prairie Finance department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            if ($staffCount -eq 1) {
                $title = "Finance Manager"
                $newManager = $True
            } elseif ($staffCount -ge 2 -and $staffCount -le 4) {
                $title = "Senior Accountant"
                if ($newManager) {
                    $newManager = $False                    
                }
            } elseif ($staffCount -ge 5 -and $staffCount -le 6) {
                $title = "Intermediate Accountant"
            } elseif ($staffCount -eq 7) {
                $title = "Junior Accountant"
            } elseif ($staffCount -ge 8 -and $staffCount -le 10) {
                $title = "Internal Auditor"
            } elseif ($staffCount -eq 11) {
                $title = "Controller"
            } else {
                $title = "Accounts Payable Clerk"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
            if ($newManager) {
                $manager = $newUser.NewUser.SAMAccountName
            }
        }
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Error "`nError: User account already exists`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "`nError: User account already exists in another OU`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch {
        Write-Error $_
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    }
    "$(Get-TimeStamp): Grande Prairie Finance department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-ContentExpertUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Grande Prairie Design Content Experts department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $newUser.Path = "OU=$department,OU=Design,DC=$domain,DC=$suffix"
            if ($staffCount -eq 1) {
                $title = "Content Manager"
                $newManager = $True
            } elseif ($staffCount -ge 2 -and $staffCount -le 3) {
                $title = "Senior Content Designer"
                if ($newManager) {
                    $newManager = $False                    
                }
            } elseif ($staffCount -eq 4) {
                $title = "Intermediate Content Designer"
            } else {
                $title = "Junior Content Designer"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
            if ($newManager) {
                $manager = $newUser.NewUser.SAMAccountName
            }
        }
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Error "`nError: User account already exists`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "`nError: User account already exists in another OU`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch {
        Write-Error $_
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    }
    "$(Get-TimeStamp): Grande Prairie Design Content Experts department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-ITUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Grande Prairie IT department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            if ($staffCount -eq 1) {
                $title = "IT Manager"
                $newManager = $True
            } elseif ($staffCount -ge 2 -and $staffCount -le 3) {
                $title = "Senior Support Analyst"
                if ($newManager) {
                    $newManager = $False                    
                }
            } else {
                $title = "Intermediate Support Analyst"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
            if ($newManager) {
                $manager = $newUser.NewUser.SAMAccountName
            }
        }
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Error "`nError: User account already exists`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "`nError: User account already exists in another OU`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch {
        Write-Error $_
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    }
    "$(Get-TimeStamp): Grande Prairie IT Administration department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-UIExpertUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Grande Prairie Design UI Experts department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $newUser.Path = "OU=$department,OU=Design,DC=$domain,DC=$suffix"
            if ($staffCount -eq 1) {
                $title = "UI Manager"
                $newManager = $True
            } elseif ($staffCount -ge 2 -and $staffCount -le 3) {
                $title = "Senior Graphic Designer"
                if ($newManager) {
                    $newManager = $False                    
                }
            } elseif ($staffCount -eq 4) {
                $title = "Intermediate Graphic Designer"
            } else {
                $title = "Junior Graphic Designer"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
            if ($newManager) {
                $manager = $newUser.NewUser.SAMAccountName
            }
        }
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Error "`nError: User account already exists`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "`nError: User account already exists in another OU`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch {
        Write-Error $_
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    }
    "$(Get-TimeStamp): Grande Prairie Design UI Experts department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-DBEngineerUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Grande Prairie Design DB Engineers department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $newUser.Path = "OU=$department,OU=Design,DC=$domain,DC=$suffix"
            if ($staffCount -eq 1) {
                $title = "DB Manager"
                $newManager = $True
            } elseif ($staffCount -ge 2 -and $staffCount -le 3) {
                $title = "Senior Engineer"
                if ($newManager) {
                    $newManager = $False                    
                }
            } elseif ($staffCount -eq 4) {
                $title = "Intermediate Engineer"
            } else {
                $title = "Junior Engineer"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
            if ($newManager) {
                $manager = $newUser.NewUser.SAMAccountName
            }
        }
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Error "`nError: User account already exists`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "`nError: User account already exists in another OU`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch {
        Write-Error $_
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    }
    "$(Get-TimeStamp): Grande Prairie Design DB Engineers department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-ProgrammingUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Grande Prairie Design Programmers department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $newUser.Path = "OU=$department,OU=Design,DC=$domain,DC=$suffix"
            if ($staffCount -eq 1) {
                $title = "Programming Manager"
                $newManager = $True
            } elseif ($staffCount -ge 2 -and $staffCount -le 3) {
                $title = "Senior Developer"
                if ($newManager) {
                    $newManager = $False                    
                }
            } elseif ($staffCount -eq 4) {
                $title = "Intermediate Developer"
            } else {
                $title = "Junior Developer"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
            if ($newManager) {
                $manager = $newUser.NewUser.SAMAccountName
            }
        }
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Error "`nError: User account already exists`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "`nError: User account already exists in another OU`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch {
        Write-Error $_
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    }
    "$(Get-TimeStamp): Grande Prairie Design Programmers department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-AnimatorUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Grande Prairie Design Animators department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $newUser.Path = "OU=$department,OU=Design,DC=$domain,DC=$suffix"
            if ($staffCount -eq 1) {
                $title = "Animation Manager"
                $newManager = $True
            } elseif ($staffCount -ge 2 -and $staffCount -le 3) {
                $title = "Senior Animator"
                if ($newManager) {
                    $newManager = $False                    
                }
            } elseif ($staffCount -eq 4) {
                $title = "Intermediate Animator"
            } else {
                $title = "Junior Animator"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
            if ($newManager) {
                $manager = $newUser.NewUser.SAMAccountName
            }
        }
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Error "`nError: User account already exists`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "`nError: User account already exists in another OU`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch {
        Write-Error $_
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    }
    "$(Get-TimeStamp): Grande Prairie Design Animators department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-ExecutiveUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone
    )
    try {
        "$(Get-TimeStamp): Starting Grande Prairie Executive department generation" | Out-File -FilePath $logPath -Append
        $directors = @{}
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            if ($staffCount -eq 1) {
                $title = "President/CEO"
                $newManager = $True
                $CEO = $newUser.NewUser.SAMAccountName
            } elseif ($staffCount -eq 2) {
                $title = "COO"
                if ($newManager) {
                    $newManager = $False                    
                }
                $COO = $newUser.NewUser.SAMAccountName
                $manager = $CEO
            } elseif ($staffCount -eq 3) {
                $title = "CFO"
                $CFO = $newUser.NewUser.SAMAccountName
                $manager = $CEO
            } elseif ($staffCount -eq 4) {
                $title = "CIO"
                $CIO = $newUser.NewUser.SAMAccountName
                $manager = $CEO
            } elseif ($staffCount -eq 5) {
                $title = "Sales Director"
                $directors["Sales"] = $newUser.NewUser.SAMAccountName
                $manager = $COO
            } elseif ($staffCount -eq 6) {
                $title = "HR Director"
                $directors["HR"] = $newUser.NewUser.SAMAccountName
                $manager = $COO
            } elseif ($staffCount -eq 7) {
                $title = "Finance Director"
                $directors["Finance"] = $newUser.NewUser.SAMAccountName
                $manager = $CFO
            } elseif ($staffCount -eq 8) {
                $title = "IT Director"
                $directors["IT"] = $newUser.NewUser.SAMAccountName
                $manager = $CIO
            } elseif ($staffCount -eq 9) {
                $title = "Design Director"
                $directors["Design"] = $newUser.NewUser.SAMAccountName
                $manager = $CIO
            } else {
                $title = "Spokane Director"
                $directors["Spokane"] = $newUser.NewUser.SAMAccountName
                $manager = $COO
                $city = $Spokane
            }
            if ($newManager) {
                New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            } else {
                New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop

            }
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
            if ($newManager) {
                $manager = $newUser.NewUser.SAMAccountName
            }
        }
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Error "`nError: User account already exists`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch [Microsoft.ActiveDirectory.Management.ADException] {
        Write-Error "`nError: User account already exists in another OU`n" -Category InvalidOperation
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    } catch {
        Write-Error $_
        $exception = "$(Get-TimeStamp): Exception caught: $($_)"
        Out-File -FilePath $logPath -Append -InputObject $exception
    }
    "$(Get-TimeStamp): Grande Prairie Executive department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
        Directors = $directors;
    }
}

# script start

# set log location, create log file if not exists:
$logFolder = "C:\Windows\DMIT2590_Logs"
$logPath = "C:\Windows\DMIT2590_Logs\New-ZenRandomUser.log"
$usernameLogPath = "C:\Windows\DMIT2590_Logs\generatedUsernames.csv"
$cellphoneLogPath = "C:\Windows\DMIT2590_Logs\generatedCellphones.csv"
try {
    if (!(Test-Path $logPath)) {
        if (!(Test-Path $logFolder)) {
            New-Item -ItemType Directory -Path $logFolder -Force -ErrorAction Stop > $null
        }
        New-Item -ItemType File -Path $logPath -Force -ErrorAction Stop > $null
    }
    if (!(Test-Path $usernameLogPath)) {
        New-Item -ItemType File -Path $usernameLogPath -Force -ErrorAction Stop > $null
        "Username" | Out-File -Append $usernameLogPath
        $generatedUsernames = @()
        $generatedUsernames += @{"Username" = @()} # keep track of usernames for duplicate checking
    } else {
        $generatedUsernames = Import-Csv -Path $usernameLogPath
        $generatedUsernames += @{"Username" = @()}
    }
    if (!(Test-Path $cellphoneLogPath)) {
        New-Item -ItemType File -Path $cellphoneLogPath -Force -ErrorAction Stop > $null
        "Cellphone" | Out-File -Append $cellphoneLogPath
        $generatedCellphones = @()
        $generatedCellphones += @{"Cellphone" = @()} # keep track of cellphone #'s in case of duplicates
    } else {
        $generatedCellphones = Import-Csv -Path $cellphoneLogPath
        $generatedCellphones += @{"Cellphone" = @()}
    }
} catch {
    Write-Error $_
}

$f_names = @("Bethany","Eva","Shyann","Monica","Clarissa","Adyson","Carissa","Kendall","Haleigh","McKenna","Leyla","Aniyah","Anna","Erin","Lilliana","Mercedes","Amelia","Naomi","Arielle","Adelaide","Sarahi","Brittany","Zariah","Genesis","Hope","Delaney","Jakayla","Denise","Kaila","Emmy","Abril","Willow","Helen","Keyla","Ayana","Azaria","Jaycee","Lesly","Maria","Yasmine","Phoebe","Ellen","Alisa","Reyna","Brenna","Siena","Reagan","Haylee","Kristen","Elise","Lorelai","Mylee","Isabella","Lizbeth","Kimberly","Nia","Melany","Marilyn","Dayami","Jamya","Kaliyah","Paisley","Ali","Caroline","Angelique","Laurel","Noelle","Raven","Kiana","Salma","Evie","Damaris","Isabel","Elena","Kiersten")
$m_names = @("Salvatore","Kadin","Hugh","Arjun","Aden","Leo","Zaiden","Rory","Fisher","Tanner","Gideon","Erik","Brendon","Tyler","Zachery","Avery","Wilson","Asa","Cohen","Sergio","Max","Cory","Leandro","Jayvon","Marvin","Giancarlo","Trevon","Devin","Robert","Alfred","Seth","Ulises","Dario","Dexter","Karson","Nigel","Keenan","Marcos","Jaylin","Braydon","Mohamed","Eliezer","Aaron","Lamar","Randall","Makai","Ayaan","Franco","Keegan","Jamarcus","Rhys","Douglas","Frank","Skylar","Abel","Sheldon","Nikhil","Ellis","Jeremy","Giovanni","Carson","Hunter","Brody","Landyn","Ronald","Makhi","Clark","Carl","Brandon","Hayden","Davon","Guillermo","Aldo","Efrain","Hudson")
$l_names = @("Hobbs","McDowell","Bruce","Christian","Farley","Phelps","Compton","Ford","Terrell","Dalton","Mayo","Hawkins","Herman","Barker","Holder","Blackwell","Cunningham","Hurst","Frye","Mendez","Pineda","Cordova","Hoffman","Randolph","Crawford","English","Fuller","Tyler","Gould","Whitaker","Chandler","Cooley","Thompson","Berg","Abbott","Hubbard","Arroyo","Russell","Stanton","Simon","Johnston","Figueroa","Roberson","Carson","Estrada","Tanner","Ibarra","Randall","Savage","Wang","Mullen","Molina","Booth","Richards","Carpenter","Dillon","Ponce","Beck","Miller","Haynes","Mitchell","Suarez","Crane","Turner","Morris","Stevens","Walsh","Gray","O'Neill","Cantrell","Buckley","Leblanc","Foster","Hurley","Evans","Ware","Petty","Briggs","Adams","Davis","Sampson","Manning","Munoz","Acosta","Owen","Hunter","Friedman","Erickson","Roy","Arias","Pham","Stout","Richmond","Glover","Aguilar","Andrade","Saunders","Mann","Hickman","Travis","Mendoza","Barton","Ortega","Nixon","Scott","Orozco","Webb","Jacobson","Ferrell","Carroll","Bush","Lee","McCormick","Mooney","Cooke","Torres","Short","Riddle","Diaz","Nguyen","Levy","Black","Webster","Gibson","Knight","Rivera","Rich","Massey","Deleon","Nielsen","Potts","Chan","Cohen","Bolton","Reese","Garner","Pena","Booker","Rasmussen","Noble","Acevedo","Joyce","Simmons","Sutton","Mathews","Armstrong","Hernandez","Cooper","O'Connor","Barber")

# global default properties
$password = "Password1" | ConvertTo-SecureString -AsPlainText -Force

# Company default properties
$domain, $suffix = $env:USERDNSDOMAIN.Split('.')

# Grande Prairie site default properties
$city = "Grande Prairie"
$country = "CA"
$company = "Zen"
$postalCode = "B1AD2C"
$state = "Alberta"
$streetAddress = "54321 76st"
$homePage = "www.Zen.com" # this could be the sharepoint once it is setup. should be easy to change
$officePhone = 7803211234 # starting value, increments by 1 for each user - each user has their own desk phone with own extension

# begin department generation
"$(Get-TimeStamp): Initiating Zen user generation" | Out-File -FilePath $logPath -Append

# Grande Prairie Executive dept - 10 staff - 1 CEO, 1 COO, 1 CFO, 1 CIO, 1 Sales Director, 1 Design Director, 1 HR Director, 1 Finance Director, 1 IT Director, 1 Spokane Director
$department = "Executive Staff"
$results = New-ExecutiveUser -staffCount 1 -maxStaff 10 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone
$directors = $results.Directors

# GP Sales dept - 87 staff - 5 Sales teams - 1 sales team manager, 6 senior sales associates, 5 intermediate sales associates, 3 junior sales associates - 1 accounts team manager, 11 sales account managers
# 1, 16, 31, 46, 61 are sales team managers
# 76 is sales accounts team manager
$northTeam = "North Sales Team"
$westTeam = "West Sales Team"
$eastTeam = "East Sales Team"
$southTeam = "South Sales Team"
$internationalTeam = "International Sales Team"
$accountsTeam = "Sales Accounts Team"
$department = "Sales"
$salesDirector = $directors["Sales"]
$results = New-SalesUser -staffCount 1 -maxStaff 87 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $salesDirector
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

# Grande Prairie HR dept - 8 staff - 1 HR manager, 3 HR specialists, 2 payroll specialists, 2 recruiters
$department = "HR"
$HRDirector = $directors["HR"]
$results = New-HRUser -staffCount 1 -maxStaff 8 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $HRDirector
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

# Grande Prairie Finance Department - 14 staff - 1 finance manager, 3 senior accountants, 2 intermediate accountants, 1 junior accountant, 3 internal auditors, 1 controller, 3 accounts payable clerks
$department = "Finance"
$financeDirector = $directors["Finance"]
$results = New-FinanceUser -staffCount 1 -maxStaff 14 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $financeDirector
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

# Grande Prairie IT Department - 5 staff - 1 IT manager, 2 senior support analysts, 2 intermediate support analysts
$department = "IT"
$ITDirector = $directors["IT"]
$results = New-ITUser -staffCount 1 -maxStaff 5 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $ITDirector
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

# Grande Prairie Design Department
"$(Get-TimeStamp): Initiating Zen Grande Prairie Design user generation" | Out-File -FilePath $logPath -Append
# Grande Prairie Programmers sub-department - 5 staff - 1 programming manager, 2 senior developers, 1 intermediate developer, 1 junior developer
$department = "Programmers"
$designDirector = $directors["Design"]
$results = New-ProgrammingUser -staffCount 1 -maxStaff 5 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $designDirector
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

# Grande Prairie DB Engineers sub-department - 5 staff - 1 DB manager, 2 senior engineers, 1 intermediate engineer, 1 junior engineer
$department = "DB Engineers"
$designDirector = $directors["Design"]
$results = New-DBEngineerUser -staffCount 1 -maxStaff 5 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $designDirector
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

# Grande Prairie UI Experts sub-department - 5 staff - 1 UI manager, 2 senior graphic designers, 1 intermediate graphic designer, 1 junior graphic designer
$department = "UI Experts"
$designDirector = $directors["Design"]
$results = New-UIExpertUser -staffCount 1 -maxStaff 5 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $designDirector
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

# Grande Prairie Content Experts sub-department - 5 staff - 1 content manager, 2 senior content designers, 1 intermediate content designer, 1 junior content designer
$department = "Content Experts"
$designDirector = $directors["Design"]
$results = New-ContentExpertUser -staffCount 1 -maxStaff 5 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $designDirector
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

# Grande Prairie Animators sub-department - 5 staff - 1 animation manager, 2 senior animators, 1 intermediate animator, 1 junior animator
$department = "Animators"
$designDirector = $directors["Design"]
$results = New-AnimatorUser -staffCount 1 -maxStaff 5 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $designDirector
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone
"$(Get-TimeStamp): Zen Grande Prairie Design user generation complete" | Out-File -FilePath $logPath -Append

"$(Get-TimeStamp): Zen user generation complete" | Out-File -FilePath $logPath -Append

# end of script - generated unique values saved to file in case script needs to run again
"$(Get-TimeStamp): Logging generated usernames at $($usernameLogPath)" | Out-File -FilePath $logPath -Append
New-UsernameLog -UsernameLogPath $usernameLogPath -GeneratedUsernames $generatedUsernames
"$(Get-TimeStamp): Logging generated cellphone numbers at $($cellphoneLogPath)" | Out-File -FilePath $logPath -Append
New-CellphoneLog -CellphoneLogPath $cellphoneLogPath -GeneratedCellphones $generatedCellphones
"$(Get-TimeStamp): Script complete" | Out-File -FilePath $logPath -Append
Write-Host "Script complete"
Read-Host "`nPress enter to exit program"
