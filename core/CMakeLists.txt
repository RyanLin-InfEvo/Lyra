# SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
#
# SPDX-License-Identifier: AGPL-3.0-or-later

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
find_package(tl-expected CONFIG REQUIRED)

set(CPP
    src/lyra_c_api.cpp
    src/router.cpp
    src/services/database_context.cpp
    src/services/repositories/sqlite_album_repository.cpp
    src/services/repositories/sqlite_artist_repository.cpp
    src/services/repositories/sqlite_playlist_repository.cpp
    src/services/repositories/sqlite_track_repository.cpp
    src/services/repositories/sqlite_work_repository.cpp
    src/utils/uuid_generator.cpp
    src/utils/json_validator.cpp
    src/utils/sqlite_helper.cpp
    src/utils/make_error.cpp
    src/models/relation_types.cpp
    src/controllers/album_controller.cpp
    src/controllers/artist_controller.cpp
    src/controllers/track_controller.cpp
    src/controllers/work_controller.cpp
    src/controllers/playlist_controller.cpp
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
    tl::expected
)

add_executable(lyra-cli src/cli/main.cpp)
target_link_libraries(lyra-cli PRIVATE lyra_core nlohmann_json::nlohmann_json fmt::fmt)
target_include_directories(lyra-cli PRIVATE include)