cmake_minimum_required(VERSION 3.28)
include(GNUInstallDirs)

###############################################################################
# Copyright (c) 2024 Hoffmann Systems. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
###############################################################################
#
# File: check_environment.cmake
# Author: Geoffrey Hoffmann
# Date: February 1, 2024
# Description: Helper monkeys
#
###############################################################################
#
# Redistribution and use in source and binary forms, with or without

# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
###################################################################################


set(SsngfnHHNJLKN) # Stop the text above appearing in the next docstring

# See that the environment and tools are available
#
# Required args - PROJECT_ROOT - The complete path up to the root CMakeLists.txt's folder
# Optional args - None
#
macro(check_environment PROJECT_ROOT)

    if(NOT DEFINED ENV{buildPath})
        message(FATAL_ERROR "Preset env var buildPath is missing. Are you configuring with the expected preset?")
    endif()

    if (NOT checkCompleted)

        macro(ceUnset)
            unset (BUILDING)
            unset (BUILD_DEBUG)
            unset (BUILD_FLAG)
            unset (BUILD_RELEASE)
            unset (BUILD_SHARED_LIBS)
            unset (BUILD_TYPE)
            unset (BUILD_TYPE_LC)
            unset (BUILD_TYPE_UC)
            unset (DM_FLAG)
            unset (EXTERNALS_DIR)
            unset (LINK_FLAG)
            unset (LINK_SHARED)
            unset (LINK_STATIC)
            unset (LINK_TYPE)
            unset (LINK_TYPE_LC)
            unset (LINK_TYPE_UC)
            unset (SHARED_LIBS_OPTIONS)
            unset (STAGING)
            unset (SUDO)
            unset (THEY_ARE_INSTALLED)
            unset (WE_ARE_INSTALLED)
            unset (_PATH)
            unset (_SYSPATH)
            unset (debugFlags)
        endmacro()
        ceUnset()

        string(TOLOWER ${APP_VENDOR} APP_VENDOR_LC)
        string(TOLOWER ${APP_NAME}   APP_NAME_LC)

        # Specify build type
        forceSet(CMAKE_BUILD_TYPE buildType Debug STRING)

        # Specify link type
        forceSet(LINK_TYPE linkType Shared STRING)


        # Valid build types. Add your own if you want. I don't want.
        set(CMAKE_CONFIGURATION_TYPES "Debug;Release")

        #Valid settings for "BUILD_SHARED_LIBS"
        set(SHARED_LIBS_OPTIONS "Static;Shared")

        # Check if BUILD_TYPE is found in CMAKE_CONFIGURATION_TYPES
        if (NOT "${CMAKE_BUILD_TYPE}" IN_LIST CMAKE_CONFIGURATION_TYPES)
            message(FATAL_ERROR "CMAKE_BUILD_TYPE [${CMAKE_BUILD_TYPE}] must be one of [${CMAKE_CONFIGURATION_TYPES}]")
        endif ()

        # Check if LINK_TYPE is found in LINKAGE_TYPES
        if (NOT "${LINK_TYPE}" IN_LIST SHARED_LIBS_OPTIONS)
            message(FATAL_ERROR "Link Type [${LINK_TYPE}] must be one of [${SHARED_LIBS_OPTIONS}]")
        endif ()

        # Set various transmutations required in different places around the traps
        string(TOLOWER "$ENV{dmType}" dmType_LC)
        string(SUBSTRING "${dmType_LC}" 0 1 DM_FLAG)

        if (${LINK_TYPE} STREQUAL "Shared")
            set(BUILD_SHARED_LIBS ON)
            set(LINK_SHARED ON)
            set(LINK_STATIC OFF)
            set(LINK_FLAG "d")
        else ()
            set(BUILD_SHARED_LIBS OFF)
            set(LINK_SHARED OFF)
            set(LINK_STATIC ON)
            set(LINK_FLAG "s")
        endif ()
        string(TOLOWER "${LINK_TYPE}" LINK_TYPE_LC)
        string(TOUPPER "${LINK_TYPE}" LINK_TYPE_UC)

        # Set various transmutations required in different places around the traps
        if (${CMAKE_BUILD_TYPE} STREQUAL Debug)
            set(BUILD_TYPE Debug)
            set(BUILD_DEBUG ON)
            set(BUILD_RELEASE OFF)
            set(BUILD_FLAG "d")
            list(APPEND debugFlags DEBUG _DEBUG)
        else ()
            set(BUILD_TYPE Release)
            set(BUILD_DEBUG OFF)
            set(BUILD_RELEASE ON)
            set(BUILD_FLAG "r")
            list(APPEND debugFlags NDEBUG)
        endif ()

        # Some values for #if defined() checks in the code
        if (${BUILD_DEBUG} STREQUAL ON)
            list(APPEND debugFlags "BUILD_DEBUG")
        else ()
            list(APPEND debugFlags "BUILD_RELEASE")
        endif ()
        if (${LINK_SHARED} STREQUAL ON)
            list(APPEND debugFlags "LINK_SHARED")
        else ()
            list(APPEND debugFlags "LINK_STATIC")
        endif ()

        string(TOLOWER ${BUILD_TYPE} BUILD_TYPE_LC)
        string(TOUPPER ${BUILD_TYPE} BUILD_TYPE_UC)

        if (NOT PRESERVE_DIRS)
            forceSet(BUILD_DIR "" "${PROJECT_ROOT}/build${stemPath}/_deps" FILEPATH)
            forceSet(OUTPUT_DIR "" "${PROJECT_ROOT}/out${stemPath}" FILEPATH)
            forceSet(EXTERNALS_DIR "" "${PROJECT_ROOT}/external${stemPath}" FILEPATH)

            forceSet(CMAKE_RUNTIME_OUTPUT_DIRECTORY "" "${OUTPUT_DIR}/${CMAKE_INSTALL_BINDIR}" FILEPATH)
            forceSet(CMAKE_LIBRARY_OUTPUT_DIRECTORY "" "${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}" FILEPATH)
            forceSet(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "" "${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}" FILEPATH)
        endif ()

        if(WIN32)
            if(DEFINED ENV{STAGE_DIR})
                set(_PATH "$ENV{STAGE_DIR}")
            elseif (DEFINED DESTDIR)
                set(_PATH "${DESTDIR}")
            else()
                if(DEFINED ENV{HOME})
                    set(_PATH "$ENV{HOME}/dev/stage")
                elseif(DEFINED ENV{USERPROFILE})
                    set(_PATH "$ENV{USERPROFILE}/dev/stage")
                else()
                    set(_PATH "C:/dev/stage")
                endif()
            endif ()

            # Release install - use APPDATA
            if(DEFINED ENV{APPDATA})
                set(SYSTEM_PATH "$ENV{APPDATA}/HoffSoft")
            else()
                set(SYSTEM_PATH "$ENV{USERPROFILE}/AppData/Roaming/HoffSoft")
            endif()

            string(REPLACE "\\" "/" _PATH "${_PATH}")
            string(REPLACE "\\" "/" SYSTEM_PATH "${SYSTEM_PATH}")

            string(SUBSTRING "${SYSTEM_PATH}" 2 -1 _SYSPATH)

        else()

            if(DEFINED ENV{STAGE_DIR})
                set(_PATH "$ENV{STAGE_DIR}")
            elseif (DEFINED DESTDIR)
                set(_PATH "${DESTDIR}")
            else()
                set(_PATH "~/dev/stage")
            endif ()
            set(SYSTEM_PATH "/usr/local")

            set(_SYSPATH "${SYSTEM_PATH}")

        endif()

        set(STAGED_PATH "${_PATH}${_SYSPATH}")
        get_filename_component(STAGED_PATH "${STAGED_PATH}" ABSOLUTE)

        if (UNIX AND NOT STAGING)
            set(SUDO sudo)
        else ()
            set(SUDO)
        endif ()

        if (NOT DEFINED CMAKE_CXX_STANDARD)
            set(CMAKE_CXX_STANDARD 23)
        endif ()

        if (NOT DEFINED COMPANY)
            set(COMPANY ${APP_VENDOR})
        endif ()

        list(REMOVE_DUPLICATES debugFlags)

#        function(hs_should_use_ansi out_var)
#            # Manual overrides first (these are very handy in CI/IDEs).
##            option(HS_FORCE_COLOR "Force ANSI colors in CMake output" OFF)
##            option(HS_NO_COLOR    "Disable ANSI colors in CMake output" OFF)
##
##            if(HS_NO_COLOR OR DEFINED ENV{NO_COLOR})
##                set(${out_var} OFF PARENT_SCOPE)
##                return()
##            endif()
##            if(HS_FORCE_COLOR)
##                set(${out_var} ON PARENT_SCOPE)
##                return()
##            endif()
##
##            # Conservative defaults.
##            set(_use ON)
##
##            # If TERM is empty or dumb, don't color (common when not a real terminal).
##            if(DEFINED ENV{TERM})
##                if("$ENV{TERM}" STREQUAL "" OR "$ENV{TERM}" STREQUAL "dumb")
##                    set(_use OFF)
##                endif()
##            endif()
##
##            if(_use)
#                if(CMAKE_HOST_WIN32)
#                    # True means output is redirected -> disable ANSI
#                    execute_process(
#                            COMMAND powershell -NoProfile -NonInteractive -Command "[Console]::IsOutputRedirected"
#                            OUTPUT_VARIABLE _redir
#                            OUTPUT_STRIP_TRAILING_WHITESPACE
#                            ERROR_QUIET
#                    )
#                    if(_redir STREQUAL "True")
#                        set(_use OFF)
#                    endif()
#                else()
#                    execute_process(
#                            COMMAND sh -c "test -t 2"
#                            RESULT_VARIABLE _is_tty
#                            OUTPUT_QUIET ERROR_QUIET
#                    )
#                    if(NOT _is_tty EQUAL 0)
#                        set(_use OFF)
#                    endif()
#
#                endif()
##            endif()
#
#            set(${out_var} ${_use} PARENT_SCOPE)
#        endfunction()
#
#        # Example usage:
#        hs_should_use_ansi(COLOUR)
#        set(COLOUR OFF) #ON)
        execute_process(
                COMMAND sh -c "tput cols </dev/tty"
                OUTPUT_VARIABLE _term_cols
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_QUIET
        )
        if(NOT _term_cols MATCHES "^[0-9]+$")
            set(_term_cols 80)
        endif()

        if(COLOUR)
            string(ASCII 27 ESC)
            set(RED     "${ESC}[31m")
            set(GREEN   "${ESC}[32m")
            set(YELLOW  "${ESC}[33m")
            set(BLUE    "${ESC}[34m")
            set(MAGENTA "${ESC}[35m")
            set(CYAN    "${ESC}[36m")
            set(WHITE   "${ESC}[37m")
            set(DEFAULT "${ESC}[38m")
            set(BOLD    "${ESC}[1m" )
            set(NC      "${ESC}[0m" )
        else()
            set(RED     "")
            set(GREEN   "")
            set(YELLOW  "")
            set(BLUE    "")
            set(MAGENTA "")
            set(CYAN    "")
            set(WHITE   "")
            set(DEFAULT "")
            set(BOLD    "")
            set(NC      "")
        endif()

        # @formatter:off
        # set(APP_VENDOR_LC       ${APP_VENDOR_LC}        PARENT_SCOPE)
        # set(APP_NAME_LC         ${APP_NAME_LC}          PARENT_SCOPE)
        # set(BUILDING            ${BUILDING}             PARENT_SCOPE)
        # set(BUILD_DEBUG         ${BUILD_DEBUG}          PARENT_SCOPE)
        # set(BUILD_RELEASE       ${BUILD_RELEASE}        PARENT_SCOPE)
        # set(BUILD_TYPE          ${BUILD_TYPE}           PARENT_SCOPE)
        # set(BUILD_TYPE_LC       ${BUILD_TYPE_LC}        PARENT_SCOPE)
        # set(BUILD_TYPE_UC       ${BUILD_TYPE_UC}        PARENT_SCOPE)
        # set(BUILD_FLAG          ${BUILD_FLAG}           PARENT_SCOPE)
        # set(CMAKE_CXX_STANDARD  ${CMAKE_CXX_STANDARD}   PARENT_SCOPE)
        # set(COMPANY             ${COMPANY}              PARENT_SCOPE)
        # set(DM_FLAG             ${DM_FLAG}              PARENT_SCOPE)
        # set(LINK_SHARED         ${LINK_SHARED}          PARENT_SCOPE)
        # set(LINK_STATIC         ${LINK_STATIC}          PARENT_SCOPE)
        # set(LINK_TYPE           ${LINK_TYPE}            PARENT_SCOPE)
        # set(LINK_TYPE_LC        ${LINK_TYPE_LC}         PARENT_SCOPE)
        # set(LINK_TYPE_UC        ${LINK_TYPE_UC}         PARENT_SCOPE)
        # set(LINK_FLAG           ${LINK_FLAG}            PARENT_SCOPE)
        # set(STAGED_DIR          ${STAGED_DIR}           PARENT_SCOPE)
        # set(SYSTEM_DIR          ${SYSTEM_DIR}           PARENT_SCOPE)
        # set(SUDO                ${SUDO}                 PARENT_SCOPE)
        # set(stemPath            ${stemPath}             PARENT_SCOPE)
        # set(buildType           ${buildType}            PARENT_SCOPE)
        # set(debugFlags          ${debugFlags}           PARENT_SCOPE)
        # set(linkType            ${linkType}             PARENT_SCOPE)
        # @formatter:on

        set(checkCompleted ON)
    endif ()
endmacro()

