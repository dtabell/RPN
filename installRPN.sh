#!/bin/bash

########################################################################
##
## @file    installRPN.sh
## @brief   installation script for RPN
## @version $Id$
##
########################################################################

## text color and mode variables
##   http://en.wikipedia.org/wiki/Tput
##   http://stackoverflow.com/questions/2924697/
##   http://linuxtidbits.wordpress.com/2008/08/11/
textBlack=$(   tput setaf 0)
textRed=$(     tput setaf 1)
textGreen=$(   tput setaf 2)
textYellow=$(  tput setaf 3)
textBlue=$(    tput setaf 4)
textMagenta=$( tput setaf 5)
textCyan=$(    tput setaf 6)
textWhite=$(   tput setaf 7)
textBF=$( tput bold) # bold face
textUL=$( tput smul) # start underline
textUX=$( tput rmul) # stop underline
textNM=$( tput sgr0) # normal mode (reset)
textBlackBF=${textBF}${textBlack}
textRedBF=${textBF}${textRed}
textBlueBF=${textBF}${textBlue}

## echo red text
function echo_red() {
  echo -n "$textRed"
  echo "$@"
  echo -n "$textNM"
}

## usage message
usage=
usage=$usage$'usage: installRPN.sh [-DhH] [-b bindir] [-l rpndir] [-L pmdir]'
usageF=$usage$'\n\n'
usageF=$usageF$'   -b bindir    specify location for the binary [$HOME/bin]\n'
usageF=$usageF$'   -D           install a debug version\n'
usageF=$usageF$'   -h           output a brief help message\n'
usageF=$usageF$'   -H           output this longer help message\n'
usageF=$usageF$'   -l rpndir    specify location for RPN libraries [$HOME/.rpn]\n'
usageF=$usageF$'   -L pmdir     use local::lib to access local Perl modules in pmdir'

## set default values
bindir="${HOME}/bin"
rpndir="${HOME}/.rpn"
pmdir="${HOME}/perl5"
debugVersion="false"
useLocalLib="false"

basefiles='
  constants2006.rpn
  constants2014.rpn
  fns.rpn
  ops.rpn
'

libfiles='
  dynEuclid.rpn
'

## parse options
while getopts "b:DhHl:L:" opt; do
  case $opt in
  b) bindir="$OPTARG" ;;
  D) debugVersion="true" ;;
  h) echo "$usage" ; exit 0 ;;
  H) echo "$usageF" ; exit 0 ;;
  l) rpndir="$OPTARG" ;;
  L) useLocalLib="true" ; pmdir="$OPTARG" ;;
  \?) echo "$usage" ; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

## ensure $bindir exists
## but request verification before creating $bindir
if [ ! -e "$bindir" ] ; then
  echo "${textRed}The directory ${textUL}${bindir}${textUX} does not exist."
  read -p "Are you sure you wish to create it?${textNM} y/n [n] "
  if [ -z "$REPLY" ] ; then
    echo "Terminating installation."
    exit 1
  else
    if [[ "$REPLY" =~ ^[[:space:]]*([yY]|[yY][eE][sS])[[:space:]]*$ ]] ; then
      echo "Okay, will create the directory ${bindir}."
      echo ${textBF}$'Be sure to add it to your $PATH.\n'${textNM}
      mkdir $bindir
    else
      echo "Terminating installation."
      exit 1
    fi
  fi
else
  if [ ! -d "$bindir" ] ; then
    echo_red "I won't be able to install the executable!"
    echo_red "Sorry: ${textUL}${bindir}${textUX} is not a directory."
    exit 1
  fi
fi

## ensure $rpndir exists
if [ ! -e "$rpndir" ] ; then
  mkdir $rpndir
else
  if [ ! -d "$rpndir" ] ; then
    echo_red "I won't be able to install the library files!"
    echo_red "Sorry: ${textUL}${rpndir}${textUX} is not a directory."
    exit 1
  fi
fi

## if requested, check that $pmdir exists
if [ "$useLocalLib" == "true" ] ; then
  if [ ! -d "$pmdir" ] ; then
    echo_red "I can't access local Perl modules in ${pmdir}!"
    echo_red "Sorry: ${textUL}${pmdir}${textUX} is not a directory."
    exit 1
  fi
fi

## ensure $basedir exists
basedir="$rpndir/base"
if [ ! -e "$basedir" ] ; then
  mkdir $basedir
else
  if [ ! -d "$basedir" ] ; then
    echo_red "I won't be able to install the base library files!"
    echo_red "Sorry: ${textUL}${basedir}${textUX} is not a directory."
    exit 1
  fi
fi

## ensure $libdir exists
libdir="$rpndir/lib"
if [ ! -e "$libdir" ] ; then
  mkdir $libdir
else
  if [ ! -d "$libdir" ] ; then
    echo_red "I won't be able to install the other library files!"
    echo_red "Sorry: ${textUL}${libdir}${textUX} is not a directory."
    exit 1
  fi
fi

## installation

## modify paths
sed -e "s:BINDIR:$bindir:" -e "s:RPNDIR:$rpndir:" < rpn.pl > rpn
## if installing a debug version
if [ "$debugVersion" == "true" ] ; then
  sed -i -e 's/^#DEBUG: //' rpn
fi
## if needed perl modules are installed locally, use local::lib
## (e.g. Term::ReadLine::*)
if [ "$useLocalLib" == "true" ] ; then
  sed -i -e "s.^#use local::lib;$.use local::lib '$pmdir';." rpn
fi
chmod 755 rpn

## install the executable and other files
echo "Installing executable:"
cmd="  mv rpn ${bindir}/rpn"
echo "$cmd"
eval $cmd
echo ""

echo "Installing base files:"
for f in $basefiles ; do
  cmd="  cp base/$f ${basedir}/$f"
  echo "$cmd"
  eval $cmd
done
echo ""

echo "Installing other library files:"
for f in $libfiles ; do
  cmd="  cp lib/$f ${libdir}/$f"
  echo "$cmd"
  eval $cmd
done
echo ""

touch ${rpndir}/rpn_history
