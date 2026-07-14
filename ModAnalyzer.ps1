# ==============================================================================
#                     BXO CHEAT ANALYZER - MINECRAFT ONLY
# ==============================================================================
# Author: BXO Staff
# Description: Custom utility to scan .jar files for movement and combat hacks.
# ==============================================================================

$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

Add-Type -AssemblyName System.IO.Compression

$Global:JarCache = @{}

# ==============================================================================
# 1. USER INTERFACE
# ==============================================================================
Write-Host "██████╗ ██╗  ██╗ ██████╗      ██████╗██╗  ██╗███████╗ █████╗ ████████╗" -ForegroundColor Cyan
Write-Host "██╔══██╗╚██╗██╔╝██╔═══██╗    ██╔════╝██║  ██║██╔════╝██╔══██╗╚══██╔══╝" -ForegroundColor Cyan
Write-Host "██████╔╝ ╚███╔╝ ██║   ██║    ██║     ███████║█████╗  ███████║   ██║   " -ForegroundColor Cyan
Write-Host "██╔══██╗ ██╔██╗ ██║   ██║    ██║     ██╔══██║██╔══╝  ██╔══██║   ██║   " -ForegroundColor Cyan
Write-Host "██████╔╝██╔╝ ██╗╚██████╔╝    ╚██████╗██║  ██║███████╗██║  ██║   ██║   " -ForegroundColor Cyan
Write-Host "╚══════╝ ╚═╝  ╚═╝ ╚═════╝     ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   " -ForegroundColor Cyan
Write-Host "                                              [ Powered by BXO Tools ]" -ForegroundColor Cyan

Write-Host "=======================================================================================================================" -ForegroundColor Gray
Write-Host " [!] This tool analyzes .jar files EXCLUSIVELY for Cheats, Hacks, and modified clients." -ForegroundColor Yellow
Write-Host "=======================================================================================================================" -ForegroundColor Gray
Write-Host ""

# ==============================================================================
# 2. SIGNATURE DATABASE
# ==============================================================================
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

# ==============================================================================
# 3. HELPER FUNCTIONS
# ==============================================================================
function Get-JarData {
    param ([string]$JarPath)
    
    if ($Global:JarCache.ContainsKey($JarPath)) {
        return $Global:JarCache[$JarPath]
    }

    $FilesData = @{}
    try {
        $Archive = [System.IO.Compression.ZipFile]::Open($JarPath, [System.IO.Compression.ZipArchiveMode]::Read)
        foreach ($Entry in $Archive.Entries) {
            if ($Entry.FullName.EndsWith("/")) { continue }

            $Stream = $Entry.Open()
            $Reader = New-Object System.IO.BinaryReader($Stream)
            $Bytes = $Reader.ReadBytes($Entry.Length)
            $TextContent = [System.Text.Encoding]::UTF8.GetString($Bytes)
            
            $FilesData[$Entry.FullName] = @{
                "Text"  = $TextContent
            }
            
            $Reader.Close()
            $Stream.Close()
        }
        $Archive.Dispose()
        $Global:JarCache[$JarPath] = $FilesData
    } catch {
        Write-Host "[-] Failed to decode JAR file: $JarPath" -ForegroundColor Red
    }
    
    return $FilesData
}

# ==============================================================================
# 4. CORE ENGINE
# ==============================================================================
function Start-BxoCheatAnalysis {
    param ([string]$JarPath)
    
    if (-not (Test-Path $JarPath)) {
        Write-Host "[-] File not found: $JarPath" -ForegroundColor Red
        return
    }

    $ModName = [System.IO.Path]::GetFileName($JarPath)
    Write-Host "-----------------------------------------------------------------------------------------------------------------------" -ForegroundColor Gray
    Write-Host " [*] STARTING SCAN ON: " -NoNewline
    Write-Host $ModName -ForegroundColor Cyan -Bold
    Write-Host "-----------------------------------------------------------------------------------------------------------------------" -ForegroundColor Gray

    $Reports = @()
    $CheatScore = 0

    $JarData = Get-JarData -JarPath $JarPath
    if ($JarData.Count -eq 0) {
        Write-Host "[-] Error: Empty or corrupted archive." -ForegroundColor Red
        return
    }

    # PASS 1: Base Integrity
    Write-Host " [1/3] Analyzing file structure..." -ForegroundColor White
    $HasManifest = $false
    foreach ($FilePath in $JarData.Keys) {
        if ($FilePath -eq "META-INF/MANIFEST.MF") { $HasManifest = $true; break }
    }
    if (-not $HasManifest) {
        $Reports += "STRUCTURE: Missing MANIFEST.MF file. Might not be a standard mod."
    }

    # PASS 2: Mixin Injection Checks
    Write-Host " [2/3] Checking Mixin injections (Player & Network modifications)..." -ForegroundColor White
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
            $Reports += "GAME INTERCEPTION: $Mixin (Direct modification to native client/player packets)."
        }
    }

    # PASS 3: Known Cheat Signatures
    Write-Host " [3/3] Scanning for known cheat strings..." -ForegroundColor White
    $CheatHits = @()
    foreach ($File in $JarData.GetEnumerator()) {
        if ($File.Key.EndsWith(".class")) {
            foreach ($Pattern in $Patterns["Cheats"]) {
                if ($File.Value.Text -match $Pattern) {
                    $CheatHits += "In $($File.Key) -> Match: '$Pattern'"
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
            $Reports += "CHEAT MODULE: $Hit"
        }
        if ($CheatHits.Count -gt 5) {
            $Reports += "CHEAT MODULE: ...and $($CheatHits.Count - 5) other cheat-related signatures detected."
        }
    }

    Show-CheatReport -ModName $ModName -CheatScore $CheatScore -Reports $Reports
}

# ==============================================================================
# 5. SCAN REPORT GENERATION
# ==============================================================================
function Show-CheatReport {
    param (
        [string]$ModName,
        [int]$CheatScore,
        [array]$Reports
    )

    if ($CheatScore -gt 100) { $CheatScore = 100 }

    $Color = "Green"
    $StatusText = "CLEAN (No Cheats Detected)"
    if ($CheatScore -ge 20 -and $CheatScore -lt 50) {
        $Color = "Yellow"
        $StatusText = "SUSPICIOUS (Unconfirmed cheat modules/references)"
    } elseif ($CheatScore -ge 50) {
        $Color = "Red"
        $StatusText = "CHEAT DETECTED (Definite hack/cheat modules)"
    }

    Write-Host ""
    Write-Host "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor $Color
    Write-Host "│                                     ANTICHEAT SCAN VERDICT                                        │" -ForegroundColor $Color
    Write-Host "├───────────────────────────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor $Color
    Write-Host "  » Scanned Mod:    $ModName" -ForegroundColor White
    Write-Host "  » Threat Status:  $StatusText" -ForegroundColor $Color -Bold
    Write-Host "  » Suspicion Score:[ $CheatScore / 100 ]" -ForegroundColor $Color
    Write-Host "├───────────────────────────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor $Color

    if ($Reports.Count -eq 0) {
        Write-Host "  [+] No suspicious strings or cheat configurations found." -ForegroundColor Green
        Write-Host "  [+] This mod appears to be regular and safe to use." -ForegroundColor Green
    } else {
        Write-Host "  [!] DETAILED DETECTIONS:" -ForegroundColor Yellow
        foreach ($Report in $Reports) {
            Write-Host "  [-] $Report" -ForegroundColor LightRed
        }
    }
    Write-Host "└───────────────────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor $Color
    Write-Host ""
}

# ==============================================================================
# 6. MENU INTERACTION
# ==============================================================================
Write-Host "How do you want to proceed?" -ForegroundColor Cyan
Write-Host "1) Analyze a single .jar file"
Write-Host "2) Analyze an entire folder (e.g. 'mods' folder)"
Write-Host "3) Exit"
Write-Host ""
$Choice = Read-Host "Choose an option (1-3)"

if ($Choice -eq "1") {
    $FilePath = Read-Host "Enter or drag & drop the .jar file path here"
    if ($FilePath) {
        # Clean quotes using ASCII 34 to completely prevent parsing conflicts
        $FilePath = $FilePath.Trim().Trim([char]34)
        Start-BxoCheatAnalysis -JarPath $FilePath
    }
} 
elseif ($Choice -eq "2") {
    $Folder = Read-Host "Enter the folder path to analyze"
    if ($Folder) {
        # Clean quotes using ASCII 34 to completely prevent parsing conflicts
        $Folder = $Folder.Trim().Trim([char]34)
        if (Test-Path $Folder) {
            $Files = Get-ChildItem -Path $Folder -Filter "*.jar"
            if ($Files.Count -eq 0) {
                Write-Host "[-] No .jar files found in the folder." -ForegroundColor Yellow
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
    Write-Host "[*] Exiting program." -ForegroundColor Cyan
}

Write-Host ""
Read-Host "Press ENTER to exit..."
