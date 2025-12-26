cmake_minimum_required(VERSION 3.10)
project(SoapySBITX CXX)

find_package(SoapySDR REQUIRED)
find_package(Threads REQUIRED)

add_library(SoapySBITX MODULE
    src/Register.cpp
    src/SBITXDevice.cpp
)

target_include_directories(SoapySBITX PRIVATE ${SOAPY_SDR_INCLUDE_DIRS})
target_link_libraries(SoapySBITX PRIVATE ${SOAPY_SDR_LIBRARIES} Threads::Threads asound)

set_target_properties(SoapySBITX PROPERTIES PREFIX "")

include(GNUInstallDirs)
# Common module dir for SoapySDR v0.8-3 on Debian/RPi. Adjust if yours differs.
install(TARGETS SoapySBITX
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/SoapySDR/modules0.8-3
)
