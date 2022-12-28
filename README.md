# Introduction

This script is to scan active directory users and find users with a password close from expiring.
The script will then send them an email to notify them, and finally send the logs to you.

# 

## How to get the Time Zone ID

Execute the following command to find the "Time Zone ID"

```powershell
[timezoneinfo]::GetSystemTimeZones() | select displayname, id
```