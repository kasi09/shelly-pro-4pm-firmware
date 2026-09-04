# Shelly Pro 4PM - Hardware

Board `ShellyPro4PM-Main_v2.2.1`. Trotz der Versionsnummer entspricht das
Pinout der v1-Referenz.

## Bausteine

| Funktion | Baustein |
|---|---|
| Hauptprozessor | ESP32-D0WDQ6 v1.1, Dual Core, 240 MHz |
| Flash | 8 MB (`FlashChipId 17701C`, Hersteller `1c`, Typ `7017`) |
| Portexpander | MCP23S17 an SPI-CS1, 16 Pins - Relais, Tasten, Klemmenschalter |
| Energiemessung | 2x ADE7953 (SPI), zusammen 4 Kanaele |
| Ethernet | LAN8720-kompatibler PHY (SMSC8720A), RMII |
| Display | ST7735S, 160x128, SPI |
| MAC | `84:1F:E8:xx:xx:xx` (WLAN), `86:1F:E8:xx:xx:xx` (Ethernet) |

## Header J8 - serielle Schnittstelle

1x6-Buchsenleiste, 1 mm Raster, direkt neben der Ethernet-Buchse.

| Pin | Signal | Bemerkung |
|---:|---|---|
| 1 | +3,3 V | Versorgung des Adapters. **Nicht** zusammen mit Netzspannung anlegen |
| 2 | GND | Masse, gemeinsame Bezugsmasse mit dem Adapter |
| 3 | GPIO0 | Bootmodus. Beim Einschalten auf GND ziehen, um in den Flash-Modus zu gelangen |
| 4 | RX | Eingang des ESP32 - an TX des Adapters |
| 5 | TX | Ausgang des ESP32 - an RX des Adapters |
| 6 | EN / RST | Reset, aktiv low |

Signalbelegung durch den erfolgreichen seriellen Flash am 04.09.2026
bestaetigt (CH340 an COM5, voller Chip-Erase plus `tasmota32.factory.bin`,
`Hash of data verified`). Die Zaehlrichtung ist an der Platinenmarkierung
zu pruefen, bevor der Adapter angeklemmt wird.

### Es gibt keine Auto-Reset-Beschaltung

DTR und RTS des Adapters liegen **nicht** auf EN und GPIO0. `esptool` kann
den Chip also nicht selbst in den Bootmodus versetzen - vier Reset-Varianten
und ein Baudraten-Sweep blieben ohne jede Antwort.

Ablauf, der funktioniert:

1. Gerät stromlos machen.
2. GPIO0 (Pin 3) fest auf GND (Pin 2) legen.
3. Versorgung einschalten - der ESP32 startet im Bootlader.
4. GPIO0 loesen, dann `esptool` mit `--before no-reset` aufrufen.

```
python -m esptool --port COM5 --baud 460800 --before no-reset \
  write-flash --erase-all 0x0 backup/shellypro4pm_v2.2.1_original_8MB.bin
```

### Sicherheitshinweis

Im eingebauten Zustand liegt an den Klemmen L1-L4 und N Netzspannung an. Der
serielle Adapter ist galvanisch mit dem Geraet verbunden. Vor dem Anklemmen
das Geraet allpolig freischalten - niemals gleichzeitig Netzspannung und
UART-Adapter.

**Falle bei der Fehlersuche auf der Werkbank:** Wird das Board nur ueber die
3,3 V des UART-Adapters versorgt, meldet sich der Portexpander als MCP23S08
mit 8 Pins und **0 Relais**, weil sein zweiter Port an der Netzteilseite
haengt. Zusammengebaut meldet dasselbe Board `MCP23S17 found`,
`Pins 16 (S4/B3/R4)`. Peripherie also nie am UART-Adapter allein beurteilen.

## MCP23S17 - Portbelegung

Aus `mcp23x.dat` dekodiert und gegen den Teardown geprueft. Die Tasmota-Codes
folgen `AGPIO(funktion) = funktion * 32 + index`.

| MCP-Pin | Code | Tasmota | Funktion am Geraet |
|---:|---:|---|---|
| 0 | 194 | `SWT1_NP +2` | Klemmenschalter 3 |
| 1 | 193 | `SWT1_NP +1` | Klemmenschalter 2 |
| 2 | 65 | `KEY1_NP +1` | **Taste RUNTER** (Display) |
| 3 | 66 | `KEY1_NP +2` | **Taste OK** (Display) |
| 4 | 3840 | `A4988_ENA` | Reset fuer Display und ADE7953 |
| 5 | 64 | `KEY1_NP +0` | **Taste HOCH** (Display) |
| 6 | 192 | `SWT1_NP +0` | Klemmenschalter 1 |
| 8 | 224 | `REL1 +0` | Relais O1 |
| 12 | 227 | `REL1 +3` | Relais O4 |
| 13 | 225 | `REL1 +1` | Relais O2 |
| 14 | 226 | `REL1 +2` | Relais O3 |
| 15 | 195 | `SWT1_NP +3` | Klemmenschalter 4 |

Daraus folgt die fuer die Bedienung entscheidende Zuordnung:

* Die **drei Display-Tasten** sind in Tasmota **Button1 (hoch)**,
  **Button2 (runter)** und **Button3 (OK)**.
* Die **vier Klemmenschalter** sind **Switch1 bis Switch4**.

Ohne `SetOption73 1` schalten die drei Display-Tasten direkt Relais 1-3. Fuer
die Menuefuehrung muessen sie entkoppelt werden; die Berry-Anzeige setzt das
beim Start selbst. Die Klemmenschalter bleiben davon unberuehrt und schalten
weiterhin direkt.

## Display

ST7735S, 160x128, SPI. Deskriptor `backup/display.ini`, uebernommen aus
`tasmota/displaydesc/ST7735S_Pro4PM_display.ini`. Kopfzeile:

```
:H,PRO_4PM,160,128,16,SPI,3,0,15,13,2,12,*,*,20
```

| Signal | GPIO |
|---|---:|
| CS | 0 |
| CLK | 15 |
| MOSI | 13 |
| DC | 2 |
| Hintergrundbeleuchtung | 12 |

Die Hintergrundbeleuchtung erscheint in Tasmota als zusaetzlicher Ausgang
**POWER5** und ist nach dem Start eingeschaltet. Die vier Relais bleiben
POWER1 bis POWER4.

Die Werte decken sich mit der ESPHome-Referenzkonfiguration
`reference/angelnu-pro4pm-base_v1.yaml`, die unabhaengig davon entstanden ist.

## Temperaturfuehler

NTC an ADC-Eingang, Kalibrierung `AdcParam1 2,5600,4700,3350`. Ohne diese
Werte meldet der Fuehler rund 87 statt 24 Grad.
