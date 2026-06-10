# Device: Pico W only (requires CYW43 WiFi chip)
# Displays current time (JST = UTC+9) updated every second.
# Syncs once per hour via NIST daytime protocol (TCP port 13, RFC 867) —
# no UDP or NTP library required.
#
# Set SSID and PASSWORD before deploying.

SSID     = "360-raspi"
PASSWORD = "raspberry"

TZ_OFFSET_H   = 9     # JST = UTC+9
SYNC_INTERVAL = 3600  # seconds between re-syncs

DAYS_IN_MONTH = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

def leap?(y)
  (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)
end

def month_days(m, y)
  m == 2 && leap?(y) ? 29 : DAYS_IN_MONTH[m]
end

def pad2(n)
  n < 10 ? "0#{n}" : "#{n}"
end

# Connect to NIST daytime service and return [y, mo, d, h, mi, s] in local
# time, or nil on failure.
#
# NIST response format (fixed-width):
#   "\nJJJJJ YY-MM-DD HH:MM:SS TT L H msADV UTC(NIST) *\n"
#    ^leading newline the server always prepends
def sync_time(offset_h)
  sock = TCPSocket.new("time.nist.gov", 13)
  data = sock.read   # read until server closes (no maxlen = read to EOF)
  sock.close
  return nil if data.nil? || data.length < 24
  # NIST always prepends "\n" before the data line; detect and skip it
  start = data[0, 1] == "\n" ? 1 : 0
  return nil if data.length - start < 23
  yr = data[start + 6,  2].to_i + 2000
  mo = data[start + 9,  2].to_i
  d  = data[start + 12, 2].to_i
  h  = data[start + 15, 2].to_i + offset_h
  mi = data[start + 18, 2].to_i
  s  = data[start + 21, 2].to_i
  # Basic sanity check to catch misaligned parses
  return nil if yr < 2020 || mo < 1 || mo > 12 || d < 1 || d > 31
  # Roll day forward when UTC+offset crosses midnight
  if h >= 24
    h -= 24
    d += 1
    if d > month_days(mo, yr)
      d = 1; mo += 1
      if mo > 12; mo = 1; yr += 1; end
    end
  end
  [yr, mo, d, h, mi, s]
rescue => e
  puts "sync failed: #{e.message}"
  nil
end

# Advance broken-down time by one second in place (returns new array).
def tick(y, mo, d, h, mi, s)
  s += 1
  if s >= 60
    s = 0; mi += 1
    if mi >= 60
      mi = 0; h += 1
      if h >= 24
        h = 0; d += 1
        if d > month_days(mo, y)
          d = 1; mo += 1
          if mo > 12; mo = 1; y += 1; end
        end
      end
    end
  end
  [y, mo, d, h, mi, s]
end

# ---- WiFi ----

CYW43.init("JP")
puts "Connecting to #{SSID}..."
begin
  CYW43::WiFi.connect(SSID, PASSWORD, CYW43::Auth::WPA2_MIXED_PSK, 15)
  puts "Connected! IP: #{CYW43::WiFi.ipv4_address}"
rescue CYW43::WiFi::ConnectError => e
  puts "Auth failed: #{e.message}"
  return
rescue CYW43::WiFi::ConnectTimeout => e
  puts "Timed out: #{e.message}"
  return
end

# ---- Initial sync (retry until successful) ----

t = nil
loop do
  t = sync_time(TZ_OFFSET_H)
  break if t
  puts "Retrying in 5s..."
  sleep 5
end

y, mo, d, h, mi, s = t
puts "Synced: #{y}-#{pad2(mo)}-#{pad2(d)} #{pad2(h)}:#{pad2(mi)}:#{pad2(s)} JST"

# ---- Main loop ----

sync_counter = 0

loop do
  puts "#{y}-#{pad2(mo)}-#{pad2(d)} #{pad2(h)}:#{pad2(mi)}:#{pad2(s)} JST"
  sleep 1
  y, mo, d, h, mi, s = tick(y, mo, d, h, mi, s)
  sync_counter += 1
  if sync_counter >= SYNC_INTERVAL
    sync_counter = 0
    new_t = sync_time(TZ_OFFSET_H)
    if new_t
      y, mo, d, h, mi, s = new_t
      puts "Re-synced."
    end
  end
end
