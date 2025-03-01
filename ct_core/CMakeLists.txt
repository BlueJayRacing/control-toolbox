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

include(${CMAKE_CURRENT_SOURCE_DIR}/../ct/cmake/compilerSettings.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/../ct/cmake/explicitTemplateHelpers.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/../ct/cmake/clang-cxx-dev-tools.cmake)


project(ct_core VERSION 3.0.2 LANGUAGES CXX)


set(CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake)
set(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -pthread -std=c++14 -Wall -Wfatal-errors")
set(CMAKE_EXE_LINKER_FLAGS  "${CMAKE_EXE_LINKER_FLAGS} -pthread -std=c++14 -Wall -Wfatal-errors")
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)


set(ct_core_LIBS "")

## find and include required dependencies
find_package(Eigen3 REQUIRED)
find_package(Boost COMPONENTS REQUIRED)

## find and include optional dependencies
find_package(LLVM QUIET)
find_package(Clang QUIET)
if(LLVM_FOUND AND CLANG_FOUND)
    message(STATUS "Found LLVM/CLANG version " ${LLVM_VERSION_MAJOR}.${LLVM_VERSION_MINOR})
    set (LLVM ON)
    list(APPEND ct_core_COMPILE_DEFINITIONS LLVM_VERSION_MAJOR=${LLVM_VERSION_MAJOR})
    list(APPEND ct_core_COMPILE_DEFINITIONS LLVM_VERSION_MINOR=${LLVM_VERSION_MINOR})
    list(APPEND ct_core_LIBS ${CLANG_LIBS})
    list(APPEND ct_core_LIBS ${LLVM_MODULE_LIBS})
    list(APPEND ct_core_target_include_dirs ${LLVM_INCLUDE_DIRS})
    list(APPEND ct_core_target_include_dirs ${CLANG_INCLUDE_DIRS})
else()
    message(STATUS "Could not find LLVM/CLANG, LLVM-JIT will not be available")
endif()
find_package(CppAD QUIET)
if(CPPAD_FOUND)
    set(CPPAD ON)
    list(APPEND ct_core_COMPILE_DEFINITIONS CPPAD)
    list(APPEND ct_core_target_include_dirs ${CPPAD_INCLUDE_DIRS})
else()
    message(STATUS "Could not find CppAD, auto-diff will not be available")
endif()
find_package(CppADCG QUIET)
if(CPPADCG_FOUND)
    set(CPPADCG ON)
    list(APPEND ct_core_COMPILE_DEFINITIONS CPPADCG)
    list(APPEND ct_core_target_include_dirs ${CPPADCG_INCLUDE_DIRS})
else()
    message(STATUS "Could not find CppADCodeGen, derivative code generation will not be available")
endif()

find_package(Qwt QUIET)
find_package(Qt4 QUIET)
if(QWT_FOUND AND Qt4_FOUND)
    message(STATUS "Qwt and QT found.")
    set(QWT_ENABLED ON)
    include(${QT_USE_FILE})
    list(APPEND ct_core_LIBS ${QWT_LIBRARY} ${QT_QTCORE_LIBRARY} ${QT_QTGUI_LIBRARY})
else()
    message(STATUS "COMPILING WITHOUT QWT")
endif()

if(${CMAKE_VERSION} VERSION_LESS "3.12.0")
    find_package(PythonLibs 3 QUIET)
    if (PYTHONLIBS_FOUND)
        message(STATUS "Found python 3")
        list(APPEND ct_core_COMPILE_DEFINITIONS PLOTTING_ENABLED)
        set(PLOTTING_ENABLED ON)
        message(STATUS "Python library path ... " ${PYTHON_LIBRARY})
        list(APPEND ct_core_LIBS ${PYTHON_LIBRARY})
    else()
        message(STATUS "Python 3 not found, plotting will not be available")
    endif()
else()
    find_package(Python COMPONENTS Development NumPy QUIET)
    if (Python_FOUND AND ${Python_VERSION_MAJOR} EQUAL 3)
        message(STATUS "Found python " ${Python_VERSION})
        list(APPEND ct_core_COMPILE_DEFINITIONS PLOTTING_ENABLED)
        set(PLOTTING_ENABLED ON)
        message(STATUS "Python library path ... " ${Python_LIBRARIES})
        list(APPEND ct_core_LIBS ${Python_LIBRARIES})
    else()
        message(STATUS "Python 3 not found, plotting will not be available")
    endif()
endif()

## configure files required for code-generation
set(CODEGEN_TEMPLATE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/templates")
set(CODEGEN_OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/generated")
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/include/ct/core/templateDir.h.in ${CMAKE_CURRENT_SOURCE_DIR}/include/ct/core/templateDir.h)


###################
# BUILD LIBRARIES #
###################

## define the directories to be included in all ct_core targets
list(APPEND ct_core_target_include_dirs ${EIGEN3_INCLUDE_DIR})
if(${CMAKE_VERSION} VERSION_LESS "3.12.0")
    if(PYTHONLIBS_FOUND)
        list(APPEND ct_core_target_include_dirs ${PYTHON_INCLUDE_DIRS})
    endif()
else()
    if(Python_FOUND AND ${Python_VERSION_MAJOR} EQUAL 3)
        list(APPEND ct_core_target_include_dirs ${Python_INCLUDE_DIRS})
        list(APPEND ct_core_target_include_dirs ${Python_NumPy_INCLUDE_DIRS})
    endif()
endif()
list(APPEND ct_core_target_include_dirs ${QWT_INCLUDE_DIR})
list(APPEND ct_core_target_include_dirs $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)
list(APPEND ct_core_target_include_dirs $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/examples/include>)
list(APPEND ct_core_target_include_dirs $<INSTALL_INTERFACE:include>)

## declare prespec libraries
set(PRESPEC_LIB_NAMES "")

## define list of libraries that contain prespecified templates
if(USE_PRESPEC)
    # extract the prespec parameters from user-input
    ct_configure_explicit_templates("${CMAKE_CURRENT_SOURCE_DIR}/../ct/config/explicit_templates.cfg"
        "${CMAKE_CURRENT_SOURCE_DIR}/prespec/"
        "ct_core"
    )
    message(STATUS "CT Core: Compiling the following explict template libraries: ${PRESPEC_LIB_NAMES}")
    # create libraries
    foreach(lib_name ${PRESPEC_LIB_NAMES})
        add_library(${lib_name} SHARED ${${lib_name}_SRCS})
        target_include_directories(${lib_name} PUBLIC ${ct_core_target_include_dirs})
    endforeach()
endif()


## create ct_core libraries
add_library(ct_plot SHARED src/core/plot/plot.cpp)
target_include_directories(ct_plot PUBLIC ${ct_core_target_include_dirs})
target_compile_definitions(ct_plot PUBLIC ${ct_core_COMPILE_DEFINITIONS})
target_link_libraries(ct_plot ${ct_core_LIBS})

# Create a dummy source file for ct_core_impl
file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/src/core/ct_core_dummy.cpp 
"// Auto-generated dummy file for ct_core implementation
namespace ct { namespace core { 
    // Empty implementation to ensure we have a non-empty library
    void __ct_core_dummy_function() {}
} }")

# Create a shared library version of ct_core for ROS2 compatibility
add_library(ct_core_impl SHARED 
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core/ct_core_dummy.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core/plot/plot.cpp
)
target_include_directories(ct_core_impl PUBLIC ${ct_core_target_include_dirs})
target_compile_definitions(ct_core_impl PUBLIC ${ct_core_COMPILE_DEFINITIONS})
target_link_libraries(ct_core_impl
    ${ct_core_LIBS}
    ${PRESPEC_LIB_NAMES}
    ct_plot
    pthread
    dl
)
set_target_properties(ct_core_impl PROPERTIES OUTPUT_NAME "ct_core")

ament_export_targets(export_ct_core HAS_LIBRARY_TARGET)

# Keep the original interface library for traditional usage
add_library(ct_core INTERFACE)
target_include_directories(ct_core INTERFACE ${ct_core_target_include_dirs})
target_compile_definitions(ct_core INTERFACE ${ct_core_COMPILE_DEFINITIONS})
target_link_libraries(ct_core INTERFACE
    ${ct_core_LIBS}
    ${PRESPEC_LIB_NAMES}
    ct_plot
    pthread
    dl # required for gcc compatibility
    )

set(ct_core ct_core CACHE INTERNAL "ct_core library target.")
set(ct_plot ct_plot CACHE INTERNAL "ct_plot library target.")

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
    find_package(GTest REQUIRED)
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
    install(DIRECTORY include/ct/core DESTINATION include/ct)
    install(DIRECTORY examples/include/ct/core DESTINATION include/ct)

    ## copy the cmake files required for find_package()
    install(FILES "cmake/ct_coreConfig.cmake" DESTINATION "share/ct_core/cmake")

    ## install library and targets
    install(
        TARGETS ct_core ct_plot ${PRESPEC_LIB_NAMES}
        EXPORT ct_core_export
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_LIBDIR}
        )

    ## create the ct_core.cmake file which holds target includes and dependencies
    install(EXPORT ct_core_export DESTINATION share/ct_core/cmake)

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
    install(DIRECTORY include/ct/core DESTINATION include/ct)
    install(DIRECTORY examples/include/ct/core DESTINATION include/ct)

    # Install libraries for ROS2
    install(
        TARGETS ct_plot ct_core_impl ${PRESPEC_LIB_NAMES}
        EXPORT export_ct_core
        ARCHIVE DESTINATION lib
        LIBRARY DESTINATION lib
        RUNTIME DESTINATION bin
    )
    
    # Install the interface library
    install(
        TARGETS ct_core
        EXPORT export_ct_core
    )

    # Export dependencies for downstream packages
    ament_export_include_directories(include include/ct/core)
    
    # Export actual library targets - ct_core_impl will be named ct_core when installed
    ament_export_libraries(ct_plot ct_core ${PRESPEC_LIB_NAMES})
    
    # Export the target for proper config file generation
    ament_export_targets(export_ct_core HAS_LIBRARY_TARGET)
    
    # Export dependencies - with Boost exported safely
    if(CMAKE_VERSION VERSION_LESS 3.27)
        # Old CMake handling for Boost
        ament_export_dependencies(
            Eigen3
        )
    else()
        ament_export_dependencies(
            Eigen3
        )
        # Adding explicit policy for newer CMake versions
        cmake_policy(SET CMP0167 NEW)
    endif()
    
    # This must be the last ament macro called
    ament_package()
endif()

#################
# DOCUMENTATION #
#################
add_subdirectory(doc)