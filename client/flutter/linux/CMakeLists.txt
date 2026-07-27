cmake_minimum_required(VERSION 3.10)
project(charo_messenger LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Application name
set(APPLICATION_ID "com.charo.messenger")
set(BINARY_NAME "charo_messenger")

# Flutter configuration
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

# Find GTK3
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK3 REQUIRED gtk+-3.0)

# Sources
add_executable(${BINARY_NAME}
  "flutter/generated_plugins.cmake"
  "runner/main.cc"
  "runner/my_application.cc"
)

apply_standard_settings(${BINARY_NAME})
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# GTK3 linking
target_link_libraries(${BINARY_NAME} PRIVATE ${GTK3_LIBRARIES})
target_include_directories(${BINARY_NAME} PRIVATE ${GTK3_INCLUDE_DIRS})

# Flutter plugins
add_subdirectory(flutter/plugins)

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
