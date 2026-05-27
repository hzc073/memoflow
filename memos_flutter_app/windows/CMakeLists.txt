# Project-level configuration.
cmake_minimum_required(VERSION 3.14)

if(WIN32 AND NOT DEFINED CMAKE_TOOLCHAIN_FILE AND DEFINED ENV{VCPKG_ROOT})
  file(TO_CMAKE_PATH "$ENV{VCPKG_ROOT}" VCPKG_ROOT_PATH)
  set(VCPKG_TOOLCHAIN_FILE "${VCPKG_ROOT_PATH}/scripts/buildsystems/vcpkg.cmake")
  if(EXISTS "${VCPKG_TOOLCHAIN_FILE}")
    set(CMAKE_TOOLCHAIN_FILE "${VCPKG_TOOLCHAIN_FILE}" CACHE STRING "")
  endif()
endif()

if(WIN32 AND NOT DEFINED VCPKG_TARGET_TRIPLET)
  set(VCPKG_TARGET_TRIPLET "x64-windows-static-md" CACHE STRING "")
endif()

project(MemoFlow LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "MemoFlow")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

function(COPY_VERIFIED_ARCHIVE_IF_NEEDED ARCHIVE_DST EXPECTED_MD5)
  set(ARCHIVE_VALID FALSE)

  if(EXISTS "${ARCHIVE_DST}")
    file(MD5 "${ARCHIVE_DST}" ARCHIVE_DST_MD5)
    if(ARCHIVE_DST_MD5 STREQUAL EXPECTED_MD5)
      set(ARCHIVE_VALID TRUE)
    else()
      message(STATUS "Removing invalid archive cache: ${ARCHIVE_DST}")
      file(REMOVE "${ARCHIVE_DST}")
    endif()
  endif()

  if(NOT ARCHIVE_VALID)
    foreach(ARCHIVE_SRC IN LISTS ARGN)
      if(EXISTS "${ARCHIVE_SRC}")
        file(MD5 "${ARCHIVE_SRC}" ARCHIVE_SRC_MD5)
        if(ARCHIVE_SRC_MD5 STREQUAL EXPECTED_MD5)
          get_filename_component(ARCHIVE_DST_DIR "${ARCHIVE_DST}" DIRECTORY)
          file(MAKE_DIRECTORY "${ARCHIVE_DST_DIR}")
          message(STATUS "Seeding local archive fallback: ${ARCHIVE_SRC}")
          configure_file("${ARCHIVE_SRC}" "${ARCHIVE_DST}" COPYONLY)
          set(ARCHIVE_VALID TRUE)
          break()
        endif()
      endif()
    endforeach()
  endif()
endfunction()

function(SEED_MEDIA_KIT_MPV_FALLBACK)
  set(LIBMPV "mpv-dev-x86_64-20230924-git-652a1dd.7z")
  set(LIBMPV_MD5 "a832ef24b3a6ff97cd2560b5b9d04cd8")
  set(LIBMPV_ARCHIVE_DST "${CMAKE_BINARY_DIR}/${LIBMPV}")

  file(GLOB LIBMPV_ARCHIVE_CANDIDATES
    "${CMAKE_CURRENT_SOURCE_DIR}/../tool/windows_native_deps/${LIBMPV}"
    "${CMAKE_CURRENT_SOURCE_DIR}/../tool/*/${LIBMPV}"
    "${CMAKE_CURRENT_SOURCE_DIR}/../tool/*/*/${LIBMPV}"
    "${CMAKE_CURRENT_SOURCE_DIR}/../dist/*/${LIBMPV}"
    "${CMAKE_CURRENT_SOURCE_DIR}/../dist/*/*/${LIBMPV}"
  )

  COPY_VERIFIED_ARCHIVE_IF_NEEDED(
    "${LIBMPV_ARCHIVE_DST}"
    "${LIBMPV_MD5}"
    ${LIBMPV_ARCHIVE_CANDIDATES}
  )
endfunction()

function(SEED_MEDIA_KIT_ANGLE_FALLBACK)
  set(ANGLE_ARCHIVE_DST "${CMAKE_BINARY_DIR}/ANGLE.7z")
  set(ANGLE_DIR_DST "${CMAKE_BINARY_DIR}/ANGLE")
  set(ANGLE_URL "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z")
  set(ANGLE_MD5 "e866f13e8d552348058afaafe869b1ed")
  set(ANGLE_REQUIRED_FILES
    "include/EGL/egl.h"
    "lib/libEGL.dll.lib"
    "lib/libGLESv2.dll.lib"
    "d3dcompiler_47.dll"
    "libEGL.dll"
    "libGLESv2.dll"
    "vk_swiftshader.dll"
    "vulkan-1.dll"
    "zlib.dll"
  )

  file(GLOB ANGLE_ARCHIVE_CANDIDATES
    "${CMAKE_CURRENT_SOURCE_DIR}/../tool/windows_native_deps/ANGLE.7z"
    "${CMAKE_CURRENT_SOURCE_DIR}/../tool/*/ANGLE.7z"
    "${CMAKE_CURRENT_SOURCE_DIR}/../tool/*/*/ANGLE.7z"
    "${CMAKE_CURRENT_SOURCE_DIR}/../dist/*/ANGLE.7z"
    "${CMAKE_CURRENT_SOURCE_DIR}/../dist/*/*/ANGLE.7z"
  )

  COPY_VERIFIED_ARCHIVE_IF_NEEDED(
    "${ANGLE_ARCHIVE_DST}"
    "${ANGLE_MD5}"
    ${ANGLE_ARCHIVE_CANDIDATES}
  )

  if(NOT EXISTS "${ANGLE_ARCHIVE_DST}")
    set(ANGLE_DOWNLOAD_SUCCESS FALSE)
    foreach(ANGLE_DOWNLOAD_ATTEMPT RANGE 1 3)
      message(STATUS "Downloading ANGLE archive from ${ANGLE_URL} (attempt ${ANGLE_DOWNLOAD_ATTEMPT}/3)...")
      file(REMOVE "${ANGLE_ARCHIVE_DST}")
      file(DOWNLOAD
        "${ANGLE_URL}"
        "${ANGLE_ARCHIVE_DST}"
        STATUS ANGLE_DOWNLOAD_STATUS
        SHOW_PROGRESS
        TIMEOUT 900
        INACTIVITY_TIMEOUT 120
      )
      list(GET ANGLE_DOWNLOAD_STATUS 0 ANGLE_DOWNLOAD_CODE)
      list(GET ANGLE_DOWNLOAD_STATUS 1 ANGLE_DOWNLOAD_MESSAGE)
      if(ANGLE_DOWNLOAD_CODE EQUAL 0 AND EXISTS "${ANGLE_ARCHIVE_DST}")
        file(MD5 "${ANGLE_ARCHIVE_DST}" ANGLE_ARCHIVE_MD5)
        if(ANGLE_ARCHIVE_MD5 STREQUAL ANGLE_MD5)
          set(ANGLE_DOWNLOAD_SUCCESS TRUE)
          break()
        endif()
        message(STATUS "Downloaded ANGLE archive MD5 mismatch; retrying.")
      else()
        message(STATUS "ANGLE archive download failed: ${ANGLE_DOWNLOAD_MESSAGE}")
      endif()
    endforeach()

    if(NOT ANGLE_DOWNLOAD_SUCCESS)
      file(REMOVE "${ANGLE_ARCHIVE_DST}")
      message(FATAL_ERROR "Failed to download a valid ANGLE archive after 3 attempts.")
    endif()
  endif()

  set(ANGLE_DIR_COMPLETE TRUE)
  foreach(ANGLE_REQUIRED_FILE IN LISTS ANGLE_REQUIRED_FILES)
    if(NOT EXISTS "${ANGLE_DIR_DST}/${ANGLE_REQUIRED_FILE}")
      set(ANGLE_DIR_COMPLETE FALSE)
    endif()
  endforeach()

  if(NOT ANGLE_DIR_COMPLETE)
    find_program(ANGLE_ARCHIVER
      NAMES 7z 7z.exe 7za 7za.exe 7zr 7zr.exe
      HINTS
        "$ENV{ProgramFiles}/7-Zip"
        "C:/Program Files (x86)/7-Zip"
        "$ENV{LOCALAPPDATA}/Programs/7-Zip"
        "$ENV{ProgramFiles}/NVIDIA Corporation/NVIDIA app"
        "$ENV{ProgramFiles}/VMware"
    )

    file(REMOVE_RECURSE "${ANGLE_DIR_DST}")
    file(MAKE_DIRECTORY "${ANGLE_DIR_DST}")

    if(ANGLE_ARCHIVER)
      execute_process(
        COMMAND "${ANGLE_ARCHIVER}" x "-o${ANGLE_DIR_DST}" -y "${ANGLE_ARCHIVE_DST}"
        RESULT_VARIABLE ANGLE_EXTRACT_RESULT
        OUTPUT_VARIABLE ANGLE_EXTRACT_OUTPUT
        ERROR_VARIABLE ANGLE_EXTRACT_ERROR
      )
    else()
      execute_process(
        COMMAND "${CMAKE_COMMAND}" -E tar xzf "${ANGLE_ARCHIVE_DST}"
        WORKING_DIRECTORY "${ANGLE_DIR_DST}"
        RESULT_VARIABLE ANGLE_EXTRACT_RESULT
        OUTPUT_VARIABLE ANGLE_EXTRACT_OUTPUT
        ERROR_VARIABLE ANGLE_EXTRACT_ERROR
      )
    endif()

    if(NOT ANGLE_EXTRACT_RESULT EQUAL 0)
      file(REMOVE_RECURSE "${ANGLE_DIR_DST}")
      message(WARNING "Failed to extract ${ANGLE_ARCHIVE_DST}: ${ANGLE_EXTRACT_OUTPUT}${ANGLE_EXTRACT_ERROR}")
    endif()

    set(ANGLE_DIR_COMPLETE TRUE)
    foreach(ANGLE_REQUIRED_FILE IN LISTS ANGLE_REQUIRED_FILES)
      if(NOT EXISTS "${ANGLE_DIR_DST}/${ANGLE_REQUIRED_FILE}")
        set(ANGLE_DIR_COMPLETE FALSE)
      endif()
    endforeach()
  endif()

  if(NOT ANGLE_DIR_COMPLETE)
    file(GLOB ANGLE_MARKER_CANDIDATES
      "${CMAKE_CURRENT_SOURCE_DIR}/../tool/*/libEGL.dll"
      "${CMAKE_CURRENT_SOURCE_DIR}/../tool/*/*/libEGL.dll"
      "${CMAKE_CURRENT_SOURCE_DIR}/../dist/*/libEGL.dll"
      "${CMAKE_CURRENT_SOURCE_DIR}/../dist/*/*/libEGL.dll"
    )

    foreach(ANGLE_MARKER_FILE IN LISTS ANGLE_MARKER_CANDIDATES)
      get_filename_component(ANGLE_MARKER_DIR "${ANGLE_MARKER_FILE}" DIRECTORY)
      set(ANGLE_MARKER_DIR_VALID TRUE)
      foreach(ANGLE_REQUIRED_FILE IN LISTS ANGLE_REQUIRED_FILES)
        if(NOT EXISTS "${ANGLE_MARKER_DIR}/${ANGLE_REQUIRED_FILE}")
          set(ANGLE_MARKER_DIR_VALID FALSE)
        endif()
      endforeach()

      if(ANGLE_MARKER_DIR_VALID)
        file(MAKE_DIRECTORY "${ANGLE_DIR_DST}")
        foreach(ANGLE_REQUIRED_FILE IN LISTS ANGLE_REQUIRED_FILES)
          get_filename_component(ANGLE_REQUIRED_DIR "${ANGLE_DIR_DST}/${ANGLE_REQUIRED_FILE}" DIRECTORY)
          file(MAKE_DIRECTORY "${ANGLE_REQUIRED_DIR}")
          file(COPY "${ANGLE_MARKER_DIR}/${ANGLE_REQUIRED_FILE}" DESTINATION "${ANGLE_REQUIRED_DIR}")
        endforeach()
        set(ANGLE_DIR_COMPLETE TRUE)
        break()
      endif()
    endforeach()
  endif()

  if(NOT ANGLE_DIR_COMPLETE)
    message(FATAL_ERROR "ANGLE archive exists, but required Windows video runtime files are incomplete in ${ANGLE_DIR_DST}.")
  endif()
endfunction()

SEED_MEDIA_KIT_MPV_FALLBACK()
SEED_MEDIA_KIT_ANGLE_FALLBACK()


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

set(CAESIUM_DLL_CANDIDATES
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/caesium.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/runner/libcaesium.dll"
)
foreach(CAESIUM_DLL IN LISTS CAESIUM_DLL_CANDIDATES)
  if(EXISTS "${CAESIUM_DLL}")
    install(FILES "${CAESIUM_DLL}"
      DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
      COMPONENT Runtime)
  endif()
endforeach()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
