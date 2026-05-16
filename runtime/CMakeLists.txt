cmake_minimum_required(VERSION 3.12)

set(RUNTIME_VERSION "0.1.2")

set(PICO_BOARD pico_w)
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

# --- Board-specific sources, defines, and libraries ---
set(BOARD_SOURCES "")
set(BOARD_DEFINES "")
set(BOARD_LIBS   "")
set(BOARD_DEPS   "")

if(PICO_BOARD STREQUAL "pico_w" OR PICO_BOARD STREQUAL "pico2_w")
  add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/src/cyw43_wrap.h
    COMMAND ${MRBC_EXECUTABLE} -B cyw43_wrap -o ${CMAKE_SOURCE_DIR}/src/cyw43_wrap.h
            ${CMAKE_SOURCE_DIR}/src/cyw43_wrap.rb
    DEPENDS ${CMAKE_SOURCE_DIR}/src/cyw43_wrap.rb
    COMMENT "Compiling cyw43_wrap.rb → cyw43_wrap.h"
  )
  add_custom_target(cyw43_wrap_h DEPENDS ${CMAKE_SOURCE_DIR}/src/cyw43_wrap.h)

  list(APPEND BOARD_SOURCES ${CMAKE_SOURCE_DIR}/src/bindings_cyw43.c)
  list(APPEND BOARD_DEFINES HAS_CYW43=1)
  list(APPEND BOARD_LIBS   pico_cyw43_arch_lwip_threadsafe_background)
  list(APPEND BOARD_DEPS   cyw43_wrap_h)
endif()

# --- Runtime: reflash-once firmware, receives .mrb via USB serial ---
# Build:  cmake --build build --target runtime
# Output: build/prremote-<board>-runtime-<version>.uf2
add_executable(runtime
  ${CMAKE_SOURCE_DIR}/src/runtime.c
  ${CMAKE_SOURCE_DIR}/src/bindings.c
  ${BOARD_SOURCES}
  ${MRUBYC_SOURCES}
)
target_include_directories(runtime PRIVATE
  ${CMAKE_SOURCE_DIR}/mrubyc/src
  ${CMAKE_SOURCE_DIR}/mrubyc/hal/rp2040
  ${CMAKE_SOURCE_DIR}/src
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
  hardware_watchdog
  ${BOARD_LIBS}
)
pico_enable_stdio_usb(runtime 1)
pico_enable_stdio_uart(runtime 0)
pico_add_extra_outputs(runtime)
