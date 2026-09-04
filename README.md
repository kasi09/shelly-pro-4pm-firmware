# Shelly Pro 4PM - Tasmota-Build mit Display *und* Energiemessung

Baut eine Tasmota-Firmware fuer den Shelly Pro 4PM, die **Display, Relais und
Energiemessung gleichzeitig** beherrscht - was kein offizieller Build kann.
Dazu eine Bedienoberflaeche fuer das eingebaute Display, mit
Uebertemperatur-Abschaltung und Messwertaufzeichnung.

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

Eine einzige Ansicht, alles gleichzeitig sichtbar - kein Umschalten:

```
 18:42                    35.1C     Uhrzeit und Temperatur, kleine Schrift
 192.168.0.42            -62dBm     Adresse und Empfangsstaerke
 ---------------------------------
|CH 1     *          1234.5W        vier Kanaele, groessere Schrift
 CH 2     o             0.0W        * eingeschaltet, o aus
 CH 3     *           123.4W
 CH 4     o             0.0W
 ---------------------------------
 Summe               1357.9W        Summe der Wirkleistung
```

Der senkrechte Strich links markiert den gewaehlten Kanal.

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

### Uebertemperatur-Abschaltung

Steigt die gemessene Temperatur ueber `TEMP_TRIP` (Vorgabe 80 °C), schaltet
die Oberflaeche **alle vier Kanaele ab** und sperrt das Wiedereinschalten
ueber die Taste. Kopf und Fusszeile werden rot, die Fusszeile zeigt `AUS!`.
Die Sperre faellt erst wieder unter `TEMP_CLEAR` (Vorgabe 70 °C) - diese
Hysterese verhindert ein Flattern an der Schwelle.

Das laeuft vollstaendig auf dem Geraet, ohne Netzwerk, ohne Server. Beide
Schwellen stehen als Konstanten am Anfang von `tapp/ShellyPro4PM.be`.

> Das ist eine Zusatzmassnahme in Software und **ersetzt keine
> Absicherung der Installation**. Leitungsschutz und Verkabelung bleiben
> Sache der Elektrofachkraft.

### Beleuchtung

Nach `DIM_AFTER` Sekunden ohne Tastendruck (Vorgabe 120) faehrt die
Hintergrundbeleuchtung auf `DIM_LOW` herunter, jeder Tastendruck holt sie auf
`DIM_HIGH` zurueck. Das schont das Panel und blendet nachts nicht.

### Aufzeichnung

Alle 15 Minuten wandert der aktuelle Messwert je Kanal in einen Ringpuffer
ueber 24 Stunden, der anschliessend nach `/power.csv` geschrieben wird.
Abrufbar ueber *Consoles -> Manage File system*.

Die Datei wird **vollstaendig neu geschrieben statt angehaengt**. Dadurch
bleibt ihre Groesse fest bei 96 Zeilen, und es braucht keine Rotationslogik,
die sonst irgendwann den Flash fuellen wuerde. Format:

```
minuten_vor_jetzt;ch1;ch2;ch3;ch4
-1425;0.0;0.0;0.0;0.0
...
-0;1234.5;0.0;123.4;0.0
```

Die erste Spalte ist das Alter des Wertes in Minuten, `-0` ist der juengste
Eintrag. Fuer echte Langzeitauswertung ist MQTT oder Home Assistant der
richtige Ort - das Geraet ist dafuer nicht gedacht.

### Drei Fallen, die Zeit kosten

**Das `.tapp`-Archiv muss unkomprimiert sein** (`ZIP_STORED`). Berry liest in
Tasmota keine deflate-gepackten Pakete und ignoriert sie beim Start
**wortlos** - ohne jede Meldung im Log. Der Bauplan sichert das mit einer
Zusicherung ab. Wer von Hand packt: `zip -j -0 ...`.

**Nicht flaechig loeschen und neu zeichnen.** Genau das erzeugt sichtbares
Flackern. Diese Oberflaeche zeichnet ausschliesslich differenziell: Jede
Bildschirmstelle merkt sich, was zuletzt dort stand, und wird nur bei echter
Aenderung ausgegeben. Texte tragen ihre Hintergrundfarbe mit (`Bi`) und
ueberschreiben sich dadurch selbst.

**Berry ist nicht Python.** Drei Abweichungen, die jeweils erst als
Syntaxfehler auf dem Geraet auffallen:

* Zeichenketten werden mit `+` verbunden - eine implizite Verkettung
  ueber Zeilenumbrueche wie in Python gibt es nicht.
* `//` beginnt ein Lambda, es ist **keine** Ganzzahldivision. Dafuer
  `int(a / b)`.
* Der Bedingungsoperator `? :` darf **nicht** in einem f-String-Platzhalter
  stehen - dort leitet der Doppelpunkt die Formatangabe ein. Bedingungen
  vorher in eine Variable schreiben.

## Aufbau des Repositories

| Pfad | Inhalt |
|---|---|
| `config/user_config_override.h` | schaltet die Display-Treiber zusaetzlich ein |
| `config/platformio_override.ini` | Bauumgebung, ohne LVGL |
| `tapp/` | Quelltext der Bedienoberflaeche |
| `CREDITS.md` | Herkunft der fremden Bestandteile |
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

Dieses Projekt baut auf Vorarbeit anderer auf - Tasmota selbst, den
Teardown von karlquinsland und die ESPHome-Konfiguration von angelnu. Wer
was beigetragen hat, steht in [`CREDITS.md`](CREDITS.md).

Lizenz: MIT, siehe [`LICENSE`](LICENSE). Ausgenommen sind die beiden aus dem
Tasmota-Projekt uebernommenen Dateien unter `device-files/`.
