cmake_minimum_required(VERSION 3.10)

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


project(ct_optcon VERSION 3.0.2 LANGUAGES CXX)


set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread -fopenmp -std=c++14 -Wno-unknown-pragmas -Wall -Wfatal-errors")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -pthread -std=c++14 -Wfatal-errors")
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)


## find and include required dependencies
if(NOT TARGET ${ct_core})
	if(USING_AMENT)
		find_package(ct_core REQUIRED)
	else()
		find_package(ct_core REQUIRED)
	endif()
endif()

# extract interface compile definitions from ct_core as options (only if target exists)
if(TARGET ct_core)
    importInterfaceCompileDefinitionsAsOptions(ct_core)
endif()


## find and include optional dependencies
option(MATLAB "Compile with matlab support" OFF)
option(MATLAB_FULL_LOG "Expose all variables to Matlab (very slow)" OFF)
option(DEBUG_PRINT "Print debug messages" OFF)


if(DEBUG_PRINT)
    message(STATUS "Debug Print ON")
    list(APPEND ct_optcon_COMPILE_DEFINITIONS DEBUG_PRINT)
endif(DEBUG_PRINT)

if(MATLAB_FULL_LOG)
    message(WARNING "Compiling with full log to matlab. Execution will be very slow.")
    set(MATLAB ON)
    list(APPEND ct_optcon_COMPILE_DEFINITIONS MATLAB_FULL_LOG)
endif(MATLAB_FULL_LOG)

if(MATLAB)
    message(STATUS "MATLAB support ON")
    find_package(matlab_cpp_interface REQUIRED)
    list(APPEND ct_optcon_COMPILE_DEFINITIONS MATLAB)
endif(MATLAB)


## lapack libs
find_package(LAPACK QUIET)
set(LAPACK_LIBS "")
if(LAPACK_FOUND)
    message(STATUS "Found LAPACK library")
    list(APPEND LAPACK_LIBS lapack)
    list(APPEND ct_optcon_COMPILE_DEFINITIONS CT_USE_LAPACK)
else(LAPACK_FOUND)
    message(STATUS "Could not find LAPACK library")
endif(LAPACK_FOUND)


## include blasfeo and hpipm, assumed to be installed in "/opt"
list(APPEND CMAKE_PREFIX_PATH "/opt")
find_package(blasfeo QUIET)
find_package(hpipm QUIET)
if(blasfeo_FOUND AND hpipm_FOUND)
    message(STATUS "Found HPIPM and BLASFEO")
    set(HPIPM ON)
    list(APPEND HPIPM_LIBS hpipm blasfeo)
    list(APPEND ct_optcon_COMPILE_DEFINITIONS HPIPM)
else()
    message(WARNING "Could not find HPIPM or BLASFEO")
endif()


## include IPOPT (after installation via sudo apt-get install coinor-libipopt-dev)
find_package(IPOPT QUIET)
if(IPOPT_FOUND)
    set(BUILD_WITH_IPOPT_SUPPORT ON)
    message(STATUS "Found IPOPT - building with IPOPT support")
    set(IPOPT_LIBS ${IPOPT_LIBRARIES})
    list(APPEND ct_optcon_COMPILE_DEFINITIONS BUILD_WITH_IPOPT_SUPPORT)
    list(APPEND ct_optcon_COMPILE_DEFINITIONS ${IPOPT_DEFINITIONS})
endif()


###################
# BUILD LIBRARIES #
###################

## define the directories to be included in all ct_optcon targets
set(ct_optcon_TARGET_INCLUDE_DIRS
    ${ct_core_INCLUDE_DIRS}
    ${matlab_cpp_interface_INCLUDE_DIRS}
    ${blasfeo_INCLUDE_DIRS}
    ${hpipm_INCLUDE_DIRS}
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

## declare prespec libraries
set(PRESPEC_LIB_NAMES "")

## assemble list of libraries that contain prespecified templates
if(USE_PRESPEC)
    ct_configure_explicit_templates("${CMAKE_CURRENT_SOURCE_DIR}/../ct/config/explicit_templates.cfg"
        "${CMAKE_CURRENT_SOURCE_DIR}/prespec/"
        "ct_optcon"
    )
    message(STATUS "CT Optcon: Compiling the following explict template libraries: ${PRESPEC_LIB_NAMES}")
    # create libraries
    foreach(lib_name ${PRESPEC_LIB_NAMES})
        add_library(${lib_name} SHARED ${${lib_name}_SRCS})
        target_include_directories(${lib_name} PUBLIC ${ct_optcon_TARGET_INCLUDE_DIRS})
        target_compile_definitions(${lib_name} PUBLIC ${ct_optcon_COMPILE_DEFINITIONS})
        if(USING_AMENT)
            target_link_libraries(${lib_name}
                ${matlab_cpp_interface_LIBRARIES}
                ${LAPACK_LIBS}
                ${HPIPM_LIBS}
                ${IPOPT_LIBS}
            )
        
        else()
            target_link_libraries(${lib_name}
                ${matlab_cpp_interface_LIBRARIES}
                ${LAPACK_LIBS}
                ${HPIPM_LIBS}
                ${IPOPT_LIBS}
            )
        endif()
    endforeach()
endif(USE_PRESPEC)


## create ct_optcon library
# Interface library for traditional builds
add_library(ct_optcon INTERFACE)
target_include_directories(ct_optcon INTERFACE ${ct_optcon_TARGET_INCLUDE_DIRS})
target_compile_definitions(ct_optcon INTERFACE ${ct_optcon_COMPILE_DEFINITIONS})
target_link_libraries(ct_optcon INTERFACE
    ${matlab_cpp_interface_LIBRARIES}
    ${LAPACK_LIBS}
    ${HPIPM_LIBS}
    ${IPOPT_LIBS}
    ${PRESPEC_LIB_NAMES}
    )

# Create a dummy source file for ct_optcon_impl
file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/src/optcon/ct_optcon_dummy.cpp 
"// Auto-generated dummy file for ct_optcon implementation
namespace ct { namespace optcon { 
    // Empty implementation to ensure we have a non-empty library
    void __ct_optcon_dummy_function() {}
} }")

# Create a shared library implementation for ROS2 compatibility
if(USING_AMENT)
    # Create a small implementation to ensure we have a real library for ROS2
    add_library(ct_optcon_impl SHARED
        src/optcon/ct_optcon_dummy.cpp
    )
    target_include_directories(ct_optcon_impl PUBLIC ${ct_optcon_TARGET_INCLUDE_DIRS})
    target_compile_definitions(ct_optcon_impl PUBLIC ${ct_optcon_COMPILE_DEFINITIONS})
    
    # Link explicitly to ct_core_impl (the real library) instead of the interface
    target_link_libraries(ct_optcon_impl PUBLIC
        ${matlab_cpp_interface_LIBRARIES}
        ${LAPACK_LIBS}
        ${HPIPM_LIBS}
        ${IPOPT_LIBS}
        ${PRESPEC_LIB_NAMES}
    )
    set_target_properties(ct_optcon_impl PROPERTIES OUTPUT_NAME "ct_optcon")
endif()

set(ct_optcon ct_optcon CACHE INTERNAL "ct_optcon library target.")

##################
# BUILD EXAMPLES #
##################
if(BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()


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
    install(DIRECTORY include/ct/optcon DESTINATION include/ct)

    ## copy the cmake files required for find_package()
    install(FILES "cmake/ct_optconConfig.cmake" DESTINATION "share/ct_optcon/cmake")

    ## install library and targets
    install(
        TARGETS ct_optcon ${PRESPEC_LIB_NAMES}
        EXPORT ct_optcon_export
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_LIBDIR}
        )

    ## create the ct_optcon.cmake file which holds target includes and dependencies
    install(EXPORT ct_optcon_export DESTINATION share/ct_optcon/cmake)

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
    install(DIRECTORY include/ct/optcon DESTINATION include/ct)

    # Install libraries for ROS2
    install(
        TARGETS ct_optcon_impl ${PRESPEC_LIB_NAMES}
        EXPORT export_ct_optcon
        ARCHIVE DESTINATION lib
        LIBRARY DESTINATION lib
        RUNTIME DESTINATION bin
    )
    
    # Install the interface library
    install(
        TARGETS ct_optcon
        EXPORT export_ct_optcon
    )

    # Export dependencies for downstream packages
    ament_export_include_directories(include)
    ament_export_libraries(ct_optcon ${PRESPEC_LIB_NAMES})
    ament_export_targets(export_ct_optcon HAS_LIBRARY_TARGET)
    
    # Export dependencies
    ament_export_dependencies(
        ct_core
    )
    
    # This must be the last ament macro called
    ament_package()
endif()


#################
# DOCUMENTATION #
#################
add_subdirectory(doc)