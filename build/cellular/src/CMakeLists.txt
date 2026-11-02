include_directories(${CMAKE_CURRENT_BINARY_DIR})
add_definitions(-DQT_NO_KEYWORDS)
add_definitions(-DPLUGIN_QML_DIR="${PLUGIN_QML_DIR}")

set(QML_SOURCES PageComponent.qml)

add_library(cellular-plugin MODULE cellular-plugin.cpp cellular-plugin.h ${QML_SOURCES})
target_link_libraries(cellular-plugin Qt5::Qml Qt5::Core LomiriSystemSettings)

add_library(M52xqCellularBackend MODULE backend/plugin.cpp backend/plugin.h backend/mobile.cpp backend/mobile.h)
target_link_libraries(M52xqCellularBackend Qt5::Qml Qt5::Quick Qt5::Core)

set(PLUG_DIR ${PLUGIN_PRIVATE_MODULE_DIR}/Lomiri/SystemSettings/M52xqCellular)
install(TARGETS cellular-plugin DESTINATION ${PLUGIN_MODULE_DIR})
install(TARGETS M52xqCellularBackend DESTINATION ${PLUG_DIR})
install(FILES backend/qmldir DESTINATION ${PLUG_DIR})
install(FILES cellular.settings DESTINATION ${PLUGIN_MANIFEST_DIR})
install(FILES ${QML_SOURCES} DESTINATION ${PLUGIN_QML_DIR}/cellular)
