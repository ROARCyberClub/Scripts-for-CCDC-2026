#Requires -RunAsAdministrator

# --- CORRECTED SCRIPT FOR 32-BIT (x86) SESSIONS USING 'net accounts' ---

function Set-DomainSecurityPolicies-Legacy-Automatic {
    Write-Host "--- Automatically Applying Domain Policies using 'net accounts' (32-bit compatible) ---" -ForegroundColor Cyan
    
    try {
        # --- Define the policy settings ---
        $MinPasswordLength = 12
        $MaxPasswordAge = 42
        $PasswordHistory = 24
        $LockoutThreshold = 3
        $LockoutDuration = 10
        $LockoutWindow = 10

        # --- Apply the policies using net accounts /domain ---
        
        Write-Host "Applying Password Length, Age, and History..." -ForegroundColor Yellow
        net accounts /domain /minpwlen:$MinPasswordLength
        net accounts /domain /maxpwage:$MaxPasswordAge
        net accounts /domain /uniquepw:$PasswordHistory

        Write-Host "Applying Account Lockout policies..." -ForegroundColor Yellow
        
        # --- CORRECTED ORDER ---
        # Set the Lockout Window FIRST to avoid "System error 87".
        net accounts /domain /lockoutwindow:$LockoutWindow
        
        # Now set the Lockout Duration. This will succeed because the window is already set.
        net accounts /domain /lockoutthreshold:$LockoutThreshold
        net accounts /domain /lockoutduration:$LockoutDuration
        
        Write-Host "`nLegacy policies have been applied." -ForegroundColor Green
        
        # Force a Group Policy update
        Write-Host "Running 'gpupdate /force' to apply changes immediately..." -ForegroundColor Yellow
        gpupdate /force
        
        Write-Host "`n--- Script Finished ---" -ForegroundColor Cyan
    }
    catch {
        Write-Host "An error occurred while applying the policies:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

# --- SCRIPT EXECUTION ---
Set-DomainSecurityPolicies-Legacy-Automatic