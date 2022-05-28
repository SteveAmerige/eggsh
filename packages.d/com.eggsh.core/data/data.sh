#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:old_set()
{
   local -r OPTIONS=$(getopt -o np:s -l "no-update,package:,string" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local UpdateShellSettings=true
   local Package=
   local IsString=false
   while true ; do
      case "$1" in
      -n|--no-update)   UpdateShellSettings=false; shift;;
      -p|--package)     Package="$2"; shift 2;;
      -s|--string)      IsString=true; shift;;
      --)               shift; break;;
      esac
   done

   if [[ -z $Package ]]; then
      Package="${_settings[\".\".primary_package]}"
      if [[ -z $Package ]]; then
         echo "Package must be specified (or :old_set -p . primary_package <package>)"
         return 1
      fi
   fi

   if [[ -z ${__UnorderedPackages[$Package]+1} ]]; then
      echo "No such package: $Package"
      return 1
   fi

   local Key Value
   # If no key/value pairs are requested to be set, then emit all currently-set key/value pairs
   if [[ $# -eq 0 ]]; then
      for Key in "${!_settings[@]}"; do
         echo "$Key=${_settings[$Key]}"
      done | sort -t'"' -k1,2
      return 0
   fi

   # Process setters
   local -a ModifiedPackages
   local Status=0
   local DataPackageSettingsFile="$_dataPackagesDir/$Package/settings.json"
   local DataPackageSettings="$(cat "$DataPackageSettingsFile")"
   local Result
   while [[ $# -gt 1 ]]; do
      Key="$1"
      if $IsString; then
         Value="\"$2\""
      else
         Value="$2"
      fi
      shift 2

      Result="$(jq -r --slurpfile in <(echo "$Value") "$Key |= \$in[]" 2>/dev/null <<<"$DataPackageSettings")"
      if [[ $? -ne 0 ]]; then
         echo "Invalid key=$Key or value=$Value"
         jq -r --slurpfile in <(echo "$Value") "$Key |= \$in[]" <<<"$DataPackageSettings"
         Status=1
         continue
      else
         DataPackageSettings="$Result"
      fi

   done

   # Update the JSON settings file
   jq -rS . <<<"$DataPackageSettings" > "$DataPackageSettingsFile"

   if $UpdateShellSettings; then
      :settings_update
   fi

   # Process optional final getter
   if [[ $# -eq 1 ]]; then
      Key="$1"
      :old_get -p "$Package" "$Key"
   fi

   return $Status
}

:old_get()
{
   local -r OPTIONS=$(getopt -o p:v: -l "package:,variable:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Package=
   local Var=
   while true ; do
      case "$1" in
      -p|--package)  Package="$2"; shift 2;;
      -v|--variable) Var="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   if [[ -z $Package ]]; then
      Package="${_settings[\".\".primary_package]}"
      if [[ -z $Package ]]; then
         echo "Package must be specified (or :old_set -p . primary_package <package>)"
         return 1
      fi
   fi

   if [[ $# -ne 1 ]]; then
      echo "One key must be specified"
      return
   fi

   local Key="$1"
   if [[ -n ${_settings[\"$Package\"$Key]+1} ]]; then
      local Value="${_settings[\"$Package\"$Key]}"
      if [[ -n $Var ]]; then
         printf -v "$Var" "%s" "$Value"
      else
         echo "$Value"
      fi
   else
      if [[ -n $Var ]]; then
         printf -v "$Var" "%s" ''
      fi
      return 1
   fi
}
