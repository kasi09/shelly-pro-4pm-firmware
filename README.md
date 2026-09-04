# Shelly Pro 4PM - eigener Tasmota-Build

Baut eine Tasmota-Firmware, die **Display und Peripherie gleichzeitig** kann.

## Warum ueberhaupt ein eigener Build

Die offiziellen Builds koennen immer nur eines von beidem:

| Build | MCP23S17 (Relais/Taster) | ADE7953 (Energie) | Display |
|---|---|---|---|
| `tasmota32.bin` | ja | ja | **nein** |
| `tasmota32-display.bin` | nein | **nein** | ja |

Ursache ist `tasmota/include/tasmota_configurations.h`: Der Block
`#ifdef FIRMWARE_DISPLAYS` enthaelt `#undef USE_ENERGY_SENSOR` und wirft die
Energiemessung heraus, um Platz zu sparen.

Dieser Build setzt deshalb auf `FIRMWARE_TASMOTA32` auf - dort sind
`USE_MCP23XXX_DRV`, `USE_ENERGY_SENSOR` und `USE_ADE7953` aktiv - und schaltet
die Display-Treiber ueber `user_config_override.h` zusaetzlich ein. Der
`FIRMWARE_TASMOTA32`-Block raeumt `USE_DISPLAY` nicht ab, die Defines bleiben
also stehen.

## Warum in der Cloud und nicht lokal

Auf dem Zielrechner ist Smart App Control aktiv und blockiert die unsignierte
`lto-wrapper.exe` der Xtensa-Toolchain. Der Compiler laeuft durch, das Linken
bricht ab:

    ld.exe: error: could not run lto-wrapper

`-fno-lto` half nicht, weil die vorkompilierten ESP-IDF-Bibliotheken selbst
LTO-Objekte enthalten. Unter Linux tritt das Problem nicht auf.

## Geraet

| | |
|---|---|
| Board | `ShellyPro4PM-Main_v2.2.1` (Pinout wie v1) |
| SoC | ESP32-D0WDQ6 v1.1, 8 MB Flash |
| Display | ST7735S, 160x128, SPI - CS 0, CLK 15, MOSI 13, DC 2, Backlight 12 |
| Peripherie | MCP23S17 an CS1 (16 Pins), 2x ADE7953, Ethernet (RMII) |
| Firmware | Tasmota 15.6.0 |
| app0-Slot | **2880 kB** - die Binary muss darunter bleiben |

Auf dem Geraet liegen bereits `display.ini`, `mcp23x.dat` und die Berry-UI
`ShellyPro4PM.tapp` im Dateisystem. Es fehlt ausschliesslich der
Display-Treiber in der Firmware.

## Was hier liegt

| Pfad | Inhalt |
|---|---|
| `config/user_config_override.h` | schaltet die Display-Treiber zusaetzlich ein |
| `config/platformio_override.ini` | Bauumgebung, ohne LVGL |
| `tapp/` | Berry-Bedienoberflaeche fuer das Display |
| `docs/HARDWARE.md` | Pinbelegung, Header J8, MCP23S17, Display |
| `.github/workflows/` | der Bauplan |

## Bedienoberflaeche

`tapp/` wird vom Workflow zu `ShellyPro4PM.tapp` gepackt und liegt dem
Artefakt bei. Die Datei gehoert ins Dateisystem des Geraets (Consoles ->
Manage File system), von wo Tasmota sie beim Start selbst laedt.

**Wichtig:** Das Archiv muss **unkomprimiert** sein (`ZIP_STORED`). Berry
liest keine deflate-gepackten Pakete und ignoriert sie beim Start wortlos -
ohne Fehlermeldung im Log. Der Workflow prueft das mit einer Zusicherung.

Bedienung ueber die drei Tasten unter dem Display:

| Taste | Tasmota | Funktion |
|---|---|---|
| 1 | Button1 | Auswahl nach oben |
| 2 | Button2 | Auswahl nach unten |
| 3 | Button3 | gewaehlten Kanal schalten |

Die Oberflaeche setzt beim Start `SetOption73 1`, sonst wuerden die Tasten
direkt die Relais 1-3 schalten statt zu navigieren. Die externen
Klemmenschalter (Switch1-4) bleiben davon unberuehrt.

Gezeichnet wird ausschliesslich differenziell: Jeder Wert merkt sich, was
zuletzt auf dem Schirm stand, und wird nur bei echter Aenderung neu
ausgegeben. Ein flaechiges Loeschen vor dem Neuzeichnen fuehrt sonst zu
sichtbarem Flackern.

## Ergebnis abholen

Reiter **Actions** -> letzter Lauf -> Abschnitt **Artifacts** ->
`shellypro4pm-firmware`. Darin liegt `tasmota32-shellypro4pm.bin`.

Der Workflow prueft die Groesse selbst gegen den 2880-kB-Slot und schlaegt
fehl, falls sie nicht passt.

## Einspielen

Im Browser auf `http://<geraet>/` -> **Firmware Upgrade** -> Datei waehlen.

Der Upload gehoert in den Browser: Tasmota prueft dort per JavaScript das
erste Byte, schaltet bei `0xE9` ueber `/u4?u4=fct` zuerst in **Safeboot** und
schreibt erst von dort nach `app0`. Ein einfacher `curl`-POST auf `/up` wuerde
diesen Schritt ueberspringen.

Tasmota 15 blockt die HTTP-API zudem ohne Referer
(`HTP: Referer '' denied`); im Browser passiert das automatisch, per
Kommandozeile muss der Header mit:

    curl -H "Referer: http://<geraet>/" "http://<geraet>/cm?cmnd=Status%200"
