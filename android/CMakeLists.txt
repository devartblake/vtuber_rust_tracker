# CMakeLists.txt for Flutter OpenSeeFace Plugin Android
cmake_minimum_required(VERSION 3.18.1)

project(flutter_openseeface_plugin)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Get Android ABI
if(NOT DEFINED ANDROID_ABI)
    set(ANDROID_ABI "arm64-v8a")
endif()

# Set Rust library path based on build type and ABI
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(RUST_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../rust/target/${RUST_TARGET}/debug")
else()
    set(RUST_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../rust/target/${RUST_TARGET}/release")
endif()

# Map Android ABI to Rust target
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(RUST_TARGET "aarch64-linux-android")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(RUST_TARGET "armv7-linux-androideabi")
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(RUST_TARGET "x86_64-linux-android")
elseif(ANDROID_ABI STREQUAL "x86")
    set(RUST_TARGET "i686-linux-android")
endif()

# Update Rust library path with correct target
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(RUST_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../rust/target/${RUST_TARGET}/debug")
else()
    set(RUST_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../rust/target/${RUST_TARGET}/release")
endif()

# Find the Rust library
find_library(RUST_LIB
    NAMES flutter_openseeface_plugin
    PATHS ${RUST_LIB_DIR}
    NO_DEFAULT_PATH
    REQUIRED
)

if(NOT RUST_LIB)
    message(FATAL_ERROR "Could not find Rust library at ${RUST_LIB_DIR}")
endif()

message(STATUS "Found Rust library: ${RUST_LIB}")
message(STATUS "Android ABI: ${ANDROID_ABI}")
message(STATUS "Rust target: ${RUST_TARGET}")

# Create the plugin library
add_library(flutter_openseeface_plugin SHARED
    src/main/cpp/flutter_openseeface_plugin.cpp
)

# Set properties
set_target_properties(flutter_openseeface_plugin PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN 1
)

# Include directories
target_include_directories(flutter_openseeface_plugin PRIVATE
    src/main/cpp/include
)

# Link libraries
target_link_libraries(flutter_openseeface_plugin
    ${RUST_LIB}
    android
    log
)

# Compiler definitions
target_compile_definitions(flutter_openseeface_plugin PRIVATE
    FLUTTER_PLUGIN_IMPL
)

# Compiler options
target_compile_options(flutter_openseeface_plugin PRIVATE
    -Wall
    -Wextra
    -Werror
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:Debug>:-O0 -g>
)
