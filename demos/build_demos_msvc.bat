@echo off

:: Copyright (C) 2018-2019 Intel Corporation
::
:: Licensed under the Apache License, Version 2.0 (the "License");
:: you may not use this file except in compliance with the License.
:: You may obtain a copy of the License at
::
::      http://www.apache.org/licenses/LICENSE-2.0
::
:: Unless required by applicable law or agreed to in writing, software
:: distributed under the License is distributed on an "AS IS" BASIS,
:: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
:: See the License for the specific language governing permissions and
:: limitations under the License.


setlocal EnableDelayedExpansion
set "ROOT_DIR=%~dp0"

set "SOLUTION_DIR64=%USERPROFILE%\Documents\Intel\OpenVINO\omz_demos_build"

set MSBUILD_BIN=
set VS_PATH=
set VS_VERSION=
set EXTRA_CMAKE_OPTS=

:argParse
if not "%1" == "" (
    rem cmd.exe mangles -DENABLE_PYTHON=YES into -DENABLE_PYTHON YES,
    rem so it gets split into two arguments
    if "%1" == "-DENABLE_PYTHON" (
        set EXTRA_CMAKE_OPTS=%EXTRA_CMAKE_OPTS% %1=%2
        shift & shift
        goto argParse
    )

    if not "%VS_VERSION%" == "" (
        echo Unexpected argument: "%1"
        goto errorHandling
    )

    if "%1"=="VS2015" (
        set "VS_VERSION=14 2015"
    ) else if "%1"=="VS2017" (
        set "VS_VERSION=15 2017"
    ) else if "%1"=="VS2019" (
        set "VS_VERSION=16 2019"
    ) else (
        echo Unrecognized Visual Studio version specified: "%1"
        echo Supported versions: VS2015, VS2017, VS2019
        goto errorHandling
    )

    shift
    goto argparse
)

if not "%VS_VERSION%" == "" (
    set EXTRA_CMAKE_OPTS=%EXTRA_CMAKE_OPTS% -G "Visual Studio %VS_VERSION%"
)

if "%INTEL_OPENVINO_DIR%"=="" (
    if exist "%ROOT_DIR%\..\..\bin\setupvars.bat" (
        call "%ROOT_DIR%\..\..\bin\setupvars.bat"
    ) else if exist "%ROOT_DIR%\..\..\..\bin\setupvars.bat" (
        call "%ROOT_DIR%\..\..\..\bin\setupvars.bat"
    ) else (
        echo Failed to set the environment variables automatically
        echo To fix, run the following command: ^<INSTALL_DIR^>\bin\setupvars.bat
        echo where INSTALL_DIR is the OpenVINO installation directory.
        goto errorHandling
    )
)

if "%PROCESSOR_ARCHITECTURE%" == "AMD64" (
    set "PLATFORM=x64"
) else (
    set "PLATFORM=Win32"
)

if exist "%SOLUTION_DIR64%\CMakeCache.txt" del "%SOLUTION_DIR64%\CMakeCache.txt"

echo Creating Visual Studio solution in %SOLUTION_DIR64%...
cd "%ROOT_DIR%" && cmake -E make_directory "%SOLUTION_DIR64%"

cd "%SOLUTION_DIR64%" && cmake -A %PLATFORM% %EXTRA_CMAKE_OPTS% "%ROOT_DIR%"

echo.
echo ###############^|^| Build Open Model Zoo Demos using MS Visual Studio ^|^|###############
echo.
echo cmake --build . --config Release
cmake --build . --config Release
if ERRORLEVEL 1 goto errorHandling

echo Done.
goto :eof

:errorHandling
echo Error
exit /B 1
