#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:archive__INFO() { echo 'Copy or move the paths provided to the archive path'; }
:archive__HELP()
{
   :man "
OPTIONS:
   -d|--delete             ^Delete source path after archiving
   -f|--force              ^Archive even if previously archived
   -p|--prefix <prefix>    ^Archive prefix dir [default: root=/orig, otherwise $HOME/.orig]
   -v|--verbose            ^Indicate actions taken

DESCRIPTION:
   Copy or move the files or directories provided to the archive directory.

   Late expansion is supported and includes exported variable expansion and
   wildcard expansion. This typically happens within quoted strings.

EXAMPLES:
   cd /etc/httpd/conf
   $__ :archive httpd.conf      ^USER=root: Copy file to /orig/etc/httpd/conf/httpd.conf
   $__ :archive -dov ~/README.txt 
                                          ^Non-root: Move file to ~/.orig/README.txt
   D=~/data  # assume a.json and b.json exist
   $__ :archive '$D/*.json'     ^Non-root: Late expansion: copy a.json and b.json to ~/.orig/data
"
}

:archive()
{
   local Options
   Options=$(getopt -o dfp:v -l "delete,force,prefix:,verbose" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$Options"

   local Delete=false
   local Force=false
   [[ $_WHOAMI = root ]] && local Prefix='/orig' || local Prefix="$HOME/.orig"
   local Verbose
   while true ; do
      case "$1" in
      -d|--delete)   Delete=true; shift;;
      -f|--force)    Force=true; shift;;
      -p|--prefix)   Prefix="$2"; shift 2;;
      -v|--verbose)  Verbose=true; shift;;
      --)            shift; break;;
      esac
   done

   # Set nullglob so that non-matching wildcard expansions are replaced by nothing
   :shopt_save
   shopt -s nullglob

   local -a Paths=()                      # The expanded list of arguments provided
   local PathItem                         # A single path item from $Paths
   local Src                              # The full path of a $PathItem
   local SrcDir                           # The directory in which $PathItem exists
   local SrcItem                          # The basename of $Src
   local Dst                              # The full path of the location to move the $PathItem
   local DstExists                        # true if $Dst exists prior to archive
   local DstDir                           # The directory in which $PathItem will be copied/moved
   local DstItem                          # The basename of $Dst
   local PerformedArchiving=1             # 0 if paths were moved; otherwise, 1

   for Paths in "$@"; do
      # Allow wildcards to expand
      Paths=( $(envsubst <<<"$Paths") )

      for PathItem in "${Paths[@]}"; do
         Src="$(readlink -f "$PathItem")"

         if [[ -e $Src ]]; then
            Dst="$Prefix$Src"

            [[ -e $Dst ]] && DstExists=true || DstExists=false

            if $DstExists && ! $Force; then
               ! $Verbose || echo "Not archived because archive exists: $Dst"
            else
               SrcDir="$(dirname "$Src")"
               SrcItem="$(basename "$Src")"
               DstDir="$(dirname "$Dst")"
               DstItem="$(basename "$Dst")"

               mkdir -p "$DstDir"

               # Perform local overlay copy
               # Note: in the future, other methods can be implemented (e.g., rsync)
               # that would allow for copying to remote servers.
               (cd "$SrcDir"; tar cpf - "$SrcItem") |
               (cd "$DstDir"; tar xpf -)

               if $Delete; then
                  ! $Verbose || echo "Archived with deletion: $Src"
                  rm -rf "$Src"
               elif $DstExists; then
                  ! $Verbose || echo "Archived with overwrite: $Src"
               else
                  ! $Verbose || echo "Archived: $Src"
               fi

               PerformedArchiving=0
            fi
         elif $Verbose; then
            echo "No such path: $Dst"
         fi
      done
   done

   :shopt_restore

   return $PerformedArchiving
}
