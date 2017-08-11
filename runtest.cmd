@rem * ******************************************************************************************* *
@rem * OCaml Labs, University of Cambridge                                                         *
@rem * ******************************************************************************************* *
@rem * OCaml Windows Test Harness Wrapper Scripts                                                  *
@rem * ******************************************************************************************* *
@rem * Copyright (c) 2017 MetaStack Solutions Ltd.                                                 *
@rem * ******************************************************************************************* *
@rem * Author: David Allsopp                                                                       *
@rem * 19-Mar-2017                                                                                 *
@rem * ******************************************************************************************* *
@rem * Redistribution and use in source and binary forms, with or without modification, are        *
@rem * permitted provided that the following two conditions are met:                               *
@rem *     1. Redistributions of source code must retain the above copyright notice, this list of  *
@rem *        conditions and the following disclaimer.                                             *
@rem *     2. Neither the name of MetaStack Solutions Ltd. nor the names of its contributors may   *
@rem *        be used to endorse or promote products derived from this software without specific   *
@rem *        prior written permission.                                                            *
@rem *                                                                                             *
@rem * This software is provided by the Copyright Holder 'as is' and any express or implied        *
@rem * warranties including, but not limited to, the implied warranties of merchantability and     *
@rem * fitness for a particular purpose are disclaimed. In no event shall the Copyright Holder be  *
@rem * liable for any direct, indirect, incidental, special, exemplary, or consequential damages   *
@rem * (including, but not limited to, procurement of substitute goods or services; loss of use,   *
@rem * data, or profits; or business interruption) however caused and on any theory of liability,  *
@rem * whether in contract, strict liability, or tort (including negligence or otherwise) arising  *
@rem * in any way out of the use of this software, even if advised of the possibility of such      *
@rem * damage.                                                                                     *
@rem * ******************************************************************************************* *
@setlocal
@echo off

rem Various bugs in Git for Windows which I couldn't be bothered to go into:
rem This produces no output, even if there are changed files:
rem   for /f "delims=" %%L IN ('git status --porcelain --untracked-files=no') do echo %%L
rem git diff --exit-code always exits with code 1, regardless of status
set CLEAN=1
for /f %%L in ('git status --porcelain') do if "%%L" neq "??" set CLEAN=0

if %CLEAN% equ 0 (
  echo There are uncomitted changes!?
  goto :EOF
)

for /f "delims=" %%H in ('git rev-parse --abbrev-ref HEAD') do set HEAD=%%H

if "%HEAD%" equ "HEAD" (
  for /f "delims=" %%H in ('git rev-parse --short HEAD') do (
    set HEAD=%%H
    echo Warning - HEAD detached at %%H
  )
)

set MODE=standard
if "%2" equ "flexlink" (
  set MODE=flexlink
)

echo Worktrees will be erased!
pause

set PORTS=mingw mingw64 msvc msvc64
if "%MODE%" neq "flexlink" set PORTS=%PORTS% cygwin cygwin64

for %%B in (%PORTS%) do call :Prepare %%B
cd ..
for /f "delims=" %%P in ('C:\cygwin\bin\cygpath --absolute .') do set ROOT=%%P

rem Launch the builds
cd ocaml
if not exist logs\%1\nul md logs\%1
echo Started>logs\%1\start.stamp

for %%P in (%PORTS%) do (
  if "%%P" equ "mingw" snap C:\Windows\System32\cmd.exe NW /c "C:\cygwin64\bin\bash -lc '%ROOT%ocaml/run.sh %ROOT% mingw %* || pause"
  if "%%P" equ "mingw64" snap C:\Windows\System32\cmd.exe NE /c "C:\cygwin64\bin\bash -lc '%ROOT%ocaml/run.sh %ROOT% mingw64 %* || pause"
  if "%%P" equ "msvc" (
    call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars32.bat"
    rem call "C:\Program Files (x86)\Microsoft Visual Studio\Shared\14.0\VC\vcvarsall.bat" x86
    snap C:\Windows\System32\cmd.exe W /c "C:\cygwin64\bin\bash -lc '%ROOT%ocaml/run.sh %ROOT% msvc %* msvs-promote-path || pause"
  )
  if "%%P" equ "msvc64" (
    call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars64.bat"
    rem call "C:\Program Files (x86)\Microsoft Visual Studio\Shared\14.0\VC\vcvarsall.bat" amd64
    snap C:\Windows\System32\cmd.exe E /c "C:\cygwin64\bin\bash -lc '%ROOT%ocaml/run.sh %ROOT% msvc64 %* msvs-promote-path || pause"
  )
  if "%%P" equ "cygwin" snap C:\Windows\System32\cmd.exe SW /c "C:\cygwin\bin\bash -lc '%ROOT%ocaml/run.sh %ROOT% cygwin %* || pause"
  if "%%P" equ "cygwin64" snap C:\Windows\System32\cmd.exe SE /c "C:\cygwin64\bin\bash -lc '%ROOT%ocaml/run.sh %ROOT% cygwin64 %* || pause"
)
goto :EOF

:Prepare
cd ..\ocaml-%1
git clean -dfx
git reset .
git checkout .
if exist flexdll\.git (
  cd flexdll
  git clean -dfx
  cd ..
)
if "%MODE%" equ "flexlink" git submodule update --init
git checkout harness-%1
git reset --hard %HEAD%
set PORT=%1
if "%PORT:~0,4%" neq "cygw" (
  cd config
rem @@DRA Should switch between these two based on the root commit in trunk where this changed
  copy s-nt.h ..\byterun\caml\s.h
  copy m-nt.h ..\byterun\caml\m.h
rem  copy s-nt.h s.h
rem  copy m-nt.h m.h
  copy Makefile.%1 Makefile
  cd ..
)
goto :EOF
