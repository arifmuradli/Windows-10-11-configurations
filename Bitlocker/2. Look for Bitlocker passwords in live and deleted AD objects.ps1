# -------------------------------------------------
# Search AD BitLocker Keys (Live + Deleted) for GUID fragment
# -------------------------------------------------

Import-Module ActiveDirectory

# --- CHANGE 1: Prompt user for GUID fragment ---
$SearchGuid = Read-Host "Enter the BitLocker GUID fragment to search for (e.g., 0890C1D0)"
if (-not $SearchGuid) {
    Write-Host "No input provided. Exiting." -ForegroundColor Red
    exit
}
$SearchGuid = $SearchGuid.Trim().ToUpper()

Write-Host "Searching for GUID fragment: '$SearchGuid'" -ForegroundColor Cyan

# Get Domain info
$Domain = Get-ADDomain
$DeletedObjectsDN = "CN=Deleted Objects,$($Domain.DistinguishedName)"

# Initialize results array
$AllMatches = @()

# -------------------------------------------------
# 1. Search LIVE (non-deleted) msFVE-RecoveryInformation objects
# -------------------------------------------------
Write-Host "Searching live AD objects..." -ForegroundColor Cyan

$LiveKeys = Get-ADObject `
    -Filter "objectClass -eq 'msFVE-RecoveryInformation'" `
    -Properties msFVE-RecoveryGuid, msFVE-RecoveryPassword, Name, DistinguishedName, Description, ObjectGUID

Write-Host "Found $($LiveKeys.Count) live BitLocker key(s). Scanning..." -ForegroundColor Yellow

foreach ($Key in $LiveKeys) {
    $GuidStr = if ($Key.'msFVE-RecoveryGuid') {
        (New-Object Guid (,$Key.'msFVE-RecoveryGuid')).ToString().ToUpper()
    } else { "" }

    $SearchValues = @(
        $Key.Name
        $Key.DistinguishedName
        $Key.'msFVE-RecoveryPassword'
        $Key.Description
        $GuidStr
        $Key.ObjectGUID.ToString()
    ) | Where-Object { $_ }

    $MatchedIn = $SearchValues | Where-Object { $_ -match $SearchGuid } | ForEach-Object { 
        "$_".Substring(0, [Math]::Min(80, $_.Length)) + "..." 
    }

    if ($MatchedIn) {
        $AllMatches += [PSCustomObject]@{
            Status           = "LIVE"
            Name             = $Key.Name
            DistinguishedName= $Key.DistinguishedName
            ObjectGUID       = $Key.ObjectGUID
            RecoveryGuid     = $GuidStr
            RecoveryPassword = $Key.'msFVE-RecoveryPassword'
            MatchedIn        = ($MatchedIn -join " | ")
        }
    }
}

# -------------------------------------------------
# 2. Search DELETED msFVE-RecoveryInformation objects
# -------------------------------------------------
Write-Host "Searching Deleted Objects container..." -ForegroundColor Cyan

$DeletedKeys = Get-ADObject `
    -SearchBase $DeletedObjectsDN `
    -IncludeDeletedObjects `
    -Filter "objectClass -eq 'msFVE-RecoveryInformation' -and isDeleted -eq `$true" `
    -Properties msFVE-RecoveryGuid, msFVE-RecoveryPassword, Name, DistinguishedName, Description, ObjectGUID

Write-Host "Found $($DeletedKeys.Count) deleted BitLocker key(s). Scanning..." -ForegroundColor Yellow

foreach ($Key in $DeletedKeys) {
    $GuidStr = if ($Key.'msFVE-RecoveryGuid') {
        (New-Object Guid (,$Key.'msFVE-RecoveryGuid')).ToString().ToUpper()
    } else { "" }

    $SearchValues = @(
        $Key.Name
        $Key.DistinguishedName
        $Key.'msFVE-RecoveryPassword'
        $Key.Description
        $GuidStr
        $Key.ObjectGUID.ToString()
    ) | Where-Object { $_ }

    $MatchedIn = $SearchValues | Where-Object { $_ -match $SearchGuid } | ForEach-Object { 
        "$_".Substring(0, [Math]::Min(80, $_.Length)) + "..." 
    }

    if ($MatchedIn) {
        $AllMatches += [PSCustomObject]@{
            Status           = "DELETED"
            Name             = $Key.Name
            DistinguishedName= $Key.DistinguishedName
            ObjectGUID       = $Key.ObjectGUID
            RecoveryGuid     = $GuidStr
            RecoveryPassword = $Key.'msFVE-RecoveryPassword'
            MatchedIn        = ($MatchedIn -join " | ")
        }
    }
}

# -------------------------------------------------
# Output Results
# -------------------------------------------------
if ($AllMatches) {
    Write-Host "`nFound $($AllMatches.Count) match(es) across live and deleted objects:`n" -ForegroundColor Green
    $AllMatches | Format-Table Status, Name, RecoveryGuid, RecoveryPassword, MatchedIn -Wrap

    # Export to Desktop
    $CsvPath = "$env:USERPROFILE\Desktop\BitLocker_Search_$SearchGuid.csv"
    $AllMatches | Export-Csv -Path $CsvPath -NoTypeInformation
    Write-Host "`nExported results to: $CsvPath" -ForegroundColor Yellow
} else {
    Write-Host "`nNo matches found for GUID fragment '$SearchGuid' in live or deleted objects." -ForegroundColor Red
}
