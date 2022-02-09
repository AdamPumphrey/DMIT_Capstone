# DMIT_Capstone
DMIT2590 Systems Administration Capstone Scripts

# New-CWSOUs.ps1

This script creates the specified OUs and sub-OUs in the present environment and logs its actions. Referring to the business case, this script creates the AD structure for Company 1 (web hosting).

This script should be ran as admin on the main domain controller for Company 1.

This script DOES NOT check to see if the OUs already exist. It is meant to be ran as part of the first-time setup of the domain.

E.g.) .\New-CWSOUs.ps1

1.	The domain and domain suffix are obtained based on the environment. E.g.) if the domain of the machine that the script is running on is TEST.CA, the domain will be TEST and the suffix will be CA.
2.	A folder named “DMIT2590_Logs” is created at C:\Windows if the C:\Windows\DMIT2590_Logs path does not already exist.
3.	A file named New-CWSOUs.log is created inside of the DMIT2590_Logs folder, if the file does not already exist.
4.	OU creation begins:
a.	For each OU in the list of OUs, a new OU is created in AD.
b.	If the OU that was just created was the IT OU, the sub-OUs for IT are created:
i.	For each sub-OU in the list of sub-OUs, a new sub-OU is created in AD under the IT OU.

Logs are written at the following points:
* OU creation begins
* When an OU is created
* When a sub-OU is created
* If an exception is caught
* When the script is complete

Notes:
* Names of OUs and sub-OUs are hard coded as string arrays
* OUs created:
  * Sales
  * HR
  * Finance
  * IT
    * Server Support
    * Networking Support
    * Application Support
    * Programming
    * Administration
    * Tech Support
  * Executive Staff

# New-ZenOUs.ps1

This script is fundamentally the same as New-CWSOUs.ps1, however some details are changed to reflect the AD structure of Company 2 (software design).

This script should be ran as admin on the main domain controller for Company 2.

This script DOES NOT check to see if the OUs already exist. It is meant to be ran as part of the first-time setup of the domain.

E.g.) .\New-ZenOUs.ps1

Changes from New-CWSOUs.ps1:
* Name of the log file is New-ZenOUs.log
* OUs and sub-OUs are different:
  * Sales
  * Design
    * Programmers
    * DB Engineers
    * UI Experts
    * Content Experts
    * Animators
  * HR
  * Finance
  * IT
  * Executive Staff

# New-LearningOUs.ps1

This script is fundamentally the same as New-CWSOUs.ps1, however some details are changed to reflect the AD structure of Company 2’s Learning sub-domain.

This script should be ran as admin on the main domain controller for the Company 2 Learning sub-domain

This script DOES NOT check to see if the OUs already exist. It is meant to be ran as part of the first-time setup of the domain.

E.g.) .\New-LearningOUs.ps1

Changes from CWSOUs.ps1:
* Name of the log file is New-LearningOUs.log
* OUs are different, no sub-OUs:
  * Design
  * Teachers
  * Students
* The domain and suffix are obtained, as well as the subdomain. E.g.) if the domain of the machine that the script is running on is LEARNING.TEST.CA, the domain will be TEST, the suffix will be CA, and the subdomain will be LEARNING.

# New-CWSRandomUser.ps1

This script randomly generates and creates AD users for the Company 1 domain.

This script should be ran as admin on the main domain controller for Company 1.

If users have already been created using New-ZenRandomUser.ps1 or New-LearningRandomUser.ps1, the generatedUsernames.csv and generatedCellphones.csv files need to be copied and pasted into C:\Windows\DMIT2590_Logs on the machine that New-CWSRandomUser.ps1 is going to run on. This is to avoid duplicate user/cellphone creation. Exceptions will be thrown if an attempted duplicate user creation is tried.

E.g.) .\New-CWSRandomUser.ps1

1. A folder named “DMIT2590_Logs” is created at C:\Windows if the C:\Windows\DMIT2590_Logs path does not already exist.
2. A file named New-CWSRandomUser.log is created inside of the DMIT2590_Logs folder if the file does not already exist.
3. The path C:\Windows\DMIT2590_Logs\generatedUsernames.csv is checked. If a file exists at that path:
    1. The generatedUsernames.csv file is imported.
    2. A hash table containing an empty array assigned to the value “Username” is appended to the result of the file import.
4.	If the file does not exist at that path:
    1. The generatedUsernames.csv file is created at that path.
    2. The string “Username” is appended to the file.
    3. An empty array is created.
    4. A hash table containing an empty array assigned to the value “Username” is appended to the empty array that was just created.
5.	The path C:\Windows\DMIT2590_Logs\generatedCellphones.csv is checked. If a file exists at that path:
    1. The generatedCellphones.csv file is imported.
    2. A hash table containing an empty array assigned to the value “Cellphone” is appended to the result of the file import.
6.	If the file does not exist at that path:
    1. The generatedCellphones.csv file is created at that path.
    2. The string “Cellphone” is appended to the file.
    3. An empty array is created.
    4. A hash table containing an empty array assigned to the value “Cellphone” is appended to the empty array that was just created.
 
Note: The generatedUsernames.csv and generatedCellphones.csv files are used to keep track of generated usernames and cellphone numbers, since these are unique values between each user. A user cannot have the same username (i.e. SAMAccountName) and having multiple users with the same cellphone number just isn’t realistic.

7.	The default password is converted to secure string, and the domain and suffix are obtained from the environment.
8.	User generation begins

User generation steps:
1. A coin is flipped to determine whether the user should have a masculine or feminine first name.
    1. For both masculine and feminine first names, a random integer is generated within the number of first names available (e.g. if there are 100 names available, a number in the range of 0-99 will be generated).
    2. The first name at the index of the generated number is chosen as the first name.
2. A number is generated within the number of last names available.
3. The last name at the index of the generated number is chosen as the last name.
4. The username is generated by combining the user’s first initial and their last name. E.g.) Sarah Connor = sconnor.
    1. The generated username is then checked against the results of the generatedUsernames.csv import (the list of generated usernames).
    2. If the generated username already exists in the list of generated usernames, a number will be appended to the end of the username until it is unique. E.g.) sconnor  sconnor1, if sconnor1 is also in use then sconnor1  sconnor2, etc)
5. The following attributes are returned in a hash table: first name, last name, full name, username (SAMAccountName), and email address (UserPrincipalName)
6. The generated username is appended to the list of generated usernames.
7. A new cellphone number is generated:
    1. A random number between 1111111 and 9999999 is generated.
    2. The number is checked against the results of the generatedCellphones.csv import (the list of generated cellphone numbers).
    3. If the generated cellphone number already exists in the list of generated cellphones, a new cellphone number will be generated until a unique cellphone number is acquired.

At this point, all of the user’s properties have data assigned to them. The following are default attributes for Company 1’s Edmonton HQ users:
* Password = Password1
* City = Edmonton
* Country = CA (Canada)
* Company = CWS
* Postal Code = A1BC2D
* State = Alberta
* Street Address = 12345 67st
* Home  Page = www.CWS.com
* Office Phone = 7801231234 (this value increments per user. E.g. the first user generated has an office phone of 78012341234, the second user has an office phone of 7801231235, etc. This is to simulate extensions inside of an office).

For Company 1’s Calgary datacentre users the following values differ:
* City = Calgary
* Street Address = 9876 321ave
* Postal Code = 8T6N2M

9. Users are generated for each department. Department breakdowns are as follows:
10. 
Note: user titles are assigned in the order of generation. E.g.) for Executive Staff 9 users are generated, the first user to generated is the CEO, the next is the COO, then CFO, then CIO, etc. This method of title assignment is applied for every department.

Executive Staff:
* 9 staff - 1 CEO, 1 COO, 1 CFO, 1 CIO, 1 Sales Director, 1 HR Director, 1 Finance Director, 1 IT Director, 1 Calgary Director.
* Sales Director and HR Director report to the COO (the COO is their Manager in their AD profiles).
* Finance Director reports to CFO.
* IT Director and Calgary Director report to CIO.
* CFO, CIO, COO all report to CEO.

Sales:
* 20 staff - 1 sales manager, 5 senior sales associates, 5 intermediate sales associates, 3 junior sales associates, 6 sales account managers
* Sales Manager reports to the Sales Director
* Everybody else in Sales reports to the Sales Manager.

HR:
* 8 staff - 1 HR manager, 3 HR specialists, 2 payroll specialists, 2 recruiters
* HR Manager reports to the HR Director
* Everybody else in HR reports to the HR Manager.

Finance:
* 14 staff - 1 finance manager, 3 senior accountants, 2 intermediate accountants, 1 junior accountant, 3 internal auditors, 1 controller, 3 accounts payable clerks
* Finance Manager reports to the Finance Director.
* Everybody else in Finance reports to the Finance Manager.

IT:
* Administration:
    * Administration sub-department - 6 staff - managers for each sub dept and one IT manager
    * Managers for each sub dept report to the IT Manager
    * IT Manager reports to IT Director

* Server Support:
    * Server Support sub-department - 4 staff - 2 senior server analysts, 2 intermediate server support analysts
    * Everybody reports to Server Support Manager in Administration
    
* Networking Support:
    * Networking Support sub-department - 5 staff - 2 senior network analysts, 2 intermediate network support analysts, 1 junior network analyst
    * Everybody reports to Networking Support Manager in Administration
    
* Application Support:
    * Application Support sub-department - 4 staff - 1 senior application analyst, 2 intermediate application analysts, 1 junior application analyst
    * Everybody reports to Application Support Manager in Administration

* Programming:
    * Programming sub-department - 4 staff - 2 senior developers, 1 intermediate developer, 1 junior developer
    * Everybody reports to Programming Manager in Administration
    
* Tech Support:
    * Tech Support sub-department - 6 staff - 2 senior support analysts, 2 intermediate support analysts, 2 junior support analysts
    * Everybody reports to Tech Support Manager in Administration

Everything in IT is generated twice, once for the Edmonton location and once for the Calgary datacentre location.

10.	Once all users are created, the lists of generated usernames and generated cellphone numbers are exported to C:\Windows\DMIT2590_Logs\generatedUsernames.csv and C:\Windows\DMIT2590_Logs\generatedCellphones.csv, respectively.

Logs are written at the following points:
* Script start
* When user generation begins for a specific department
* When a new name is generated
* When a new user is created in AD
* When user generation for a specific department is complete
* When the generated usernames/cellphones are exported to csv’s.
* If an exception is caught
* When the script is complete

# New-ZenRandomUser.ps1

This script is fundamentally the same as New-CWSRandomUser.ps1, however some details are changed to reflect the AD structure of Company 2’s domain.

This script should be ran as admin on the main domain controller for Company 2.

If users have already been created using New-CWSRandomUser.ps1 or New-LearningRandomUser.ps1, the generatedUsernames.csv and generatedCellphones.csv files need to be copied and pasted into C:\Windows\DMIT2590_Logs on the machine that New-ZenRandomUser.ps1 is going to run on. This is to avoid duplicate user/cellphone creation. Exceptions will be thrown if an attempted duplicate user creation is tried.

Aside from the log file name changing, the changes are in the departments and titles that are generated:

Executive Staff:
* 10 staff - 1 CEO, 1 COO, 1 CFO, 1 CIO, 1 Sales Director, 1 Design Director, 1 HR Director, 1 Finance Director, 1 IT Director, 1 Spokane Director
* Sales Director, Spokane Director, and HR Director report to the COO (the COO is their Manager in their AD profiles).
* Finance Director reports to CFO.
* IT Director and Design Director report to CIO.
* CFO, CIO, COO all report to CEO.

Sales:
* Sales dept - 87 staff - 5 Sales teams - 1 sales team manager, 6 senior sales associates, 5 intermediate sales associates, 3 junior sales associates - 1 accounts team manager, 11 sales account managers
* North Sales Team Manager, South Sales Team Manager, West Sales Team Manager, East Sales Team Manager, International Sales Team Manager, Sales Accounts Team Manager all report to Sales Director
* Everyone else reports to their respective team managers
* 5 Sales teams - North, West, East, South, International
* 1 Sales Account teams

IT:
* IT Department - 5 staff - 1 IT manager, 2 senior support analysts, 2 intermediate support analysts
* IT Manager reports to IT Director
* Everyone else reports to IT Manager

Design:
* Programmers:
    * Programmers sub-department - 5 staff - 1 programming manager, 2 senior developers, 1 intermediate developer, 1 junior developer
    * Programming manager reports to Design Director
    * Everyone else reports to Programming Manager

* DB Engineers:
    * DB Engineers sub-department - 5 staff - 1 DB manager, 2 senior engineers, 1 intermediate engineer, 1 junior engineer
    * DB Manager reports to Design Director
    * Everyone else reports to DB Manager

* UI Experts:
    * UI Experts sub-department - 5 staff - 1 UI manager, 2 senior graphic designers, 1 intermediate graphic designer, 1 junior graphic designer
    * UI Manager reports to Design Director
    * Everyone else reports to UI Manager

* Content Experts:
    * Content Experts sub-department - 5 staff - 1 content manager, 2 senior content designers, 1 intermediate content designer, 1 junior content designer
    * Content Manager reports to Design Director
    * Everyone else reports to Content Manager

* Animators:
    * Animators sub-department - 5 staff - 1 animation manager, 2 senior animators, 1 intermediate animator, 1 junior animator
    * Animation Manager reports to Design Director
    * Everyone else reports to Animation Manager

# New-LearningRandomUser.ps1

This script is fundamentally the same as New-CWSRandomUser.ps1, however some details are changed to reflect the AD structure of Company 2’s sub-domain.

This script should be ran as admin on the main sub-domain controller for Company 2.

If users have already been created using New-CWSRandomUser.ps1 or New-ZenRandomUser.ps1, the generatedUsernames.csv and generatedCellphones.csv files need to be copied and pasted into C:\Windows\DMIT2590_Logs on the machine that New-ZenRandomUser.ps1 is going to run on. This is to avoid duplicate user/cellphone creation. Exceptions will be thrown if an attempted duplicate user creation is tried.

Aside from the log file name changing, the changes are in the departments and titles that are generated:

Design:
* 5 staff - 1 Programming Admin, 1 DB Engineering Admin, 1 UI Admin, 1 Content Admin, 1 Animation Admin

Teachers:
* 3 staff - 3 Teachers

Students:
* 47 staff - 47 Students
* Classes of 15 students per teacher unless there are remainders. E.g.) 47 students, one class of 15, one class of 15, one class of 17
