cmake_minimum_required(VERSION 3.12)

set(RUNTIME_VERSION "0.1.1")

set(PICO_BOARD pico_w)
include(pico_sdk_import.cmake)

project(mrubyc-pico-w-runtime C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

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

# --- Runtime: reflash-once firmware, receives .mrb via USB serial ---
# Build:  make runtime   (or: rake runtime)
# Output: build/runtime.uf2
add_executable(runtime
  ${CMAKE_SOURCE_DIR}/src/runtime.c
  ${MRUBYC_SOURCES}
)
target_include_directories(runtime PRIVATE
  ${CMAKE_SOURCE_DIR}/mrubyc/src
  ${CMAKE_SOURCE_DIR}/mrubyc/hal/rp2040
  ${CMAKE_SOURCE_DIR}/src
)
set_target_properties(runtime PROPERTIES
  OUTPUT_NAME "prremote-picow-runtime-${RUNTIME_VERSION}"
)
target_compile_definitions(runtime PRIVATE
  MRBC_SCHEDULER_EXIT=1
  RUNTIME_VERSION="${RUNTIME_VERSION}"
)
add_dependencies(runtime autogen mrblib)
target_link_libraries(runtime
  pico_stdlib
  pico_cyw43_arch_lwip_threadsafe_background
  hardware_gpio
  hardware_watchdog
)
pico_enable_stdio_usb(runtime 1)
pico_enable_stdio_uart(runtime 0)
pico_add_extra_outputs(runtime)
