#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ :build,ReadSpec()
{
   local SpecificationFile="$1"
   local -a (.)_Packages=()
   local (.)_Package

   # Create the :JSON object to store the specification file content
   :new :JSON (@)_BuildSpec

   # Set :JSON options
   $(@)_BuildSpec:option +envsubst
   + option +raw

   # Create auxiliary data store for build information
   unset (@)_BuildInfo
   local -gA (@)_BuildInfo

   # Set :JSON properties
   + property error.suffix   "File:     ^$SpecificationFile"
   + property save.type      associative   # associative, positional, string, none
   + property save.var       (@)_BuildInfo

   :try {
      # If a file is present, then read it
      if [[ -n $SpecificationFile ]] ; then
         + readfile "$SpecificationFile"
      fi

      (@)_BuildInfo[.spec]="${!(@)_BuildSpec}"

      # Basic properties
      + select .executable      -d "$__"
      + select .releasedir      -d "$HOME"
      + select .appliance       -d false

      # AMP: Assemble, Modify, Package
      + select .assemble        -d '[ "'"$_corePackage"'" ]' --type=array
      + select .modify          -d '[ ]'

      + select .package.type    -d 'none' --match 'none|bin|tgz|rpm'
      case "${(@)_BuildInfo['.package.type']}" in
      bin)
         + select .package.extract_method -d 'full' --match 'full|addon|patch'
         ;;
      *)
         ;;
      esac

      # Extraction type: determines which self-extracting installer to use
      + select .extract         -d 'full' --match 'full|addon|patch'

      + select .dateformat      -d '%Y-%m-%d.%H%M%S'
      + select .git.project_dir -d '' 

      # Get the list of packages to be included in the build
      readarray -t (.)_Packages <<<"$(jq -r '.[]' <<<"${(@)_BuildInfo[.assemble]}")"

      # Read the options for each package
      local (.)_Problems=
      local -a (.)_SpecInclude=()

      for (.)_Package in "${(.)_Packages[@]}"; do
         # If a package name resolves to the empty string, skip it
         [[ -n $(.)_Package ]] || continue

         # Check to see that the package is actually available to the build process
         if [[ -n ${_packageDirs["$(.)_Package"]} ]]; then

            # Skip over duplicate packages
            if [[ ! " ${(.)_SpecInclude[@]} " =~ " $(.)_Package " ]] ; then
               # Mark this package as processed
               (.)_SpecInclude+=( "$(.)_Package" )

               # Read external-resources specification for the package
               + select ".packages.\"$(.)_Package\".external" -d ''

               # Read git access information for the package
               + select ".packages.\"$(.)_Package\".git.clone"
               + select ".packages.\"$(.)_Package\".git.revision"
               + select ".packages.\"$(.)_Package\".git.push"     -d 'false'
            fi

         # Otherwise, report an error for unrecognized packages
         else
            [[ -z $(.)_Problems ]] || (.)_Problems+='\n'
            (.)_Problems+="Problem:  ^No such package: $(.)_Package"
         fi
      done
      if [[ -n $(.)_Problems ]] ; then
         + property error.text "$(.)_Problems"
         $(exit 1)
      fi

      # Store important package info
      (@)_BuildInfo['assemble']="${(.)_SpecInclude[@]}"
      (@)_BuildInfo['primary']="${(.)_SpecInclude[0]}"

      # Create date strings
      local Date="$(date)"
      (@)_BuildInfo['date']="$(date -d "$Date" +"${(@)_BuildInfo[.dateformat]}")"
      (@)_BuildInfo['manifest_date']="$(date -d "$Date" +%Y-%m-%d.%H%M%S)"
   } :catch {
      if [[ $(+ property error.stack) != true ]] ; then
            local (.)_Text="
$_RED$_UNDERLINE[ERROR] :build EXCEPTION $_tryStatus CAUGHT ON LINE $_tryErrorLine$_NORMAL

$(+ property error.text)
$(::stacktrace 0)"

         + property error.text "$(.)_Text"
      fi

      $(@)_BuildSpec:property --color error.text
      return $_tryStatus
   }

   return 0
}
