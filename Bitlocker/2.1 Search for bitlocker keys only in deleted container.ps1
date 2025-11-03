# -------------------------------------------------
# Search ONLY Deleted AD BitLocker Keys for GUID/ID fragment
# -------------------------------------------------

Import-Module ActiveDirectory

# --- Prompt for the fragment / ID to search ---
$SearchGuid = Read-Host "Enter the BitLocker GUID fragment or any ID to search for (e.g., 0890C1D0)"
if (-not $SearchGuid) {
    Write-Host "No input provided. Exiting." -ForegroundColor Red
    exit
}
$SearchGuid = $SearchGuid.Trim().ToUpper()

Write-Host "Searching Deleted Objects container for '$SearchGuid'..." -ForegroundColor Cyan

# Get Domain and Deleted Objects DN
$Domain          = Get-ADDomain
$DeletedObjectsDN = "CN=Deleted Objects,$($Domain.DistinguishedName)"

# -------------------------------------------------
# Search DELETED msFVE-RecoveryInformation objects only
# -------------------------------------------------
$DeletedKeys = Get-ADObject `
    -SearchBase $DeletedObjectsDN `
    -IncludeDeletedObjects `
    -Filter "objectClass -eq 'msFVE-RecoveryInformation' -and isDeleted -eq `$true" `
    -Properties msFVE-RecoveryGuid, msFVE-RecoveryPassword, Name, DistinguishedName, Description, ObjectGUID

Write-Host "Found $($DeletedKeys.Count) deleted BitLocker key(s). Scanning..." -ForegroundColor Yellow

$Matches = foreach ($Key in $DeletedKeys) {
    # Convert byte[] GUID to readable string
    $GuidStr = if ($Key.'msFVE-RecoveryGuid') {
        (New-Object Guid (,$Key.'msFVE-RecoveryGuid')).ToString().ToUpper()
    } else { "" }

    # All fields we want to scan
    $SearchValues = @(
        $Key.Name
        $Key.DistinguishedName
        $Key.'msFVE-RecoveryPassword'
        $Key.Description
        $GuidStr
        $Key.ObjectGUID.ToString()
    ) | Where-Object { $_ }

    # Look for the fragment (case-insensitive)
    $MatchedIn = $SearchValues |
                 Where-Object { $_ -match [regex]::Escape($SearchGuid) } |
                 ForEach-Object { "$_".Substring(0, [Math]::Min(80, $_.Length)) + "..." }

    if ($MatchedIn) {
        [PSCustomObject]@{
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
# Output results
# -------------------------------------------------
if ($Matches) {
    Write-Host "`nFound $($Matches.Count) match(es) in Deleted Objects:`n" -ForegroundColor Green
    $Matches | Format-List   # Full detail, no truncation

    # Export to Desktop
    $CsvPath = "$env:USERPROFILE\Desktop\BitLocker_Deleted_$SearchGuid.csv"
    $Matches | Export-Csv -Path $CsvPath -NoTypeInformation
    Write-Host "Exported to: $CsvPath" -ForegroundColor Yellow
}
else {
    Write-Host "No matches found for '$SearchGuid' in the Deleted Objects container." -ForegroundColor Red
}
