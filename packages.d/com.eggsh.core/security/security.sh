#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:sudo_available()
{
   sudo -n true >/dev/null 2>&1
}

:sudo()
{
   local -r OPTIONS=$(getopt -o d:flns:u: -l "directory:,login,needed,shell:,user:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Directory=""
   local Login=""
   local OnlyCheckIfNeeded=false
   local Shell=""
   local User=""
   while true ; do
      case "$1" in
      -d|--directory)
         Directory="$2"
         shift 2;;
      -l|--login)
         Login="-l"
         shift;;
      -n|--needed)
         OnlyCheckIfNeeded=true
         shift;;
      -s|--shell)
         Shell="$2"
         shift 2;;
      -u|--user)
         User="$2"
         shift 2;;
      --)
         shift
         break;;
      esac
   done

   if [[ -n $User ]] ; then
      # Disallow specifying both -d and -u
      [[ -z $Directory ]] || { echo "Cannot specify both -d and -u" >&2; return 1; }

      # Ensure specified user exists
      getent passwd "$User" >/dev/null 2>&1 || { echo "No such user: $User" >&2; return 1; }
   else
      # Disallow specifying both -d and -u
      [[ -z $User ]] || { echo "Cannot specify both -d and -u" >&2; return 1; }

      # If directory is not explicitly stated, then assume $_releaseDir; Assert directory exists.
      if [[ -n $Directory ]] ; then
         if [[ -d $Directory ]] ; then
            # Get the username from the directory ownership info; Assert username exists.
            User=$(stat -c %U "$Directory")
            getent passwd "$User" >/dev/null 2>&1 || { echo "Cannot determine username from directory: $Directory" >&2; return 1; }
         else
            echo "Directory does not exist: $Directory" >&2
            return 1
         fi
      else
         User=root
      fi

   fi

   # If a shell is requested, then check that it is allowed.
   if [[ -n $Shell ]] ; then
      grep -q "^$Shell$" /etc/shells || { echo "Specified shell is not listed in /etc/shells" >&2; return 1; }
      Shell="-s $Shell"
   fi

   # Check to see if there is, in fact, a need to use sudo runuser
   if [[ $User = $_WHOAMI ]] ; then
      if $OnlyCheckIfNeeded; then
         return 1
      fi
      "$@"
   else
      :sudo_available || { echo "Sudo access is not available for running: $*" >&2; return 1; }
      if $OnlyCheckIfNeeded; then
          _sudoUser="$User"
          return 0
       fi

      sudo runuser $Shell $Login -u "$User" -- "$@"
   fi
}

:sudo_needed_for_path()
{
   local -r OPTIONS=$(getopt -o d:f:v: -l "dir:,file:,variable:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Dir=false
   local File=false
   local Path=
   local Var=

   while true ; do
      case "$1" in
      -d|--dir)      Dir=true; Path="$2"; shift 2;;
      -f|--file)     File=true; Path="$2"; shift 2;;
      -v|--variable) Var="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   $Dir && $File && { echo "Only one of -d or -f may be used"; return 1; }
   $Dir || $File || { echo "One of -d or -f must be used"; return 1; }

   # Convert to absolute path
   Path="$(readlink -m "$Path")"
   :sudo_needed_for_path,Stat "$Var" "$Path" && return

   $Dir &&
      { DirPath="$Path"; FilePath=; } ||
      { DirPath="$(dirname "$Path")"; FilePath="$(basename "$Path")"; }

   # Find the first existing directory at or above $DirPath
   local SearchPath="$DirPath"
   while [[ ! -d $SearchPath ]] ; do
      SearchPath="$(dirname "$SearchPath")"
   done

   :sudo_needed_for_path,Stat "$Var" "$SearchPath"
}

# Returns 0 if path exists and sets -v <var> to one of "", "sudo", or "sudo -u <username>".
# Returns 1 if path does not exist
:sudo_needed_for_path,Stat()
{
   local Var="$1"
   local Path="$2"

   # If the path doesn't exist, then just return 1
   [[ -e $Path ]] || return 1

   # The path does exist: get its ownership
   PathOwnership="$(stat -c %U "$Path")"

   # Determine what kind of sudo command is needed
   [[ $_WHOAMI = $PathOwnership ]] &&
      SudoCommand="" ||
      { [[ $PathOwnership = root ]] && SudoCommand="sudo" || SudoCommand="sudo -u $PathOwnership"; }

   printf -v "$Var" "%s" "$SudoCommand"
}
