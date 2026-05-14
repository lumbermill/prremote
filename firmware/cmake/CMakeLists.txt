cmake_minimum_required(VERSION 3.22)

include(pico_sdk_import.cmake)
include(pico_extras_import.cmake)

pico_sdk_init()

execute_process(COMMAND date +%Y%m%d OUTPUT_VARIABLE CMAKE_BUILDDATE OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND git rev-parse --short HEAD OUTPUT_VARIABLE CMAKE_REVISION OUTPUT_STRIP_TRAILING_WHITESPACE WORKING_DIRECTORY ${PICORUBY_ROOT})

project("prremote-${PRREMOTE_VERSION}-${PICO_BOARD}-${CMAKE_BUILDDATE}-${CMAKE_REVISION}")

add_compile_options(-Wall
  -Wno-format
  -Wno-unused-function
  -ffunction-sections
  -fdata-sections
  -fshort-enums
  -mthumb
)

if(PICORB_DEBUG)
  add_compile_definitions(PICORB_DEBUG=1)
  add_compile_options(-O0 -g3)
else()
  add_compile_definitions(NDEBUG=1)
  add_compile_options(-O2)
endif()

file(GLOB SOURCE_FILES CONFIGURE_DEPENDS
  ${PICORUBY_ROOT}/mrbgems/*/ports/rp2040/*.c
  ${PICORUBY_ROOT}/mrbgems/*/ports/common/*.c
  ${PRREMOTE_SRC_DIR}/ports/rp2040/*.c
)

if(USE_WIFI)
  add_compile_definitions(USE_WIFI=1)
  file(GLOB REMOVE_SRCS CONFIGURE_DEPENDS
    ${PICORUBY_ROOT}/mrbgems/picoruby-filesystem-fat/ports/rp2040/*.c
    ${PICORUBY_ROOT}/mrbgems/picoruby-net/ports/rp2040/*.c
  )
else()
  file(GLOB REMOVE_SRCS CONFIGURE_DEPENDS
    ${PICORUBY_ROOT}/mrbgems/picoruby-filesystem-fat/ports/rp2040/*.c
    ${PICORUBY_ROOT}/mrbgems/picoruby-cyw43/ports/rp2040/*.c
    ${PICORUBY_ROOT}/mrbgems/picoruby-net/ports/rp2040/*.c
    ${PICORUBY_ROOT}/mrbgems/picoruby-socket/ports/rp2040/*.c
    ${PICORUBY_ROOT}/mrbgems/picoruby-ble/ports/rp2040/*.c
    ${PICORUBY_ROOT}/mrbgems/picoruby-mbedtls/ports/**/*.c
  )
endif()
list(REMOVE_ITEM SOURCE_FILES ${REMOVE_SRCS})

if(PICORB_VM_MRUBYC)
  file(GLOB REMOVE_MRUBY_SRCS CONFIGURE_DEPENDS
    ${PICORUBY_ROOT}/mrbgems/picoruby-mruby/ports/rp2040/*.c
  )
  list(REMOVE_ITEM SOURCE_FILES ${REMOVE_MRUBY_SRCS})
endif()

add_executable(${PROJECT_NAME} ${SOURCE_FILES})

pico_enable_stdio_usb(${PROJECT_NAME} 0)
if(PICORB_DEBUG)
  pico_enable_stdio_uart(${PROJECT_NAME} 1)
else()
  pico_enable_stdio_uart(${PROJECT_NAME} 0)
endif()

if(PICO_BOARD STREQUAL "pico" OR PICO_BOARD STREQUAL "pico_w")
  add_compile_definitions(PICO_RP2040=1)
  target_compile_definitions(${PROJECT_NAME} PRIVATE FLASH_TARGET_OFFSET=0x00140000)
endif()

add_compile_definitions(PICO_FLASH_ASSUME_CORE1_SAFE=1)

# Compile agent.rb → mrb/main_task.c via picorbc
set(PICORBC ${PICORUBY_ROOT}/bin/picorbc)

add_custom_target(mrbdir ALL
  COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/mrb
)

add_custom_target(main_task
  COMMAND
    ${PICORBC} -Bmain_task -o${CMAKE_BINARY_DIR}/mrb/main_task.c ${PRREMOTE_SRC_DIR}/agent.rb
  DEPENDS ${PRREMOTE_SRC_DIR}/agent.rb
)
add_dependencies(${PROJECT_NAME} mrbdir main_task)

target_link_directories(${PROJECT_NAME} PRIVATE
  ${EXTRA_LIBRARY_PATH}
  ${PICORUBY_ROOT}/build/${MRUBY_CONFIG}/lib
)

target_link_options(${PROJECT_NAME} PRIVATE -Wl,--gc-sections)

target_compile_definitions(${PROJECT_NAME} PRIVATE
  PICO_STACK_SIZE=0x1000
  PICO_CORE1_STACK_SIZE=0x0800
  PICO_HEAP_SIZE=0x0400
)

target_link_libraries(${PROJECT_NAME} PRIVATE
  pico_stdlib
  pico_stdio
  pico_stdio_uart
  pico_bootsel_via_double_reset
  tinyusb_device
  tinyusb_board
  hardware_flash
  hardware_adc
  hardware_uart
  hardware_i2c
  hardware_spi
  hardware_pwm
  pico_runtime
  pico_multicore
  hardware_claim
  hardware_pio
  hardware_dma
  hardware_sleep
  hardware_rtc
  mruby
)

if(USE_WIFI)
  target_link_libraries(${PROJECT_NAME} PRIVATE
    pico_cyw43_arch_lwip_threadsafe_background
  )
endif()

add_compile_definitions(PICORB_ALLOC_ESTALLOC=1)

if(PICORB_VM_MRUBY)
  add_compile_definitions(PICORB_VM_MRUBY=1 MRB_INT64=1 MRB_NO_BOXING=1 MRB_32BIT=1 MRB_UTF8_STRING=1)
  target_include_directories(${PROJECT_NAME} PRIVATE
    ${PICORUBY_ROOT}/mrbgems/picoruby-mruby/lib/mruby/include
  )
elseif(PICORB_VM_MRUBYC)
  add_compile_definitions(PICORB_VM_MRUBYC=1)
  target_include_directories(${PROJECT_NAME} PRIVATE
    ${PICORUBY_ROOT}/mrbgems/picoruby-mrubyc/lib/mrubyc/src
  )
endif()

target_include_directories(${PROJECT_NAME} PRIVATE
  ${CMAKE_BINARY_DIR}/mrb
  ${PICORUBY_ROOT}/include
  ${PICORUBY_ROOT}/mrbgems/mruby-compiler2/lib/prism/include
  ${PICORUBY_ROOT}/mrbgems/mruby-compiler2/include
  ${PICORUBY_ROOT}/build/${MRUBY_CONFIG}/include
  ${PICORUBY_ROOT}/build/${MRUBY_CONFIG}/mrbgems
  ${PICORUBY_ROOT}/mrbgems/picoruby-machine/include
  ${PICORUBY_ROOT}/mrbgems/picoruby-littlefs/lib/littlefs
  ${PICO_SDK_PATH}/src/rp2_common/pico_stdio_usb/include
  ${PICO_SDK_PATH}/src/rp2_common/hardware_dma/include
  ${EXTRA_INCLUDE_DIR}
)

pico_add_extra_outputs(${PROJECT_NAME})

add_custom_command(
  TARGET ${PROJECT_NAME}
  POST_BUILD
  COMMAND gzip -kf ${PROJECT_NAME}.uf2
)
