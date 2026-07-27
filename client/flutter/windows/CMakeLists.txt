cmake_minimum_required(VERSION 3.14)
project(charo_messenger LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Flutter build configuration
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

# Application name
set(APPLICATION_ID "com.charo.messenger")

# Windows-specific options
set(WIN32_EXECUTABLE TRUE)

# Sources
add_executable(${BINARY_NAME} WIN32
  "flutter/generated_plugins.cmake"
  "runner/main.cpp"
  "runner/flutter_window.cpp"
  "runner/utils.cpp"
  "runner/resource.h"
)

# Apply standard settings
apply_standard_settings(${BINARY_NAME})

# Add Windows-specific dependencies
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Resource files
set(RESOURCES_APPLICATION_ID "com.charo.messenger")
set(RESOURCES_APP_NAME "ЧАРО")

configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/Runner.rc.in"
  "${CMAKE_CURRENT_BINARY_DIR}/runner/Runner.rc"
  @ONLY
)

target_sources(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/runner/Runner.rc")

# Flutter plugins
add_subdirectory(flutter/plugins)

# Install
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
