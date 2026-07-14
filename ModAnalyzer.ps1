# ==============================================================================
#                     BXO CHEAT ANALYZER - MINECRAFT ONLY
# ==============================================================================
# Autore: BXO Staff Tool
# Descrizione: Analizzatore specifico per rilevare moduli hack e cheat nei .jar
# ==============================================================================

# Configurazione Console
$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

# Carica le librerie per la gestione dei file ZIP (i JAR sono archivi ZIP)
Add-Type -AssemblyName System.IO.Compression

# Cache globale per evitare di rileggere i file più volte
$Global:JarCache = @{}

# ==============================================================================
# 1. INTERFACCIA GRAFICA
# ==============================================================================
Write-Host @"
██████╗ ██╗  ██╗ ██████╗      ██████╗██╗  ██╗███████╗ █████╗ ████████╗
██╔══██╗╚██╗██╔╝██╔═══██╗    ██╔════╝██║  ██║██╔════╝██╔══██╗╚══██╔══╝
██████╔╝ ╚███╔╝ ██║   ██║    ██║     ███████║█████╗  ███████║   ██║   
██╔══██╗ ██╔██╗ ██║   ██║    ██║     ██╔══██║██╔══╝  ██╔══██║   ██║   
██████╔╝██╔╝ ██╗╚██████╔╝    ╚██████╗██║  ██║███████╗██║  ██║   ██║   
╚══════╝ ╚═╝  ╚═╝ ╚═════╝     ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   
                                              [ Powered by BXO Tools ]
"@ -ForegroundColor Cyan

Write-Host "=======================================================================================================================" -ForegroundColor Gray
Write-Host " [!] Questo tool analizza i file .jar alla ricerca ESCLUSIVA di Cheat, Hack e Client modificati." -ForegroundColor Yellow
Write-Host "=======================================================================================================================" -ForegroundColor Gray
Write-Host ""


$Patterns = @{
    # Stringhe e metodi tipici dei moduli cheat di movimento, combattimento e render
    "Cheats" = @(
        "net/minecraft/client/Minecraft;thePlayer", 
        "net/minecraft/network/play/client/C03PacketPlayer", 
        "bypass", "reach", "killaura", "flight", "autoclicker", "velocity", 
        "speedhack", "aimbot", "esp", "xray", "noslow", "phase", "scaffold",
        "PacketEvent", "PlayerPackets", "noFall", "criticals", "fastbow",
        "superhero", "timerhack", "triggerbot", "blink", "jesusfloat"
    );
    # Mixin invasivi che modificano il comportamento nativo del player o della rete
    "Mixins" = @(
        "Lnet/minecraft/client/entity/EntityPlayerSP;", 
        "Lnet/minecraft/network/NetworkManager;", 
        "Lnet/minecraft/client/multiplayer/PlayerControllerMP;",
        "Lnet/minecraft/client/network/NetHandlerPlayClient;"
    )
}

# ==============================================================================
# Support Functions
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
        Write-Host "[-] Impossibile decodificare il file JAR: $JarPath" -ForegroundColor Red
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
    Write-Host "-----------------------------------------------------------------------------------------------------------------------" -ForegroundColor Gray
    Write-Host " [*] Scansion start on: " -NoNewline
    Write-Host $ModName -ForegroundColor Cyan -Bold
    Write-Host "-----------------------------------------------------------------------------------------------------------------------" -ForegroundColor Gray

    $Reports = @()
    $CheatScore = 0

    # Carica in memoria il JAR
    $JarData = Get-JarData -JarPath $JarPath
    if ($JarData.Count -eq 0) {
        Write-Host "[-] Errore: Archivio vuoto o corrotto." -ForegroundColor Red
        return
    }


    Write-Host " [1/3] Analisi della struttura del file..." -ForegroundColor White
    $HasManifest = $false
    foreach ($FilePath in $JarData.Keys) {
        if ($FilePath -eq "META-INF/MANIFEST.MF") { $HasManifest = $true; break }
    }
    if (-not $HasManifest) {
        $Reports += "STRUTTURA: File MANIFEST.MF mancante. Potrebbe non essere una mod valida."
    }

    # --------------------------------------------------------------------------
    # PASSAGGIO 2: Analising Suspect Mixin 
    # --------------------------------------------------------------------------
    Write-Host " [2/3] Analisi dei Mixin (Modifiche al Player o alla Rete)..." -ForegroundColor White
    $SuspiciousMixins = @()
    
    foreach ($File in $JarData.GetEnumerator()) {
        if ($File.Key -match "mixins?\..*json$") {
            foreach ($Target in $Patterns["Mixins"]) {
                if ($File.Value.Text -match $Target) {
                    $SuspiciousMixins += "Mixin: $($File.Key) -> Modifica la classe: $Target"
                }
            }
        }
    }

    if ($SuspiciousMixins.Count -gt 0) {
        # Modificare direttamente le classi di movimento o invio pacchetti è tipico dei cheat
        $CheatScore += 45
        foreach ($Mixin in $SuspiciousMixins) {
            $Reports += "INTERCETTAZIONE GIOCO: $Mixin (Rilevata modifica diretta al comportamento del giocatore o della connessione)."
        }
    }

  
    Write-Host " [3/3] Ricerca firme e stringhe di Cheat conosciuti..." -ForegroundColor White
    $CheatHits = @()
    foreach ($File in $JarData.GetEnumerator()) {
        if ($File.Key.EndsWith(".class")) {
            foreach ($Pattern in $Patterns["Cheats"]) {
                if ($File.Value.Text -match $Pattern) {
                    $CheatHits += "In $($File.Key) -> Trovato riferimento a '$Pattern'"
                }
            }
        }
    }

    if ($CheatHits.Count -gt 0) {
        # Aumenta il punteggio in base al numero di moduli cheat rilevati
        $Multiplier = $CheatHits.Count
        if ($Multiplier -gt 5) { $Multiplier = 5 }
        $CheatScore += (15 * $Multiplier)
        
        # Mostra solo i primi 5 cheat per non intasare lo schermo, ma segnala il totale
        $ShownHits = $CheatHits | Select-Object -First 5
        foreach ($Hit in $ShownHits) {
            $Reports += "MODULO CHEAT: $Hit"
        }
        if ($CheatHits.Count -gt 5) {
            $Reports += "MODULO CHEAT: ...e altre $($CheatHits.Count - 5) stringhe collegate a hack rilevate."
        }
    }

    # Mostra i risultati finali focalizzati sui Cheat
    Show-CheatReport -ModName $ModName -CheatScore $CheatScore -Reports $Reports
}


function Show-CheatReport {
    param (
        [string]$ModName,
        [int]$CheatScore,
        [array]$Reports
    )

    if ($CheatScore -gt 100) { $CheatScore = 100 }

    # Colore in base al livello di cheat rilevato
    $Color = "Green"
    $StatusText = "PULITA (Nessun Cheat Rilevato)"
    if ($CheatScore -ge 20 -and $CheatScore -lt 50) {
        $Color = "Yellow"
        $StatusText = "SOSPETTA (Possibili moduli di Hack/Cheat non confermati)"
    } elseif ($CheatScore -ge 50) {
        $Color = "Red"
        $StatusText = "CHEAT RILEVATO (Contiene moduli Hack palesi)"
    }

    Write-Host ""
    Write-Host "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor $Color
    Write-Host "│                                 RESULT                                   │" -ForegroundColor $Color
    Write-Host "├───────────────────────────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor $Color
    Write-Host "  » Mod Scansionata: $ModName" -ForegroundColor White
    Write-Host "  » Stato Rilevato:  $StatusText" -ForegroundColor $Color -Bold
    Write-Host "  » Indice Sospetto: [ $CheatScore / 100 ]" -ForegroundColor $Color
    Write-Host "├───────────────────────────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor $Color

    if ($Reports.Count -eq 0) {
        Write-Host "  [+] Nessuna stringa o configurazione di cheat è stata trovata." -ForegroundColor Green
        Write-Host "  [+] La mod sembra regolare e conforme." -ForegroundColor Green
    } else {
        Write-Host "  [!] DETTAGLIO RILEVAMENTI CHEAT:" -ForegroundColor Yellow
        foreach ($Report in $Reports) {
            Write-Host "  [-] $Report" -ForegroundColor LightRed
        }
    }
    Write-Host "└───────────────────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor $Color
    Write-Host ""
}

# ==============================================================================
# MENU
# ==============================================================================
Write-Host "Come vuoi procedere?" -ForegroundColor Cyan
Write-Host "1) Analizza un singolo file .jar"
Write-Host "2) Analizza un'intera cartella (es. la cartella 'mods')"
Write-Host "3) Esci"
Write-Host ""
$Choice = Read-Host "Scegli un'opzione (1-3)"

if ($Choice -eq "1") {
    $FilePath = Read-Host "Inserisci o trascina qui il percorso del file .jar da analizzare"
    $FilePath = $FilePath.Replace('"', '').Trim()
    Start-BxoCheatAnalysis -JarPath $FilePath
} 
elseif ($Choice -eq "2") {
    $Folder = Read-Host "Inserisci il percorso della cartella da analizzare"
    $Folder = $Folder.Replace('"', '').Trim()
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
else {
    Write-Host "[*] Chiusura del programma." -ForegroundColor Cyan
}

Write-Host ""
Read-Host "Premi INVIO per uscire..."