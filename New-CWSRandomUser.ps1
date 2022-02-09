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
  Log file stored in C:\Windows\DMIT2590_Logs\New-CWSRandomUser.log
  Log of generated usernames stored in C:\Windows\DMIT2590_Logs\generatedUsernames.csv
  Log of generated cellphone numbers stored in C:\Windows\DMIT2590_Logs\generatedCellphones.csv
  Users are generated into AD and enabled upon generation.
.NOTES
  Version:        1.0
  Author:         Adam Pumphrey
  Creation Date:  January 28, 2022
  Purpose/Change: Initial script for CWS AD user generation.
  
.EXAMPLE
  .\New-CWSRandomUser.ps1
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
        "$(Get-TimeStamp): Starting Edmonton Sales department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            if ($staffCount -eq 1) {
                $title = "Sales Manager"
                $newManager = $True
            } elseif ($staffCount -ge 2 -and $staffCount -le 6) {
                $title = "Senior Sales Associate"
                if ($newManager) {
                    $newManager = $False                    
                }
            } elseif ($staffCount -ge 7 -and $staffCount -le 11) {
                $title = "Intermediate Sales Associate"
            } elseif ($staffCount -ge 12 -and $staffCount -le 14) {
                $title = "Junior Sales Associate"
            } else {
                $title = "Sales Account Manager"
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
    "$(Get-TimeStamp): Edmonton Sales department generation complete" | Out-File -FilePath $logPath -Append
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
        "$(Get-TimeStamp): Starting Edmonton HR department generation" | Out-File -FilePath $logPath -Append
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
    "$(Get-TimeStamp): Edmonton HR department generation complete" | Out-File -FilePath $logPath -Append
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
        "$(Get-TimeStamp): Starting Edmonton Finance department generation" | Out-File -FilePath $logPath -Append
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
    "$(Get-TimeStamp): Edmonton Finance department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-ServerUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Edmonton IT Server Support department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $newUser.Path = "OU=$department,OU=IT,DC=$domain,DC=$suffix"
            if ($staffCount -ge 1 -and $staffCount -le 2) {
                $title = "Senior Server Analyst"
            } else {
                $title = "Intermediate Server Analyst"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
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
    "$(Get-TimeStamp): Edmonton IT Server Support department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-AdministrationUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Edmonton IT Administration department generation" | Out-File -FilePath $logPath -Append
        $ITManagers = @{}
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $newUser.Path = "OU=$department,OU=IT,DC=$domain,DC=$suffix"
            if ($staffCount -eq 1) {
                $title = "IT Manager"
                $newManager = $True
            } elseif ($staffCount -eq 2) {
                $title = "Server Support Manager"
                if ($newManager) {
                    $newManager = $False                    
                }
                $ITManagers["Server"] = $newUser.NewUser.SAMAccountName
            } elseif ($staffCount -eq 3) {
                $title = "Networking Support Manager"
                $ITManagers["Network"] = $newUser.NewUser.SAMAccountName
            } elseif ($staffCount -eq 4) {
                $title = "Application Support Manager"
                $ITManagers["Application"] = $newUser.NewUser.SAMAccountName
            } elseif ($staffCount -eq 5) {
                $title = "Programming Manager"
                $ITManagers["Programming"] = $newUser.NewUser.SAMAccountName
            } else {
                $title = "Tech Support Manager"
                $ITManagers["Tech"] = $newUser.NewUser.SAMAccountName
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
    "$(Get-TimeStamp): Edmonton IT Administration department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
        ITManagers = $ITManagers;
    }
}

function New-NetworkingUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Edmonton IT Networking Support department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $newUser.Path = "OU=$department,OU=IT,DC=$domain,DC=$suffix"
            if ($staffCount -ge 1 -and $staffCount -le 2) {
                $title = "Senior Network Analyst"
            } elseif ($staffCount -ge 3 -and $staffCount -le 4) {
                $title = "Intermediate Network Analyst"
            } else {
                $title = "Junior Network Analyst"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
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
    "$(Get-TimeStamp): Edmonton IT Networking Support department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-ApplicationUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Edmonton IT Application Support department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $newUser.Path = "OU=$department,OU=IT,DC=$domain,DC=$suffix"
            if ($staffCount -eq 1) {
                $title = "Senior Application Analyst"
            } elseif ($staffCount -ge 2 -and $staffCount -le 3) {
                $title = "Intermediate Application Analyst"
            } else {
                $title = "Junior Application Analyst"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
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
    "$(Get-TimeStamp): Edmonton IT Application Support department generation complete" | Out-File -FilePath $logPath -Append
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
        "$(Get-TimeStamp): Starting Edmonton IT Programming department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $newUser.Path = "OU=$department,OU=IT,DC=$domain,DC=$suffix"
            if ($staffCount -ge 1 -and $staffCount -le 2) { # first user for the dept
                $title = "Senior Developer"
            } elseif ($staffCount -eq 3) {
                $title = "Intermediate Developer"
            } else {
                $title = "Junior Developer"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
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
    "$(Get-TimeStamp): Edmonton IT Programming department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-TechUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $manager
    )
    try {
        "$(Get-TimeStamp): Starting Edmonton IT Tech Support department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $newUser.Path = "OU=$department,OU=IT,DC=$domain,DC=$suffix"
            if ($staffCount -ge 1 -and $staffCount -le 2) { # first user for the dept
                $title = "Senior Support Analyst"
            } elseif ($staffCount -ge 3 -and $staffCount -le 4) {
                $title = "Intermediate Support Analyst"
            } else {
                $title = "Junior Developer"
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Manager $manager -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            $staffCount++
            $officePhone++
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
    "$(Get-TimeStamp): Edmonton IT Tech Support department generation complete" | Out-File -FilePath $logPath -Append
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
        "$(Get-TimeStamp): Starting Edmonton Executive department generation" | Out-File -FilePath $logPath -Append
        $directors = @{}
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -GeneratedUsernames $generatedUsernames -GeneratedCellphones $generatedCellphones
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
            } else {
                $title = "Calgary Director"
                $directors["Calgary"] = $newUser.NewUser.SAMAccountName
                $manager = $CIO
                $city = $Calgary
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
    "$(Get-TimeStamp): Edmonton Executive department generation complete" | Out-File -FilePath $logPath -Append
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
$logPath = "C:\Windows\DMIT2590_Logs\New-CWSRandomUser.log"
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

# Edmonton site default properties
$city = "Edmonton"
$country = "CA"
$company = "CWS"
$postalCode = "A1BC2D"
$state = "Alberta"
$streetAddress = "12345 67st"
$homePage = "www.CWS.com" # this could be the sharepoint once it is setup. should be easy to change
$officePhone = 7801231234 # starting value, increments by 1 for each user - each user has their own desk phone with own extension

# begin department generation
"$(Get-TimeStamp): Initiating CWS user generation" | Out-File -FilePath $logPath -Append
Write-Host "Generating CWS users..."

# Edmonton Executive dept - 9 staff - 1 CEO, 1 COO, 1 CFO, 1 CIO, 1 Sales Director, 1 HR Director, 1 Finance Director, 1 IT Director, 1 Calgary Director
$department = "Executive Staff"
$results = New-ExecutiveUser -staffCount 1 -maxStaff 9 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone
$directors = $results.Directors

# Edmonton Sales dept - 20 staff - 1 sales manager, 5 senior sales associates, 5 intermediate sales associates, 3 junior sales associates, 6 sales account managers
$department = "Sales"
$salesDirector = $directors["Sales"]
$results = New-SalesUser -staffCount 1 -maxStaff 20 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $salesDirector
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

# Edmonton HR dept - 8 staff - 1 HR manager, 3 HR specialists, 2 payroll specialists, 2 recruiters
$department = "HR"
$HRDirector = $directors["HR"]
$results = New-HRUser -staffCount 1 -maxStaff 8 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $HRDirector
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

# Edmonton Finance Department - 14 staff - 1 finance manager, 3 senior accountants, 2 intermediate accountants, 1 junior accountant, 3 internal auditors, 1 controller, 3 accounts payable clerks
$department = "Finance"
$financeDirector = $directors["Finance"]
$results = New-FinanceUser -staffCount 1 -maxStaff 14 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $financeDirector
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

for ($i = 0; $i -lt 2; $i++) {
    if (!($i)) {
        # Edmonton IT Department
        "$(Get-TimeStamp): Initiating CWS Edmonton IT user generation" | Out-File -FilePath $logPath -Append
        # Edmonton Administration sub-department - 6 staff - managers for each sub dept and one IT manager
        $department = "Administration"
        $ITDirector = $directors["IT"]
        $results = New-AdministrationUser -staffCount 1 -maxStaff 6 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -manager $ITDirector
        $generatedUsernames = $results.GeneratedUsernames
        $generatedCellphones = $results.GeneratedCellphones
        $officePhone = $results.OfficePhone
        $ITManagers = $results.ITManagers

        # Edmonton Server Support sub-department - 4 staff - 2 senior server analysts, 2 intermediate server support analysts
        $department = "Server Support"
        $serverManager = $ITManagers["Server"]
        $results = New-ServerUser -staffCount 1 -maxStaff 4 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $serverManager
        $generatedUsernames = $results.GeneratedUsernames
        $generatedCellphones = $results.GeneratedCellphones
        $officePhone = $results.OfficePhone

        # Edmonton Networking Support sub-department - 5 staff - 2 senior network analysts, 2 intermediate network support analysts, 1 junior network analyst
        $department = "Networking Support"
        $networkManager = $ITManagers["Network"]
        $results = New-NetworkingUser -staffCount 1 -maxStaff 5 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $networkManager
        $generatedUsernames = $results.GeneratedUsernames
        $generatedCellphones = $results.GeneratedCellphones
        $officePhone = $results.OfficePhone

        # Edmonton Application Support sub-department - 4 staff - 1 senior application analyst, 2 intermediate application analysts, 1 junior application analyst
        $department = "Application Support"
        $applicationManager = $ITManagers["Application"]
        $results = New-ApplicationUser -staffCount 1 -maxStaff 4 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $applicationManager
        $generatedUsernames = $results.GeneratedUsernames
        $generatedCellphones = $results.GeneratedCellphones
        $officePhone = $results.OfficePhone

        # Edmonton Programming sub-department - 4 staff - 2 senior developers, 1 intermediate developer, 1 junior developer
        $department = "Programming"
        $programmingManager = $ITManagers["Programming"]
        $results = New-ProgrammingUser -staffCount 1 -maxStaff 4 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $programmingManager
        $generatedUsernames = $results.GeneratedUsernames
        $generatedCellphones = $results.GeneratedCellphones
        $officePhone = $results.OfficePhone

        # Edmonton Tech Support sub-department - 6 staff - 2 senior support analysts, 2 intermediate support analysts, 2 junior support analysts
        $department = "Tech Support"
        $techManager = $ITManagers["Tech"]
        $results = New-TechUser -staffCount 1 -maxStaff 6 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $techManager
        $generatedUsernames = $results.GeneratedUsernames
        $generatedCellphones = $results.GeneratedCellphones
        $officePhone = $results.OfficePhone
        "$(Get-TimeStamp): CWS Edmonton IT user generation complete" | Out-File -FilePath $logPath -Append
    } else {
        # Calgary IT Department
        $city = "Calgary"
        $streetAddress = "98765 321ave"
        $postalCode = "8T6N2M"
        
        "$(Get-TimeStamp): Initiating CWS Calgary IT user generation" | Out-File -FilePath $logPath -Append
        # Calgary Administration sub-department - 6 staff - managers for each sub dept and one IT manager
        $department = "Administration"
        $ITDirector = $directors["Calgary"]
        $results = New-AdministrationUser -staffCount 1 -maxStaff 6 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -manager $ITDirector
        $generatedUsernames = $results.GeneratedUsernames
        $generatedCellphones = $results.GeneratedCellphones
        $officePhone = $results.OfficePhone
        $ITManagers = $results.ITManagers

        # Calgary Server Support sub-department - 4 staff - 2 senior server analysts, 2 intermediate server support analysts
        $department = "Server Support"
        $serverManager = $ITManagers["Server"]
        $results = New-ServerUser -staffCount 1 -maxStaff 4 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $serverManager
        $generatedUsernames = $results.GeneratedUsernames
        $generatedCellphones = $results.GeneratedCellphones
        $officePhone = $results.OfficePhone

        # Calgary Networking Support sub-department - 5 staff - 2 senior network analysts, 2 intermediate network support analysts, 1 junior network analyst
        $department = "Networking Support"
        $networkManager = $ITManagers["Network"]
        $results = New-NetworkingUser -staffCount 1 -maxStaff 5 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $networkManager
        $generatedUsernames = $results.GeneratedUsernames
        $generatedCellphones = $results.GeneratedCellphones
        $officePhone = $results.OfficePhone

        # Calgary Application Support sub-department - 4 staff - 1 senior application analyst, 2 intermediate application analysts, 1 junior application analyst
        $department = "Application Support"
        $applicationManager = $ITManagers["Application"]
        $results = New-ApplicationUser -staffCount 1 -maxStaff 4 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $applicationManager
        $generatedUsernames = $results.GeneratedUsernames
        $generatedCellphones = $results.GeneratedCellphones
        $officePhone = $results.OfficePhone

        # Calgary Programming sub-department - 4 staff - 2 senior developers, 1 intermediate developer, 1 junior developer
        $department = "Programming"
        $programmingManager = $ITManagers["Programming"]
        $results = New-ProgrammingUser -staffCount 1 -maxStaff 4 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $programmingManager
        $generatedUsernames = $results.GeneratedUsernames
        $generatedCellphones = $results.GeneratedCellphones
        $officePhone = $results.OfficePhone

        # Calgary Tech Support sub-department - 6 staff - 2 senior support analysts, 2 intermediate support analysts, 2 junior support analysts
        $department = "Tech Support"
        $techManager = $ITManagers["Tech"]
        $results = New-TechUser -staffCount 1 -maxStaff 6 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -Manager $techManager
        $generatedUsernames = $results.GeneratedUsernames
        $generatedCellphones = $results.GeneratedCellphones
        $officePhone = $results.OfficePhone
        "$(Get-TimeStamp): CWS Calgary IT user generation complete" | Out-File -FilePath $logPath -Append
    }
}

"$(Get-TimeStamp): CWS user generation complete" | Out-File -FilePath $logPath -Append

# end of script - generated unique values saved to file in case script needs to run again
"$(Get-TimeStamp): Logging generated usernames at $($usernameLogPath)" | Out-File -FilePath $logPath -Append
New-UsernameLog -UsernameLogPath $usernameLogPath -GeneratedUsernames $generatedUsernames
"$(Get-TimeStamp): Logging generated cellphone numbers at $($cellphoneLogPath)" | Out-File -FilePath $logPath -Append
New-CellphoneLog -CellphoneLogPath $cellphoneLogPath -GeneratedCellphones $generatedCellphones
"$(Get-TimeStamp): Script complete" | Out-File -FilePath $logPath -Append
Write-Host "Script complete"
Read-Host "`nPress enter to exit program"
