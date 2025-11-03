Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "OSActiveDirectoryBackup" -Value 1 -Type DWORD
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\FVE" -Name "OSRecovery" -Value 1 -Type DWORD
# Enable BitLocker with TPM protector only (encrypts used space only for speed; change to -TpmAndPINProtector if PIN needed, but that would require input)
Enable-BitLocker -MountPoint "C:" -EncryptionMethod XtsAes256 -UsedSpaceOnly -SkipHardwareTest -TpmProtector

# Add a recovery password protector (generates a random 48-digit key if not specified)
Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector

# Back up the recovery password key protector to Active Directory
$BLV = Get-BitLockerVolume -MountPoint "C:"
$KeyProtectorID = ($BLV.KeyProtector | Where-Object {$_.KeyProtectorType -eq "RecoveryPassword"}).KeyProtectorId
Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $KeyProtectorID
