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
  Log file stored in C:\Windows\DMIT2590_Logs\New-LearningRandomUser.log
  Log of generated usernames stored in C:\Windows\DMIT2590_Logs\generatedUsernames.csv
  Log of generated cellphone numbers stored in C:\Windows\DMIT2590_Logs\generatedCellphones.csv
  Users are generated into AD and enabled upon generation.
.NOTES
  Version:        1.0
  Author:         Adam Pumphrey
  Creation Date:  January 30, 2022
  Purpose/Change: Initial script for Zen Learning AD user generation.
  
.EXAMPLE
  .\New-LearningRandomUser.ps1
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
    $path = "OU=$department,DC=$subdomain,DC=$domain,DC=$suffix"
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

function New-StudentUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone,
        $managers
    )
    try {
        "$(Get-TimeStamp): Starting Spokane Student department generation" | Out-File -FilePath $logPath -Append
        $classCount = $maxStaff - 15
        $teacherCount = 0
        $title = "Student"
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $newUser.Path = "OU=$department,DC=$subdomain,DC=$domain,DC=$suffix"
            $manager = $managers[$teacherCount]
            if ($classCount -ge 15 -and ($staffCount % 15 -eq 0)) { # 15 students per class unless less than 15 students are leftover
                # eg) if 17 students, assign 15 students to teacher. Remainder is 2 (less than 15), so assign remaining 2 students to same teacher
                $classCount -= 15
                $teacherCount++
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
    "$(Get-TimeStamp): Spokane Student department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

function New-TeacherUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone
    )
    try {
        "$(Get-TimeStamp): Starting Spokane Teaching department generation" | Out-File -FilePath $logPath -Append
        $teachers = @()
        $title = "Teacher"
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            $teachers += ($newUser.NewUser.SAMAccountName)
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
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
    "$(Get-TimeStamp): Spokane Teaching department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
        Teachers = $teachers;
    }
}

function New-DesignAdminUser {
    param (
        $staffCount,
        $maxStaff,
        $generatedCellphones,
        $generatedUsernames,
        $officePhone
    )
    try {
        "$(Get-TimeStamp): Starting Spokane Learning Design department generation" | Out-File -FilePath $logPath -Append
        while ($staffCount -le $maxStaff) {
            $newUser = New-UserSetup -generatedUsernames $generatedUsernames -generatedCellphones $generatedCellphones
            $generatedUsernames = $newUser.GeneratedUsernames
            $generatedCellphones = $newUser.GeneratedCellphones
            switch ($staffCount) {
                1 { $title = "Programming Admin" }
                2 { $title = "DB Engineering Admin" }
                3 { $title = "UI Admin" }
                4 { $title = "Content Admin" }
                Default { $title = "Animation Admin"}
            }
            New-ADUser -GivenName $newUser.NewUser.FirstName -Surname $newUser.NewUser.LastName -Name $newUser.NewUser.FullName -DisplayName $newUser.displayName -SamAccountName $newUser.NewUser.SAMAccountName -AccountPassword $password -OfficePhone $officePhone -MobilePhone $newUser.mobilePhone -UserPrincipalName $newUser.NewUser.UserPrincipalName -EmailAddress $newUser.emailAddress -Path $newUser.path -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True -ErrorAction Stop
            "$(Get-TimeStamp): New user created: -GivenName $($newUser.NewUser.FirstName) -Surname $($newUser.NewUser.LastName) -Name $($newUser.NewUser.FullName) -DisplayName $($newUser.displayName) -SamAccountName $($newUser.NewUser.SAMAccountName) -OfficePhone $officePhone -MobilePhone $($newUser.mobilePhone) -UserPrincipalName $($newUser.NewUser.UserPrincipalName) -EmailAddress $($newUser.emailAddress) -Path $($newUser.path) -Title $title -City $city -Company $company -PostalCode $postalCode -StreetAddress $streetAddress -State $state -HomePage $homePage -Department $department -Office $department -Country $country -Description $title -ChangePasswordAtLogon $True -Enabled $True" | Out-File -FilePath $logPath -Append
            Add-ADGroupMember -Identity "Domain Admins" -Members $newUser.NewUser.SAMAccountName
            "$(Get-TimeStamp): User $($newUser.NewUser.SAMAccountName) added to Domain Admins group."
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
    "$(Get-TimeStamp): Spokane Learning Design department generation complete" | Out-File -FilePath $logPath -Append
    return @{
        GeneratedUsernames = $generatedUsernames;
        GeneratedCellphones = $generatedCellphones;
        OfficePhone = $officePhone;
    }
}

# script start

# set log location, create log file if not exists:
$logFolder = "C:\Windows\DMIT2590_Logs"
$logPath = "C:\Windows\DMIT2590_Logs\New-LearningRandomUser.log"
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
        if (!($generatedUsernames)) {
            $generatedUsernames = @()
        }
        $generatedUsernames += @{"Username" = @()}
    }
    if (!(Test-Path $cellphoneLogPath)) {
        New-Item -ItemType File -Path $cellphoneLogPath -Force -ErrorAction Stop > $null
        "Cellphone" | Out-File -Append $cellphoneLogPath
        $generatedCellphones = @()
        $generatedCellphones += @{"Cellphone" = @()} # keep track of cellphone #'s in case of duplicates
    } else {
        $generatedCellphones = Import-Csv -Path $cellphoneLogPath
        if (!($generatedCellphones)) {
            $generatedCellphones = @()
        }
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

# domain default properties
$subdomain, $domain, $suffix = $env:USERDNSDOMAIN.Split('.')

# Grande Prairie site default properties
$city = "Spokane"
$country = "US"
$company = "Zen"
$postalCode = "Y5XU8N"
$state = "Washington"
$streetAddress = "90852 65st"
$homePage = "www.learning.zen.com" # this could be the sharepoint once it is setup. should be easy to change
$officePhone = 7803211234 # starting value, increments by 1 for each user - each user has their own desk phone with own extension

# begin department generation
"$(Get-TimeStamp): Initiating Zen Learning user generation" | Out-File -FilePath $logPath -Append
Write-Host "Generating Zen Learning users..."

$department = "Teachers"
$results = New-TeacherUser -staffCount 1 -maxStaff 3 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone
$teachers = $results.Teachers

$department = "Students"
$results = New-StudentUser -staffCount 1 -maxStaff 47 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone -managers $teachers
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

$department = "Design"
$results = New-DesignAdminUser -staffCount 1 -maxStaff 5 -generatedCellphones $generatedCellphones -generatedUsernames $generatedUsernames -officePhone $officePhone
$generatedUsernames = $results.GeneratedUsernames
$generatedCellphones = $results.GeneratedCellphones
$officePhone = $results.OfficePhone

"$(Get-TimeStamp): Zen Learning user generation complete" | Out-File -FilePath $logPath -Append

# end of script - generated unique values saved to file in case script needs to run again
"$(Get-TimeStamp): Logging generated usernames at $($usernameLogPath)" | Out-File -FilePath $logPath -Append
New-UsernameLog -UsernameLogPath $usernameLogPath -GeneratedUsernames $generatedUsernames
"$(Get-TimeStamp): Logging generated cellphone numbers at $($cellphoneLogPath)" | Out-File -FilePath $logPath -Append
New-CellphoneLog -CellphoneLogPath $cellphoneLogPath -GeneratedCellphones $generatedCellphones
"$(Get-TimeStamp): Script complete" | Out-File -FilePath $logPath -Append
Write-Host "Script complete"
Read-Host "`nPress enter to exit program"
