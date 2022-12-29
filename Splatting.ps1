$FunctionPath = ".\Search-ExpiredPassword.ps1"
. $FunctionPath

$Splatting_ExpP = @{
#Mandatory parameters
    DC = "dc.example.com"
    LogFileDirectory = "C:\Temp\" 
    LogFileName = "ExpirationNotice_" 
    Attachment = "C:\Temp\guide.pdf"
    EmailHTML = "C:\Temp\mail.html"
    MonitoringEmail = "monitoring@example.com"
    LogSubject = "Password Expiration Notice - LOGs for $Now"
    SMTP_srv = "smtp.office365.com";
    SMTP_prt = 587;
    SMTP_from = "myemail@example.com";
    ## Credential for the service account with rights on AD
    SA_Username = "mySAusername"
    SA_Password = ConvertTo-SecureString "YourPassword" -AsPlainText -Force
    #BodyEmail
    BodyEmail = "Dear $($t_user.DisplayName) , The password for your account $($t_user.EmailAddress) is due to expire on $ExpirationDate. `n
    Please update your password by following, if needed, the detailed instructions available in attachment. `n
    Failure to update your password may result in your account being locked out. `n 
    Please contact your IT Helpdesk if you have any questions, thank you. `n
    Best Regards, `n
    Your IT team"
    #The following parameters are not mandatory
	DebugMode = "Yes"
	DebugEmail = "debug@example.com"
    TimeZoneId = "UTC"
    ## Credential for the SMTP account
    SMTP_Username = "myemail@example.com"
    SMTP_Password = ConvertTo-SecureString "YourPassword" -AsPlainText -Force
}

Search-ExpiredPassword @Splatting_ExpP