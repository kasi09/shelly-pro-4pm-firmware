# Shelly Pro 4PM - Tasmota-Build mit Display *und* Energiemessung

Baut eine Tasmota-Firmware fuer den Shelly Pro 4PM, die **Display, Relais und
Energiemessung gleichzeitig** beherrscht - was kein offizieller Build kann.
Dazu eine Bedienoberflaeche fuer das eingebaute Display.

Gebaut wird in GitHub Actions. Ein eigener Rechner mit Toolchain ist nicht
noetig: Fork anlegen, Bauplan starten, fertige `.bin` herunterladen.

---

## ⚠ Sicherheitshinweis

Der Shelly Pro 4PM schaltet **vier Stromkreise mit Netzspannung**, je bis 16 A.

* Arbeiten an der Verkabelung gehoeren in die Hand einer Elektrofachkraft.
* Vor jedem Eingriff das Geraet **allpolig freischalten** und Spannungsfreiheit
  pruefen.
* Niemals gleichzeitig Netzspannung und einen seriellen Adapter anschliessen -
  der Adapter ist galvanisch mit dem Geraet verbunden.
* Das Aufspielen fremder Firmware kostet die Gewaehrleistung und kann das
  Geraet unbrauchbar machen.

Benutzung auf eigene Gefahr. Es wird keinerlei Haftung uebernommen.

---

## Das Problem

Die offiziellen Tasmota-Builds koennen immer nur eines von beidem:

| Build | MCP23S17 (Relais/Tasten) | ADE7953 (Energie) | Display |
|---|---|---|---|
| `tasmota32.bin` | ja | ja | **nein** |
| `tasmota32-display.bin` | nein | **nein** | ja |

Die Ursache steht in `tasmota/include/tasmota_configurations.h` im Tasmota-
Quellbaum. Der Block `#ifdef FIRMWARE_DISPLAYS` enthaelt

```c
#undef USE_ENERGY_SENSOR    // Disable energy sensors (-14k code)
```

und wirft damit die Energiemessung heraus, um Platz zu sparen. `USE_MCP23XXX_DRV`
wird dort ebenfalls nicht gesetzt.

## Die Loesung

Dieser Build setzt auf `FIRMWARE_TASMOTA32` auf - dort sind
`USE_MCP23XXX_DRV`, `USE_ENERGY_SENSOR` und `USE_ADE7953` aktiv - und schaltet
die Display-Treiber ueber `user_config_override.h` zusaetzlich ein. Das
funktioniert, weil der `FIRMWARE_TASMOTA32`-Block `USE_DISPLAY` nicht
abraeumt; die eigenen Defines bleiben stehen.

Kosten: rund 35 kB gegenueber dem Standardbuild. Das Ergebnis liegt bei etwa
2166 kB und passt damit bequem in den 2880 kB grossen `app0`-Slot.

---

## Voraussetzung

**Auf dem Geraet muss bereits Tasmota laufen.** Dieses Repository baut nur
eine Firmware - es beschreibt nicht den Weg von der Shelly-Originalfirmware
zu Tasmota. Dafuer gibt es zwei etablierte Wege:

* **Seriell** ueber den internen Header J8 (Pinbelegung in
  [`docs/HARDWARE.md`](docs/HARDWARE.md)). Ermoeglicht vorher ein
  vollstaendiges Backup der Originalfirmware - dringend empfohlen, es ist der
  einzige gesicherte Rueckweg.
* **Ueber das Netzwerk** mit
  [mgos32-to-tasmota32](https://github.com/tasmota/mgos32-to-tasmota32),
  anschliessend Auto-configuration und Partition Wizard.

Ausserdem muessen `display.ini` und `mcp23x.dat` im Dateisystem des Geraets
liegen - siehe [`device-files/`](device-files/). Die Tasmota-Autokonfiguration
(Configuration -> Auto-configuration -> Shelly Pro 4PM) legt beide selbst ab.

---

## Bauen

1. Dieses Repository **forken**.
2. Reiter **Actions** oeffnen und die Workflows aktivieren.
3. Workflow *Shelly Pro 4PM Firmware bauen* waehlen -> **Run workflow**.
   (Jeder Push startet ihn ebenfalls.)
4. Nach etwa acht Minuten unter **Artifacts** das Paket
   `shellypro4pm-firmware` herunterladen.

Darin liegen:

| Datei | Verwendung |
|---|---|
| `tasmota32-shellypro4pm.bin` | **fuer OTA** - diese Datei einspielen |
| `tasmota32-shellypro4pm.factory.bin` | nur seriell, an Offset `0x0` |
| `ShellyPro4PM.tapp` | Bedienoberflaeche, ins Dateisystem des Geraets |

> Die `factory.bin` **niemals** ueber Tasmotas Firmware-Upgrade einspielen.
> Sie enthaelt Bootloader und Partitionstabelle und gehoert an Offset `0x0`.
> Ihr erstes Byte ist ebenfalls `0xE9`, Tasmotas Pruefung winkt sie also
> durch - danach steht Bootloader-Code dort, wo die Anwendung erwartet wird,
> und das Geraet startet nicht mehr.

Der Bauplan prueft die Groesse selbst gegen den 2880-kB-Slot und schlaegt
fehl, falls sie nicht passt.

## Einspielen

**Firmware:** Im Browser `http://<geraet-ip>/` -> **Firmware Upgrade** ->
`tasmota32-shellypro4pm.bin` waehlen -> *Start upgrade*.

Der Upload gehoert in den Browser: Tasmota prueft dort per JavaScript das
erste Byte, schaltet bei `0xE9` ueber `/u4?u4=fct` zuerst in **Safeboot** und
schreibt erst von dort nach `app0`. Ein einfacher `curl`-POST auf `/up`
ueberspringt diesen Schritt.

**Oberflaeche:** *Consoles -> Manage File system* -> `ShellyPro4PM.tapp`
hochladen, dann Geraet neu starten. Tasmota laedt die Datei beim Start selbst
und meldet im Log `TAP: Loaded Tasmota App '/ShellyPro4PM.tapp'`.

---

## Bedienoberflaeche

Zeigt je Kanal Name, aktuelle Wirkleistung und Schaltzustand, dazu Kopfzeile
mit WLAN-Guete und Uhrzeit. Weisse Schrift auf schwarzem Grund.

Bedient wird ueber die drei Tasten unter dem Display:

| Tasmota | Funktion |
|---|---|
| `Button1` | Auswahl nach oben |
| `Button2` | Auswahl nach unten |
| `Button3` | gewaehlten Kanal schalten |

Welche Taste physisch welche ist, laesst sich am schnellsten ausprobieren -
die Zuordnung folgt der Reihenfolge im Portexpander, nicht zwingend der
Anordnung am Gehaeuse.

Die Oberflaeche setzt beim Start `SetOption73 1`. Ohne das schalten die drei
Tasten direkt die Relais 1-3, statt zu navigieren. Die externen
Klemmenschalter (`Switch1`-`Switch4`) bleiben davon unberuehrt und schalten
weiterhin unmittelbar.

### Zwei Fallen, die Zeit kosten

**Das `.tapp`-Archiv muss unkomprimiert sein** (`ZIP_STORED`). Berry liest in
Tasmota keine deflate-gepackten Pakete und ignoriert sie beim Start
**wortlos** - ohne jede Meldung im Log. Der Bauplan sichert das mit einer
Zusicherung ab. Wer von Hand packt: `zip -j -0 ...`.

**Nicht flaechig loeschen und neu zeichnen.** Genau das erzeugt sichtbares
Flackern. Diese Oberflaeche zeichnet ausschliesslich differenziell: Jeder Wert
merkt sich, was zuletzt auf dem Schirm stand, und wird nur bei echter
Aenderung ausgegeben. Texte tragen ihre Hintergrundfarbe mit (`Bi`) und
ueberschreiben sich dadurch selbst.

---

## Aufbau des Repositories

| Pfad | Inhalt |
|---|---|
| `config/user_config_override.h` | schaltet die Display-Treiber zusaetzlich ein |
| `config/platformio_override.ini` | Bauumgebung, ohne LVGL |
| `tapp/` | Quelltext der Bedienoberflaeche |
| `device-files/` | `display.ini` und `mcp23x.dat` fuer das Geraet |
| `docs/HARDWARE.md` | Pinbelegung, Header J8, MCP23S17, Display |
| `.github/workflows/` | der Bauplan |

## Zur Tasmota-Version

Der Bauplan holt **Tasmota v15.6.0**. Wer eine andere Version baut, sollte den
Tag in `.github/workflows/build-firmware.yml` anpassen. Ein Versionswechsel
kann die gespeicherten Einstellungen des Geraets verwerfen - vorher unter
*Configuration -> Backup Configuration* sichern.

## Kommandozeile

Tasmota 15 weist API-Aufrufe ohne Referer ab und schliesst die Verbindung
wortlos (`curl`: *Empty reply from server*). Auf der seriellen Konsole meldet
das Geraet dazu `HTP: Referer '' denied.` Mit Header funktioniert es, ohne
`SetOption128` setzen zu muessen:

```bash
curl -H "Referer: http://<geraet-ip>/" "http://<geraet-ip>/cm?cmnd=Status%200"
```

## Herkunft

Dieses Projekt baut auf Vorarbeit anderer auf - siehe
[`CREDITS.md`](CREDITS.md). Bitte dort lesen, **bevor** dieses Repository
weiterverbreitet wird: Die Bedienoberflaeche geht auf ein Projekt ohne
Lizenzangabe zurueck.

Lizenz fuer die eigenen Bestandteile: MIT, siehe [`LICENSE`](LICENSE).
