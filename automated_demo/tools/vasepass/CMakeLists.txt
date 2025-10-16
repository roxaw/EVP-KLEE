cmake_minimum_required(VERSION 3.9)
project(VaseInstrumentPass)

# Set your LLVM path if needed
set(LLVM_DIR "/usr/lib/llvm-10/cmake")

# Find LLVM package and load the configuration
find_package(LLVM 10.0 REQUIRED CONFIG)

# Add LLVM cmake module path
list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Include directories for LLVM and nlohmann_json
include_directories(${LLVM_INCLUDE_DIRS})
include_directories("/home/roxana/klee-env/klee-source/klee/externals/nlohmann_json/include")

# Add LLVM definitions
add_definitions(${LLVM_DEFINITIONS})

# Create MODULE library for the pass (MODULE is important for LLVM's dynamic loading)
add_library(VaseInstrumentPass MODULE VaseInstrumentPass.cpp)

# Set proper shared library flags for macos
if(APPLE)
  set_target_properties(VaseInstrumentPass PROPERTIES
    LINK_FLAGS "-undefined dynamic_lookup"
  )
endif()

# For MODULE type, we don't need to explicitly link against LLVM libraries
# target_link_libraries(VaseInstrumentPass ${llvm_libs})

# Debugging output
message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

