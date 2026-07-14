$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Add-Type -AssemblyName System.IO.Compression

$Global:JarCache = @{}

Write-Host "--- BXO MOD ANALYZER ---" -ForegroundColor Cyan
Write-Host "Utility di scansione per file .jar" -ForegroundColor Gray
Write-Host ""

$Patterns = @{
    "Cheats" = @(
        "net/minecraft/client/Minecraft;thePlayer", 
        "net/minecraft/network/play/client/C03PacketPlayer", 
        "bypass", "reach", "killaura", "flight", "autoclicker", "velocity", 
        "speedhack", "aimbot", "esp", "xray", "noslow", "phase", "scaffold",
        "PacketEvent", "PlayerPackets", "noFall", "criticals", "fastbow",
        "superhero", "timerhack", "triggerbot", "blink", "jesusfloat"
    );
    "Mixins" = @(
        "Lnet/minecraft/client/entity/EntityPlayerSP;", 
        "Lnet/minecraft/network/NetworkManager;", 
        "Lnet/minecraft/client/multiplayer/PlayerControllerMP;",
        "Lnet/minecraft/client/network/NetHandlerPlayClient;"
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
        Write-Host "[-] Impossibile decodificare il file JAR: $JarPath" -ForegroundColor Red
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
        Write-Host "[-] File non trovato: $JarPath" -ForegroundColor Red
        return
    }

    $ModName = [System.IO.Path]::GetFileName($JarPath)
    Write-Host "--------------------------------------------------" -ForegroundColor Gray
    Write-Host " [*] Analisi avviata su: $ModName" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Gray

    $Reports = @()
    $CheatScore = 0

    $JarData = Get-JarData -JarPath $JarPath
    if ($JarData.Count -eq 0) {
        Write-Host "[-] Errore: Archivio vuoto o corrotto." -ForegroundColor Red
        return
    }

    $HasManifest = $false
    foreach ($FilePath in $JarData.Keys) {
        if ($FilePath -eq "META-INF/MANIFEST.MF") { $HasManifest = $true; break }
    }
    if (-not $HasManifest) {
        $Reports += "STRUTTURA: MANIFEST.MF mancante. Potrebbe non essere una mod standard."
    }

    $SuspiciousMixins = @()
    foreach ($File in $JarData.GetEnumerator()) {
        if ($File.Key -match "mixins?\..*json$") {
            foreach ($Target in $Patterns["Mixins"]) {
                if ($File.Value.Text -match $Target) {
                    $SuspiciousMixins += "Mixin: $($File.Key) -> Target class: $Target"
                }
            }
        }
    }

    if ($SuspiciousMixins.Count -gt 0) {
        $CheatScore += 45
        foreach ($Mixin in $SuspiciousMixins) {
            $Reports += "INTERCETTAZIONE: $Mixin (Modifica dei pacchetti nativi)."
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
        if ($Multiplier -gt 5) { $Multiplier = 5 }
        $CheatScore += (15 * $Multiplier)
        
        $ShownHits = $CheatHits | Select-Object -First 5
        foreach ($Hit in $ShownHits) {
            $Reports += "MODULO CHEAT: $Hit"
        }
        if ($CheatHits.Count -gt 5) {
            $Reports += "MODULO CHEAT: ...e altri $($CheatHits.Count - 5) rilevamenti."
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
    $StatusText = "PULITO (Nessun Cheat Rilevato)"
    if ($CheatScore -ge 20 -and $CheatScore -lt 50) {
        $Color = "Yellow"
        $StatusText = "SOSPETTO (Rilevate possibili stringhe modificate)"
    } elseif ($CheatScore -ge 50) {
        $Color = "Red"
        $StatusText = "CHEAT RILEVATO (Presenza di moduli di hack)"
    }

    Write-Host ""
    Write-Host "=== VERDETTO ANTICHEAT ===" -ForegroundColor $Color
    Write-Host "Mod analizzata: $ModName" -ForegroundColor White
    Write-Host "Stato minaccia: $StatusText" -ForegroundColor $Color
    Write-Host "Punteggio di sospetto: $CheatScore / 100" -ForegroundColor $Color
    Write-Host "==========================" -ForegroundColor $Color

    if ($Reports.Count -eq 0) {
        Write-Host "  [+] Nessuna stringa sospetta trovata. La mod sembra sicura." -ForegroundColor Green
    } else {
        Write-Host "  [!] RILEVAMENTI DETTAGLIATI:" -ForegroundColor Yellow
        foreach ($Report in $Reports) {
            Write-Host "  [-] $Report" -ForegroundColor LightRed
        }
    }
    Write-Host ""
}

Write-Host "Seleziona opzione:" -ForegroundColor Cyan
Write-Host "1) Analizza una singola mod (.jar)"
Write-Host "2) Analizza una cartella intera"
Write-Host "3) Esci"
Write-Host ""
$Choice = Read-Host "Scegli (1-3)"

if ($Choice -eq "1") {
    $FilePath = Read-Host "Inserisci il percorso del file .jar"
    if ($FilePath) {
        $FilePath = $FilePath.Trim().Trim([char]34)
        Start-BxoCheatAnalysis -JarPath $FilePath
    }
} 
elseif ($Choice -eq "2") {
    $Folder = Read-Host "Inserisci il percorso della cartella"
    if ($Folder) {
        $Folder = $Folder.Trim().Trim([char]34)
        if (Test-Path $Folder) {
            $Files = Get-ChildItem -Path $Folder -Filter "*.jar"
            if ($Files.Count -eq 0) {
                Write-Host "[-] Nessun file .jar trovato nella cartella." -ForegroundColor Yellow
            } else {
                Write-Host "[+] Trovati $($Files.Count) file da scansionare." -ForegroundColor Green
                foreach ($File in $Files) {
                    Start-BxoCheatAnalysis -JarPath $File.FullName
                }
            }
        } else {
            Write-Host "[-] Cartella non trovata." -ForegroundColor Red
        }
    }
} 
else {
    Write-Host "[*] Uscita." -ForegroundColor Cyan
}

Write-Host ""
Read-Host "Premi INVIO per uscire..."
