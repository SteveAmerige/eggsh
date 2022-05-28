#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:command_exists()
{
   local OPTIONS
   OPTIONS=$(getopt -o v -l "verbose" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$OPTIONS"

   local Quiet=true
   while true ; do
      case "$1" in
      -v|--verbose)  Quiet=false; shift;;
      --)            shift; break;;
      *)             break;;
      esac
   done

   local Status=0
   local Command
   for Command ; do
      if ! command -v "$Command" >/dev/null 2>&1; then
         Status=1
         $Quiet || echo "Required command is not available: $Command"
      fi
   done

   return $Status
}

:package_exists()
{
   local -r OPTIONS=$(getopt -o i -l "install" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Install="false"

   while true ; do
      case "$1" in
      -i|--install)     Install="true"; shift;;
      --)               shift; break;;
      esac
   done

   local Package
   local Status=0
   for Package ; do
      rpm -q "$Package" >/dev/null 2>&1 ||
      {
         if $Install ; then
            :sudo_available ||
               { echo "Permission to run sudo is not granted to user $USER"; return 1; }

            sudo yum -y install "$Package" ||
               { echo "Could not install package: $Package"; Status=1; }
         else
            echo "Package $Package is not installed and is required"
            Status=1
         fi
      }
   done

   return $Status
}

:command_install_required()
{
   local Packages=(
      epel-release
      jq
   )

   :package_exists -i "${Packages[@]}"
}
