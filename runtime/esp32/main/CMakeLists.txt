# Shared sources live in runtime/src (protocol core, Ruby wrappers) and the
# mrubyc submodule; only the ESP32 platform/binding code lives here.
set(PRR_SRC    ${CMAKE_CURRENT_LIST_DIR}/../../src)
set(MRUBYC_DIR ${CMAKE_CURRENT_LIST_DIR}/../../mrubyc)

file(READ "${CMAKE_CURRENT_LIST_DIR}/../../../VERSION" RUNTIME_VERSION_RAW)
string(STRIP "${RUNTIME_VERSION_RAW}" RUNTIME_VERSION)

set(MRUBYC_SOURCES
  ${MRUBYC_DIR}/src/alloc.c
  ${MRUBYC_DIR}/src/c_array.c
  ${MRUBYC_DIR}/src/c_hash.c
  ${MRUBYC_DIR}/src/c_math.c
  ${MRUBYC_DIR}/src/c_numeric.c
  ${MRUBYC_DIR}/src/c_object.c
  ${MRUBYC_DIR}/src/c_proc.c
  ${MRUBYC_DIR}/src/c_range.c
  ${MRUBYC_DIR}/src/c_string.c
  ${MRUBYC_DIR}/src/class.c
  ${MRUBYC_DIR}/src/console.c
  ${MRUBYC_DIR}/src/error.c
  ${MRUBYC_DIR}/src/global.c
  ${MRUBYC_DIR}/src/keyvalue.c
  ${MRUBYC_DIR}/src/load.c
  ${MRUBYC_DIR}/src/mrblib.c
  ${MRUBYC_DIR}/src/rrt0.c
  ${MRUBYC_DIR}/src/symbol.c
  ${MRUBYC_DIR}/src/value.c
  ${MRUBYC_DIR}/src/vm.c
  ${MRUBYC_DIR}/hal/esp32/hal.c
)

idf_component_register(
  SRCS
    ${PRR_SRC}/runtime.c
    platform_esp32.c
    bindings_esp32.c
    bindings_wifi_esp32.c
    lcd_ili9342c.c
    ${MRUBYC_SOURCES}
  INCLUDE_DIRS
    .
    ${PRR_SRC}
    ${MRUBYC_DIR}/src
    ${MRUBYC_DIR}/hal/esp32
  REQUIRES driver vfs esp_timer esp_partition spi_flash esp_adc esp_lcd
           esp_wifi esp_netif nvs_flash
)

target_compile_definitions(${COMPONENT_LIB} PRIVATE
  MRBC_USE_HAL_ESP32
  MRBC_REQUIRE_32BIT_ALIGNMENT
  MAX_REGS_SIZE=256
  MAX_SYMBOLS_COUNT=500
  MRBC_SCHEDULER_EXIT=1
  HAS_LCD=1
  HAS_WIFI=1
  RUNTIME_VERSION="${RUNTIME_VERSION}"
)

# Find mrbc for compiling Ruby wrappers — same lookup as the Pico build
# (runtime/CMakeLists.txt); rbenv shims shadow the real binary.
if(DEFINED ENV{MRBC})
  set(MRBC_EXECUTABLE "$ENV{MRBC}")
else()
  find_program(MRBC_EXECUTABLE mrbc
    PATHS /opt/homebrew/bin /usr/local/bin /usr/bin
    NO_DEFAULT_PATH
  )
  if(NOT MRBC_EXECUTABLE)
    find_program(MRBC_EXECUTABLE mrbc)
  endif()
endif()
if(NOT MRBC_EXECUTABLE)
  message(FATAL_ERROR "mrbc not found. Install mruby: brew install mruby")
endif()

add_custom_command(
  OUTPUT ${PRR_SRC}/hw_wrap.h
  COMMAND ${MRBC_EXECUTABLE} -B hw_wrap -o ${PRR_SRC}/hw_wrap.h
          ${PRR_SRC}/hw_wrap.rb
  DEPENDS ${PRR_SRC}/hw_wrap.rb
  COMMENT "Compiling hw_wrap.rb → hw_wrap.h"
)
add_custom_target(hw_wrap_h DEPENDS ${PRR_SRC}/hw_wrap.h)

add_custom_command(
  OUTPUT ${PRR_SRC}/lcd_wrap.h
  COMMAND ${MRBC_EXECUTABLE} -B lcd_wrap -o ${PRR_SRC}/lcd_wrap.h
          ${PRR_SRC}/lcd_wrap.rb
  DEPENDS ${PRR_SRC}/lcd_wrap.rb
  COMMENT "Compiling lcd_wrap.rb → lcd_wrap.h"
)
add_custom_target(lcd_wrap_h DEPENDS ${PRR_SRC}/lcd_wrap.h)

add_custom_command(
  OUTPUT ${PRR_SRC}/cyw43_wrap.h
  COMMAND ${MRBC_EXECUTABLE} -B cyw43_wrap -o ${PRR_SRC}/cyw43_wrap.h
          ${PRR_SRC}/cyw43_wrap.rb
  DEPENDS ${PRR_SRC}/cyw43_wrap.rb
  COMMENT "Compiling cyw43_wrap.rb → cyw43_wrap.h"
)
add_custom_target(cyw43_wrap_h DEPENDS ${PRR_SRC}/cyw43_wrap.h)

add_custom_command(
  OUTPUT ${PRR_SRC}/time_wrap.h
  COMMAND ${MRBC_EXECUTABLE} -B time_wrap -o ${PRR_SRC}/time_wrap.h
          ${PRR_SRC}/time_wrap.rb
  DEPENDS ${PRR_SRC}/time_wrap.rb
  COMMENT "Compiling time_wrap.rb → time_wrap.h"
)
add_custom_target(time_wrap_h DEPENDS ${PRR_SRC}/time_wrap.h)

# mruby/c autogen headers + mrblib bytecode (host-side make, idempotent).
add_custom_command(
  OUTPUT ${MRUBYC_DIR}/src/_autogen_builtin_symbol.h
  WORKING_DIRECTORY ${MRUBYC_DIR}/src
  COMMAND make RUBY_INSTALLED=1 autogen
)
add_custom_target(mrubyc_autogen
  DEPENDS ${MRUBYC_DIR}/src/_autogen_builtin_symbol.h
)
add_custom_command(
  OUTPUT ${MRUBYC_DIR}/src/mrblib.c
  WORKING_DIRECTORY ${MRUBYC_DIR}/mrblib
  COMMAND make
)
add_custom_target(mrubyc_mrblib DEPENDS ${MRUBYC_DIR}/src/mrblib.c)

add_dependencies(${COMPONENT_LIB} hw_wrap_h lcd_wrap_h cyw43_wrap_h time_wrap_h mrubyc_autogen mrubyc_mrblib)
