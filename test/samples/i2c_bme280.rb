# Device: Pico / Pico W — I2C temperature/humidity/pressure sensor (BME280)
# Wiring: SDA → GPIO 4, SCL → GPIO 5, VCC → 3.3V, GND → GND
# BME280 I2C address: 0x76 (SDO=GND), 0x77 (SDO=3.3V)
# Board: https://akizukidenshi.com/catalog/g/g109421/

I2C_ADDR = 0x76

i2c = I2C.new(unit: :RP2040_I2C0, sda_pin: 4, scl_pin: 5, frequency: 400_000)

# Read 6 bytes of temperature calibration trimming data from 0x88 (T1, T2, T3)
calib = i2c.read(I2C_ADDR, 6, 0x88)&.bytes
unless calib
  puts "calibration read error"
  return
end

dig_T1 = (calib[1] << 8) | calib[0]           # unsigned 16-bit
dig_T2 = (calib[3] << 8) | calib[2]           # signed 16-bit
dig_T2 -= 65536 if dig_T2 >= 32768
dig_T3 = (calib[5] << 8) | calib[4]           # signed 16-bit
dig_T3 -= 65536 if dig_T3 >= 32768

# ctrl_meas (0xF4): temp oversampling x1 (001), pressure skip (000), normal mode (11)
i2c.write(I2C_ADDR, 0xF4, 0x23)
sleep 0.1

loop do
  raw = i2c.read(I2C_ADDR, 3, 0xFA)&.bytes
  if raw
    adc_T = (raw[0] << 12) | (raw[1] << 4) | (raw[2] >> 4)

    # Temperature compensation formula from BME280 datasheet section 4.2.3
    var1 = ((adc_T >> 3) - (dig_T1 << 1)) * dig_T2 >> 11
    var2 = (((adc_T >> 4) - dig_T1) * ((adc_T >> 4) - dig_T1) >> 12) * dig_T3 >> 14
    temp = ((var1 + var2) * 5 + 128) >> 8  # 0.01 degC units

    puts "#{temp / 100.0} C"
  else
    puts "read error"
  end
  sleep 1
end
