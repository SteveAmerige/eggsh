#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:build,UpdateGit()
{
   local Package
   for Package in ${(@)_BuildInfo['assemble']}; do
      if [[ ${(@)_BuildInfo[".packages.\"$Package\".git.push"]} = true ]]; then
         :build,PushVersionChangesToGit "$Package"
      fi
   done
}

:build,PushVersionChangesToGit()
{
   :command_exists git || return

   local Package="$1"
   local VersionString=

   for Part in major minor patch build copy; do
      VersionString+="${(+)_Version[$Package.version.$Part]}."
   done
   VersionString="${VersionString::-1}"

   cd "${_packageDirs[$Package]}"
   git rev-parse --show-toplevel >/dev/null 2>&1 || return
   Remote="${(@)_BuildInfo[.packages.\"$Package\".git.remote]}"
   :highlight <<<"<h2>### Updating git for Package $Package...</h2>"
   echo "GIT: $VersionString to $Remote from $(pwd)"

   git pull
   git add version.json
   if [[ -f manifest.json ]]; then
      git add manifest.json
   fi
   git commit -m "[release] $Package v$VersionString on ${(@)_BuildInfo['manifest_date']}"
   git push $Remote

   echo
}

:build,DumpSpec()
{
   echo "================================================== SPECIFICATION:"
   jq -cr . <<<"${!(@)_BuildSpec}"
   for Key in $(printf "%s\n" "${!(@)_BuildInfo[@]}" | LC_ALL=C sort -u | tr '\n' ' '); do
      echo "$Key: ${(@)_BuildInfo[$Key]}"
   done
   echo
}

:build,DumpVersion()
{
   echo "================================================== VERSION:"
   jq -cr . <<<"${!(+)_VersionJSON}"
   for Key in $(printf "%s\n" "${!(+)_Version[@]}" | LC_ALL=C sort -u | tr '\n' ' '); do
      echo "$Key: ${(+)_Version[$Key]}"
   done
   echo
}
