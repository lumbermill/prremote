cmake_minimum_required(VERSION 3.12)

file(READ "${CMAKE_SOURCE_DIR}/../VERSION" RUNTIME_VERSION_RAW)
string(STRIP "${RUNTIME_VERSION_RAW}" RUNTIME_VERSION)

# Default board is pico_w; override with: cmake -B build/pico -DPICO_BOARD=pico
set(PICO_BOARD pico_w CACHE STRING "Target board (pico, pico_w, pico2_w, etc.)")
include(pico_sdk_import.cmake)

project(mrubyc-pico-w-runtime C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

# Find mrbc for compiling Ruby wrappers — skip rbenv shims which shadow the binary
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

add_compile_options(-DMRBC_USE_HAL_RP2040 -DMRBC_REQUIRE_32BIT_ALIGNMENT -DMAX_REGS_SIZE=256 -DMAX_SYMBOLS_COUNT=500)

# hal.c uses mrbc_tick() declared in rrt0.h, but mrubyc upstream does not include rrt0.h
# from hal.h yet — suppress the implicit-function-declaration warning rather than patching
# the submodule. https://github.com/mrubyc/mrubyc/issues/288
set_source_files_properties(mrubyc/hal/rp2040/hal.c
  PROPERTIES COMPILE_OPTIONS "-Wno-implicit-function-declaration"
)

set(MRUBYC_SOURCES
  mrubyc/src/alloc.c
  mrubyc/src/c_array.c
  mrubyc/src/c_hash.c
  mrubyc/src/c_math.c
  mrubyc/src/c_numeric.c
  mrubyc/src/c_object.c
  mrubyc/src/c_proc.c
  mrubyc/src/c_range.c
  mrubyc/src/c_string.c
  mrubyc/src/class.c
  mrubyc/src/console.c
  mrubyc/src/error.c
  mrubyc/src/global.c
  mrubyc/src/keyvalue.c
  mrubyc/src/load.c
  mrubyc/src/mrblib.c
  mrubyc/src/rrt0.c
  mrubyc/src/symbol.c
  mrubyc/src/value.c
  mrubyc/src/vm.c
  mrubyc/hal/rp2040/hal.c
)

# Shared: mruby/c autogen headers
add_custom_command(
  OUTPUT ${CMAKE_SOURCE_DIR}/mrubyc/src/_autogen_builtin_symbol.h
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/mrubyc/src
  COMMAND make RUBY_INSTALLED=1 autogen
)
add_custom_target(autogen
  DEPENDS ${CMAKE_SOURCE_DIR}/mrubyc/src/_autogen_builtin_symbol.h
)

# Shared: mrblib.c (built-in Ruby methods compiled to bytecode)
add_custom_command(
  OUTPUT ${CMAKE_SOURCE_DIR}/mrubyc/src/mrblib.c
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/mrubyc/mrblib
  COMMAND make
)
add_custom_target(mrblib
  DEPENDS ${CMAKE_SOURCE_DIR}/mrubyc/src/mrblib.c
)

# Map cmake PICO_BOARD to the gem's naming convention (no underscores)
string(REPLACE "_" "" RUNTIME_BOARD "${PICO_BOARD}")

# Compile hw_wrap.rb (GPIO / ADC / PWM Ruby classes) — always included
add_custom_command(
  OUTPUT ${CMAKE_SOURCE_DIR}/src/hw_wrap.h
  COMMAND ${MRBC_EXECUTABLE} -B hw_wrap -o ${CMAKE_SOURCE_DIR}/src/hw_wrap.h
          ${CMAKE_SOURCE_DIR}/src/hw_wrap.rb
  DEPENDS ${CMAKE_SOURCE_DIR}/src/hw_wrap.rb
  COMMENT "Compiling hw_wrap.rb → hw_wrap.h"
)
add_custom_target(hw_wrap_h DEPENDS ${CMAKE_SOURCE_DIR}/src/hw_wrap.h)

# --- Board-specific sources, defines, and libraries ---
set(BOARD_SOURCES  "")
set(BOARD_DEFINES  "")
set(BOARD_LIBS     "")
set(BOARD_DEPS     hw_wrap_h)
set(BOARD_INCLUDES "")

if(PICO_BOARD STREQUAL "pico_w" OR PICO_BOARD STREQUAL "pico2_w")
  # picoruby submodule paths
  set(PICORUBY_DIR   ${CMAKE_SOURCE_DIR}/picoruby)
  set(PICOSOCKET_DIR ${PICORUBY_DIR}/mrbgems/picoruby-socket)

  add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/src/cyw43_wrap.h
    COMMAND ${MRBC_EXECUTABLE} -B cyw43_wrap -o ${CMAKE_SOURCE_DIR}/src/cyw43_wrap.h
            ${CMAKE_SOURCE_DIR}/src/cyw43_wrap.rb
    DEPENDS ${CMAKE_SOURCE_DIR}/src/cyw43_wrap.rb
    COMMENT "Compiling cyw43_wrap.rb → cyw43_wrap.h"
  )
  add_custom_target(cyw43_wrap_h DEPENDS ${CMAKE_SOURCE_DIR}/src/cyw43_wrap.h)

  # socket_wrap: basic_socket.rb + tcp_socket.rb → bytecode header
  add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/src/socket_wrap.h
    COMMAND ${MRBC_EXECUTABLE} -B socket_wrap -o ${CMAKE_SOURCE_DIR}/src/socket_wrap.h
            ${PICOSOCKET_DIR}/mrblib/basic_socket.rb
            ${PICOSOCKET_DIR}/mrblib/tcp_socket.rb
    DEPENDS
            ${PICOSOCKET_DIR}/mrblib/basic_socket.rb
            ${PICOSOCKET_DIR}/mrblib/tcp_socket.rb
    COMMENT "Compiling socket_wrap (picoruby-socket) → socket_wrap.h"
  )
  add_custom_target(socket_wrap_h DEPENDS ${CMAKE_SOURCE_DIR}/src/socket_wrap.h)

  # time_wrap: Time class (NTP-synced clock) — Pico W only
  add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/src/time_wrap.h
    COMMAND ${MRBC_EXECUTABLE} -B time_wrap -o ${CMAKE_SOURCE_DIR}/src/time_wrap.h
            ${CMAKE_SOURCE_DIR}/src/time_wrap.rb
    DEPENDS ${CMAKE_SOURCE_DIR}/src/time_wrap.rb
    COMMENT "Compiling time_wrap.rb → time_wrap.h"
  )
  add_custom_target(time_wrap_h DEPENDS ${CMAKE_SOURCE_DIR}/src/time_wrap.h)

  list(APPEND BOARD_SOURCES
    ${CMAKE_SOURCE_DIR}/src/bindings_cyw43.c
    ${CMAKE_SOURCE_DIR}/src/ntp.c
    ${PICOSOCKET_DIR}/ports/rp2040/tcp_socket.c
    ${CMAKE_SOURCE_DIR}/src/net_helpers.c
    ${CMAKE_SOURCE_DIR}/src/mdns_resolver.c
    ${PICOSOCKET_DIR}/src/mrubyc/tcp_socket.c
    ${CMAKE_SOURCE_DIR}/src/socket_init.c
  )
  list(APPEND BOARD_INCLUDES ${PICOSOCKET_DIR}/include)
  list(APPEND BOARD_DEFINES  HAS_WIFI=1 HAS_SOCKET=1)
  list(APPEND BOARD_LIBS     pico_cyw43_arch_lwip_threadsafe_background)
  list(APPEND BOARD_DEPS     cyw43_wrap_h socket_wrap_h time_wrap_h)

  # picoruby-socket sources include "picoruby.h"; inject compat header only for those files
  set_source_files_properties(
    ${PICOSOCKET_DIR}/ports/rp2040/tcp_socket.c
    ${PICOSOCKET_DIR}/src/mrubyc/tcp_socket.c
    ${CMAKE_SOURCE_DIR}/src/socket_init.c
    PROPERTIES COMPILE_OPTIONS "-include;${CMAKE_SOURCE_DIR}/src/picoruby_compat.h"
  )
endif()

# --- Runtime: reflash-once firmware, receives .mrb via USB serial ---
# Build:  cmake --build build --target runtime
# Output: build/prremote-<board>-runtime-<version>.uf2
add_executable(runtime
  ${CMAKE_SOURCE_DIR}/src/runtime.c
  ${CMAKE_SOURCE_DIR}/src/platform_pico.c
  ${CMAKE_SOURCE_DIR}/src/bindings.c
  ${BOARD_SOURCES}
  ${MRUBYC_SOURCES}
)
target_include_directories(runtime PRIVATE
  ${CMAKE_SOURCE_DIR}/mrubyc/src
  ${CMAKE_SOURCE_DIR}/mrubyc/hal/rp2040
  ${CMAKE_SOURCE_DIR}/src
  ${BOARD_INCLUDES}
)
set_target_properties(runtime PROPERTIES
  OUTPUT_NAME "prremote-${RUNTIME_BOARD}-runtime-${RUNTIME_VERSION}"
)
target_compile_definitions(runtime PRIVATE
  MRBC_SCHEDULER_EXIT=1
  RUNTIME_VERSION="${RUNTIME_VERSION}"
  ${BOARD_DEFINES}
)
add_dependencies(runtime autogen mrblib ${BOARD_DEPS})
target_link_libraries(runtime
  pico_stdlib
  hardware_gpio
  hardware_adc
  hardware_pwm
  hardware_i2c
  hardware_spi
  hardware_timer
  hardware_watchdog
  hardware_flash
  hardware_sync
  ${BOARD_LIBS}
)
pico_enable_stdio_usb(runtime 1)
pico_enable_stdio_uart(runtime 0)
pico_add_extra_outputs(runtime)
