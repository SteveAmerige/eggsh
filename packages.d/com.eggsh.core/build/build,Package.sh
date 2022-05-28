#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ :build,Package()
{
   local PackageType="${(@)_BuildInfo['.package.type']}"
   if :function_exists "(@):::build,Package_$PackageType"; then
      "(@):::build,Package_$PackageType"
   else
      "(@):::build,Package_none"
   fi
}

@ :build,Package_bin()
{
   :highlight <<<"<h2>### Packaging Files into a bin installer...</h2>"

   local Installer="${(@)_BuildInfo['.package.extract_method']}"
   local PrimaryPackage="${(@)_BuildInfo['primary']}"
   local BuildResourceDir
   :function_path -v BuildResourceDir -s /_build (@):::build
   local (.)_TmpBinInstaller="$(mktemp -p "$(+)_DestDir" .tmp.XXXXXXXXXX)"

   LC_ALL=C sed \
         -e "s|%{DEFAULT_EXECUTABLE}%|$(+)_Executable|g" \
         -e "s|%{PRIMARY_PACKAGE}%|$PrimaryPackage|g" \
         -e "s|%{TO_VERSION}%|${(@)_BuildInfo[version.long]}|g" \
         -e "s|%{TO_SHORT_VERSION}%|${(@)_BuildInfo[version.short]}|g" \
         -e "s|%{TO_VERSION_MAJOR}%|${(+)_Version[$PrimaryPackage.version.major]}|g" \
         -e "s|%{TO_VERSION_MINOR}%|${(+)_Version[$PrimaryPackage.version.minor]}|g" \
         -e "s|%{TO_VERSION_PATCH}%|${(+)_Version[$PrimaryPackage.version.patch]}|g" \
         -e "s|%{TO_VERSION_FIX}%|${(+)_Version[$PrimaryPackage.version.fix]}|g" \
         -e "s|%{TO_VERSION_COPY}%|${(+)_Version[$PrimaryPackage.version.copy]}|g" \
      < "$BuildResourceDir/bin/$Installer.sh" \
      > "$(.)_TmpBinInstaller"

   cd "$(+)_BuildDir"
   if hash pv 2>/dev/null ; then
      Size="$(sudo du -cbs * | tail -1 | awk '{print $1}')"

      sudo tar --numeric-owner --format=pax -cpf - * | sudo pv -s "$Size" >> "$(.)_TmpBinInstaller"
   else
      sudo tar --numeric-owner --format=pax -cpf - * >> "$(.)_TmpBinInstaller"
   fi

   local DateFormat="${(@)_BuildInfo['.dateformat']}"
   local Date=
   if [[ -n $DateFormat ]]; then
      Date="-$(date -r "$(.)_TmpBinInstaller" "+$DateFormat")"
   fi
   local BinInstallerDest="$(+)_DestDir/$(+)_Executable$Date-${(@)_BuildInfo[version.long]}.bin"
   sudo mv "$(.)_TmpBinInstaller" "$BinInstallerDest"
   sudo chmod a+rx "$BinInstallerDest"

   :highlight <<<"\n<blue>Created bin installer: $BinInstallerDest</blue>"

   # Cleanup
   sudo rm -rf "$(+)_BuildDir" >/dev/null 2>&1 &
}

@ :build,Package_none()
{
   (
      cd "$(+)_BuildDir"
      sudo tar --numeric-owner --format=pax -cpf - .
   ) |
   (
      cd "$(+)_DestDir"
      sudo tar --numeric-owner --format=pax -xpf -
   )

   # Cleanup
   sudo rm -rf "$(+)_BuildDir" >/dev/null 2>&1 &
}
