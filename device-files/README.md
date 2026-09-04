# Dateien fuer das Dateisystem des Geraets

Beide Dateien stammen unveraendert aus dem Tasmota-Projekt und muessen im
Dateisystem des Geraets liegen (Consoles -> Manage File system -> Upload).
Ohne sie bleibt das Display dunkel und die Relais sind nicht ansprechbar.

| Datei | Zweck | Herkunft |
|---|---|---|
| `display.ini` | Deskriptor des ST7735S, 160x128 | `tasmota/displaydesc/ST7735S_Pro4PM_display.ini` |
| `mcp23x.dat` | Portbelegung des MCP23S17 | Autoconf-Paket `Shelly_Pro_4PM` |

Sie werden ueblicherweise von der Tasmota-Autokonfiguration
(Configuration -> Auto-configuration -> Shelly Pro 4PM) automatisch abgelegt.
Hier liegen sie fuer den Fall bei, dass von Hand konfiguriert wird.
