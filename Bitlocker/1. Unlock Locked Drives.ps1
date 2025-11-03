#Requires -RunAsAdministrator

# Get all locked data volumes
$LockedVolumes = Get-BitLockerVolume | Where-Object {
    $_.VolumeType -eq 'Data' -and $_.LockStatus -eq 'Locked'
}

if (-not $LockedVolumes) {
    Write-Host "No locked data volumes found." -ForegroundColor Green
    return
}

foreach ($Vol in $LockedVolumes) {
    $Drive = $Vol.MountPoint
    Write-Host "`nProcessing: $Drive" -ForegroundColor Cyan

    # Find RecoveryPassword protectors
    $RecProt = $Vol.KeyProtector | Where-Object {
        $_.KeyProtectorType -eq 'RecoveryPassword'
    }

    if (-not $RecProt) {
        Write-Warning "No recovery password on $Drive. Skipping."
        continue
    }

    foreach ($Prot in $RecProt) {
        $Id = $Prot.KeyProtectorId.Split('{')[1].Split('}')[0].Substring(0,8).ToUpper()

        $Password = Read-Host "Enter password for $Id ($Drive)" -MaskInput

        if ([string]::IsNullOrWhiteSpace($Password)) {
            Write-Warning "Empty password. Skipping."
            continue
        }

        try {
            Unlock-BitLocker -MountPoint $Drive -RecoveryPassword $Password
            Write-Host "$Drive UNLOCKED with $Id" -ForegroundColor Green
            break  # Success → stop trying others
        }
        catch {
            Write-Warning "Failed with $Id — wrong password?"
        }
    }
}
