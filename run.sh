#!/bin/bash
# ################################################################################################ #
# OCaml Labs, University of Cambridge                                                              #
# ################################################################################################ #
# OCaml Windows Test Harness Wrapper Scripts                                                       #
# ################################################################################################ #
# Copyright (c) 2017 MetaStack Solutions Ltd.                                                      #
# ################################################################################################ #
# Author: David Allsopp                                                                            #
# 19-Mar-2017                                                                                      #
# ################################################################################################ #
# Redistribution and use in source and binary forms, with or without modification, are permitted   #
# provided that the following two conditions are met:                                              #
#     1. Redistributions of source code must retain the above copyright notice, this list of       #
#        conditions and the following disclaimer.                                                  #
#     2. Neither the name of MetaStack Solutions Ltd. nor the names of its contributors may be     #
#        used to endorse or promote products derived from this software without specific prior     #
#        written permission.                                                                       #
#                                                                                                  #
# This software is provided by the Copyright Holder 'as is' and any express or implied warranties  #
# including, but not limited to, the implied warranties of merchantability and fitness for a       #
# particular purpose are disclaimed. In no event shall the Copyright Holder be liable for any      #
# direct, indirect, incidental, special, exemplary, or consequential damages (including, but not   #
# limited to, procurement of substitute goods or services; loss of use, data, or profits; or       #
# business interruption) however caused and on any theory of liability, whether in contract,       #
# strict liability, or tort (including negligence or otherwise) arising in any way out of the use  #
# of this software, even if advised of the possibility of such damage.                             #
# ################################################################################################ #

ROOT=$1
BUILD=$2
PORT=${2%64}

cd $ROOT/ocaml-$BUILD

TAG=$3

shift 3

FLAMBDA=0
SAFE_STRING=0
SPACETIME=0
NO_ERRORS=0
NOFLAT=0
WINDOWS_UNICODE=1

CYG_FLAMBDA=
CYG_SPACETIME=
CYG_SAFE_STRING=
CYG_NOFLAT=

PHASES=flexdll.opt
MODE=standard

while [[ -n $1 ]] ; do
  case "$1" in
    msvs-promote-path)
      eval $(tools/msvs-promote-path)
      ;;
    noflat)
      NOFLAT=1
      CYG_NOFLAT=-no-flat-float-array
      ;;
    flambda)
      FLAMBDA=1
      CYG_FLAMBDA=-flambda
      ;;
    safe-string)
      SAFE_STRING=1
      CYG_SAFE_STRING=-safe-string
      ;;
    spacetime)
      SPACETIME=1
      CYG_SPACETIME=-spacetime
      ;;
    windows-ansi)
      WINDOWS_UNICODE=0
      ;;
    no-errors)
      NO_ERRORS=1
      ;;
    flexlink)
      PHASES="flexdll.opt flexdll flexlink.opt flexlink external"
      MODE=flexlink
      ;;
    standard)
      ;;
    *)
      echo "Unrecognised parameter \"$1\"">&2
      exit 1
      ;;
  esac
  shift
done

PRE_WORLD=
POST_WORLD=flexlink.opt

for phase in $PHASES ; do
  if [[ $MODE = "flexlink" ]] ; then
    case $phase in
      flexdll|flexlink|external)
        POST_WORLD=install
        ;;
      *.opt)
        POST_WORLD="flexlink.opt install"
        ;;
    esac
    SET_FLEX=0
    NATIVE_FLEXLINK=0
    INSTALLED_FLEXLINK=1
    INSTALLED_FLEXDLL=0
    case $phase in
      flexdll.opt)
        PRE_WORLD=flexdll
        NATIVE_FLEXLINK=1
        INSTALLED_FLEXDLL=1
        ;;
      flexdll)
        # Copy artefacts from the previous phase for use later
        rm -rf ../flexdll-$BUILD
        mkdir -p ../flexdll-$BUILD/src
        cp flexdll/flexdll*.o* flexdll/flexdll.h flexdll/*.manifest ../flexdll-$BUILD/src/
        cp flexdll/flexlink.opt ../flexdll-$BUILD/src/flexlink.exe
        INSTALLED_FLEXDLL=1
        PRE_WORLD=flexdll
        ;;
      flexlink.opt)
        mv ../flexdll-$BUILD/src/flexdll* ../flexdll-$BUILD/src/*.manifest ../flexdll-$BUILD/
        SET_FLEX=1
        NATIVE_FLEXLINK=1
        PRE_WORLD=flexlink
        ;;
      flexlink)
        SET_FLEX=1
        PRE_WORLD=flexlink
        ;;
      external)
        mv ../flexdll-$BUILD/src/flexlink.exe ../flexdll-$BUILD/
        export PATH="$(cygpath --absolute ../flexdll-$BUILD):$PATH"
        git submodule deinit flexdll
        INSTALLED_FLEXLINK=0
        PRE_WORLD=
        ;;
    esac
    if [[ $phase != "flexdll.opt" ]] ; then
      git clean -dfx
      cd flexdll
      git clean -dfx
      cd ..
      cp config/s-nt.h config/s.h
      cp config/m-nt.h config/m.h
      cp config/Makefile.$BUILD config/Makefile
    fi
    PREFIX=$(cygpath --absolute --mixed .)
    sed -i -e "s|PREFIX=[^\r]*|PREFIX=$PREFIX/install|" config/Makefile
    if ((SET_FLEX)) ; then
      FLEX_PATH=$(cygpath --mixed --absolute ../flexdll-$BUILD)
      sed -i -e "s|FLEXDIR:=[^\r]*|FLEXDIR=$FLEX_PATH|" \
             -e "/FLEXLINK_FLAGS=/s|\r\?$| -L$FLEX_PATH|" config/Makefile
    fi
    export PATH="$PATH:$ROOT/ocaml-$BUILD/install/bin"
  fi
  if [[ $PORT != "cygwin" ]] ; then
    if [[ $MODE = "standard" ]] ; then
      PRE_WORLD=flexdll
    fi
    MAKE_INVOKE="make"
    if ((!NO_ERRORS)) ; then
      if [[ $PORT = "mingw" ]] ; then
        WARNERROR=-Werror
      elif [[ $PORT = "msvc" ]] ; then
        WARNERROR=-WX
      fi
      sed -i -e "/^ *CFLAGS *=/s/\r\?$/ $WARNERROR\0/" config/Makefile
    fi
    if ((NOFLAT)) ; then
      sed -i -e "s/FLAT_FLOAT_ARRAY=true/FLAT_FLOAT_ARRAY=false/" config/Makefile
      sed -i -e "/FLAT_FLOAT_ARRAY/d" byterun/caml/m.h
    fi
    if ((FLAMBDA)) ; then
      sed -i -e "s/FLAMBDA=false/FLAMBDA=true/" config/Makefile
    fi
    if ((SAFE_STRING)) ; then
      sed -i -e "s/SAFE_STRING=[a-z]*/SAFE_STRING=true/" config/Makefile
    fi
    if ((!WINDOWS_UNICODE)) ; then
      sed -i -e "s/WINDOWS_UNICODE=1/WINDOWS_UNICODE=0/" config/Makefile
    fi
    if ((SPACETIME)) ; then
      sed -i -e "s/WITH_SPACETIME=false/WITH_SPACETIME=true/" config/Makefile
    fi
  fi

  if [[ $MODE != "standard" ]] ; then
    echo "Test phase \"$phase\"" >> $ROOT/ocaml/logs/$TAG/build-$BUILD.log
  fi

  if [[ $PORT = "cygwin" ]] ; then
    if ! script --return --append -c "./configure $CYG_NOFLAT $CYG_FLAMBDA $CYG_SAFE_STRING $CYG_SPACETIME" $ROOT/ocaml/logs/$TAG/build-$BUILD.log ; then
      exit 1
    fi
    sed -i -e "s/MAX_TESTSUITE_DIR_RETRIES=0/MAX_TESTSUITE_DIR_RETRIES=1/" config/Makefile
    MAKE_INVOKE=make
    POST_WORLD=
  else
    rm -f $ROOT/ocaml/logs/$TAG/build-$BUILD.log
  fi

  mkdir -p $ROOT/ocaml/logs/$TAG
  if script --return --append -c "$MAKE_INVOKE $PRE_WORLD world.opt $POST_WORLD" $ROOT/ocaml/logs/$TAG/build-$BUILD.log ; then
    if [[ $BUILD = "cygwin64" ]] ; then
      rebase -b 0x7cd20000 otherlibs/unix/dllunix.so
      rebase -b 0x7cdc0000 otherlibs/systhreads/dllthreads.so
    fi
    if [[ $MODE = "standard" ]] ; then
      make -C testsuite all
      STATUS=$?
      cp testsuite/_log $ROOT/ocaml/logs/$TAG/_log-$BUILD
      make --no-print-directory -C testsuite report > $ROOT/ocaml/logs/$TAG/_report-$BUILD
      exit $STATUS
    else
      echo "Test phase \"$phase\"" >> $ROOT/ocaml/logs/$TAG/_flex-$BUILD
      if ! script --return --append -c "../ocaml/test-flexlink.sh $BUILD $INSTALLED_FLEXLINK $NATIVE_FLEXLINK $INSTALLED_FLEXDLL" $ROOT/ocaml/logs/$TAG/_flex-$BUILD ; then
        exit 1
      fi
    fi
  else
    exit 1
  fi
done

if [[ $MODE = "flexlink" ]] ; then
  git submodule update --init flexdll
  rm -rf ../flexdll-$BUILD
fi
