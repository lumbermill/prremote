MRuby::CrossBuild.new("prremote-picoruby-pico") do |conf|

  ###############################################################
  # You need following tools:
  #   arm-none-eabi       | to make libmruby.a
  ###############################################################

  conf.toolchain :gcc

  conf.cc.command = "arm-none-eabi-gcc"
  conf.linker.command = "arm-none-eabi-ld"
  conf.linker.flags << "-static"
  conf.archiver.command = "arm-none-eabi-ar"

  conf.cc.host_command = "gcc"

  conf.cc.flags.flatten!
  conf.cc.flags << "-mcpu=cortex-m0plus"
  conf.cc.flags << "-mthumb"
  conf.cc.flags << "-fno-strict-aliasing"
  conf.cc.flags << "-fshort-enums"
  conf.cc.flags << "-Wall"
  conf.cc.flags << "-Wno-format"
  conf.cc.flags << "-Wno-unused-function"
  conf.cc.flags << "-ffunction-sections"
  conf.cc.flags << "-fdata-sections"

  conf.cc.defines << "PICORB_PLATFORM_RP2"
  conf.cc.defines << "MRBC_REQUIRE_32BIT_ALIGNMENT=1"
  conf.cc.defines << "MRBC_CONVERT_CRLF=1"
  conf.cc.defines << "MRBC_USE_FLOAT=2"
  conf.cc.defines << "MRBC_USE_MATH=1"
  conf.cc.defines << "MRBC_TICK_UNIT=1"
  conf.cc.defines << "MRBC_TIMESLICE_TICK_COUNT=10"
  conf.cc.defines << "NO_CLOCK_GETTIME=1"
  conf.cc.defines << "MAX_SYMBOLS_COUNT=1800"
  conf.cc.defines << "PICORB_ALLOC_ESTALLOC"
  conf.cc.defines << "PICORB_ALLOC_ALIGN=8"

  conf.gembox "minimum"
  conf.gembox "core"
  conf.gembox "stdlib"
  conf.gembox "peripherals"

  conf.mrubyc_hal_arm
  conf.femtoruby(alloc_libc: false)

end
