cmake_minimum_required(VERSION 3.20)
project(LyraCore CXX)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# set C++ standard to 20
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# load FetchContent module
include(FetchContent)

# load vcpkg dependencies
find_package(nlohmann_json CONFIG REQUIRED)
find_package(fmt CONFIG REQUIRED)
find_package(SQLiteCpp CONFIG REQUIRED)
find_package(stduuid CONFIG REQUIRED)

set(CPP
    src/lyra_c_api.cpp
    src/database.cpp
    src/utils/uuid_generator.cpp
)

add_library(lyra_core SHARED ${CPP})

# .h files in include/ directory
target_include_directories(lyra_core PUBLIC include)

# link vcpkg packages with our code
target_link_libraries(lyra_core PRIVATE 
    nlohmann_json::nlohmann_json 
    fmt::fmt
    SQLiteCpp
    stduuid
)