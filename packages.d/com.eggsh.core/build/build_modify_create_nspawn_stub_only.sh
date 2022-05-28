#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ __build_modify_create_nspawn_stub_only()
{
   local Options
   Options=$(getopt -o a: -l "assembledir:" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$Options"

   local AssembleDir=
   while true ; do
      case "$1" in
      -a|--assembledir) AssembleDir="$2"; shift 2;;
      --)               shift; break;;
      *)                break;;
      esac
   done

   :highlight <<<"<h2>### Modifications: create nspawn stub only...</h2>"

   # Create temporary directory to hold all contents of (+)_BuildDir
   local (.)_TmpHoldDir="$(mktemp -d -p "$(+)_DestDir" .hld.XXXXXXXXXX)"

   # Enable dotglob (* matches dotfiles) and nullglob (unmatched globs -> empty string)
   :shopt_save
   shopt -s dotglob nullglob

   # Move all contents of (+)_BuildDir into the (.)_TmpHoldDir directory
   mv "$(+)_BuildDir"/* "$(.)_TmpHoldDir"/.

   # Restore previous shopt settings
   :shopt_restore

   # Create empty nspawn
   mkdir -p "$(+)_BuildDir/image/usr/local"
   sudo mv "$(.)_TmpHoldDir" "$(+)_BuildDir/image/usr/local/$(+)_Executable"

   echo
}
