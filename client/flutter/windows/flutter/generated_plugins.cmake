list(APPEND FLUTTER_PLUGIN_LIST
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
)

set(PLUGIN_BUNDLED_SOURCES_DIR "${BUNDLED_SOURCES_DIR}")
foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory("${FLUTTER_MANAGED_DIR}/plugins/${plugin}" "${PLUGIN_BUNDLED_SOURCES_DIR}/${plugin}")
  list(APPEND PLUGIN_BUNDLED_SOURCES "${${plugin}_bundled_sources}")
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory("${FLUTTER_MANAGED_DIR}/plugins/${ffi_plugin}" "${PLUGIN_BUNDLED_SOURCES_DIR}/${ffi_plugin}")
  list(APPEND PLUGIN_BUNDLED_SOURCES "${${ffi_plugin}_bundled_sources}")
endforeach(ffi_plugin)
