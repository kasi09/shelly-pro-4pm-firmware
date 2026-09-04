# Herkunft und Danksagung

Dieses Projekt steht auf fremder Vorarbeit. Was von wem stammt:

## Firmware

**[Tasmota](https://github.com/arendst/Tasmota)** von Theo Arends und
Mitwirkenden, GPLv3. Dieses Repository enthaelt keinen Tasmota-Quellcode -
der Bauplan holt ihn zur Bauzeit selbst. Uebernommen sind lediglich zwei
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

## Bedienoberflaeche

`tapp/` ist eine **eigenstaendige Umsetzung** fuer dieses Projekt. Grundlage
ist allein die dokumentierte DisplayText-Syntax von Tasmota.

Zur Einordnung, weil die Aufgabenstellung naheliegt und es ein aelteres
Projekt dazu gibt: **[mdaskalov/shelly-pro-4pm](https://github.com/mdaskalov/shelly-pro-4pm)**
loest dieselbe Aufgabe. Eine fruehere Fassung dieses Repositories baute
darauf auf. Da jenes Projekt **keine Lizenzangabe** traegt und damit striktes
Urheberrecht gilt, wurde die Oberflaeche vollstaendig neu geschrieben, bevor
dieses Repository veroeffentlicht wurde - mit eigenem Aufbau, eigener
Zustandshaltung und anderer Darstellung (Zustandspunkt statt Schiebeschalter,
Empfangsstaerke als Zahl statt Balkengrafik, Summenzeile, zweizeiliger Kopf).
Es wird hier genannt, weil es die Vorlage der abgeloesten Fassung war und
weil es Nachbauern als Alternative dienen kann.

## Dieses Repository

Bauplan, Konfiguration, Bedienoberflaeche und Dokumentation stehen unter der
MIT-Lizenz, siehe `LICENSE`. Diese gilt **nicht** fuer die oben genannten
fremden Bestandteile aus dem Tasmota-Projekt.
