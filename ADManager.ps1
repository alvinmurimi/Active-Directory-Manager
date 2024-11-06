# Import Active Directory module
Import-Module ActiveDirectory

# Write logs with timestamp
function Write-Log {
    param($Message)
    
    # Create logs directory if it doesn't exist
    $LogDir = ".\logs"
    if (-not (Test-Path -Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir | Out-Null
    }
    
    # Use single log file per day
    $LogFile = Join-Path $LogDir "AD_User_Creation_$(Get-Date -Format 'yyyyMMdd').log"
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Add script execution separator if new run
    if (-not (Test-Path -Path $LogFile)) {
        "----------------------------------------" | Out-File -FilePath $LogFile -Append
        "$TimeStamp - Starting new script execution" | Out-File -FilePath $LogFile -Append
        "----------------------------------------" | Out-File -FilePath $LogFile -Append
    }
    
    # Write log entry with timestamp
    "$TimeStamp - $Message" | Tee-Object -FilePath $LogFile -Append
}

function Test-UserData {
    param (
        [string]$FullName,
        [string]$Username,
        [string]$Password
    )
    
    # Check only the columns needed for the current operation
    switch ($Action.ToLower()) {
        'create' {
            if ([string]::IsNullOrEmpty($FullName) -or 
                [string]::IsNullOrEmpty($Username) -or 
                [string]::IsNullOrEmpty($Password)) {
                return $false
            }
        }
        'delete' {
            if ([string]::IsNullOrEmpty($Username)) {
                return $false
            }
        }
    }
    return $true
}


function Test-UserExists {
    param (
        [string]$Username
    )
    
    try {
        $user = Get-ADUser -Identity $Username -ErrorAction SilentlyContinue
        return $null -ne $user
    }
    catch {
        return $false
    }
}

# Add user to Active Directory
function New-ADUserFromCSV {
    param (
        [string]$FullName,
        [string]$Username,
        [string]$Password
    )
    
    try {
        # Check if user already exists
        if (Test-UserExists -Username $Username) {
            Write-Log "User $Username already exists in Active Directory. Skipping creation."
            return $false
        }

        # Split full name into first and last name
        $Names = $FullName.Trim() -split ' ', 2
        $FirstName = $Names[0]
        $LastName = if ($Names.Length -gt 1) { $Names[1] } else { "" }
        
        # Define user principal name - trim username
        $UPN = "$($Username.Trim())@$((Get-ADDomain).DNSRoot)"
        
        # Create new AD user
        New-ADUser `
            -Name $FullName `
            -GivenName $FirstName `
            -Surname $LastName `
            -UserPrincipalName $UPN `
            -SamAccountName $Username.Trim() `
            -DisplayName $FullName `
            -AccountPassword (ConvertTo-SecureString -String $Password -AsPlainText -Force) `
            -Enabled $true `
            -PasswordNeverExpires $true

        Write-Log "Successfully created user: $Username"
        return $true
    }
    catch {
        Write-Log "Error creating user $Username`: $_"
        return $false
    }
}

# Remove user from Active Directory
function Remove-ADUserFromCSV {
    param (
        [string]$Username
    )
    
    try {
        # Check if user exists before attempting deletion
        if (Test-UserExists -Username $Username) {
            Remove-ADUser -Identity $Username -Confirm:$false
            Write-Log "Successfully deleted user: $Username"
            return $true
        }
        else {
            Write-Log "User $Username does not exist in Active Directory. Skipping deletion."
            return $false
        }
    }
    catch {
        Write-Log "Error deleting user $Username`: $_"
        return $false
    }
}

try {
    # Check if script is running with admin privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as Administrator"
    }

    $Action = $args[1]
    if ([string]::IsNullOrEmpty($Action)) {
        $Action = Read-Host "Enter action (create/delete)"
    }
    
    # Get CSV file path from parameter or prompt
    $CSVPath = $args[0]
    if ([string]::IsNullOrEmpty($CSVPath)) {
        $CSVPath = Read-Host "Enter the path to your CSV file"
    }
    
    # Verify file exists
    if (-not (Test-Path $CSVPath)) {
        throw "CSV file not found at: $CSVPath"
    }
    
    # Initialize counters
    $Successful = 0
    $Failed = 0
    $Skipped = 0
    
    Write-Log "Starting user $Action process with CSV file: $CSVPath"
    
    # Process CSV file
    Import-Csv $CSVPath | ForEach-Object {
        switch ($Action.ToLower()) {
            'create' {
                if (Test-UserData -FullName $_.fullname -Username $_.username -Password $_.password) {
                    if (Test-UserExists -Username $_.username.Trim()) {
                        Write-Log "Skipped existing user: $($_.username)"
                        $Skipped++
                    }
                    elseif (New-ADUserFromCSV -FullName $_.fullname -Username $_.username -Password $_.password) {
                        $Successful++
                    }
                    else {
                        $Failed++
                    }
                }
                else {
                    Write-Log "Invalid data in row: $($_.fullname), $($_.username)"
                    $Failed++
                }
            }
            'delete' {
                $usernameValue = $_.PSObject.Properties.Value | Where-Object { $_.ToString() -match '^[a-zA-Z0-9_-]+' }
                
                if ($usernameValue) {
                    if (Remove-ADUserFromCSV -Username $usernameValue.ToString().Trim()) {
                        $Successful++
                    }
                    else {
                        $Skipped++
                    }
                }
                else {
                    Write-Log "Invalid username in row"
                    $Failed++
                }
            }

            default {
                throw "Invalid action specified. Use 'create' or 'delete'"
            }
        }
    }
    
    # Write summary with separator
    Write-Log "----------------------------------------"
    Write-Log "Process completed"
    Write-Log "Summary:"
    switch ($Action.ToLower()) {
        'create' {
            Write-Log "Successfully created users: $Successful"
            Write-Log "Skipped existing users: $Skipped"
            Write-Log "Failed to create users: $Failed"
        }
        'delete' {
            Write-Log "Successfully deleted users: $Successful"
            Write-Log "Skipped non-existent users: $Skipped"
            Write-Log "Failed to delete users: $Failed"
        }
    }
    Write-Log "----------------------------------------"
}
catch {
    Write-Log "Script execution failed: $_"
    Write-Log "----------------------------------------"
    exit 1
}