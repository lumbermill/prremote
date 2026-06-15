# Device: M5GO / M5Stack Core (ESP32)
# Digital spirit level using the built-in MPU6886 IMU — no wiring needed.
# Internal I2C bus: SDA=GPIO21, SCL=GPIO22, IMU I2C address=0x68.
# Tilt the M5GO to move the bubble; green = level (within ~10 px of center).

IMU_ADDR = 0x68
SCALE    = 16384   # LSB/g for ±2 g full-scale range (MPU6886 default)
CX       = 160
CY       = 125
RING_R   = 70
BULL_R   = 12
DISP_R   = 54      # max bubble displacement = RING_R - BULL_R - 4

GRAY = LCD.rgb(80, 80, 80)
GOLD = LCD.rgb(160, 140, 0)

i2c = I2C.new(sda_pin: 21, scl_pin: 22)
i2c.write(IMU_ADDR, 0x6B, 0x00) # PWR_MGMT_1: clear sleep bit to wake MPU6886
sleep 0.1

lcd = LCD.new
lcd.fill(LCD::BLACK)
lcd.text(40, 5, "SPIRIT LEVEL", color: LCD::WHITE, scale: 2)

# Static ring border (square, 2 px thick)
lcd.fill_rect(CX - RING_R,     CY - RING_R,     RING_R * 2, 2,          GRAY)
lcd.fill_rect(CX - RING_R,     CY + RING_R - 2, RING_R * 2, 2,          GRAY)
lcd.fill_rect(CX - RING_R,     CY - RING_R,     2,          RING_R * 2, GRAY)
lcd.fill_rect(CX + RING_R - 2, CY - RING_R,     2,          RING_R * 2, GRAY)

# Crosshairs
lcd.fill_rect(CX - RING_R + 2, CY - 1, (RING_R * 2) - 4, 2, GRAY)
lcd.fill_rect(CX - 1, CY - RING_R + 2, 2, (RING_R * 2) - 4, GRAY)

# Small target marker at center
lcd.fill_rect(CX - 5, CY - 5, 10, 10, GOLD)

prev_bx = CX
prev_by = CY

loop do
  raw = i2c.read(IMU_ADDR, 6, 0x3B)
  next unless raw

  b = raw.bytes

  ax = (b[0] << 8) | b[1]
  ax -= 65536 if ax >= 32768
  ay = (b[2] << 8) | b[3]
  ay -= 65536 if ay >= 32768

  dx = ax * DISP_R / SCALE
  dy = -ay * DISP_R / SCALE # flip: screen +Y is downward

  dx =  DISP_R if dx >  DISP_R
  dx = -DISP_R if dx < -DISP_R
  dy =  DISP_R if dy >  DISP_R
  dy = -DISP_R if dy < -DISP_R

  bx = CX + dx
  by = CY + dy

  # Erase previous bubble, then restore crosshairs it may have covered
  lcd.fill_rect(prev_bx - BULL_R, prev_by - BULL_R, BULL_R * 2, BULL_R * 2, LCD::BLACK)
  lcd.fill_rect(CX - RING_R + 2, CY - 1, (RING_R * 2) - 4, 2, GRAY)
  lcd.fill_rect(CX - 1, CY - RING_R + 2, 2, (RING_R * 2) - 4, GRAY)
  lcd.fill_rect(CX - 5, CY - 5, 10, 10, GOLD)

  color = (dx * dx) + (dy * dy) < 100 ? LCD::GREEN : LCD::CYAN
  lcd.fill_rect(bx - BULL_R, by - BULL_R, BULL_R * 2, BULL_R * 2, color)

  prev_bx = bx
  prev_by = by

  sleep 0.04
end
