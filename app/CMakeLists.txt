# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(smartband LANGUAGES C)

target_sources(app PRIVATE
  src/main.c
  src/imu.c
  src/ppg.c
  src/ui.c
)

target_include_directories(app PRIVATE src)
