$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Add-Type -AssemblyName System.IO.Compression

$Global:JarCache = @{}

Write-Host "--- BXO MOD ANALYZER ---" -ForegroundColor Cyan
Write-Host "JAR scan and cheat detection utility" -ForegroundColor Gray
Write-Host ""

$Patterns = @{
    "Cheats" = @(
        "net/minecraft/client/Minecraft;thePlayer", 
        "net/minecraft/network/play/client/C03PacketPlayer", 
        "killaura", "speedhack", "scaffold", "timerhack", "triggerbot", "flight"
    );
    "Mixins" = @(
        "Lnet/minecraft/client/entity/EntityPlayerSP;", 
        "Lnet/minecraft/network/NetworkManager;"
    )
}

function Get-JarData {
    param ([string]$JarPath)
    
    if ($Global:JarCache.ContainsKey($JarPath)) {
        return $Global:JarCache[$JarPath]
    }

    $FilesData = @{}
    $Stream = $null
    $Archive = $null
    
    try {
        $Stream = [System.IO.File]::Open($JarPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $Archive = New-Object System.IO.Compression.ZipArchive($Stream, [System.IO.Compression.ZipArchiveMode]::Read)
        
        foreach ($Entry in $Archive.Entries) {
            if ($Entry.FullName.EndsWith("/")) { continue }

            $EntryStream = $Entry.Open()
            $Reader = New-Object System.IO.BinaryReader($EntryStream)
            $Bytes = $Reader.ReadBytes($Entry.Length)
            $TextContent = [System.Text.Encoding]::UTF8.GetString($Bytes)
            
            $FilesData[$Entry.FullName] = @{ "Text" = $TextContent }
            
            $Reader.Close()
            $EntryStream.Close()
        }
    } catch {
        Write-Host "[-] Failed to decode JAR file: $JarPath" -ForegroundColor Red
    } finally {
        if ($null -ne $Archive) { $Archive.Dispose() }
        if ($null -ne $Stream) { $Stream.Dispose() }
    }
    
    if ($FilesData.Count -gt 0) {
        $Global:JarCache[$JarPath] = $FilesData
    }
    return $FilesData
}

function Start-BxoCheatAnalysis {
    param ([string]$JarPath)
    
    if (-not (Test-Path $JarPath)) {
        Write-Host "[-] File not found: $JarPath" -ForegroundColor Red
        return
    }

    $ModName = [System.IO.Path]::GetFileName($JarPath)
    Write-Host "--------------------------------------------------" -ForegroundColor Gray
    Write-Host " [*] Scanning: $ModName" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Gray

    $Reports = @()
    $CheatScore = 0

    $JarData = Get-JarData -JarPath $JarPath
    if ($JarData.Count -eq 0) {
        Write-Host "[-] Error: Empty or corrupted archive." -ForegroundColor Red
        return
    }

    $HasManifest = $false
    foreach ($FilePath in $JarData.Keys) {
        if ($FilePath -eq "META-INF/MANIFEST.MF") { $HasManifest = $true; break }
    }
    if (-not $HasManifest) {
        $Reports += "STRUCTURE: Missing MANIFEST.MF file."
    }

    $SuspiciousMixins = @()
    foreach ($File in $JarData.GetEnumerator()) {
        if ($File.Key -match "mixins?\..*json$") {
            foreach ($Target in $Patterns["Mixins"]) {
                if ($File.Value.Text -match $Target) {
                    $SuspiciousMixins += "Mixin: $($File.Key) -> Target: $Target"
                }
            }
        }
    }

    if ($SuspiciousMixins.Count -gt 0) {
        $CheatScore += 20
        foreach ($Mixin in $SuspiciousMixins) {
            $Reports += "INTERCEPTION: $Mixin"
        }
    }

    $CheatHits = @()
    foreach ($File in $JarData.GetEnumerator()) {
        if ($File.Key.EndsWith(".class")) {
            foreach ($Pattern in $Patterns["Cheats"]) {
                if ($File.Value.Text -match $Pattern) {
                    $CheatHits += "In $($File.Key) -> Match: $Pattern"
                }
            }
        }
    }

    if ($CheatHits.Count -gt 0) {
        $Multiplier = $CheatHits.Count
        if ($Multiplier -gt 4) { $Multiplier = 4 }
        $CheatScore += (20 * $Multiplier)
        
        $ShownHits = $CheatHits | Select-Object -First 4
        foreach ($Hit in $ShownHits) {
            $Reports += "CHEAT SIGNATURE: $Hit"
        }
        if ($CheatHits.Count -gt 4) {
            $Reports += "CHEAT SIGNATURE: ...and $($CheatHits.Count - 4) other matches."
        }
    }

    Show-CheatReport -ModName $ModName -CheatScore $CheatScore -Reports $Reports
}

function Show-CheatReport {
    param (
        [string]$ModName,
        [int]$CheatScore,
        [array]$Reports
    )

    if ($CheatScore -gt 100) { $CheatScore = 100 }

    $Color = "Green"
    $StatusText = "CLEAN (No Cheats Found)"
    if ($CheatScore -ge 30 -and $CheatScore -lt 65) {
        $Color = "Yellow"
        $StatusText = "SUSPICIOUS (Review recommended)"
    } elseif ($CheatScore -ge 65) {
        $Color = "Red"
        $StatusText = "CHEAT DETECTED (High confidence)"
    }

    Write-Host ""
    Write-Host "=== SCAN VERDICT ===" -ForegroundColor $Color
    Write-Host "Mod file: $ModName" -ForegroundColor White
    Write-Host "Status:   $StatusText" -ForegroundColor $Color
    Write-Host "Score:    $CheatScore / 100" -ForegroundColor $Color
    
    # Mostra i flag attivi direttamente dentro i dettagli del verdetto
    if ($Reports.Count -gt 0) {
        Write-Host "Active Flags:" -ForegroundColor $Color
        foreach ($Report in $Reports) {
            Write-Host "  -> $Report" -ForegroundColor LightRed
        }
    } else {
        Write-Host "Active Flags: None (Mod seems safe)" -ForegroundColor Green
    }
    Write-Host "====================" -ForegroundColor $Color
    Write-Host ""
}

Write-Host "Select option:" -ForegroundColor Cyan
Write-Host "1) Scan a single mod (.jar)"
Write-Host "2) Scan a folder"
Write-Host "3) Exit"
Write-Host ""
$Choice = Read-Host "Choice (1-3)"

if ($Choice -eq "1") {
    $FilePath = Read-Host "Enter the path of the .jar file"
    if ($FilePath) {
        $FilePath = $FilePath.Trim().Trim([char]34)
        Start-BxoCheatAnalysis -JarPath $FilePath
    }
} 
elseif ($Choice -eq "2") {
    $Folder = Read-Host "Enter the folder path"
    if ($Folder) {
        $Folder = $Folder.Trim().Trim([char]34)
        if (Test-Path $Folder) {
            $Files = Get-ChildItem -Path $Folder -Filter "*.jar"
            if ($Files.Count -eq 0) {
                Write-Host "[-] No .jar files found in this folder." -ForegroundColor Yellow
            } else {
                Write-Host "[+] Found $($Files.Count) files to scan." -ForegroundColor Green
                foreach ($File in $Files) {
                    Start-BxoCheatAnalysis -JarPath $File.FullName
                }
            }
        } else {
            Write-Host "[-] Folder not found." -ForegroundColor Red
        }
    }
} 
else {
    Write-Host "[*] Exiting." -ForegroundColor Cyan
}

Write-Host ""
Read-Host "Press ENTER to close..."
