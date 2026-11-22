# Compila todos los .c de src/ (componente principal: tiene acceso a todos los drivers)
FILE(GLOB_RECURSE app_sources ${CMAKE_SOURCE_DIR}/src/*.c)
idf_component_register(SRCS ${app_sources})
