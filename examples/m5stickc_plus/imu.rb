# Device: M5StickC PLUS (ESP32-PICO-D4)
# Reads acceleration (g) and angular rate (deg/s) from the internal MPU6886
# IMU over I2C — no wiring needed (I2C address 0x68, shared bus with the
# AXP192 PMIC on SDA=GPIO21/SCL=GPIO22).
#
# Init sequence and register map follow M5StickC-Plus's MPU6886.cpp
# (https://github.com/m5stack/M5StickC-Plus, src/utility/MPU6886.{h,cpp}).
# Confirmed on physical hardware: WHO_AM_I reads 0x19 as expected.

MPU_ADDR = 0x68

i2c = I2C.new(sda_pin: 21, scl_pin: 22)

i2c.write(MPU_ADDR, 0x6B, 0x00) # PWR_MGMT_1: wake up
sleep 0.01
i2c.write(MPU_ADDR, 0x6B, 0x80) # PWR_MGMT_1: device reset
sleep 0.01
i2c.write(MPU_ADDR, 0x6B, 0x01) # PWR_MGMT_1: clock = PLL with X-axis gyro ref
i2c.write(MPU_ADDR, 0x1C, 0x10) # ACCEL_CONFIG: +/-8G
i2c.write(MPU_ADDR, 0x1B, 0x18) # GYRO_CONFIG: +/-2000dps
i2c.write(MPU_ADDR, 0x1A, 0x01) # CONFIG: DLPF
i2c.write(MPU_ADDR, 0x19, 0x05) # SMPLRT_DIV
i2c.write(MPU_ADDR, 0x38, 0x00) # INT_ENABLE: off (while configuring)
i2c.write(MPU_ADDR, 0x1D, 0x00) # ACCEL_CONFIG2
i2c.write(MPU_ADDR, 0x6A, 0x00) # USER_CTRL
i2c.write(MPU_ADDR, 0x23, 0x00) # FIFO_EN: off
i2c.write(MPU_ADDR, 0x37, 0x22) # INT_PIN_CFG
i2c.write(MPU_ADDR, 0x38, 0x01) # INT_ENABLE: data ready

ACCEL_RES = 8.0 / 32_768.0    # +/-8G full scale
GYRO_RES  = 2000.0 / 32_768.0 # +/-2000dps full scale

def to_i16(hi, lo)
  v = (hi << 8) | lo
  v -= 65_536 if v >= 32_768
  v
end

# mrubyc's Float has no #round(ndigits) — truncate to n decimal places by hand.
def trunc(x, scale)
  (x * scale).to_i / scale.to_f
end

puts "Move/tilt the board (reading for 10 s)..."
100.times do
  bytes = i2c.read(MPU_ADDR, 6, 0x3B)&.bytes
  ax = to_i16(bytes[0], bytes[1]) * ACCEL_RES
  ay = to_i16(bytes[2], bytes[3]) * ACCEL_RES
  az = to_i16(bytes[4], bytes[5]) * ACCEL_RES

  bytes = i2c.read(MPU_ADDR, 6, 0x43)&.bytes
  gx = to_i16(bytes[0], bytes[1]) * GYRO_RES
  gy = to_i16(bytes[2], bytes[3]) * GYRO_RES
  gz = to_i16(bytes[4], bytes[5]) * GYRO_RES

  puts "accel(g)=#{trunc(ax, 100)},#{trunc(ay, 100)},#{trunc(az, 100)} " \
       "gyro(dps)=#{trunc(gx, 10)},#{trunc(gy, 10)},#{trunc(gz, 10)}"
  sleep 0.1
end
