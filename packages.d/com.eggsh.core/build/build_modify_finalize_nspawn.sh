#!/bin/bash
################################################################
#  Copyright © 2014-2017 by SAS Institute Inc., Cary, NC, USA  #
#  All Rights Reserved.                                        #
################################################################

@ __build_modify_finalize_nspawn()
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

   :highlight <<<"<h2>### Modifications: finalize nspawn...</h2>"

   # Get the executable name
   local Executable="${(@)_BuildInfo['.executable']}"

   # Fix the ownership and access permissions
   sudo chown -R \
      --reference "$AssembleDir/image/home/$Executable" \
      "$AssembleDir/image/usr/local/$Executable"        \
      "$AssembleDir/image/home/$Executable"

   echo
}
