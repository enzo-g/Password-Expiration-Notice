. "C:\Scripts\ExpiredPassword\function_Search-ExpiredPassword.ps1"

$Splatting_ExpP = @{
    DC = "SIN1-VWSAD-JP-1.kwjp.keywordsintl.com"
    LogFileDirectory = "C:\Scripts\ExpiredPassword\Logs\" 
    LogFileName = "kwjp" 
    Attachment = "C:\Scripts\ExpiredPassword\O365_ChangePassword.png"
    EmailHTML = "C:\Scripts\ExpiredPassword\kwjp_mail.html"
    TimeZoneId = "Tokyo Standard Time"
    MonitoringEmail = "apac-it-monitoring@keywordsstudios.com"
    LogSubject = " KWJP - Password Expiration Notice - LOGs for $Now"
	DebugMode = "Yes"
	DebugEmail = "egautier@keywordsstudios.com"
}

Search-ExpiredPassword @Splatting_ExpP