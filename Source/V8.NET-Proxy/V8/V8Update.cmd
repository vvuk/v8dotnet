@echo off
setlocal
set errorlevel=
set v8rev=
set GIT_CURL_VERBOSE=1

REM _01234567890123456789012345678901234567890123456789012345678901234567890123456789___________________________________________________________________________________

REM (in order for "%errorlevel%" to expand correctly, we need to make sure there's no matching environment variable set with the same name)
set errorlevel=

if not exist ..\v8\ echo You must run this in the "V8.NET Proxy\V8" project folder. & pause & goto :EOF

set WorkingDir=%CD%

:Restart

cd "%WorkingDir%"

cls

echo This command file is used to download the V8 source and build it.
echo The 'git' and 'svn' command line programs are required (see ReadMe.txt).
echo.
echo 1. Open ReadMe.txt
echo 2. Download V8 source
echo 3. Download required 3rd-party tools
echo 4. Compile V8 source
echo 5. Exit

choice /C 12345 /M "Press 1 to open ReadMe.txt, 2 to continue, and 3 to cancel."
echo.

if errorlevel 5 goto :EOF
if errorlevel 4 goto CheckEnv
if errorlevel 3 goto GetTools
if errorlevel 2 goto GetSrc

notepad "%cd%\ReadMe.txt"

goto restart

REM _01234567890123456789012345678901234567890123456789012345678901234567890123456789___________________________________________________________________________________

:GetTools

if not exist build\v8\ echo V8 Source not downloaded. & pause & goto restart

cd build\v8

if exist "getGYP.log" del getGYP.log
if exist "getPython.log" del getPython.log
if exist "getCygwin.log" del getCygwin.log
if exist "getICU.log" del getICU.log
if exist "getGTest.log" del getGTest.log
if exist "getGMock.log" del getGMock.log

echo Downloading GYP ...
git clone https://chromium.googlesource.com/external/gyp
  build/gyp  >getGYP.log
REM Old Link: http://gyp.googlecode.com/svn/trunk
if errorlevel 1 goto Error

echo Downloading Python ...
svn co http://src.chromium.org/svn/trunk/tools/third_party/python_26  third_party/python_26  >getPython.log
if errorlevel 1 goto Error

echo Downloading Cygwin...
svn co http://src.chromium.org/svn/trunk/deps/third_party/cygwin third_party/cygwin  >getCygwin.log
if errorlevel 1 goto Error

echo Downloading ICU ...
svn co https://src.chromium.org/chrome/trunk/deps/third_party/icu52  third_party/icu  >getICU.log
if errorlevel 1 goto Error

echo Downloading GTest ...
svn co http://googletest.googlecode.com/svn/trunk  testing/gtest  >getGTest.log
if errorlevel 1 goto Error

echo Downloading GMock ...
svn co http://googlemock.googlecode.com/svn/trunk  testing/gmock  >getGMock.log
if errorlevel 1 goto Error

echo.
echo Download completed.
pause
goto restart

REM _01234567890123456789012345678901234567890123456789012345678901234567890123456789___________________________________________________________________________________

:GetSrc

if "%v8rev%"=="" set v8rev=HEAD
echo V8 revision: %v8rev%
choice /M "Is the revision ok? If not, you have to update the revision at the top of this command file."
if errorlevel 2 goto restart

if not exist build\v8\ goto CreateBuildDir

echo The V8 source files already exist. 
echo 1. Delete and redownload
echo 2. Update to the revision %v8rev%.
echo 3. Appy/Reapply V8.GYP file updates
echo 4. Main Menu

choice /C 1234
echo.

if errorlevel 4 goto Restart
if errorlevel 3 goto UpdateV8GYP
if errorlevel 2 goto UpdateToRev

:redownload
echo Removing old build directory ...
rd /s /q build

:CreateBuildDir

echo Creating build directory ...
if exist build\ goto BeginSrcDownload
md build
if errorlevel 1 goto Error

:BeginSrcDownload
echo Downloading V8 ...
REM svn checkout -r %v8rev% http://v8.googlecode.com/svn/trunk/@%v8rev% build\v8 >getV8.log ; ISSUE 2882
REM git clone https://chromium.googlesource.com/external/v8.git  build\v8
git clone https://chromium.googlesource.com/v8/v8.git build\v8 >getv8.log
if errorlevel 1 goto Error

:UpdateToRev
cd build\v8
git checkout %v8rev%
git pull --rebase origin master
cd ..\..

:UpdateV8GYP
echo Updating V8.GYP file ...
call UpdateGYP "build\v8\tools\gyp"
if "%added%"=="false" goto error
echo Completed.
pause

goto Restart

REM _01234567890123456789012345678901234567890123456789012345678901234567890123456789___________________________________________________________________________________

:CheckEnv

if not exist build\v8\ echo V8 Source not downloaded. & pause & goto restart

cd build

if not exist v8\build\gyp\ echo Required tool 'GYP' not downloaded. & pause & goto restart
if not exist v8\third_party\python_26\ echo Required tool 'Python' not downloaded. & pause & goto restart
if not exist v8\third_party\cygwin\ echo Required tool 'Cygwin' not downloaded. & pause & goto restart
if not exist v8\third_party\icu\ echo Required tool 'ICU' not downloaded. & pause & goto restart

REM Check if we are running in the correct environment (supports VS2010 and VS2012) ...
REM (note: more than one version of Visual Studio may be installed, so start from highest version, to least)

if not "%DevEnvDir%"=="" set VSTools=%DevEnvDir%..\Tools\ & goto BeginV8Compile

echo This command file should be run via the Visual Studio developer prompt.
echo Attempting to do so now ...

if not "%VS120COMNTOOLS%"=="" set VSTools=%VS120COMNTOOLS%& set VSVer=2013& goto SetVSEnv
if not "%VS110COMNTOOLS%"=="" set VSTools=%VS110COMNTOOLS%& set VSVer=2012& goto SetVSEnv
if not "%VS100COMNTOOLS%"=="" set VSTools=%VS100COMNTOOLS%& set VSVer=2010& goto SetVSEnv

echo Failed to detect correct version of Visual Studio.  Please open the developer prompt and run the command file there.

goto Exit

:SetVSEnv
Echo Visual Studio %VSVer% detected ...
set GYP_MSVS_VERSION=%VSVer%
call "%VSTools%VsDevCmd.bat"
echo Visual Studio developer prompt environment was setup successfully!
echo.

:BeginV8Compile
cd %WorkingDir%
echo Visual Studio environment being used: %DevEnvDir%
echo.

:SetMode
set mode=%1
if "%mode%"=="" goto PromptReleaseMode
if /i "%mode%"=="debug" goto DebugMode
if /i "%mode%"=="release" goto ReleaseMode
echo %mode%: Invalid build mode; please specify "Debug" or "Release"
goto PromptReleaseMode
:DebugMode
set mode=Debug
goto Start
:ReleaseMode
set mode=Release
goto Start
:PromptReleaseMode
choice /C DR /M "Please choose a build mode: [D]ebug, or [R]elease"
echo.
if errorlevel 2 goto ReleaseMode
if errorlevel 1 goto DebugMode

REM _01234567890123456789012345678901234567890123456789012345678901234567890123456789___________________________________________________________________________________

:Start
echo Build mode: %mode%

:BuildV8

cd build

echo Building 32-bit V8 ...
if not exist "v8-ia32" goto CopyV832Bit
echo Do a clean build of the V8 source for the 32-bit libraries?
choice /M "This will delete both existing debug and release directories as well."
if errorlevel 2 cd v8-ia32 & goto BuildV832Bit
echo Cleaning the V8 source for the 32-bit libraries...
:CopyV832Bit
set ERRORLEVEL=0
if exist "v8-ia32" echo Removing old files ... & rd /s /q v8-ia32
if not errorlevel 0 goto Error
md v8-ia32
if errorlevel 1 goto Error
echo Copying needed files ...
xcopy v8\*.* v8-ia32\ /e /y >nul
if errorlevel 1 goto Error
cd v8-ia32
echo Generating Visual Studio project files for the 32-bit libraries...
third_party\python_26\python build\gyp_v8 -Dtarget_arch=ia32 -Dcomponent=static_library
REM -Dcomponent=shared_library -Dv8_use_snapshot=false
if errorlevel 1 goto Error
if not exist "build\all.sln" echo "Error: build\all.sln was not created." & goto Error
:BuildV832Bit
echo Building v8-ia32\tools\gyp\v8.sln ...
set LogFile=%CD%\build.log
msbuild /p:Configuration=%mode% /p:Platform=Win32 tools\gyp\v8.sln >"%LogFile%"
if errorlevel 1 goto Error
set LogFile=
cd ..

REM _01234567890123456789012345678901234567890123456789012345678901234567890123456789___________________________________________________________________________________

if not "%PROCESSOR_ARCHITECTURE%"=="x86" goto 64BitSupported
echo.
echo While compiling the 64-bit version of V8 on a 32-bit system will work, the last
echo build step will fail for some reason (even though the compile will succeed).
echo If you continue, an error may occur, but the 64-bit DLLs will be present.
echo Just restart this script a second time and skip this compile and the 64-bit
echo DLLs will be copied correctly.
choice /M "Attempt to build 64-bit version?"
echo.
if errorlevel 2 goto ImportLibs
:64BitSupported
echo Building 64-bit V8 ...
if not exist "v8-x64" goto CopyV864Bit
echo Do a clean build of the V8 source for the 64-bit libraries?
choice /M "This will delete both existing debug and release directories as well."
if errorlevel 2 cd v8-x64 & goto BuildV864Bit
echo Cleaning the V8 source for the 64-bit libraries...
:CopyV864Bit
set ERRORLEVEL=0
if exist "v8-x64" echo Removing old files ... & rd /s /q v8-x64
if not errorlevel 0 goto Error
md v8-x64
if errorlevel 1 goto Error
echo Copying needed files ...
xcopy v8\*.* v8-x64\ /e /y >nul
if errorlevel 1 goto Error
cd v8-x64
echo Generating Visual Studio project files for the 64-bit libraries...
third_party\python_26\python build\gyp_v8 -Dtarget_arch=x64 -Dcomponent=static_library
REM -Dcomponent=shared_library -Dv8_use_snapshot=false
if not exist "build\all.sln" echo "Error: build\all.sln was not created." & goto Error
if errorlevel 1 goto Error
:BuildV864Bit
echo Building v8-x64\tools\gyp\v8.sln ...
set LogFile=%CD%\build.log
msbuild /p:Configuration=%mode% /p:Platform=x64 /p:TreatWarningsAsErrors=false tools\gyp\v8.sln >"%LogFile%"
REM Note: 'TreatWarningsAsErrors' must be false, as size_t (int64 in x64) is downsized to int32 in some areas.
REM (For more options see http://msdn.microsoft.com/en-us/library/bb629394.aspx)
if errorlevel 1 goto Error
set LogFile=
cd ..

:ImportLibs
echo Importing V8 libraries ...

REM *** .NET 4.0 ***

xcopy v8-ia32\build\%mode%\*.dll ..\..\..\bin\%mode%\x86\ /Y >nul
if errorlevel 1 goto Error

xcopy v8-ia32\build\%mode%\*.pdb ..\..\..\bin\%mode%\x86\ /Y >nul
if errorlevel 1 goto Error

xcopy v8-x64\build\%mode%\*.dll ..\..\..\bin\%mode%\x64\ /Y >nul
if errorlevel 1 goto Error

xcopy v8-x64\build\%mode%\*.pdb ..\..\..\bin\%mode%\x64\  /Y >nul
if errorlevel 1 goto Error

REM *** .NET 3.5 ***

xcopy v8-ia32\build\%mode%\*.dll ..\..\..\bin\3.5\%mode%\x86\ /Y >nul
if errorlevel 1 goto Error

xcopy v8-ia32\build\%mode%\*.pdb ..\..\..\bin\3.5\%mode%\x86\ /Y >nul
if errorlevel 1 goto Error

xcopy v8-x64\build\%mode%\*.dll ..\..\..\bin\3.5\%mode%\x64\ /Y >nul
if errorlevel 1 goto Error

xcopy v8-x64\build\%mode%\*.pdb ..\..\..\bin\3.5\%mode%\x64\  /Y >nul
if errorlevel 1 goto Error


:success
echo Success!
pause
goto Restart

REM _01234567890123456789012345678901234567890123456789012345678901234567890123456789___________________________________________________________________________________

:Error
echo *** THE PREVIOUS STEP FAILED ***

:ErrorOptions
REM (in order for "%errorlevel%" to expand correctly, we need to make sure there's no matching environment variable set with the same name)
set errorlevel=
echo.
echo Options:
if not "%LogFile%"=="" echo   [L]og: Open the log file (%LogFile%)
echo   [C]md: Open the command prompt with the existing environment
echo   [R]estart
echo   [E]xit
echo.
if "%LogFile%"=="" choice /C ERCL & goto ErrOptResponse
if not "%LogFile%"=="" choice /C ERCL & goto ErrOptResponse
:ErrOptResponse
if "%errorlevel%"=="1" goto End
if "%errorlevel%"=="2" goto Restart
if "%errorlevel%"=="3" cmd
if "%errorlevel%"=="4" notepad "%LogFile%"
goto ErrorOptions

REM _01234567890123456789012345678901234567890123456789012345678901234567890123456789___________________________________________________________________________________

:End
REM Success! Change back to root working directory.
cd "%WorkingDir%"

REM _01234567890123456789012345678901234567890123456789012345678901234567890123456789___________________________________________________________________________________

:Exit
REM Possibly no success, so stay at current location for debug purposes.
endlocal
