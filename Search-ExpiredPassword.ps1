function Search-ExpiredPassword {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $DC,
        [string]
        $LogFileName = "ExpirationNotice_" ,
        [Parameter(Mandatory)]
        [string]
        $LogFileDirectory,
        [Parameter(Mandatory)]
        [string]            
        $MonitoringEmail,
        [Parameter(Mandatory)]
        [string]
        $Guide,
        [Parameter(Mandatory)]
        [string]
        $EmailHTML,
        [string]
        $TimeZoneId = "UTC",
        [Parameter()]
        [string]
        $LogSubject = "Password Expiration Notice - LOGs for $Now",
        [Parameter()]
        [string]
        $SearchBase = (Get-ADDomain -Server $DC).DistinguishedName,
        [Parameter()]
        [int]
        $StartNotif = 7,
		[ValidateSet("Yes","No")]
        [string]
        $DebugMode = "No",
        [Parameter()]
        [string]
        $DebugEmail = "mailme@example.com",
        [Parameter(Mandatory)]
        [string]
        $SA_Username,
        [Parameter(Mandatory)]
        [securestring]
        $SA_Password,
        [string]
        $SMTP_Username,
        [securestring]
        $SMTP_Password,
        [Parameter(Mandatory)]
        [string]
        $SMTP_srv,
        [Parameter(Mandatory)]
        [string]
        $SMTP_prt,
        [Parameter(Mandatory)]
        [string]
        $SMTP_from,
        [Parameter(Mandatory)]
        [string]
        $EmailSubject
    )

    #Force TLS 1.2 as security protocol to use with (send-mailmessage)
    [System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    #Email settings - Common for any email send
    $smtpsettings = @{
        from = $SMTP_from;
        smtp_server = $SMTP_srv;
        smtp_port = $SMTP_prt;
        subject = $EmailSubject;
        user = $SMTP_Username;
        password = $SMTP_Password;
    }
    $CredentialEmail = New-Object System.Management.Automation.PSCredential $smtpsettings["user"], $smtpsettings["password"]

    #Credential of User that connect to AD to scan users 
    $UserScan = $SA_Username
    $PasswordScan = $SA_Password
    $Credential = New-Object System.Management.Automation.PSCredential $UserScan,$PasswordScan
    
    #We start to warn the user 7 days in advance by default
    $WarnDate = (Get-Date).adddays($StartNotif)
    $Now = Get-Date
    $logdate = Get-Date -format yyyyMMdd

    #Log file
    $LogFile = $LogFileDirectory + $LogFileName + "_maillog" + $logdate + ".txt"
	New-item $LogFile -Force
    
    #Content of the email sent to the user
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

    foreach ($t_user in $UsersAD){
        #If expiration date minus warndate is less than 7 and more than 0 we send an email to user.
        #We don't send email to users with a password already expired.
        $ndays = $WarnDate - $t_user.PasswordExpiry 
        if (($ndays -lt "7") -and ($ndays -gt "0")) {
            #Convert date of expiration to correspond to the timezone.
            $time1 = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($t_user.PasswordExpiry, $TimeZoneId)
            
            #Format the date as we want it to be displayed for end-users
            $ExpirationDate = $time1.ToString("dddd dd/MM/yyyy HH:mm '$UTCvalue'")
            
            #Debug 
            if ($DebugMode -eq "Yes"){ $t_user.EmailAddress = $DebugEmail }
            
            #Send message to user
            Send-MailMessage -UseSsl -Encoding UTF8 -credential $CredentialEmail `
            -SmtpServer $smtpsettings["smtp_server"] -Port $smtpsettings["smtp_port"] `
            -To $t_user.EmailAddress -From $smtpsettings["from"] `
            -Subject $smtpsettings["subject"] -Attachment $Guide `
            -BodyAsHtml ($html -f $t_user.DisplayName, $t_user.EmailAddress, $ExpirationDate)
            
            #Add info to log file
            $Notice = "Password for $($t_user.DisplayName) must be changed before $($t_user.PasswordExpiry)."
            Add-Content -Pass $LogFile -Value "$Notice Email was sent to $($t_user.EmailAddress) on $Now"
            Write-Output $Notice
        }
    }

	#Debug mode will send all email to your debug address instead to send it to users or to monitoring mailbox.
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
.INPUTS
    Users to scan to find their password expiration date.
.OUTPUTS
    Email send to users with a password closed to expire + a log message sent to an email monitored by support.
.NOTES
    URL: https://github.com/enzo-g/Password-Expiration-Notice
    Version:  1.0
    Author:   Enzo Gautier
.EXAMPLE
    Check the Splatting.ps1 file.
    Search-ExpiredPassword @Splatting_ExpP
#>