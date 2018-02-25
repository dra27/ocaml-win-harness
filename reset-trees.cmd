@rem 7-Feb-2018 @ DRA
@setlocal
@echo off

for %%P in (cygwin cygwin64 mingw mingw64 msvc msvc64) do (
  pushd ..\ocaml-%%P
  echo Resetting %%P
  for /f "delims=" %%F in ('dir /a-d/b') do if "%%F" neq ".git" del "%%F"
  for /f "delims=" %%D in ('dir /ad/b') do rd /s/q "%%D"
  if %%P neq cygwin if %%P neq cygwin64 git checkout trunk -- .gitmodules && git submodule sync && git submodule update --init flexdll
  popd
)
