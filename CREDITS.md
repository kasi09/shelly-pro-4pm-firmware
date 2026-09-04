# Herkunft und Danksagung

Dieses Projekt steht auf fremder Vorarbeit. Was von wem stammt:

## Berry-Bedienoberflaeche (`tapp/`)

Geht zurueck auf **[mdaskalov/shelly-pro-4pm](https://github.com/mdaskalov/shelly-pro-4pm)**
("Basic UI for Shelly Pro 4PM flashed with Tasmota").

Uebernommen wurden das Grundgeruest der Klasse, die Darstellung des
Schiebeschalters ueber die Zeichenbefehle `U` und `K` sowie die Logik der
WLAN-Balken. Hinzugekommen sind die Tastenfuehrung mit Auswahlcursor und
Entprellung, die Leistungsanzeige je Kanal, das differenzielle Zeichnen gegen
Flackern und die Farbgebung.

> **Achtung, ungeklaerte Rechtslage:** Das Ursprungsprojekt steht **ohne
> Lizenzangabe** auf GitHub. Ohne Lizenz gilt striktes Urheberrecht - eine
> Weiterverbreitung ist formal nicht gestattet, auch nicht in abgewandelter
> Form. Vor einer Veroeffentlichung sollte der Autor um Zustimmung gebeten
> oder die Oberflaeche eigenstaendig neu geschrieben werden.

## Firmware

**[Tasmota](https://github.com/arendst/Tasmota)** von Theo Arends und
Mitwirkenden, GPLv3. Dieses Repository enthaelt keinen Tasmota-Quellcode - der
Bauplan holt ihn zur Bauzeit selbst. Uebernommen sind lediglich zwei
Konfigurationsdateien:

* `device-files/display.ini` aus `tasmota/displaydesc/ST7735S_Pro4PM_display.ini`
* `device-files/mcp23x.dat` aus dem Autoconf-Paket `Shelly_Pro_4PM`

## Hardware-Erkenntnisse

* **[karlquinsland.com](https://karlquinsland.com/shelly-pro-4pm-teardown/)** -
  Teardown mit der Bestimmung der Bausteine (ESP32-D0WDQ6, 2x ADE7953ACPZ,
  MCP23S17, SMSC8720A) und dem Hinweis auf den seriellen Header.
* **[angelnu/esphome](https://github.com/angelnu/esphome)**,
  `devices/shelly/pro4pm/base_v1.yaml` - unabhaengig entstandene
  ESPHome-Konfiguration, die als Gegenprobe fuer die Portbelegung des
  MCP23S17 und die Display-Pins diente.

## Dieses Repository

Bauplan, Konfiguration und Dokumentation stehen unter der MIT-Lizenz, siehe
`LICENSE`. Diese gilt **nicht** fuer die oben genannten fremden Bestandteile.
