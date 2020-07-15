## Author: Ali Nikouei
## Copyright: MIT License

## Explanation:
### you need to define couple of things:
###   - path to the .csv file to the users. You can see the example list to see the format. You can also add/remove properties. Here is the full list of properties: https://docs.microsoft.com/en-us/powershell/module/addsadministration/new-aduser
###   - In the CSV file, you need to use the country code, not the name of the country. It is uses ISO standard.
###   - Organizational Units and Groups should be exist in the Active Directory
###   - Avatar Images should be in URL, if you like to use local files, you need to do some modifications to the sectoion of this script related to 'thumbnailPhoto' property.
###   - Passwords should meet the policy you have in AD.
###   - For the boolean parameters, use 'True' or 'False' values. I was thinking of T/F and 0/1 but they can make issues if you use one letter name or one digit numbers.
###   - The 'Manager' Property should be the 'Name' of an existing user. In my data, because it is a mock list of users, it doesn't work.

# import the AD module
Import-Module ActiveDirectory

# load the location of the CSV file; if it is saved on the desktop
$users = Import-csv ([Environment]::GetFolderPath("Desktop") + '\Mock_Users.csv')

# get the list of properties
$properties = ($users | Get-Member -MemberType NoteProperty).Name

# list of escaping properties
# it is reserved for all special properties that need more care
$escape = @('Group', 'thumbnailPhoto')

# date format
$date_format = 'm/dd/yyyy'

# a variable to count the number of imported users
[int]$no = 1

# iterate over users and properties
foreach ($user in $users) {
  # if the user already is in AD, do nothing
  if (Get-ADUser -Filter "sAMAccountName -eq '$($user.sAMAccountName)'") {
    continue
  }
  else {
    # initiate the list of parameters
    $parameters = @{}
  
    # convert the plaintext password to the encrypted password
    $user.AccountPassword = $user.AccountPassword | ConvertTo-SecureString -AsPlainText -Force

    # get the random member of groups and OUs
    [string]$OU    = $OUs    | Get-Random
    [string]$group = $groups | Get-Random

    # iterate over the list of properties
    foreach ($property in $properties) {
      # pass the null or escaping parameters 
      if (($null -eq $user.$property) -or ($user.$property -eq "") -or $escape.Contains($property)) {
        continue
      }

      # fix the boolean (True) parameters
      elseif ($user.$property -eq 'True')  {$parameters.$property = $True}

      # fix the boolean (False) parameters
      elseif ($user.$property -eq 'False') {$parameters.$property = $False}

      # fix the date parameters
      elseif ($property -and ($property -eq 'AccountExpirationDate')) {
        $parameters.AccountExpirationDate = [datetime]::parseexact($user.AccountExpirationDate, "m/dd/yyyy", $null)
      }
    
      # add non-empty property and correspondig value of it to the parameters variable
      else {$parameters.$property = $user.$property}
    }

    try {
      # add the new user to AD
      New-ADUser @parameters

      # download images and assign them
      if ($user.thumbnailPhoto) {
        # download the image into the temp folder
        Invoke-WebRequest $user.thumbnailPhoto -OutFile "$($env:temp)\$($user.sAMAccountName).jpg"
        
        # store the image location into the corresponding parameter
        $user.thumbnailPhoto = "$($env:temp)\$($user.sAMAccountName).jpg"
        
        # set the image to the user
        Set-ADUser -Identity $user.sAMAccountName -Replace @{thumbnailPhoto=([byte[]](Get-Content $user.thumbnailPhoto -Encoding byte))}
      }

      # add the user to the group, if applicant
      if ($user.Group) {
        Add-ADGroupMember -Identity $group -Members $user.sAMAccountName
      }

      write-host $no -ForegroundColor White -NoNewline
      write-host "`t $($user.Name)" -ForegroundColor Green
    }
    catch {
      Write-Host "It is not possible to create the user"
    }

    $no += 1
  }
}

Write-Host "`n`r$no users are created." -ForegroundColor Yellow
