# Bedienoberflaeche fuer den Shelly Pro 4PM (ST7735S, 160x128).
#
# Eigenstaendige Umsetzung fuer dieses Projekt. Grundlage ist allein die
# dokumentierte DisplayText-Syntax von Tasmota.
#
# Eine einzige Ansicht, alles gleichzeitig sichtbar:
#
#   18:42                35.1C     Kopf, klein: Uhrzeit und Temperatur
#   192.168.0.42         -62dBm    Kopf, klein: Adresse und Empfang
#   ------------------------------
#   CH 1   *          1234.5W      vier Kanaele, groessere Schrift
#   CH 2   o             0.0W
#   CH 3   *           123.4W
#   CH 4   o             0.0W
#   ------------------------------
#   Summe             1357.9W
#
# Bedienung ueber die drei Tasten am Geraet:
#   Button1 blaettert aufwaerts, Button2 abwaerts, Button3 schaltet den
#   markierten Kanal. Die Tasten haengen am Portexpander und wuerden ohne
#   SetOption73 unmittelbar die Relais 1 bis 3 schalten; init() setzt die
#   Option daher selbst. Die Klemmenschalter Switch1 bis Switch4 bleiben
#   unberuehrt und schalten weiterhin direkt.
#
# Schutz: Ueberschreitet die gemessene Temperatur TEMP_TRIP, werden alle
# vier Kanaele abgeschaltet und ein Wiedereinschalten ueber die Taste
# gesperrt. Die Sperre faellt erst unter TEMP_CLEAR, damit es an der
# Schwelle nicht flattert. Das laeuft ohne Netzwerk.
#
# Aufzeichnung: Alle 15 Minuten wandert der aktuelle Messwert in einen
# Ringpuffer ueber 24 Stunden, der anschliessend vollstaendig nach
# CSV_PATH geschrieben wird - vollstaendig statt angehaengt, damit die
# Datei nicht waechst und keine Rotation noetig ist, die sonst irgendwann
# den Flash fuellen wuerde.
#
# Zeichnen: Jede Bildschirmstelle fuehrt in "cache" den zuletzt
# ausgegebenen Text mit; ausgegeben wird nur, was sich unterscheidet.
# Flaechiges Loeschen vor dem Neuzeichnen unterbleibt - es flackert.
#
# Berry weicht an drei Stellen von vertrauter Syntax ab, die hier bewusst
# gemieden werden: Zeichenketten werden mit "+" verbunden (keine implizite
# Verkettung ueber Zeilen), "//" beginnt ein Lambda statt einer
# Ganzzahldivision, und der Bedingungsoperator "? :" darf nicht in einem
# f-String-Platzhalter stehen, weil dort der Doppelpunkt die Formatangabe
# einleitet.

import string

class Pro4PM_Panel

  var labels, cursor, watts, cache
  var guardKey, guardAt
  var temp, tripped         # Temperatur, Zustand der Schutzabschaltung
  var lastTouch, dimmed     # letzte Bedienung, Dimmzustand
  var arch, archAt          # Viertelstundenwerte fuer die Aufzeichnung

  # Geometrie
  var WIDTH, LINE1, LINE2, HEAD_H, ROW_TOP, ROW_H, FOOT_Y, COUNT
  # Farbstellen der Tasmota-Palette
  var cBack, cText, cMuted, cLive, cMark, cWarn
  # Einstellungen
  var TEMP_TRIP, TEMP_CLEAR, DIM_AFTER, DIM_LOW, DIM_HIGH
  var ARCH_LEN, CSV_PATH

  def init()
    self.WIDTH   = 160
    self.LINE1   = 9       # Grundlinie Kopfzeile 1 (Uhrzeit, Temperatur)
    self.LINE2   = 20      # Grundlinie Kopfzeile 2 (Adresse, Empfang)
    self.HEAD_H  = 23      # Trennlinie unter dem Kopf
    self.ROW_TOP = 25      # erste Kanalzeile
    self.ROW_H   = 17      # 25 + 4*17 = 93
    self.FOOT_Y  = 95      # Trennlinie ueber dem Fuss
    self.COUNT   = 4

    self.cBack  = 0        # schwarz
    self.cText  = 1        # weiss
    self.cMuted = 15       # grau
    self.cLive  = 3        # gruen, eingeschalteter Kanal
    self.cMark  = 7        # gelb, Markierung
    self.cWarn  = 2        # rot, Uebertemperatur

    self.TEMP_TRIP  = 80   # Grad Celsius, ab hier wird abgeschaltet
    self.TEMP_CLEAR = 70   # Grad Celsius, darunter faellt die Sperre
    self.DIM_AFTER  = 120  # Sekunden ohne Bedienung bis zum Dimmen
    self.DIM_LOW    = 10   # Helligkeit gedimmt, Prozent
    self.DIM_HIGH   = 100  # Helligkeit bei Bedienung, Prozent
    self.ARCH_LEN   = 96   # Viertelstundenwerte = 24 Stunden
    self.CSV_PATH   = "/power.csv"

    self.watts     = [0, 0, 0, 0]
    self.cache     = {}
    self.cursor    = 0
    self.temp      = 0
    self.tripped   = false
    self.guardKey  = -1
    self.guardAt   = 0
    self.lastTouch = tasmota.millis()
    self.dimmed    = false
    self.archAt    = -1

    # Ringpuffer fuer die Aufzeichnung: je Kanal eine Liste fester Laenge
    self.arch = []
    var ch = 0
    while ch < self.COUNT
      var b = []
      var i = 0
      while i < self.ARCH_LEN
        b.push(0)
        i += 1
      end
      self.arch.push(b)
      ch += 1
    end

    self.fetch_labels()
    tasmota.cmd("SetOption73 1", true)
    tasmota.cmd(f"DisplayDimmer {self.DIM_HIGH}", true)
    self.bind_keys()
    tasmota.add_driver(self)

    self.repaint()
    tasmota.set_timer(3000, /-> self.repaint())
  end

  def deinit()
    self.del()
  end

  def del()
    self.unbind_keys()
    tasmota.remove_driver(self)
  end

  # --------------------------------------------------------------- Aufbau
  def fetch_labels()
    self.labels = []
    var named = tasmota.cmd("status", true)["Status"]["FriendlyName"]
    var idx = 0
    while idx < self.COUNT
      var caption = idx < named.size() ? named[idx] : ""
      if caption == "" || string.find(caption, "Tasmota") == 0
        caption = f"CH {idx + 1}"
      end
      self.labels.push(caption)
      idx += 1
    end
  end

  # --------------------------------------------------------------- Tasten
  def bind_keys()
    var idx = 0
    while idx < 3
      var slot = idx
      tasmota.add_rule(f"Button{idx + 1}#State",  def (v,t,m) self.tap(slot) end)
      tasmota.add_rule(f"Button{idx + 1}#Action", def (v,t,m) self.tap(slot) end)
      idx += 1
    end
    idx = 0
    while idx < self.COUNT
      tasmota.add_rule(f"POWER{idx + 1}#state", def (v,t,m) self.sync() end)
      idx += 1
    end
  end

  def unbind_keys()
    var idx = 0
    while idx < 3
      tasmota.remove_rule(f"Button{idx + 1}#State")
      tasmota.remove_rule(f"Button{idx + 1}#Action")
      idx += 1
    end
    idx = 0
    while idx < self.COUNT
      tasmota.remove_rule(f"POWER{idx + 1}#state")
      idx += 1
    end
  end

  # Ein Druck, der binnen 300 ms erneut gemeldet wird, gilt als derselbe.
  # Tasmota meldet je nach Einstellung sowohl #State als auch #Action.
  def tap(slot)
    var now = tasmota.millis()
    if self.guardKey == slot && now - self.guardAt < 300
      return
    end
    self.guardKey = slot
    self.guardAt = now
    self.wake()

    if slot == 2
      # Nach einer Schutzabschaltung nicht wieder einschalten
      if !self.tripped
        tasmota.cmd(f"POWER{self.cursor + 1} TOGGLE", true)
      end
      self.sync()
      return
    end

    var step = (slot == 0) ? -1 : 1
    self.cursor = (self.cursor + step) % self.COUNT
    if self.cursor < 0
      self.cursor += self.COUNT
    end
    self.sync()
  end

  # ----------------------------------------------------------- Beleuchtung
  def wake()
    self.lastTouch = tasmota.millis()
    if self.dimmed
      self.dimmed = false
      tasmota.cmd(f"DisplayDimmer {self.DIM_HIGH}", true)
    end
  end

  def check_dim()
    if self.dimmed
      return
    end
    if tasmota.millis() - self.lastTouch > self.DIM_AFTER * 1000
      self.dimmed = true
      tasmota.cmd(f"DisplayDimmer {self.DIM_LOW}", true)
    end
  end

  # --------------------------------------------------------------- Ausgabe
  def put(slot, payload)
    if self.cache.find(slot) == payload
      return false
    end
    self.cache[slot] = payload
    tasmota.cmd(f"DisplayText {payload}", true)
    return true
  end

  def repaint()
    self.cache = {}
    tasmota.cmd(f"DisplayText [Ci{self.cText}Bi{self.cBack}z]", true)
    tasmota.cmd(f"DisplayText [x0y{self.HEAD_H}Ci{self.cMuted}h{self.WIDTH}" +
                f"x0y{self.FOOT_Y}Ci{self.cMuted}h{self.WIDTH}]", true)
    self.paint_clock()
    self.paint_head()
    self.sync()
  end

  def paint_clock()
    # "t" ersetzt Tasmota selbst, der Befehlstext bleibt gleich - ein
    # Inhaltsvergleich griffe nie. Daher die Minute als Merkmal.
    var minute = int(tasmota.rtc()["local"] / 60)
    if self.cache.find("clock") == minute
      return
    end
    self.cache["clock"] = minute
    tasmota.cmd(f"DisplayText [x3y{self.LINE1}Ci{self.cText}Bi{self.cBack}f0t]", true)
  end

  # Temperatur oben rechts, Adresse und Empfang in der zweiten Kopfzeile.
  # Alles in der kleinen Schrift, damit die Kanaele den Platz behalten.
  def paint_head()
    var col = self.cMuted
    if self.tripped
      col = self.cWarn
    end
    self.put("temp",
             f"[x112y{self.LINE1}Ci{col}Bi{self.cBack}f0]{self.temp:%5.1f}C")

    var net = tasmota.wifi()
    var ip = net.find("ip")
    if ip == nil
      ip = "  ohne Netz  "
    end
    self.put("ip",
             f"[x3y{self.LINE2}Ci{self.cMuted}Bi{self.cBack}f0]{ip}     ")

    var rssi = net.find("rssi")
    var signal = "  --dBm"
    if rssi != nil
      signal = f"{rssi:%4d}dBm"
    end
    self.put("rssi",
             f"[x112y{self.LINE2}Ci{self.cMuted}Bi{self.cBack}f0]{signal}")
  end

  def paint_row(idx)
    var top = self.ROW_TOP + idx * self.ROW_H
    var base = top + 12
    var live = tasmota.get_power(idx)
    var here = (idx == self.cursor)

    var cMarkNow = here ? self.cMark : self.cBack
    var cName    = here ? self.cText : self.cMuted
    var cDot     = live ? self.cLive : self.cMuted
    var cWatt    = live ? self.cText : self.cMuted
    var glyph    = live ? "K4" : "k4"
    var dotY     = top + 8

    self.put(f"mark{idx}",
             f"[x2y{top + 2}Ci{cMarkNow}R2:{self.ROW_H - 4}]")
    self.put(f"name{idx}",
             f"[x9y{base}Ci{cName}Bi{self.cBack}f1]" + f"{self.labels[idx]}     ")
    self.put(f"dot{idx}",
             f"[x62y{dotY}Ci{self.cBack}R11:11" +
             f"x67y{dotY + 5}Ci{cDot}{glyph}]")
    self.put(f"watt{idx}",
             f"[x80y{base}Ci{cWatt}Bi{self.cBack}f1]" +
             f"{self.watts[idx]:%7.1f}W")
  end

  def paint_total()
    var sum = 0.0
    var idx = 0
    while idx < self.COUNT
      sum += self.watts[idx]
      idx += 1
    end
    var label = "Summe"
    var col = self.cMuted
    if self.tripped
      label = "AUS! "
      col = self.cWarn
    end
    self.put("total",
             f"[x9y{self.FOOT_Y + 12}Ci{col}Bi{self.cBack}f1]{label}")
    self.put("totalval",
             f"[x80y{self.FOOT_Y + 12}Ci{self.cText}Bi{self.cBack}f1]" +
             f"{sum:%7.1f}W")
  end

  def sync()
    var idx = 0
    while idx < self.COUNT
      self.paint_row(idx)
      idx += 1
    end
    self.paint_total()
  end

  # ------------------------------------------------------------ Messwerte
  def read_watts()
    var report = tasmota.cmd("status 10", true)
    if report == nil return end
    var sns = report.find("StatusSNS")
    if sns == nil return end

    var probe = sns.find("ANALOG")
    if probe != nil
      var t = probe.find("Temperature1")
      if t != nil
        self.temp = t
      end
    end

    var energy = sns.find("ENERGY")
    if energy == nil return end
    var reading = energy.find("Power")
    if reading == nil return end
    var idx = 0
    while idx < self.COUNT
      if idx < reading.size()
        self.watts[idx] = reading[idx]
      end
      idx += 1
    end
  end

  # Schutzabschaltung mit Hysterese
  def check_temp()
    if !self.tripped && self.temp >= self.TEMP_TRIP
      self.tripped = true
      var idx = 0
      while idx < self.COUNT
        tasmota.cmd(f"POWER{idx + 1} OFF", true)
        idx += 1
      end
      print(f"PANEL: {self.temp:.1f}C ueber {self.TEMP_TRIP}C - alle Kanaele abgeschaltet")
      self.repaint()
    elif self.tripped && self.temp <= self.TEMP_CLEAR
      self.tripped = false
      print(f"PANEL: {self.temp:.1f}C wieder unter {self.TEMP_CLEAR}C - Sperre aufgehoben")
      self.repaint()
    end
  end

  # Viertelstundenwert sichern und die Datei neu schreiben
  def push_archive()
    self.archAt = (self.archAt + 1) % self.ARCH_LEN
    var idx = 0
    while idx < self.COUNT
      self.arch[idx][self.archAt] = self.watts[idx]
      idx += 1
    end
    self.write_csv()
  end

  def write_csv()
    var f = open(self.CSV_PATH, "w")
    if f == nil
      return
    end
    f.write("minuten_vor_jetzt;ch1;ch2;ch3;ch4\n")
    var i = 0
    while i < self.ARCH_LEN
      var slot = (self.archAt + 1 + i) % self.ARCH_LEN
      var age = (self.ARCH_LEN - 1 - i) * 15
      var line = f"-{age};"
      var ch = 0
      while ch < self.COUNT
        line += f"{self.arch[ch][slot]:.1f}"
        if ch < self.COUNT - 1
          line += ";"
        end
        ch += 1
      end
      f.write(line + "\n")
      i += 1
    end
    f.close()
  end

  def every_second()
    var stamp = tasmota.rtc()["local"]
    var sec = stamp % 60

    if sec % 2 == 0
      self.read_watts()
      self.check_temp()
      self.sync()
    end
    if sec == 0
      if int(stamp / 60) % 15 == 0
        self.push_archive()
      end
    end
    self.paint_clock()
    self.paint_head()
    self.check_dim()
  end

end

return Pro4PM_Panel
