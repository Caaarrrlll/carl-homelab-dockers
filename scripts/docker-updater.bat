@echo off
rem docker-updater.bat: build and push every image locally, in dependency
rem order (debian -> [fedora] -> wine -> asa). Optional: CI on GitHub is the
rem normal build path (see AGENTS.md "Building / releasing").
rem
rem Usage: set DOCKERHUB_USER=myuser
rem        scripts\docker-updater.bat
rem        (set BUILD_FEDORA=1 to also build the parked Fedora image)

setlocal

rem --- Repository root -------------------------------------------------------------

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%\.."

rem --- Docker Hub namespace (required, never defaulted) ------------------------------

if not defined DOCKERHUB_USER (
    echo.
    echo Error: DOCKERHUB_USER is not set.
    echo Set it to your Docker Hub username, e.g. set DOCKERHUB_USER=myuser
    endlocal
    exit /b 1
)

rem --- Images, in dependency order -----------------------------------------------------

call :buildpush ^
    "images\systems\debian-base" ^
    "%DOCKERHUB_USER%/debian-slim-baseimage:trixie-latest"
if errorlevel 1 goto error

rem Fedora is parked: only build it when explicitly asked (BUILD_FEDORA=1), same as CI.
if "%BUILD_FEDORA%"=="1" (
    call :buildpush ^
        "images\systems\fedora-base" ^
        "%DOCKERHUB_USER%/fedora-baseimage:latest"
    if errorlevel 1 goto error
) else (
    echo.
    echo === Skipping Fedora ^(set BUILD_FEDORA=1 to build it^) ===
)

call :buildpush ^
    "images\systems\wine-base" ^
    "%DOCKERHUB_USER%/wine-baseimage:latest"
if errorlevel 1 goto error

call :buildpush ^
    "images\games\asa-docker" ^
    "%DOCKERHUB_USER%/asa-wine:latest"
if errorlevel 1 goto error

goto end

rem --- :buildpush <context> <tag> -----------------------------------------------------
rem Build the image in <context> and push it as <tag>; exit code 1 on failure.

:buildpush
echo.
echo === Building %~1 ===
pushd "%~1"

docker image build -t "%~2" .
if errorlevel 1 (
    popd
    exit /b 1
)

docker image push "%~2"
if errorlevel 1 (
    popd
    exit /b 1
)

popd
exit /b 0

rem --- Exit paths --------------------------------------------------------------------

:error
echo.
echo Build/push failed.
endlocal
exit /b 1

:end
echo.
echo All images built and pushed.
endlocal
exit /b 0
