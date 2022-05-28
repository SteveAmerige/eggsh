#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:Object:[()
{
   :method

   local -r OPTIONS=$(getopt -o m:v: -l "map:,variable:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Var=
   local Map="map"
   while true ; do
      case "$1" in
      -m|--map)      Map="map_$2"; shift 2;;
      -v|--variable) Var="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   # Remove any trailing bracket
   [[ ${@:$#} != ']' ]] || set -- "${@:1:$#-1}"

   # Ensure that the map exists
   [[ -v ${this}_$Map[@] ]] || local -Ag "${this}_$Map"

   # Perform setter operations
   while [[ $# -ge 2 ]]; do
      # Store the key
      local Key="$1"
      shift

      # If the optional key/value separator (:) is present, remove it
      [[ $1 != ':' ]] || shift

      # Double-check to ensure that there are still parameters to process
      if [[ $# -gt 0 ]]; then
         # Store the value
         printf -v "${this}_$Map[$Key]" "%s" "$1"
         shift

         # If the optional medial separator (,) is present, remove it
         [[ $1 != ',' ]] || shift
      fi
   done

   # Is there a getter?
   if [[ $# -eq 1 ]]; then
      # Ensure the copy variable exists
      [[ -v $Var ]] || local -g "$Var"

      local Indirect="${this}_$Map[$1]"

      # Save the result to a variable?
      if [[ -n $Var ]]; then
         printf -v "$Var" "%s" "${!Indirect}"
      else
         echo "${!Indirect}"
      fi

   # Is this a request to copy the associative array?
   elif [[ -n $Var ]]; then
      # Ensure the copy associative array exists
      [[ -v $Var ]] || local -Ag "$Var"

      local -a Keys
      local Key
      local Indirect="${this}_$Map"

      eval Keys=( \"\${!$Indirect[@]}\" )
      for Key in "${Keys[@]}"; do
         eval printf -v \"$Var[$Key]\" \"%s\" \"\${$Indirect[$Key]}\"
      done
   fi

   ..
}

:Object:[].exists()
{
   :method

   local -r OPTIONS=$(getopt -o m: -l "map:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Map="map"
   while true ; do
      case "$1" in
      -m|--map)      Map="map_$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   local Indirect="${this}_$Map[$1]+exists"
   [[ ${!Indirect} ]]
}

:Object:[].print()
{
   :method

   local -r OPTIONS=$(getopt -o lm: -l "long,map:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Long=false
   local Map="map"
   while true ; do
      case "$1" in
      -l|--long)     Long=true; shift;;
      -m|--map)      Map="map_$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   if $Long; then
      local Indirect="${this}_$Map[@]"
      echo "${!Indirect}"
   else
      declare -p "${this}_$Map"
   fi
}
