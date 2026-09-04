# Wird von Tasmota beim Start ausgefuehrt, sobald die .tapp im
# Dateisystem liegt. Packen mit: zip -j -0 ShellyPro4PM.tapp tapp/*
# Das -0 ist zwingend - Berry liest nur unkomprimierte Archive.
import ShellyPro4PM

var shelly = ShellyPro4PM()
