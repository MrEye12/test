# Startet die Brücke: Roblox Studio MCP -> HTTP (supergateway) -> SSH-Tunnel -> blackair.dev
#
# Voraussetzungen auf deinem PC:
#   - Roblox Studio offen, Roblox-MCP-Plugin aktiv
#   - Node.js installiert (für npx)
#   - SSH-Alias für deinen Server in ~/.ssh/config (mit echter IP, User und Key)
#
# Start:  powershell -ExecutionPolicy Bypass -File .\start-bridge.ps1

# === ANPASSEN ===
# Pfad zur Roblox-MCP-Exe (steht in der Anleitung von Roblox bzw. in der
# Claude-Desktop-Config, die der Roblox-Installer angelegt hat).
$RobloxMcpExe = "$env:LOCALAPPDATA\Roblox\rbx-studio-mcp.exe"

# SSH-Alias aus ~/.ssh/config. NICHT "user@blackair.dev": die Domain zeigt auf
# Cloudflare, und Cloudflare leitet Port 22 nicht weiter.
$ServerLogin = "blackair"
$Port        = 8808   # muss zur nginx-Config passen
# ================

# --- Vorprüfungen ---
if (-not (Test-Path $RobloxMcpExe)) {
    Write-Host "Roblox-MCP nicht gefunden: $RobloxMcpExe" -ForegroundColor Red
    Write-Host "Trage oben in `$RobloxMcpExe den richtigen Pfad ein." -ForegroundColor Red
    exit 1
}
if ($RobloxMcpExe -match ' ') {
    Write-Host "Der Pfad enthält Leerzeichen, das mag supergateway nicht. Kopier die Exe in einen Ordner ohne Leerzeichen." -ForegroundColor Red
    exit 1
}
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
    Write-Host "Port $Port ist schon belegt (läuft die Brücke schon?)." -ForegroundColor Red
    exit 1
}
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Host "npx nicht gefunden. Bitte Node.js installieren: https://nodejs.org" -ForegroundColor Red
    exit 1
}

# --- supergateway starten ---
Write-Host "Starte supergateway auf Port $Port ..." -ForegroundColor Cyan
$gatewayCmd = "npx -y supergateway --stdio '$RobloxMcpExe --stdio' --outputTransport streamableHttp --port $Port"
Start-Process powershell -ArgumentList @("-NoExit", "-Command", $gatewayCmd)

# Warten, bis der Port wirklich lauscht (beim ersten Start lädt npx noch)
$deadline = (Get-Date).AddSeconds(120)
while (-not (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)) {
    if ((Get-Date) -gt $deadline) {
        Write-Host "supergateway lauscht nach 120 s immer noch nicht auf Port $Port. Schau ins andere Fenster." -ForegroundColor Red
        exit 1
    }
    Start-Sleep -Seconds 1
}
Write-Host "supergateway läuft." -ForegroundColor Green

# --- SSH-Tunnel ---
Write-Host "Öffne SSH-Tunnel zu $ServerLogin ..." -ForegroundColor Cyan
Write-Host "Fenster offen lassen! Strg+C beendet den Tunnel." -ForegroundColor Yellow
while ($true) {
    ssh -N `
        -o ServerAliveInterval=30 `
        -o ExitOnForwardFailure=yes `
        -R "127.0.0.1:${Port}:127.0.0.1:${Port}" `
        $ServerLogin
    Write-Host "Tunnel getrennt, neuer Versuch in 5 Sekunden ..." -ForegroundColor Red
    Start-Sleep -Seconds 5
}
