function(importInterfaceCompileDefinitionsAsOptions TARGET_NAME)
    # Only proceed if the target exists
    if(TARGET ${TARGET_NAME})
        get_property(TARGET_DEFINITIONS TARGET ${TARGET_NAME} PROPERTY INTERFACE_COMPILE_DEFINITIONS)
        foreach(DEFINITION ${TARGET_DEFINITIONS})
            # Extract option name and value
            if(${DEFINITION} MATCHES "([^=]+)=(.+)")
                set(OPTION_NAME ${CMAKE_MATCH_1})
                set(OPTION_VALUE ${CMAKE_MATCH_2})
                # If option not defined, add as cmake option
                if(NOT DEFINED ${OPTION_NAME})
                    set(${OPTION_NAME} ${OPTION_VALUE} CACHE BOOL "Auto-imported from ${TARGET_NAME}")
                endif()
            else()
                # Handle case without value, treat as boolean
                set(OPTION_NAME ${DEFINITION})
                set(OPTION_VALUE ON)
                # If option not defined, add as cmake option
                if(NOT DEFINED ${OPTION_NAME})
                    set(${OPTION_NAME} ${OPTION_VALUE} CACHE BOOL "Auto-imported from ${TARGET_NAME}")
                endif()
            endif()
        endforeach()
    else()
        message(STATUS "Target ${TARGET_NAME} not found, skipping compile definitions import")
    endif()
endfunction()