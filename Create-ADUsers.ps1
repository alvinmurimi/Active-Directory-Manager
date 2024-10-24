# Import Active Directory module
Import-Module ActiveDirectory

# Write logs with timestamp
function Write-Log {
    param($Message)
    
    $LogFile = "AD_User_Creation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Tee-Object -FilePath $LogFile -Append
}

# Validate user data
function Test-UserData {
    param (
        [string]$FullName,
        [string]$Username,
        [string]$Password
    )
    
    if ([string]::IsNullOrEmpty($FullName) -or 
        [string]::IsNullOrEmpty($Username) -or 
        [string]::IsNullOrEmpty($Password)) {
        return $false
    }
    return $true
}

# check if user exists
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

# Create AD user
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

try {
    # Check if script is running with admin privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as Administrator"
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
    
    Write-Log "Starting user creation process..."
    
    # Process CSV file
    Import-Csv $CSVPath | ForEach-Object {
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
    
    # Write summary
    Write-Log "Process completed`n"
    Write-Log "Summary:"
    Write-Log "Successfully created users: $Successful"
    Write-Log "Skipped existing users: $Skipped"
    Write-Log "Failed to create users: $Failed"
}
catch {
    Write-Log "Script execution failed: $_"
    exit 1
}