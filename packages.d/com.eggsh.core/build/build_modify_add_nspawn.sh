#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ __build_modify_add_nspawn()
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

   :highlight <<<"<h2>### Modifications: add nspawn...</h2>"

   # Ensure image file exists
   $(@)_BuildSpec:select .image
   local Image="${(@)_BuildInfo['.image']}"
   local ImageURI Size
   :to_uri -v ImageURI "$Image"

   # Get the size of the image file
   Size="$(curl -sI "$ImageURI" | grep "Content-Length" | awk '{printf "%d",$2}')"
   if [[ -z $Size ]]; then
      echo "No such image file: $Image"
      return 1
   fi

   # Create temporary directory to hold all contents of (+)_BuildDir
   local (.)_TmpHoldDir="$(mktemp -d -p "$(+)_DestDir" .hld.XXXXXXXXXX)"

   # Enable dotglob (* matches dotfiles) and nullglob (unmatched globs -> empty string)
   :shopt_save
   shopt -s dotglob nullglob

   # Move all contents of (+)_BuildDir into the (.)_TmpHoldDir directory
   mv "$(+)_BuildDir"/* "$(.)_TmpHoldDir"/.

   # Restore previous shopt settings
   :shopt_restore

   # Download the image file
   local (.)_TmpImage="$(mktemp -p "$(+)_DestDir" .img.XXXXXXXXXX)"

   :highlight <<<"<b>--- Downloading Image...</b>"
   if hash pv 2>/dev/null ; then
      curl -s "$ImageURI" | pv -s "$Size" > "$(.)_TmpImage"
   else
      echo "Copying $ImageURI"
      curl -s -o "$(.)_TmpImage" "$ImageURI"
   fi

   # Extract the image file
   :highlight <<<"\n<b>--- Extracting Image...</b>"
   cd "$(+)_BuildDir"

   if hash pv 2>/dev/null ; then
      pv "$(.)_TmpImage" | sudo tar --numeric-owner --format=pax -xpf -
   else
      sudo tar --numeric-owner --format=pax -xpf "$(.)_TmpImage"
   fi
   rm -f "$(.)_TmpImage"

   # Relocate the files placed in (.)_TmpHoldDir into (+)_BuildDir/image/usr/local/$(+)_Executable
   sudo mv "$(.)_TmpHoldDir" "$(+)_BuildDir/image/usr/local/$(+)_Executable"
   sudo chmod a+rx "$(+)_BuildDir/image/usr/local/$(+)_Executable"

   # Create external bin directory
   cd "$(+)_BuildDir"
   mkdir 'bin'

   # Copy the start executable
   local BuildResourceDir
   :function_path -v BuildResourceDir -s /_build (@):::build

   cp -p "$BuildResourceDir/bin/start" bin/.

   # Create a link to $(+)_Executable in $(+)_BuildDir/image/usr/local/bin
   cd "$(+)_BuildDir/image/usr/local/bin"
   sudo ln -s "$(sudo realpath --relative-to=. "$(+)_BuildDir/image/usr/local/$(+)_Executable/bin/$(+)_Executable")" .

   echo
}
