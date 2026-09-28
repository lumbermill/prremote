# BM8563 / PCF8563 real-time clock (I2C address 0x51).
# Board library for prremote — compiled into the script by the host when it
# references BM8563 (see lib/prremote/boards.rb); this file runs on the device.
#
#   rtc = BM8563.new(i2c)
#   rtc.valid?                 # false until the time has been set (VL flag)
#   puts rtc.time.to_s         # => "2026-09-28T08:30:42+9" (a Time)
#   rtc.time = Time.new(offset: 9).sync("ntp.nict.jp")
#
# The chip holds local time; `time(offset:)` says which zone that is (JST by
# default) and `time=` writes the given Time in its own offset.
class BM8563
  ADDR = 0x51

  def initialize(i2c)
    @i2c = i2c
  end

  # false while the VL (voltage-low) flag says the clock lost integrity —
  # never set, or the backup battery ran out.
  def valid?
    r = @i2c.read(ADDR, 1, 0x02)
    !r.nil? && r.getbyte(0) < 0x80
  end

  def time(offset: 9)
    r = @i2c.read(ADDR, 7, 0x02).bytes
    t = Time.new(offset: offset)
    year = _dec(r[6]) + (r[5] < 0x80 ? 2000 : 1900) # month bit7 = century
    days = t._days_since_epoch(year, _dec(r[5] & 0x1F), _dec(r[3] & 0x3F))
    t._set_from_epoch((days * 86_400) + _seconds_of_day(r) - (offset * 3600))
    t
  end

  # Also clears the VL flag and restarts the clock if it was stopped.
  def time=(t)
    wday = (((t.epoch + (t.utc_offset * 3600)) / 86_400) + 4) % 7 # 1970-01-01 = Thu
    @i2c.write(ADDR, 0x00, 0x00, 0x00) # control 1/2: running, no alarm/timer IRQ
    @i2c.write(ADDR, 0x02, _bcd(t.sec), _bcd(t.min), _bcd(t.hour), _bcd(t.day),
               wday, _bcd(t.month), _bcd(t.year % 100))
  end

  # r: registers 0x02.. (sec, min, hour, ...)
  def _seconds_of_day(r)
    (_dec(r[2] & 0x3F) * 3600) + (_dec(r[1] & 0x7F) * 60) + _dec(r[0] & 0x7F)
  end

  def _dec(b)
    ((b >> 4) * 10) + (b & 0x0F)
  end

  def _bcd(n)
    ((n / 10) << 4) | (n % 10)
  end
end
