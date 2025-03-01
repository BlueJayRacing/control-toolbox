cmake_minimum_required(VERSION 3.5)

# Determine if we're being built with colcon/ROS2
if(DEFINED ENV{AMENT_PREFIX_PATH})
  set(USING_AMENT TRUE)
else()
  set(USING_AMENT FALSE)
endif()

# If using ament, find ament package
if(USING_AMENT)
  find_package(ament_cmake REQUIRED)
endif()

if(NOT TARGET clang-format)
	include(${CMAKE_CURRENT_SOURCE_DIR}/../ct/cmake/compilerSettings.cmake)
	include(${CMAKE_CURRENT_SOURCE_DIR}/../ct/cmake/explicitTemplateHelpers.cmake)
	include(${CMAKE_CURRENT_SOURCE_DIR}/../ct/cmake/clang-cxx-dev-tools.cmake)
endif()
include(${CMAKE_CURRENT_SOURCE_DIR}/../ct/cmake/ct-cmake-helpers.cmake)

project(ct_rbd VERSION 3.0.2 LANGUAGES CXX)


set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wfatal-errors -std=c++14 -Wall -Wno-unknown-pragmas")
SET(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

find_package(kindr REQUIRED)
if(NOT TARGET ${ct_optcon})
	if(USING_AMENT)
		find_package(ct_optcon REQUIRED)
	else()
		find_package(ct_optcon REQUIRED)
	endif()
endif()

# extract interface compile definitions from ct_core and ct_optcon as options
importInterfaceCompileDefinitionsAsOptions(ct_core)
importInterfaceCompileDefinitionsAsOptions(ct_optcon)


###################
# BUILD LIBRARIES #
###################

## define the directories to be included in all ct_rbd targets
set(ct_rbd_target_include_dirs
    ${kindr_INCLUDE_DIRS}
    ${ct_optcon_INCLUDE_DIRS}
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include/ct>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include/ct/rbd>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include/ct/rbd/robot/kinematics/ikfast>
    $<INSTALL_INTERFACE:include>
    $<INSTALL_INTERFACE:include/ct>
    $<INSTALL_INTERFACE:include/ct/rbd>
    $<INSTALL_INTERFACE:include/ct/rbd/robot/kinematics/ikfast>
)


## create ct_rbd library
add_library(ct_rbd INTERFACE)
target_include_directories(ct_rbd INTERFACE ${ct_rbd_target_include_dirs})
target_link_libraries(ct_rbd INTERFACE ct_optcon)

set(ct_rbd ct_rbd CACHE INTERNAL "ct_rbd library target.")

###########
# TESTING #
###########

if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(test)
endif()


##########################################
# INSTALLATION - TRADITIONAL CMAKE BUILD #
##########################################
if(NOT USING_AMENT)
    # for correct libraries locations across platforms
    include(GNUInstallDirs)

    ## copy the header files
    install(DIRECTORY include/ct/rbd DESTINATION include/ct)
    install(DIRECTORY include/ct/iit DESTINATION include/ct)

    ## copy the cmake files required for find_package()
    install(FILES "cmake/ct_rbdConfig.cmake" DESTINATION "share/ct_rbd/cmake")

    ## install library and targets
    install(
        TARGETS ct_rbd
        EXPORT ct_rbd_export
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_LIBDIR}
        )

    ## create the ct_rbd.cmake file which holds target includes and dependencies
    install(EXPORT ct_rbd_export DESTINATION share/ct_rbd/cmake)

    ## add uninstall target
    if(NOT TARGET uninstall)
        configure_file(
            "${CMAKE_CURRENT_SOURCE_DIR}/../ct/cmake/cmake_uninstall.cmake.in"
            "${CMAKE_CURRENT_BINARY_DIR}/../ct/cmake/cmake_uninstall.cmake"
            IMMEDIATE @ONLY)

        add_custom_target(uninstall
            COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/../ct/cmake/cmake_uninstall.cmake)
    endif()

###############################
# INSTALLATION - AMENT/COLCON #
###############################
else()
    # Install header files for ROS2
    install(DIRECTORY include/ct/rbd DESTINATION include/ct)
    install(DIRECTORY include/ct/iit DESTINATION include/ct)

    # Install libraries for ROS2
    install(
        TARGETS ct_rbd
        EXPORT export_ct_rbd
        ARCHIVE DESTINATION lib
        LIBRARY DESTINATION lib
        RUNTIME DESTINATION bin
    )

    # Export dependencies for downstream packages
    ament_export_include_directories(include)
    ament_export_libraries(ct_rbd)
    ament_export_targets(export_ct_rbd)
    
    # Export dependencies
    ament_export_dependencies(
        ct_optcon
        kindr
    )
    
    # This must be the last ament macro called
    ament_package()
endif()


#################
# DOCUMENTATION #
#################
add_subdirectory(doc)