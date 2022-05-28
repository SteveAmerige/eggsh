#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ __build_modify_create_manifest()
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

   :highlight <<<"<h2>### Modifications: create manifest...</h2>"

   # Create the manifest file for all packages
   :new :JSON (.)_AssembleManifest = '{}'
   local Package
   for Package in ${(@)_BuildInfo['assemble']}; do
      if [[ ${(@)_BuildInfo[".packages.\"$Package\".git.push"]} = true ]]; then
         local ManifestOptions=(
            '-b' "${_packageDirs[$Package]}"
            '--verbose'
         )
         if [[ -f ${_packageDirs[$Package]}/version.json ]]; then
            ManifestOptions+=( '--version' "${_packageDirs[$Package]}/version.json" )
         fi

         # Build the manifest for this package
         :build_manifest "${ManifestOptions[@]}"

         # Add this manifest to the top-level combined manifest
         local PackagePath="${_packageDirs[$Package]}"
         $(.)_AssembleManifest:join -p "$Package" -f "${_packageDirs[$Package]}/manifest.json"

         local Component="$(+)_BuildDir/${PackagePath##$(readlink -f "$PackagePath/../..")/}" 
      fi
   done

   if [[ ${(@)_BuildInfo[".package.extract_method"]} = full ]]; then
      $(.)_AssembleManifest:dump > "$(+)_BuildDir/manifest.json"
   fi

   echo
}
