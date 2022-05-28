#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:function_path()
{
   local -r OPTIONS=$(getopt -o fs:v: -l "file,suffix:,variable:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Directory=true
   local Suffix=
   local Variable=

   while true ; do
      case "$1" in
      -f|--file)     Directory=false; shift;;
      -s|--suffix)   Suffix="$2"; shift 2;;
      -v|--variable) Variable="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   # Specify the function to look up: either explicit or from a PUBLIC function/method
   local Function

   if [[ $# -gt 0 ]] ; then
      Function="$1"
   elif [[ ${FUNCNAME[1]} = @ ]] ; then
      Function="${FUNCNAME[2]}"
   else
      Function="${FUNCNAME[1]}"
   fi

   # Lookup the path to this function
   local Path="${__FunctionPath[$Function]}"

   if $Directory && [[ -n $Path ]] ; then
      Path="$(dirname "$Path")"
   fi

   # Either save it or echo it
   if [[ -n $Variable ]] ; then
      printf -v "$Variable" "%s" "$Path$Suffix"
   else
      echo "$Path$Suffix"
   fi
}
