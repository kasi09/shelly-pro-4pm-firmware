# Anzeige fuer den Shelly Pro 4PM auf dem 160x128-Display (ST7735S).
#
# Bedienung ueber die drei Tasten unter dem Display:
#   Button1 = hoch, Button2 = runter, Button3 = gewaehlten Kanal schalten.
#
# Die Tasten werden per SetOption73 von den Relais entkoppelt, sonst wuerden
# sie direkt Relais 1-3 schalten statt zu navigieren. Die externen
# Klemmenschalter (Switch1-4) bleiben unberuehrt und schalten weiterhin.
#
# Gegen Flackern wird ausschliesslich differenziell gezeichnet: Jeder Wert
# merkt sich, was zuletzt auf dem Schirm stand, und wird nur bei echter
# Aenderung neu ausgegeben. Texte tragen ihre Hintergrundfarbe mit (Bi),
# ueberschreiben sich also selbst - es wird nie vorher grossflaechig geloescht.

import string

class ShellyPro4PM

  var names          # Anzeigename je Kanal
  var power          # aktuell gelesene Wirkleistung je Kanal
  var selected       # markierte Zeile, 0..3
  var wifiSum, wifiSamples
  var lastKey, lastKeyTime

  # zuletzt tatsaechlich gezeichneter Zustand - Grundlage des Abgleichs
  var shownPower     # Leistung als fertiger Text
  var shownOn        # Schaltzustand
  var shownSel       # markierte Zeile
  var shownBars      # Anzahl WLAN-Balken

  # Layout (Display ist 160x128)
  var W, HDR, ROW, N
  # Farbindizes der Tasmota-Palette
  var BG, FG, DIM, ON, SEL

  def init()
    self.W   = 160
    self.HDR = 20          # Hoehe der Kopfzeile
    self.ROW = 27          # 20 + 4*27 = 128
    self.N   = 4
    self.BG  = 0           # schwarz
    self.FG  = 1           # weiss
    self.DIM = 15          # grau
    self.ON  = 3           # gruen
    self.SEL = 4           # blau

    self.power       = [0, 0, 0, 0]
    self.shownPower  = ["", "", "", ""]
    self.shownOn     = [nil, nil, nil, nil]
    self.shownSel    = -1
    self.shownBars   = -1
    self.selected    = 0
    self.wifiSum     = 0
    self.wifiSamples = 0
    self.lastKey     = -1
    self.lastKeyTime = 0
    self.read_names()

    # Tasten entkoppeln, damit sie navigieren statt zu schalten
    tasmota.cmd("SetOption73 1", true)

    self.add_rules()
    tasmota.add_driver(self)

    self.draw_all()
    # Noch einmal zeichnen, falls der Startbildschirm dazwischenfunkt
    tasmota.set_timer(3000, /-> self.draw_all())
  end

  def deinit()
    self.del()
  end

  def del()
    self.remove_rules()
    tasmota.remove_driver(self)
  end

  # ------------------------------------------------------------------ Namen
  def read_names()
    self.names = []
    var friendly = tasmota.cmd("status", true)["Status"]["FriendlyName"]
    for i: 0..self.N-1
      var n = i < friendly.size() ? friendly[i] : ""
      if n == "" || string.find(n, "Tasmota") == 0
        n = f"CH {i+1}"          # Vorgabenamen ersetzen
      end
      self.names.push(n)
    end
  end

  # --------------------------------------------------------------- Tastatur
  def add_rules()
    # Tasmota meldet Tastendruecke je nach Einstellung als #State oder
    # #Action. Beides wird registriert; key_event() entprellt, damit ein
    # Druck nicht doppelt zaehlt, falls beide Ereignisse eintreffen.
    tasmota.add_rule("Button1#State",  def (v,t,m) self.key_event(0) end)
    tasmota.add_rule("Button2#State",  def (v,t,m) self.key_event(1) end)
    tasmota.add_rule("Button3#State",  def (v,t,m) self.key_event(2) end)
    tasmota.add_rule("Button1#Action", def (v,t,m) self.key_event(0) end)
    tasmota.add_rule("Button2#Action", def (v,t,m) self.key_event(1) end)
    tasmota.add_rule("Button3#Action", def (v,t,m) self.key_event(2) end)
    for i: 0..self.N-1
      tasmota.add_rule(f"POWER{i+1}#state", def (v,t,m) self.refresh_rows() end)
    end
  end

  def remove_rules()
    for n: ["Button1#State", "Button2#State", "Button3#State",
            "Button1#Action", "Button2#Action", "Button3#Action"]
      tasmota.remove_rule(n)
    end
    for i: 0..self.N-1
      tasmota.remove_rule(f"POWER{i+1}#state")
    end
  end

  # Entprellung: Ereignisse innerhalb von 300 ms gelten als derselbe Druck.
  def key_event(key)
    var now = tasmota.millis()
    if self.lastKey == key && now - self.lastKeyTime < 300
      return
    end
    self.lastKey = key
    self.lastKeyTime = now
    if   key == 0  self.move(-1)
    elif key == 1  self.move(1)
    else           self.toggle()
    end
  end

  def move(delta)
    self.selected += delta
    if self.selected < 0        self.selected = self.N - 1 end
    if self.selected >= self.N  self.selected = 0          end
    self.refresh_selection()
  end

  def toggle()
    tasmota.cmd(f"POWER{self.selected + 1} TOGGLE", true)
    self.refresh_rows()
  end

  # --------------------------------------------------------------- Ausgabe
  def out(cmd)
    if cmd != ""
      tasmota.cmd(f"DisplayText {cmd}", true)
    end
  end

  def row_y(i)   return self.HDR + i * self.ROW end
  def row_mid(i) return self.row_y(i) + self.ROW / 2 end

  # Vollstaendiger Aufbau - nur beim Start
  def draw_all()
    self.out(f"[Ci{self.FG}Bi{self.BG}z]")
    self.shownPower = ["", "", "", ""]
    self.shownOn    = [nil, nil, nil, nil]
    self.shownSel   = -1
    self.shownBars  = -1
    self.sample_wifi()
    self.out(f"[x4y13Ci{self.FG}Bi{self.BG}f0]Shelly Pro 4PM[x0y{self.HDR-1}Ci{self.DIM}h{self.W}]")
    self.draw_clock()
    self.draw_wifi(true)
    for i: 0..self.N-1
      self.draw_name(i)
    end
    self.refresh_rows()
  end

  def draw_name(i)
    var col = (i == self.selected) ? self.FG : self.DIM
    var cmd = f"[x8y{self.row_mid(i)}Ci{col}Bi{self.BG}f0]{self.names[i]}    "
    # Markierungsbalken links
    var barCol = (i == self.selected) ? self.SEL : self.BG
    cmd += f"[x0y{self.row_y(i)+2}Ci{barCol}R3:{self.ROW-4}]"
    self.out(cmd)
  end

  # Nur die beiden betroffenen Zeilen anfassen, nicht alle vier
  def refresh_selection()
    if self.shownSel == self.selected return end
    var prev = self.shownSel
    self.shownSel = self.selected
    if prev >= 0 && prev < self.N
      self.draw_name(prev)
    end
    self.draw_name(self.selected)
  end

  # Leistung und Schaltzustand, jeweils nur bei echter Aenderung
  def refresh_rows()
    self.refresh_selection()
    var cmd = ""
    for i: 0..self.N-1
      var on = tasmota.get_power(i)
      var txt = f"{self.power[i]:%6.1f}W"
      if self.shownPower[i] != txt || self.shownOn[i] != on
        var col = on ? self.FG : self.DIM
        cmd += f"[x58y{self.row_mid(i)}Ci{col}Bi{self.BG}f0]{txt}"
        self.shownPower[i] = txt
      end
      if self.shownOn[i] != on
        cmd += self.switch_glyph(i, on)
        self.shownOn[i] = on
      end
    end
    self.out(cmd)
  end

  def switch_glyph(i, state)
    var w = 26
    var h = 13
    var r = h / 2
    var x = self.W - w - 6
    var y = self.row_y(i) + (self.ROW - h) / 2
    var col = state ? self.ON : self.DIM
    var cx = x + r + (state ? (w - h) : 0)
    var cy = y + r
    # Alten Schalter mit Hintergrundfarbe ueberdecken, dann neu zeichnen
    return f"[x{x}y{y}Ci{self.BG}R{w}:{h}x{x}y{y}Ci{col}U{w}:{h}:{r}x{cx}y{cy}Ci{self.FG}K{r-2}]"
  end

  def draw_clock()
    self.out(f"[x124y13Ci{self.FG}Bi{self.BG}f0t]")
  end

  def draw_wifi(force)
    var avg = self.wifiSamples == 0 ? 0 : self.wifiSum / self.wifiSamples
    var bars = 0
    if avg >= 20 bars = 1 end
    if avg >= 40 bars = 2 end
    if avg >= 60 bars = 3 end
    if avg >= 80 bars = 4 end
    if !force && bars == self.shownBars return end
    self.shownBars = bars
    var x = 104
    var y = 15
    var cmd = ""
    for b: 0..3
      var col = bars > b ? self.FG : self.DIM
      var h = (b + 1) * 2
      cmd += f"Ci{col}x{x + b*4}y{y - h}v{h}x{x + b*4 + 1}y{y - h}v{h}"
    end
    self.out(f"[{cmd}]")
  end

  # ------------------------------------------------------------- Messwerte
  def read_power()
    var sns = tasmota.cmd("status 10", true)
    if sns == nil return end
    var e = sns.find("StatusSNS")
    if e == nil return end
    e = e.find("ENERGY")
    if e == nil return end
    var p = e.find("Power")
    if p == nil return end
    for i: 0..self.N-1
      if i < p.size()
        self.power[i] = p[i]
      end
    end
  end

  def sample_wifi()
    var q = tasmota.wifi().find("quality")
    self.wifiSum += q ? q : 0
    self.wifiSamples += 1
  end

  def every_second()
    var secs = tasmota.time_dump(tasmota.rtc()["local"])["sec"]
    if secs % 2 == 0
      self.read_power()
      self.refresh_rows()      # zeichnet nur, was sich geaendert hat
    end
    if secs % 10 == 0
      self.sample_wifi()
      self.draw_wifi(false)
    end
    if secs == 0
      self.draw_clock()
      self.wifiSum = 0
      self.wifiSamples = 0
    end
  end

end

return ShellyPro4PM
