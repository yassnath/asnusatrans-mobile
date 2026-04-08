# This file controls Flutter-level build steps. It should not be edited.
cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided via flutter tool.
include(${EPHEMERAL_DIR}/generated_config.cmake)

# Set fallback configurations for older versions of the flutter tool before
# resolving SDK artifact paths that depend on the target platform.
if (NOT DEFINED FLUTTER_TARGET_PLATFORM)
  set(FLUTTER_TARGET_PLATFORM "windows-x64")
endif()

# TODO: Move the rest of this into files in ephemeral. See
# https://github.com/flutter/flutter/issues/57146.
set(WRAPPER_ROOT "${EPHEMERAL_DIR}/cpp_client_wrapper")
set(FLUTTER_ENGINE_FALLBACK_ROOT
  "${FLUTTER_ROOT}/bin/cache/artifacts/engine/${FLUTTER_TARGET_PLATFORM}")
set(WRAPPER_FALLBACK_ROOT
  "${FLUTTER_ENGINE_FALLBACK_ROOT}/cpp_client_wrapper")
set(WRAPPER_INCLUDE_ROOT "${WRAPPER_ROOT}/include")
set(FLUTTER_DART_BINARY
  "${FLUTTER_ROOT}/bin/cache/dart-sdk/bin/dart.exe")
set(FLUTTER_ASSET_BUNDLE_DIR "${PROJECT_DIR}/build/flutter_assets")
set(FLUTTER_ASSET_MANIFEST_SCRIPT
  "${PROJECT_DIR}/tooling/windows/ensure_asset_manifests.dart")

# Some Windows environments end up with an incomplete ephemeral wrapper folder
# where only the include directory exists. Repopulate the wrapper sources from
# the Flutter SDK cache so MSBuild can still compile the Windows runner.
if((NOT EXISTS "${WRAPPER_ROOT}/core_implementations.cc"
    OR NOT EXISTS "${WRAPPER_ROOT}/plugin_registrar.cc"
    OR NOT EXISTS "${WRAPPER_ROOT}/standard_codec.cc"
    OR NOT EXISTS "${WRAPPER_ROOT}/flutter_engine.cc"
    OR NOT EXISTS "${WRAPPER_ROOT}/flutter_view_controller.cc")
   AND EXISTS "${WRAPPER_FALLBACK_ROOT}/core_implementations.cc")
  file(MAKE_DIRECTORY "${WRAPPER_ROOT}")
  file(COPY "${WRAPPER_FALLBACK_ROOT}/" DESTINATION "${WRAPPER_ROOT}")
endif()

if(EXISTS "${WRAPPER_FALLBACK_ROOT}/include/flutter")
  set(WRAPPER_INCLUDE_ROOT "${WRAPPER_FALLBACK_ROOT}/include")
endif()

add_custom_target(flutter_sync_ephemeral_fallback
  COMMAND ${CMAKE_COMMAND} -E make_directory "${EPHEMERAL_DIR}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${WRAPPER_ROOT}"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_ENGINE_FALLBACK_ROOT}/flutter_export.h"
    "${EPHEMERAL_DIR}/flutter_export.h"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_ENGINE_FALLBACK_ROOT}/flutter_windows.h"
    "${EPHEMERAL_DIR}/flutter_windows.h"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_ENGINE_FALLBACK_ROOT}/flutter_messenger.h"
    "${EPHEMERAL_DIR}/flutter_messenger.h"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_ENGINE_FALLBACK_ROOT}/flutter_plugin_registrar.h"
    "${EPHEMERAL_DIR}/flutter_plugin_registrar.h"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_ENGINE_FALLBACK_ROOT}/flutter_texture_registrar.h"
    "${EPHEMERAL_DIR}/flutter_texture_registrar.h"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_ENGINE_FALLBACK_ROOT}/flutter_windows.dll"
    "${EPHEMERAL_DIR}/flutter_windows.dll"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_ENGINE_FALLBACK_ROOT}/flutter_windows.dll.lib"
    "${EPHEMERAL_DIR}/flutter_windows.dll.lib"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_ENGINE_FALLBACK_ROOT}/icudtl.dat"
    "${EPHEMERAL_DIR}/icudtl.dat"
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${WRAPPER_FALLBACK_ROOT}"
    "${WRAPPER_ROOT}"
  VERBATIM
)

add_custom_target(flutter_generate_asset_manifests
  COMMAND "${FLUTTER_DART_BINARY}"
    "${FLUTTER_ASSET_MANIFEST_SCRIPT}"
    "${FLUTTER_ASSET_BUNDLE_DIR}"
    "${PROJECT_DIR}"
    "${FLUTTER_ROOT}"
  VERBATIM
)

function(resolve_wrapper_source out_var filename)
  if(EXISTS "${WRAPPER_FALLBACK_ROOT}/${filename}")
    set(${out_var} "${WRAPPER_FALLBACK_ROOT}/${filename}" PARENT_SCOPE)
  elseif(EXISTS "${WRAPPER_ROOT}/${filename}")
    set(${out_var} "${WRAPPER_ROOT}/${filename}" PARENT_SCOPE)
  else()
    set(${out_var} "${WRAPPER_FALLBACK_ROOT}/${filename}" PARENT_SCOPE)
  endif()
endfunction()

# === Flutter Library ===
set(FLUTTER_LIBRARY "${EPHEMERAL_DIR}/flutter_windows.dll")

# Published to parent scope for install step.
set(FLUTTER_LIBRARY ${FLUTTER_LIBRARY} PARENT_SCOPE)
set(FLUTTER_ICU_DATA_FILE "${EPHEMERAL_DIR}/icudtl.dat" PARENT_SCOPE)
set(PROJECT_BUILD_DIR "${PROJECT_DIR}/build/" PARENT_SCOPE)
set(AOT_LIBRARY "${PROJECT_DIR}/build/windows/app.so" PARENT_SCOPE)

list(APPEND FLUTTER_LIBRARY_HEADERS
  "flutter_export.h"
  "flutter_windows.h"
  "flutter_messenger.h"
  "flutter_plugin_registrar.h"
  "flutter_texture_registrar.h"
)
list(TRANSFORM FLUTTER_LIBRARY_HEADERS PREPEND "${EPHEMERAL_DIR}/")
add_library(flutter INTERFACE)
target_include_directories(flutter INTERFACE
  "${EPHEMERAL_DIR}"
)
target_link_libraries(flutter INTERFACE "${FLUTTER_LIBRARY}.lib")
add_dependencies(flutter flutter_assemble)

# === Wrapper ===
resolve_wrapper_source(CPP_WRAPPER_SOURCE_CORE_IMPLEMENTATIONS "core_implementations.cc")
resolve_wrapper_source(CPP_WRAPPER_SOURCE_STANDARD_CODEC "standard_codec.cc")
set(CPP_WRAPPER_SOURCES_CORE
  "${CPP_WRAPPER_SOURCE_CORE_IMPLEMENTATIONS}"
  "${CPP_WRAPPER_SOURCE_STANDARD_CODEC}"
)
resolve_wrapper_source(CPP_WRAPPER_SOURCE_PLUGIN_REGISTRAR "plugin_registrar.cc")
set(CPP_WRAPPER_SOURCES_PLUGIN
  "${CPP_WRAPPER_SOURCE_PLUGIN_REGISTRAR}"
)
resolve_wrapper_source(CPP_WRAPPER_SOURCE_FLUTTER_ENGINE "flutter_engine.cc")
resolve_wrapper_source(CPP_WRAPPER_SOURCE_FLUTTER_VIEW_CONTROLLER "flutter_view_controller.cc")
set(CPP_WRAPPER_SOURCES_APP
  "${CPP_WRAPPER_SOURCE_FLUTTER_ENGINE}"
  "${CPP_WRAPPER_SOURCE_FLUTTER_VIEW_CONTROLLER}"
)

# Wrapper sources needed for a plugin.
add_library(flutter_wrapper_plugin STATIC
  ${CPP_WRAPPER_SOURCES_CORE}
  ${CPP_WRAPPER_SOURCES_PLUGIN}
)
apply_standard_settings(flutter_wrapper_plugin)
set_target_properties(flutter_wrapper_plugin PROPERTIES
  POSITION_INDEPENDENT_CODE ON)
set_target_properties(flutter_wrapper_plugin PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_link_libraries(flutter_wrapper_plugin PUBLIC flutter)
target_include_directories(flutter_wrapper_plugin PUBLIC
  "${WRAPPER_INCLUDE_ROOT}"
)
add_dependencies(flutter_wrapper_plugin flutter_assemble)
add_dependencies(flutter_wrapper_plugin flutter_sync_ephemeral_fallback)
add_dependencies(flutter_wrapper_plugin flutter_generate_asset_manifests)

# Wrapper sources needed for the runner.
add_library(flutter_wrapper_app STATIC
  ${CPP_WRAPPER_SOURCES_CORE}
  ${CPP_WRAPPER_SOURCES_APP}
)
apply_standard_settings(flutter_wrapper_app)
target_link_libraries(flutter_wrapper_app PUBLIC flutter)
target_include_directories(flutter_wrapper_app PUBLIC
  "${WRAPPER_INCLUDE_ROOT}"
)
add_dependencies(flutter_wrapper_app flutter_assemble)
add_dependencies(flutter_wrapper_app flutter_sync_ephemeral_fallback)
add_dependencies(flutter_wrapper_app flutter_generate_asset_manifests)

# === Flutter tool backend ===
# _phony_ is a non-existent file to force this command to run every time,
# since currently there's no way to get a full input/output list from the
# flutter tool.
set(PHONY_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/_phony_")
set_source_files_properties("${PHONY_OUTPUT}" PROPERTIES SYMBOLIC TRUE)
add_custom_command(
  OUTPUT ${FLUTTER_LIBRARY} ${FLUTTER_LIBRARY_HEADERS}
    ${CPP_WRAPPER_SOURCES_CORE} ${CPP_WRAPPER_SOURCES_PLUGIN}
    ${CPP_WRAPPER_SOURCES_APP}
    ${PHONY_OUTPUT}
  COMMAND ${CMAKE_COMMAND} -E env
    ${FLUTTER_TOOL_ENVIRONMENT}
    "${FLUTTER_ROOT}/packages/flutter_tools/bin/tool_backend.bat"
      ${FLUTTER_TARGET_PLATFORM} $<CONFIG>
  VERBATIM
)
add_custom_target(flutter_assemble DEPENDS
  "${FLUTTER_LIBRARY}"
  ${FLUTTER_LIBRARY_HEADERS}
  ${CPP_WRAPPER_SOURCES_CORE}
  ${CPP_WRAPPER_SOURCES_PLUGIN}
  ${CPP_WRAPPER_SOURCES_APP}
)
add_dependencies(flutter_sync_ephemeral_fallback flutter_assemble)
add_dependencies(flutter_generate_asset_manifests flutter_assemble)
