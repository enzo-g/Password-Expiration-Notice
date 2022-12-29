$FunctionPath = ".\Search-ExpiredPassword.ps1"
. $FunctionPath

$Splatting_ExpP = @{
#Mandatory parameters
    DC = "dc.example.com"
    LogFileDirectory = "C:\Temp\" 
    LogFileName = "ExpirationNotice_" 
    Attachment = "C:\Temp\guide.pdf"
    EmailHTML = "C:\Temp\Email_example.html"
    MonitoringEmail = "monitoring@example.com"
    LogSubject = "Password Expiration Notice - LOGs for $Now"
    SMTP_srv = "smtp.office365.com";
    SMTP_prt = 587;
    SMTP_from = "myemail@example.com";
    ## Credential for the service account with rights on AD
    SA_Username = "mySAusername"
    SA_Password = ConvertTo-SecureString "YourPassword" -AsPlainText -Force
    #The following parameters are not mandatory
	DebugMode = "Yes"
	DebugEmail = "debug@example.com"
    TimeZoneId = "UTC"
    ## Credential for the SMTP account
    SMTP_Username = "myemail@example.com"
    SMTP_Password = ConvertTo-SecureString "YourPassword" -AsPlainText -Force
}

Search-ExpiredPassword @Splatting_ExpP