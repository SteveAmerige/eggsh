#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ :build,GetAndUpdateVersion()
{
   # Create the :JSON object to store the version file content
   :new :JSON (+)_VersionJSON

   # Create auxiliary data store for build information
   unset (+)_Version
   local -gA (+)_Version

   # For each package, read/update the version file
   local (-)_Package
   for (-)_Package in ${(@)_BuildInfo['assemble']}; do
      # Read the version file
      (@):::build,ReadVersionInfo "$(-)_Package"
      [[ $_tryStatus -eq 0 ]] || return

      # If the specification enable git updating, then perform the git update
      if [[ ${(@)_BuildInfo[".packages.\"$(-)_Package\".git.push"]} = true ]] ; then
         (@):::build,UpdateVersionInfo "$(-)_Package"
      fi
   done

   local Part ShortVersionString
   local PrimaryPackage="${(@)_BuildInfo['primary']}"
   local VersionString=

   for Part in major minor patch fix; do
      VersionString+="${(+)_Version[$PrimaryPackage.version.$Part]}."
   done
   ShortVersionString="${VersionString::-1}"

   for Part in build copy; do
      VersionString+="${(+)_Version[$PrimaryPackage.version.$Part]}."
   done
   VersionString="${VersionString::-1}"

   (@)_BuildInfo['version.long']="$VersionString"
   (@)_BuildInfo['version.short']="$ShortVersionString"

   return 0
}

@ :build,ReadVersionInfo()
{
   local (-)_VersionFile="${_packageDirs["$(-)_Package"]}/version.json"

   # Set :JSON options
   $(+)_VersionJSON:option    +raw

   # Set :JSON properties
   + property error.suffix    "File:     ^$(-)_VersionFile"
   + property save.type       associative
   + property save.var        (+)_Version
   + property save.prefix     "$(-)_Package"

   # Set custom :JSON properties
   + property save.file       "$(-)_VersionFile"

   :try {
      :persist $(+)_VersionJSON ${(+)_VersionJSON}_info

      # A version file must exist; if it does not exist then create it
      if [[ ! -f $(-)_VersionFile ]]; then

         # Create a default version file and throw an error if it is not possible
         if ! jq . <<<'{"name":"'"$(-)_Package package"'", "date":"", "version":{}}' > "$(-)_VersionFile" 2>/dev/null; then
            + property error.text "Problem:  ^Could not write to: $(-)_VersionFile"
            $(exit 1)
         fi
      fi

      # Now, read the version file
      + readfile "$(-)_VersionFile"

      + select .name
      + select .tags -d '[]' --type=array --tostring
      + select .version.major -d 0
      + select .version.minor -d 0
      + select .version.patch -d 0
      + select .version.fix   -d 0
      + select .version.build -d 0
      + select .version.copy  -d 0
      + select .date -d ''
   } :catch {
      if [[ $(+ property error.stack) != true ]] ; then
            Text="
$_RED$_UNDERLINE[ERROR] :build EXCEPTION $_tryStatus CAUGHT ON LINE $_tryErrorLine$_NORMAL

$(+ property error.text)
$(::stacktrace 0)"

         + property error.text "$Text"
      fi

      $Version:property --color error.text
      return $_tryStatus
   }
}

@ :build,UpdateVersionInfo()
{
   local Build Copy

   if [[ $_distributionType = source ]]; then
      Build=$((++(+)_Version["$(-)_Package.version.build"]))
      $(+)_VersionJSON:update .version.build "$Build"
   else
      Copy=$((++(+)_Version["$(-)_Package.version.copy"]))
      $(+)_VersionJSON:update .version.build "$Copy"
   fi

   (+)_Version["$(-)_Package".date]="${(@)_BuildInfo['date']}"
   $(+)_VersionJSON:update .date "\"${(@)_BuildInfo['date']}\""

   (-)_VersionFile="$($(+)_VersionJSON:property save.file)"
   rm -f "$(-)_VersionFile"
   jq . <<<"${!(+)_VersionJSON}" > "$(-)_VersionFile"
}
