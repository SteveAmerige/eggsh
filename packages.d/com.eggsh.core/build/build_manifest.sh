#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:build_manifest()
{
   local -r OPTIONS=$(getopt -o b:s:m: -l "basedir:,subdir:,manifestname:,verbose,version:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local BaseDirectory="$(readlink -f '.')"
   local -a Subdirectories=()
   local Directory
   local ManifestName='manifest.json'
   local Verbose=false
   local VersionFile=

   while true ; do
      case "$1" in
      -b|--basedir)
         BaseDirectory="$2"
         if [[ ! -d $BaseDirectory ]]; then
            echo "No such directory: $BaseDirectory"
            return 1
         fi
         if [[ ${#Subdirectories[@]} -gt 0 ]]; then
            echo "Subdirectories must be specified after -b"
            return 1
         fi
         cd "$BaseDirectory"
         shift 2
         ;;
      -s|--subdir)
         Directory="$2"
         if [[ -d $Directory ]]; then
            Subdirectories+=( "$Directory" )
            shift 2
         else
            echo "No such directory: $Directory"
            return 1
         fi
         shift 2
         ;;
      -m)
         ManifestName="$2"
         if [[ $ManifestName =~ / ]]; then
            echo 'The manifest filename may not contain "/" (directory separator)'
            return 1
         fi
         if [[ ! $ManifestName =~ '.json'$ ]]; then
            echo 'The manifest filename must end with .json'
            return 1
         fi
         shift 2
         ;;
      --verbose)
         Verbose=true
         shift
         ;;
      --version)
         VersionFile="$(readlink -f "$2")"
         if [[ ! -f $VersionFile ]]; then
            echo "No such version file: $VersionFile"
            return 1
         fi
         shift 2
         ;;
      --)   shift; break;;
      esac
   done

   ! [[ $Verbose = false ]] || :highlight <<<"<b>--- Creating manifest: $BaseDirectory/$ManifestName</b>"
   cd "$BaseDirectory"

   if [[ ${#Subdirectories[@]} -eq 0 ]]; then
      Subdirectories+=( '.' )
   fi

   local NoMD5Sum='0'
   local Filename MD5Sum

   {
   # Emit version header
   cat <<EOF
{
"version": $(
   if [[ -n $VersionFile ]]; then
      cat "$VersionFile"
      echo ','
   else
      cat <<VERSION
         {
            "date": "${(@)_BuildInfo['manifest_date']}"
         },
VERSION
   fi
)
"filenames":
   {
EOF

   local -a Filenames
   local -i I=0
   local Mode User Group LastModified FileType
   for Directory in "${Subdirectories[@]}"; do
      Filenames=()
      readarray -t Filenames <<<"$(find "$Directory")"
      for ((I=0; I<${#Filenames[@]}; I++)); do
         Filename="${Filenames[I]}"
         [[ $Filename != '.' ]] || continue

         Filename="$(sed "s#^\./##" <<<"$Filename")"
         if [[ -f $Filename ]]; then
            MD5Sum="$(md5sum "$Filename" | sed 's|\s.*||')"
         elif [ -e $Filename ] ; then
            MD5Sum="$NoMD5Sum"
         else
            MD5Sum="ERROR"
         fi  

         Mode="$(stat -c '%a' "$Filename")"
         User="$(stat -c '%u' "$Filename")"
         Group="$(stat -c '%g' "$Filename")"
         LastModified="$(date -d @"$(stat -c '%Y' "$Filename")" +"%Y-%m-%d.%H%M%S")"
         FileType="$(stat -c '%F' "$Filename")"

         cat <<FILEBLOCK
            "$Filename":
            {
               "filetype": "$FileType",
               "mode": "$Mode",
               "user": "$User",
               "group": "$Group",
               "last_modified": "$LastModified",
               "md5sum": "$MD5Sum"
            }
FILEBLOCK

         if (($I < ${#Filenames[@]} - 1)); then
            echo ','
         fi
      done
   done

   cat <<EOF
   }
}
EOF
   } | jq -rS . > "$BaseDirectory/$ManifestName"
}
