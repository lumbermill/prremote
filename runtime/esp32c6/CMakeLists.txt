# prremote runtime for ESP32-C6 (RISC-V).
#
# Requires ESP-IDF v5.3 (not vendored; see runtime/README section "ESP32"):
#   source $IDF_PATH/export.sh && idf.py build
# or from runtime/:  rake build:esp32c6

cmake_minimum_required(VERSION 3.16)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(prremote-esp32c6-runtime)
