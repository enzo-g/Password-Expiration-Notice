function Search-ExpiredPassword {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $DC,
        [Parameter(Mandatory)]
        [string]
        $LogFileName,
        [Parameter(Mandatory)]
        [string]
        $LogFileDirectory,
        [Parameter(Mandatory)]
        [string]            
        $MonitoringEmail,
        [Parameter(Mandatory)]
        [string]
        $Attachment,
        [Parameter(Mandatory)]
        [string]
        $EmailHTML,
        [Parameter(Mandatory)]
        [string]
        $TimeZoneId,
        [Parameter()]
        [string]
        $LogSubject = "Password Expiration Notice - LOGs for $Now",
        [Parameter()]
        [string]
        $SearchBase = (Get-ADDomain -Server $DC).DistinguishedName,
        [Parameter()]
        [int]
        $StartNotif = 7,
		[Parameter(Mandatory)]
		[ValidateSet("Yes","No")]
        [string]
        $DebugMode,
        [Parameter()]
        [string]
        $DebugEmail = "it_apac_monitoring@keywordsstudios.com"
    )

    #Force TLS 1.2 as security protocol to use with (send-mailmessage)
    [System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    #Email settings - Common for any email send
    $smtpsettings = @{
        from = "it_apac_noreply@keywordsstudios.com";
        smtp_server = "smtp.office365.com";
        smtp_port = 587;
        subject = "Password Expiration Notice";
        user = $env:useritapacnoreply;
        password = ConvertTo-SecureString $env:passitapacnoreply -AsPlainText -Force;
    }
    $CredentialEmail = New-Object System.Management.Automation.PSCredential $smtpsettings["user"], $smtpsettings["password"]

    #Credential of User that connect to AD to scan users 
    $UserScan = $env:uname
    $PasswordScan = ConvertTo-SecureString $env:passw -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential $UserScan,$PasswordScan
    
    #We start to warn the user 7 days in advance by default
    $WarnDate = (Get-Date).adddays($StartNotif)
    $Now = Get-Date
    $logdate = Get-Date -format yyyyMMdd

    #Log file
    $LogFile = $LogFileDirectory + $LogFileName + "_maillog" + $logdate + ".txt"
	New-item $LogFile -Force
    #Content of the email sent to the user
    $AttachmentO365 = $Attachment
    $html = Get-Content -encoding UTF8 -path $EmailHTML

    #Display the corresponding UTC of the timezone, in the email that we are sending to the user.
    $timez = (Get-TimeZone -Id $TimeZoneId).DisplayName
    $UTC = [regex]::match($timez,'(?<=\().+?(?=\))')
    $UTCvalue = $UTC.value

    #Get info about AD users with specific criteria.
    #Enabled Account, Password not set to never expires, Email attribute not empty

    $UsersAD = Get-ADUser -SearchBase $SearchBase -Credential $Credential -server $DC `
    -filter {Enabled -eq $True -and PasswordNeverExpires -eq $False -and mail -like '*'} `
    -Properties "DisplayName", "EmailAddress", "msDS-UserPasswordExpiryTimeComputed" | `
    Select-Object -Property "DisplayName", "EmailAddress", `
    @{Name = "PasswordExpiry"; Expression = {[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed") }}

    foreach ($u1 in $UsersAD){
        #If expiration date minus warndate is less than 7 and more than 0 we send an email to user.
        #We don't send email to users with a password already expired.
        $ndays = $WarnDate - $u1.PasswordExpiry 
        if (($ndays -lt "7") -and ($ndays -gt "0")) {
            #Convert date of expiration to correspond to the timezone.
            $u2 = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($u1.PasswordExpiry, $TimeZoneId)
            #Format the date as we want it to be displayed for end-users
            $u3 = $u2.ToString("dddd dd/MM/yyyy HH:mm '$UTCvalue'")
            #Debug 
            if ($DebugMode -eq "Yes"){ $u1.EmailAddress = $DebugEmail }
            #Send message to user
            Send-MailMessage -UseSsl -Encoding UTF8 -credential $CredentialEmail `
            -SmtpServer $smtpsettings["smtp_server"] -Port $smtpsettings["smtp_port"] -To $u1.EmailAddress `
            -From $smtpsettings["from"] -Subject $smtpsettings["subject"] -Attachment $AttachmentO365 `
            -BodyAsHtml ($html -f $u1.DisplayName, $u1.EmailAddress, $u3, $u1.DisplayName, $u1.EmailAddress, $u3)
            $Notice = "Password for $($u1.DisplayName) must be changed before $($u1.PasswordExpiry)."
            Add-Content $LogFile  "$Notice Email was sent to $($u1.EmailAddress) on $Now"
            Write-Output $Notice
        }
    }

	#Debug mode
	if ($DebugMode -eq "Yes"){ $MonitoringEmail = $DebugEmail }
    #Send Email to the specified logging Email address with the attached logfile, containing all users that received the Notifiation Email on that day
    Write-Output "Sending logs to $MonitoringEmail"
	
	#Info
	
	$Body1 = "This is the log from $Now"
	$TestLog = get-content $LogFile
	if ($null -eq $TestLog){ $Body1 = "The log file is empty, none of the users needs to renew their password." }
	
    #Send log email
    Send-MailMessage -UseSsl -credential $CredentialEmail -Port $smtpsettings["smtp_port"] -SmtpServer $smtpsettings["smtp_server"] `
    -To $MonitoringEmail -From $smtpsettings["from"] `
    -Subject  $LogSubject -Body $Body1 `
    -Attachment $LogFile
	
	Write-Output $Body1
}

<#
.SYNOPSIS
    Script is checking AD users for their password expiration date and email them if its going to expire in the next 7 days.
.DESCRIPTION
    This script should be triggered with a service accounts that can read the necessary attributes of AD users.
    Not all necessary settings are defined thanks to Parameters.
    This script has been designed to be used for Keywordsintl.com infrastructure with credential injection from jenkins.
.PARAMETER SearchBase
    If you want you can restrict the password expiration time research to a specific Users OU. If not precised, it will scan the whole domain.
.PARAMETER LogFileDirectory
    Enter directory in that format: "C:\Scripts\ExpiredPassword\Logs\"
.PARAMETER TimeZoneiD
    Enter the iD of the timezone of users to display their password expiration date with the proper hour in their timezone
    You can find that Id with the command: Get-TimeZone -ListAvailable 
.INPUTS
    Users to scan to find their password expiration date.
.OUTPUTS
    Email send to users with a password closed to expire + a log message sent to an email monitored by support.
.NOTES
    Version:  1.1
    Author:   Enzo Gautier
.EXAMPLE
    $Splatting_ExpP = @{
        DC = "SIN1-VWSAD-JP-1.kwjp.keywordsintl.com"
        LogFileDirectory = "C:\Scripts\ExpiredPassword\Logs\" 
        LogFileName = "kwjp" 
        Attachment = "C:\Scripts\ExpiredPassword\O365_ChangePassword.png"
        EmailHTML = "C:\Scripts\ExpiredPassword\kwjp_mail.html"
        TimeZoneId = "Tokyo Standard Time"
        MonitoringEmail = "egautier@keywordsstudios.com"
        LogSubject = " KWJP - Password Expiration Notice - LOGs for $Now"
    }
    Search-ExpiredPassword @Splatting_ExpP
#>