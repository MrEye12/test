# Roblox Studio MCP über blackair.dev

So kann Claude in der Cloud (Claude Code im Web) dein Roblox Studio steuern.

```
Roblox Studio ── Roblox MCP ── supergateway ── SSH-Tunnel ── nginx auf blackair.dev ── Claude
   (dein PC)       (stdio)      (HTTP :8808)                 (https://mcp.blackair.dev/…)
```

Dein PC und Roblox Studio müssen laufen, solange Claude am Spiel arbeitet.

## ⚠️ Sicherheit

Wer die URL kennt, kann dein Roblox Studio steuern und dort Code ausführen.
Deshalb enthält die URL einen **langen geheimen Token**.

- Den Token niemals in dieses Repo committen oder irgendwo posten.
- Wenn er rausgekommen ist, erzeugst du einen neuen und änderst die nginx-Config.
- Wenn du die Brücke nicht brauchst, schließt du das Tunnel-Fenster.

## Einmalig: Server (blackair.dev)

1. **DNS:** A-Record `mcp.blackair.dev` → IP deines Servers.
2. **Token erzeugen:**
   ```bash
   openssl rand -hex 24
   ```
3. **nginx-Config:** Kopiere `nginx-mcp.blackair.dev.conf` nach `/etc/nginx/sites-available/` und ersetze `GEHEIM_ERSETZEN` durch den Token.
   ```bash
   sudo ln -s /etc/nginx/sites-available/nginx-mcp.blackair.dev.conf /etc/nginx/sites-enabled/
   sudo certbot --nginx -d mcp.blackair.dev
   sudo nginx -t && sudo systemctl reload nginx
   ```
   Tipp: Wenn certbot meckert, weil das Zertifikat noch fehlt, kommentiere den
   443-Block kurz aus, hol das Zertifikat und aktiviere den Block dann wieder.

Port 8808 muss **nicht** in der Firewall geöffnet werden, weil der Tunnel nur auf `127.0.0.1` lauscht.

## Einmalig: Dein PC

1. Installiere **Node.js** (https://nodejs.org).
2. Richte das **Roblox Studio MCP** nach der Anleitung von Roblox ein und aktiviere das Plugin in Studio.
3. Trage in `start-bridge.ps1` diese Werte ein:
   - `$RobloxMcpCommand`: der Befehl, der den Roblox MCP im stdio-Modus startet
   - `$ServerLogin`: dein SSH-Login, z. B. `root@blackair.dev`
4. Am besten richtest du einen SSH-Key ein, damit der Tunnel ohne Passwort läuft.

## Jedes Mal: Brücke starten

1. Öffne Roblox Studio und dein Spiel.
2. Starte die Brücke:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\start-bridge.ps1
   ```
3. Lass beide Fenster offen.

## Testen

Ersetze `TOKEN` durch deinen Token:

```bash
curl -s https://mcp.blackair.dev/TOKEN/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}'
```

Wenn als Antwort JSON mit `serverInfo` kommt, funktioniert die Brücke.

## In Claude eintragen

1. Öffne https://claude.ai/customize/connectors → **Add custom connector**.
2. Gib einen Namen ein, z. B. `Roblox Studio`.
3. URL: `https://mcp.blackair.dev/TOKEN/mcp`
4. **Starte eine neue Claude-Code-Session.** Connectors werden nur beim Start geladen.

Falls die Session den Host blockiert, erlaubst du `mcp.blackair.dev` in den
Netzwerk-Einstellungen der Cloud-Umgebung (Umgebungsmenü oben in der Session → **Edit** → Network access).

## Fehlersuche

| Problem | Lösung |
|---|---|
| `502 Bad Gateway` | Tunnel oder supergateway läuft nicht. Prüfe, ob beide Fenster offen sind. |
| `404` | Der Pfad bzw. Token in der URL passt nicht zur nginx-Config. |
| `remote port forwarding failed` | Port 8808 ist auf dem Server noch belegt, z. B. durch einen alten Tunnel. Warte kurz oder beende den alten SSH-Prozess. |
| Antwort kommt, aber Studio reagiert nicht | Das Roblox-MCP-Plugin ist in Studio nicht aktiv, oder Studio ist nicht offen. |
