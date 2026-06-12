# Time — SNTP-synced wall clock for Pico W.
# Not compatible with picoruby-time; this is a prremote-specific class.
# WiFi (CYW43) must be connected before calling sync.
#
# Example:
#   t = Time.new(offset: 9)    # JST = UTC+9
#   t.sync("ntp.nict.jp")      # fetch via SNTP (UDP port 123)
#   puts t.to_s                 # "2026-06-11T15:30:00+9"
#                               # NOTE: explicit .to_s — mruby/c's OP_STRCAT
#                               # does not call a Ruby-defined #to_s, so
#                               # "#{t}" interpolates as an empty string.
#   t.sleep(60)                 # sleep 60 s and advance internal clock
class Time
  DAYS_IN_MONTH = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

  def initialize(offset: 0)
    @utc_offset = offset
    @year  = 1970
    @month = 1
    @day   = 1
    @hour  = 0
    @min   = 0
    @sec   = 0
  end

  def year;       @year;       end
  def month;      @month;      end
  def day;        @day;        end
  def hour;       @hour;       end
  def min;        @min;        end
  def sec;        @sec;        end
  def utc_offset; @utc_offset; end

  # Fetch time via SNTP (UDP port 123).
  # Returns self on success, nil on failure.
  # interval: nil  — single attempt (default); Integer — retry every N seconds
  # timeout:  nil  — no time limit; Integer — give up after N seconds total (wall clock)
  def sync(host = "pool.ntp.org", interval: nil, timeout: nil)
    deadline = timeout ? uptime_ms + timeout * 1000 : nil
    loop do
      return self if _try_sync(host)
      return nil if interval.nil?
      return nil if deadline && uptime_ms >= deadline
      sleep(interval)
    end
  end

  # Sleep n seconds and advance the internal clock by n seconds.
  # super calls Object#sleep (the C binding) without recursing into Time#sleep.
  def sleep(n)
    super
    _advance(n)
    self
  end

  # Seconds since Unix epoch (1970-01-01 00:00:00 UTC).
  def epoch
    days = _days_since_epoch(@year, @month, @day)
    days * 86400 + (@hour - @utc_offset) * 3600 + @min * 60 + @sec
  end

  # Returns elapsed seconds. Accepts Integer (epoch) or another Time.
  def -(other)
    case other
    when Integer then epoch - other
    when Time    then epoch - other.epoch
    end
  end

  def to_s
    sign = @utc_offset >= 0 ? "+" : "-"
    "#{@year}-#{_p2(@month)}-#{_p2(@day)}T#{_p2(@hour)}:#{_p2(@min)}:#{_p2(@sec)}#{sign}#{@utc_offset.abs}"
  end

  # ------------------------------------------------------------------ #
  # Private helpers                                                      #
  # ------------------------------------------------------------------ #

  # Single SNTP attempt via _ntp_gettime (C binding, UDP port 123).
  def _try_sync(host)
    unix_time = _ntp_gettime(host, 10000)
    return nil if unix_time == 0
    return nil if unix_time < 1_577_836_800   # sanity: before 2020-01-01
    _set_from_epoch(unix_time)
    self
  rescue
    nil
  end

  # Set broken-down time from a Unix epoch integer.
  # Days-to-civil-date uses the Hinnant O(1) algorithm.
  def _set_from_epoch(unix_time)
    s     = unix_time + @utc_offset * 3600
    @sec  = s % 60; s = s / 60
    @min  = s % 60; s = s / 60
    @hour = s % 24
    days  = s / 24

    z   = days + 719468
    era = z / 146097
    doe = z - era * 146097
    yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365
    y   = yoe + era * 400
    doy = doe - (365*yoe + yoe/4 - yoe/100)
    mp  = (5*doy + 2) / 153
    @day   = doy - (153*mp + 2)/5 + 1
    @month = mp < 10 ? mp + 3 : mp - 9
    @year  = y + (@month <= 2 ? 1 : 0)
  end

  def _p2(n)
    n < 10 ? "0#{n}" : "#{n}"
  end

  def _leap?(y)
    (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)
  end

  def _month_days(m, y)
    m == 2 && _leap?(y) ? 29 : DAYS_IN_MONTH[m]
  end

  # Days since 1970-01-01 (proleptic Gregorian, O(1) formula).
  def _days_since_epoch(y, m, d)
    my = m <= 2 ? y - 1 : y
    mm = m <= 2 ? m + 12 : m
    a = 365 * my + my / 4 - my / 100 + my / 400
    b = (153 * mm - 457) / 5
    a + b + d - 719_469
  end

  # Advance the broken-down time by secs seconds in O(1) arithmetic.
  def _advance(secs)
    @sec += secs
    xm = @sec / 60; @sec = @sec % 60
    @min += xm
    xh = @min / 60; @min = @min % 60
    @hour += xh
    xd = @hour / 24; @hour = @hour % 24
    xd.times do
      @day += 1
      if @day > _month_days(@month, @year)
        @day = 1; @month += 1
        if @month > 12; @month = 1; @year += 1; end
      end
    end
  end
end
