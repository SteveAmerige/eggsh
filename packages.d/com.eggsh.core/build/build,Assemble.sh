#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ :build,Assemble()
{
   # Assemble files
   :try
   {
      # Copy package content into the (+)_BuildDir via package-specific __build_assemble calls
      local SourceDir AssemblePackage

      for Package in ${(@)_BuildInfo['assemble']}; do
         # Determine which __build_assemble to call. Use the core function if not available in the Package.
         if :function_exists -p "$Package" __build_assemble ; then
            AssemblePackage="$Package" 
         else
            AssemblePackage="$_corePackage"
         fi
         SourceDir="$(readlink -f "${_packageDirs[$Package]}/../..")"

         # Call the __build_assemble for the Package
         :highlight <<<"<green>### Assembling $Package...</green>\n"
         @ -p $AssemblePackage __build_assemble --assembledir "$(+)_BuildDir" --sourcedir "$SourceDir"
      done

      # Remove any make.sh other than the core make.sh that performs simple package copying into the build dir
      cd "$(+)_BuildDir"
      local Item
      for Item in "$_PACKAGES_DIR"/*/make.sh "$_PACKAGES_DIR"/*/_external; do
         if [[ -e $Item ]]; then
            rm -rf "$Item"
         fi
      done
   }
   :catch
   {
      if [[ $($(@)_BuildSpec:property error.stack) != true ]] ; then
            echo "
$_RED$_UNDERLINE[ERROR] :build EXCEPTION $_tryStatus CAUGHT ON LINE $_tryErrorLine$_NORMAL

$($(@)_BuildSpec:property error.text)
$(::stacktrace 0)"

      fi

      return $_tryStatus
   }

   return 0
}
