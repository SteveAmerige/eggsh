#!/bin/bash
################################################################
#  Copyright © 2014-2017 by SAS Institute Inc., Cary, NC, USA  #
#  All Rights Reserved.                                        #
################################################################

@ __build_modify_remove_percent_paths()
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

   :highlight <<<"<h2>### Modifications: remove percent paths...</h2>"

   local Executable="${(@)_BuildInfo['.executable']}"

   if [[ -d $AssembleDir/image ]]; then
      cd "$AssembleDir/image/usr/local/$Executable/$_PACKAGES_DIR"
   else
      cd "$AssembleDir/$_PACKAGES_DIR"
   fi

   # Remove any files or directories beginning with a % character
   local -a PercentPaths
   readarray -t PercentPaths < <(
      find . -name '%*' -prune
   )

   sudo rm -rf "${PercentPaths[@]}"

   echo
}
