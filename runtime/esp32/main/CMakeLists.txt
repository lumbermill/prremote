# Shared sources live in runtime/src (protocol core, Ruby wrappers) and the
# mrubyc submodule; only the ESP32 platform/binding code lives here.
set(PRR_SRC    ${CMAKE_CURRENT_LIST_DIR}/../../src)
set(MRUBYC_DIR ${CMAKE_CURRENT_LIST_DIR}/../../mrubyc)
set(PICOSOCKET ${CMAKE_CURRENT_LIST_DIR}/../../picoruby/mrbgems/picoruby-socket)

file(READ "${CMAKE_CURRENT_LIST_DIR}/../../../VERSION" RUNTIME_VERSION_RAW)
string(STRIP "${RUNTIME_VERSION_RAW}" RUNTIME_VERSION)
# Re-run CMake when VERSION changes so a bump re-embeds RUNTIME_VERSION instead
# of reusing the configure-time cached value (otherwise the READY banner stays
# stale until a manual idf.py reconfigure / fullclean).
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
             "${CMAKE_CURRENT_LIST_DIR}/../../../VERSION")

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

# picoruby-socket: TCP/UDP over the ESP-IDF lwIP BSD socket API — same wiring
# as the esp32c6 build (see runtime/esp32c6/main/CMakeLists.txt for the full
# rationale on the vendored bindings, socket.h path and lwipopts.h shadowing).
set(SOCKET_SOURCES
  ${PICOSOCKET}/ports/esp32/tcp_socket.c
  ${PICOSOCKET}/ports/esp32/udp_socket.c
  ${PRR_SRC}/tcp_socket_binding.c
  ${PRR_SRC}/udp_socket_binding.c
  ${PRR_SRC}/socket_init.c
)

idf_component_register(
  SRCS
    ${PRR_SRC}/runtime.c
    platform_esp32.c
    bindings_esp32.c
    bindings_wifi_esp32.c
    lcd_ili9342c.c
    ${SOCKET_SOURCES}
    ${MRUBYC_SOURCES}
  INCLUDE_DIRS
    .
    ${PRR_SRC}
    ${MRUBYC_DIR}/src
    ${MRUBYC_DIR}/hal/esp32
  REQUIRES driver vfs esp_timer esp_partition spi_flash esp_adc esp_lcd
           esp_wifi esp_netif nvs_flash lwip
)

target_compile_definitions(${COMPONENT_LIB} PRIVATE
  MRBC_USE_HAL_ESP32
  MRBC_REQUIRE_32BIT_ALIGNMENT
  MAX_REGS_SIZE=256
  MAX_SYMBOLS_COUNT=500
  MRBC_SCHEDULER_EXIT=1
  MRBC_SUPPORT_OP_EXT
  # One mruby/c VM per wrap task plus the user script: hw + WiFi + time +
  # TCPSocket + UDPSocket + LCD = 6, +1 user = 7, which exceeds mruby/c's
  # default MAX_VM_COUNT of 5 ("Can't assign VM-ID") — same as esp32c6.
  MAX_VM_COUNT=8
  HAS_LCD=1
  HAS_WIFI=1
  HAS_SOCKET=1
  HAS_UDP_SOCKET=1
  RUNTIME_VERSION="${RUNTIME_VERSION}"
  MRB_BUFFER_SIZE_KB=64
)

# picoruby-socket C sources include "picoruby.h" and expect picorb_alloc/free;
# picoruby_compat.h (injected via -include) bridges them to plain mruby/c.
# PICORB_PLATFORM_POSIX selects the BSD-socket (fd-based) picorb_socket_t.
set_source_files_properties(${SOCKET_SOURCES} PROPERTIES
  COMPILE_OPTIONS "-include;${PRR_SRC}/picoruby_compat.h;-DPICORB_PLATFORM_POSIX=1")

# runtime/src contains the pico-sdk lwIP config src/lwipopts.h (NO_SYS=1 /
# LWIP_SOCKET=0), which would shadow ESP-IDF's and compile the BSD socket API
# out. Put ESP-IDF's lwip port include (the correct lwipopts.h) first to win
# the lookup — see runtime/esp32c6/main/CMakeLists.txt.
idf_component_get_property(lwip_dir lwip COMPONENT_DIR)
target_include_directories(${COMPONENT_LIB} BEFORE PRIVATE ${lwip_dir}/port/include)

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

# socket_wrap.h (BasicSocket + TCPSocket Ruby layer) is shared verbatim with
# the picow build and committed under runtime/src; reuse it as-is. Only the
# UDPSocket Ruby layer needs compiling into a separate bytecode blob.
add_custom_command(
  OUTPUT ${PRR_SRC}/socket_wrap_udp.h
  COMMAND ${MRBC_EXECUTABLE} -B socket_wrap_udp -o ${PRR_SRC}/socket_wrap_udp.h
          ${PICOSOCKET}/mrblib/udp_socket.rb
  DEPENDS ${PICOSOCKET}/mrblib/udp_socket.rb
  COMMENT "Compiling udp_socket.rb → socket_wrap_udp.h"
)
add_custom_target(socket_wrap_udp_h DEPENDS ${PRR_SRC}/socket_wrap_udp.h)

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

add_dependencies(${COMPONENT_LIB} hw_wrap_h lcd_wrap_h cyw43_wrap_h time_wrap_h socket_wrap_udp_h mrubyc_autogen mrubyc_mrblib)
