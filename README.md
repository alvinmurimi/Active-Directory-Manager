# Active Directory User Management Script

## Overview

This PowerShell script automates the process of creating and deleting Active Directory users from a CSV file. It provides error handling, detailed logging, and user verification.

## Features

- Bulk creation and deletion of Active Directory users from CSV
- Preserves exact password formatting (including spaces and special characters)
- Detailed logging with timestamps
- Duplicate user detection and skipping
- Password never expires setting
- Success/Failure/Skipped reporting
- Administrative privilege verification

## Prerequisites

- Windows Server with Active Directory Domain Services
- PowerShell 5.1 or higher
- Active Directory PowerShell module
- Domain Administrator privileges

## Installation

1. Clone this repository or download the script:

```powershell
git clone https://github.com/alvinmurimi/Active-Directory-Manager.git
```

2. Ensure you have the Active Directory PowerShell module installed:

```powershell
Import-Module ActiveDirectory
```

## CSV File Format

For user creation, the script requires a specific CSV format with the following headers:

```csv
fullname,username,password
```

Example CSV content:

```csv
fullname,username,password
John William Smith,jsmith,Complex Pass@123!
Sarah Jane Parker,sparker,Keep Spaces As Is!@#
Robert James Brown,rjbrown,No@Trimming  Here
```

For user deletion, only the username column is required, additional columns:

```csv
username
```

Example CSV content:

```csv
jsmith
sparker
rjbrown
```

### CSV Format Rules

- For creation: The first line must contain the exact headers: `fullname,username,password`
- For deletion: The first line must contain the exact header: `username`
- `fullname`: Can contain multiple spaces (e.g., "John William Smith")
- `username`: Should not contain spaces (e.g., "jsmith")
- `password`: Can contain any characters, will be preserved exactly as entered

## Usage

1. Prepare your CSV file according to the format above

2. Run the script as Administrator:

For creating users:

```powershell
.\ADManager.ps1 path\to\users.csv create
```

For deleting users:

```powershell
.\ADManager.ps1 path\to\users.csv delete
```

3. If no path is provided, the script will prompt for the CSV file location

## Logging

- Logs are created in the same directory as the script
- Log filename format: `AD_User_Creation_YYYYMMDD_HHMMSS.log`
- Each action is logged with a timestamp
- Summary of successful, failed, and skipped users is provided

## Example Log Output

```
2024-10-24 10:15:23 - Starting user creation process...
2024-10-24 10:15:24 - Successfully created user: jsmith
2024-10-24 10:15:24 - Skipped existing user: sparker
2024-10-24 10:15:25 - Successfully created user: rjbrown
2024-10-24 10:15:25 - Process completed

2024-10-24 10:15:25 - Summary:
2024-10-24 10:15:25 - Successfully created users: 2
2024-10-24 10:15:25 - Skipped existing users: 1
2024-10-24 10:15:25 - Failed to create users: 0
```

## User Settings

Users are created with the following default settings:

- Account is enabled
- Password never expires
- No forced password change at first logon
- UPN format: username@yourdomain.com

## Troubleshooting

1. Ensure you're running PowerShell as Administrator
2. Verify CSV file encoding (UTF-8 recommended)
3. Check log file for specific error messages
4. Ensure Active Directory module is installed
5. Verify domain connectivity

## Disclaimer

Always test this script in a non-production environment first. Review the CSV file carefully before running in production, as the script will create users with the exact passwords provided or delete users permanently.
