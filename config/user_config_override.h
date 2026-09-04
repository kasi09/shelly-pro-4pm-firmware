/*
  user_config_override.h - Shelly Pro 4PM

  Zweck dieses Builds: Display UND Peripherie gleichzeitig.

  Die offiziellen Builds koennen immer nur eins von beidem:
    - tasmota32.bin          MCP23S17 + ADE7953, aber kein Display
    - tasmota32-display.bin  Display, aber FIRMWARE_DISPLAYS enthaelt
                             "#undef USE_ENERGY_SENSOR" und wirft damit die
                             ADE7953-Energiemessung raus.

  Dieser Build setzt auf FIRMWARE_TASMOTA32 auf - dort sind USE_MCP23XXX_DRV,
  USE_ENERGY_SENSOR und USE_ADE7953 aktiv - und schaltet die Display-Treiber
  zusaetzlich ein. Der FIRMWARE_TASMOTA32-Block in
  tasmota/include/tasmota_configurations_ESP32.h raeumt USE_DISPLAY nicht ab,
  die Defines hier bleiben also stehen.

  Display laut device-files/display.ini: ST7735S, 160x128, SPI,
  CS 0, CLK 15, MOSI 13, DC 2, Backlight 12.
  Der Universal-Display-Treiber liest diese Datei aus dem Dateisystem.
*/

#ifndef _USER_CONFIG_OVERRIDE_H_
#define _USER_CONFIG_OVERRIDE_H_

// Display-Unterstuetzung (im Standardbuild aus)
#define USE_DISPLAY                              // Grundgeruest Display
#define USE_UNIVERSAL_DISPLAY                    // [DisplayModel 17] liest display.ini
#define USE_DISPLAY_MODES1TO5                    // Anzeigemodi zusaetzlich zu Mode 0

// SPI wird von FIRMWARE_TASMOTA32 bereits gesetzt; hier zur Sicherheit,
// falls die Basis-Firmware einmal wechselt.
#ifndef USE_SPI
  #define USE_SPI
#endif

#endif  // _USER_CONFIG_OVERRIDE_H_
