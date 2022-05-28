#!/bin/bash
################################################################
#  Copyright © 2014-2017 by SAS Institute Inc., Cary, NC, USA  #
#  All Rights Reserved.                                        #
################################################################

@ __build_modify_precompile_nspawn()
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

   :highlight <<<"<h2>### Modifications: precompile nspawn...</h2>"

   local Executable="${(@)_BuildInfo['.executable']}"

   sudo systemd-nspawn -D "$AssembleDir/image" runuser -l "$Executable" -c "$Executable -r" >/dev/null 2>&1

   echo
}
