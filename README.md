# Introduction

This script is to scan active directory users and find users with a password close from expiring.
The script will then send them an email to notify them, and finally send the logs to you.

# How do I recommend to use that script ?

The script is a function, I recommend to use that function by splatting the parameters you want to use with the function.
The function come with a lot of mandatory parameters to fill, however splatting those parameters will help you to keep your code clear.
Please check at the file "Splatting.ps1".


# Requirement

## Service accounts

* A service account with enought rights to read the AD attributes "msDS-UserPasswordExpiryTimeComputed".
* A SMTP server to send emails to your user. You can either use a SMTP server configured for unauthenticated access, or one that need credentials.

## Documents

* You need to prepare an HTML file that will be the content of the email sent to your users.
* You need to prepare a document that will be sent in attachement of the email for your end-users. I recommend that document to be a guide to explain them how to change their password.


# Tips 

## Credential vault

* Instead of storing your password in clear text as you can see it in the file "Splatting.ps1". I recommend you reading those articles:
* * [Use Credential Manager Module in PowerShell](https://www.delftstack.com/howto/powershell/use-credential-manager-in-powershell/)
* * [SecretManagement and SecretStore](https://devblogs.microsoft.com/powershell/secretmanagement-and-secretstore-are-generally-available/)

* Using Jenkins to run that script would allow you to store the credential needed within that script in a secure vault easely. Jenkisn can also be useful to have a nice graphical interface to schedule the exeuction of the script and see the results.

## Time Zone ID 

By indicating the Time Zone ID in parameter, the email sent to the user will contain an expiration date easier to read for your end-user.
To find the value you are interested in, execute the following powershell command to get a list of "Time Zone ID".
Default value is "UTC".

```powershell
[timezoneinfo]::GetSystemTimeZones() | select displayname, id
```

## Body Email

BodyEmail is the variable that will contain the text sent to your end-users.
Within that variable, you have 3 variables that you should use:

* $($t_user.DisplayName): It will display the name of the user (Enzo Gautier)
* $($t_user.EmailAddress): It will display the email of the user ( enzo@example.com )
* $ExpirationDate It will display the password expiration date of the user ( Friday 16/12/2022 14:09 GMT+9 )

```powershell
    BodyEmail = "Dear $($t_user.DisplayName) , The password for your account $($t_user.EmailAddress) is due to expire on $ExpirationDate. `n
    Please update your password by following, if needed, the detailed instructions available in attachment. `n
    Failure to update your password may result in your account being locked out. `n 
    Please contact your IT Helpdesk if you have any questions, thank you. `n
    Best Regards, `n
    Your IT team"
```