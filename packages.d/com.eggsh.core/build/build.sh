#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ :build__INFO() { echo "Build a product from either a source or a release distribution"; }
@ :build__HELP()
{
   :man -a "<specification>" "

DESCRIPTION:
   Build a release distribution.

   A JSON <specification> file must be provided.

EXAMPLES:
   $_productName :build specification.json : Build according to the specification.json file"
}

@ :build()
{
   # Ensure a specification file exists
   local SpecificationFile="$1"
   [[ -f $SpecificationFile ]] || { echo "No specification file was provided: no action taken."; return 1; }

   ##### PREPARE TO BUILD
   # Read the specification file into the associative array: (@)_BuildInfo
   # This is used both by the core build functions as well as by individual packages's make.sh.
   # Those packages will use the idiom (@:)_BuildInfo to access this variable.
   (@):::build,ReadSpec "$SpecificationFile"
   [[ $? -eq 0 ]] || return

   # TODO: Clone source files
   #(@):::build,GitClone
   #[[ $? -eq 0 ]] || return

   # Read Version information from all packages into the associative array: (+)_Version
   # This variable is not available to individual package make.sh functions.
   # Update the version.json files if the specification file says to do so
   (@):::build,GetAndUpdateVersion
   [[ $? -eq 0 ]] || return

   ##### BUILD
   # Trap on exit
   trap :build,Quit EXIT

   # Ensure destination directory exists
   local (+)_DestDir="${(@)_BuildInfo['.releasedir']}"
   mkdir -p "$(+)_DestDir" ||
      { echo "The releasedir does not exist or could not be created: $(+)_DestDir"; return 1; }

   # Create temporary build directory
   local (+)_BuildDir="$(mktemp -d -p "$(+)_DestDir" .bld.XXXXXXXXXX)"

   # The executable name
   local (+)_Executable="${(@)_BuildInfo['.executable']}"

   :highlight <<<'\n<h2>### Build Specification and Package Versions</h2>\n'
   :highlight <<<'<green>Specification:</green>'
   :dump_associative_array (@)_BuildInfo

   :highlight <<<'\n<green>Package Versions:</green>'
   :dump_associative_array (+)_Version
   echo

   ### AMP: Assemble, Modify, and Package
   # Assemble all package files into (+)_BuildDir
   (@):::build,Assemble
   [[ $? -eq 0 ]] || return

   # Modify the assembled contents
   (@):::build,Modify
   [[ $? -eq 0 ]] || return

   # Package the assembled and modified contents
   (@):::build,Package
   [[ $? -eq 0 ]] || return

   ##### POST-BUILD
   # After the product has been built, update Git repos as directed by the spec file
   :build,UpdateGit
   [[ $? -eq 0 ]] || return
}

:build,Quit()
{
   # Cleanup
   [[ ! -d $(+)_BuildDir ]] || rm -rf "$(+)_BuildDir"
}
