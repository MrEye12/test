# Startet die Brücke: Roblox Studio MCP -> HTTP (supergateway) -> SSH-Tunnel -> blackair.dev
#
# Voraussetzungen auf deinem PC:
#   - Roblox Studio offen, Roblox-MCP-Plugin aktiv
#   - Node.js installiert (für npx)
#   - SSH-Zugang zu deinem Server (am besten per SSH-Key)
#
# Start:  powershell -ExecutionPolicy Bypass -File .\start-bridge.ps1

# === ANPASSEN ===
# Befehl, mit dem der Roblox MCP im stdio-Modus startet.
# Den genauen Pfad findest du in der Anleitung von Roblox bzw. in der
# Claude-Desktop-Config, die der Roblox-Installer angelegt hat.
$RobloxMcpCommand = "`"$env:LOCALAPPDATA\Roblox\rbx-studio-mcp.exe`" --stdio"

$ServerLogin = "user@blackair.dev"   # SSH-Login zu deinem Server
$Port        = 8808                  # muss zur nginx-Config passen
# ================

Write-Host "Starte supergateway auf Port $Port ..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command",
    "npx -y supergateway --stdio '$RobloxMcpCommand' --outputTransport streamableHttp --port $Port"
)

Start-Sleep -Seconds 5

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
