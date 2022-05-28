#!/bin/bash

::help()
{
   echo "
OPTIONS:
   -d|--directory <dir>    Specify the installation directory [default: $HOME]
   -e|--executable <name>  Build with the executable named <name> [default: $_defaultExecutable]
   -s|--skipversioncheck   Skip the version check

                           WARNING: Use this option ONLY if you are absolutely sure
                           that your operating system meets installation requirements.
                           This option is present to future-proof this installer for
                           operating system releases that do not follow version numbering
                           standards that were in place when this installer was made.

   --update                Perform an update installation

   --split                 Split the bin installer into parts: install.sh and install.tar
                           These files are placed under the directory: <dir>/<name>/.split
   --use-split             Install using <dir>/<name>/.split/install.sh

   -x                      Turn on Bash debugging

   -h|--help               Show this help

DESCRIPTION:
   Extract the archive to <dir>/<name>, by default:
   
      $HOME/$_defaultExecutable

   If the --update option is given, then the above directory is updated with new software."
   exit 0
}

::getopt()
{
   # Set variables indicating how this script was called
   local -gr _program="$(readlink -f "${BASH_SOURCE[0]}")"
   local -gr __=$(basename "$_program")
   local -gr _invocationDir="$(readlink -f .)"

   # Some global variables
   local -gr _BOLD="$(tput bold)"
   local -gr _NORM="$(tput sgr0)"
   local -gr _NBLD="$_NORM$_BOLD"
   local -gr _BLUE="$_BOLD$(tput setaf 4)"
   local -gr _RED="$_BOLD$(tput setaf 1)"

   # This token will be replaced with the build specification executable
   local -gr _defaultExecutable="%{DEFAULT_EXECUTABLE}%"

   # Process options
   local Options
   Options=$(getopt -o d:he:sx -l "directory:,help,executable:,skipversioncheck,split,use-split,update" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$Options"

   local -g _installDir="$HOME"
   local -g _executable="$_defaultExecutable"
   local -g _performVersionCheck=true
   local -g _create_split=false
   local -g _use_split=false
   local -g _update=false
   local -ga PassArgs=()
   local -g Debug=false

   while true ; do
      case "$1" in
      -d|--directory)
            _installDir="$2"
            if [[ ! -d $_installDir ]]; then
               echo "Destination directory does not exist: $_installDir"
               return 1
            fi
            _installDir="$(readlink -f "$2")"
            PassArgs+=('-d' "$_installDir")
            shift 2;;

      -h|--help)
            ::help
            shift;;

      -e|--executable)
            _executable="$2"
            if [[ ! $_executable =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
               echo "The executable must be a simple word"
               return 1
            fi
            PassArgs+=('-e' "$_executable")
            shift 2;;

      -s|--skipversioncheck)
            _performVersionCheck=false
            PassArgs+=('--skipversioncheck')
            shift;;

      -x)   PassArgs+=('-x')
            Debug=true
            shift;;

      --split)
            _create_split=true
            shift;;

      --use-split)
            _use_split=true
            shift;;

      --update)
            _update=true
            PassArgs+=('--update')
            shift;;

      --)
            shift
            break;;
      esac
   done
}

::init()
{
   if $Debug; then
      set -x
   fi

   # The installation directory
   local -g _installExeDir="$_installDir/$_executable"
   local -g _splitDir="$_installExeDir/.split"

   # If an image file is provided (as was created using --split), then verify it exists
   if $_use_split; then
      if [[ -f $_splitDir/install.sh && -f $_splitDir/install.tar ]]; then
         bash "$_splitDir/install.sh" "${PassArgs[@]}" "$_splitDir/install.tar"
         exit
      fi
   fi

   # Check if requesting splitting the image
   if $_create_split; then
      echo "Splitting..."

      mkdir -p "$_splitDir" || return
      chown --reference="$_installDir" "$_installExeDir" || return
      chown --reference="$_installDir" -R "$_splitDir" || return
      cd "$_splitDir"

      # Ensure the split artifacts do not already exist
      rm -f install.sh install.tar

      # The file install.sh is too small to show a progress bar
      LC_ALL=C sed -n '/^__ARCHIVE_BELOW__/q;p' < "$_program" > "install.sh"

      # Split out the install.tar file
      if hash pv 2>/dev/null ; then
         local Size=$(du -cbs "$_program" | tail -1 | awk '{print $1}')
         LC_ALL=C sed '1,/^__ARCHIVE_BELOW__/d' < "$_program" | pv -s $Size > "install.tar"
      else
         LC_ALL=C sed '1,/^__ARCHIVE_BELOW__/d' < "$_program" > "install.tar"
      fi

      # Fix ownership
      chown --reference="$_installDir" install.sh install.tar

      exit 0
   fi

   # If called internally, then this is the location of the image file
   local -g _image="$1"

   # If updating, then an installation directory must exist
   if $_update; then
      if [[ ! -d $_installExeDir ]]; then
         echo "Nothing to update found, expecting: $_installExeDir"
         return 1
      fi

   # If not updating, then an installation directory must not exist
   elif [[ -e $_installExeDir ]]; then
      echo "Installation already exists: $_installExeDir"
      return 1
   fi
}

::checkversion()
{
   local Version Major Minor Patch
   # Take uname -r and ignore everything after <Version>.<MajorRevision>.<MinorRevision>-<Patch>
   # and then store into separate variables.
   # See: http://www.linfo.org/kernel_version_numbering.html
   IFS=. read Version Major Minor Patch < <(uname -r | LC_ALL=C sed -e 's|\(.*-[0-9]*\).*|\1|' -e 's|-|.|')

   # Regular expression for a number
   local Number='^[0-9]+$'

   # All version components must be numbers
   [[ $Version =~ $Number && $Major =~ $Number && $Minor =~ $Number && $Patch =~ $Number ]] ||
      { echo "Operating system kernel numbering is not numeric: $(uname -r)"; return 1; }

   # CentOS 7.2 or later is required. The <Patch> number corresponds to the CentOS 7.x release number
   #     CentOS 7.2  3.10.0-327
   #     CentOS 7.3  3.10.0-514
   #     CentOS 7.4  3.10.0-693
   # https://access.redhat.com/articles/3078#RHEL7
   [[ $Version -eq 3 && $Major -eq 10 && $Minor -eq 0 && $Patch -ge 327 ]] ||
      { echo "Operating system kernel version must be at or after 3.10.0-327 (7.2)"; return 1; }

   # The only distributions supported are CentOS and Red Hat Enterprise Linux
   if [[ -f /etc/os-release ]]; then
      Name=$(grep '^NAME=' /etc/os-release | LC_ALL=C sed -e 's|^NAME=||' -e 's|"||g')
      [[ $Name = "CentOS Linux" || $Name = "Red Hat Enterprise Linux"* ]] ||
         { echo "Operating system must be CentOS or Red Hat Enterprise Linux"; return 1; }
   fi

   # Ensure the existing installation is older than what this installer would install
   if $_update; then
      ::checkversion_update || return
   fi
}

::checkversion_update()
{
   # If updating, then get the version from which the update will be processed
   local FromVersionFile
   FromVersionFile="$_installExeDir/image/usr/local/$_executable/settings.json"
   if [[ ! -f $FromVersionFile ]]; then
      FromVersionFile="$_installExeDir/image/usr/local/$_executable/packages.d/%{PRIMARY_PACKAGE}%/version.json"
      if [[ ! -f $FromVersionFile ]]; then
         echo "Could not determine the currently-installed version"
         return 1
      fi
   fi

   local FromVersionJSON
   FromVersionJSON="$(jq -r . "$FromVersionFile")"

   # Get the version information
   local -A FromVersion
   local -a Parts=(major minor patch fix)
   local Part
   for Part in "${Parts[@]}"; do
      FromVersion[.version.$Part]="$(jq -r ".version.$Part" <<<"$FromVersionJSON")"
      if [[ -z ${FromVersion[.version.$Part]} || ${FromVersion[.version.$Part]} = null ]]; then
         FromVersion[.version.$Part]='0'
      fi
   done

   # Put together a human-readable version string
   local VersionString=
   for Part in "${Parts[@]}"; do
      VersionString+="${FromVersion[.version.$Part]}."
   done
   VersionString="${VersionString::-1}"               # Take off the final dot

   # Determine if the current installation is newer than the installer
   local Error= ErrorTo ErrorFrom
   # Major greater is an error
   if [[ ${FromVersion[.version.major]} -gt %{TO_VERSION_MAJOR}% ]]; then
      Error="Major"
      ErrorTo="${_RED}%{TO_VERSION_MAJOR}%$_NBLD.%{TO_VERSION_MINOR}%.%{TO_VERSION_PATCH}%.%{TO_VERSION_FIX}%$_NORM"
      ErrorFrom="$_RED${FromVersion[.version.major]}$_NBLD.${FromVersion[.version.minor]}.${FromVersion[.version.patch]}.${FromVersion[.version.fix]}$_NORM"
   # Major equal: must next consider Minor
   elif [[ ${FromVersion[.version.major]} -eq %{TO_VERSION_MAJOR}% ]]; then 
      # Minor greater is an error
      if [[ ${FromVersion[.version.minor]} -gt %{TO_VERSION_MINOR}% ]]; then
         Error="Minor"
         ErrorTo="${_BOLD}%{TO_VERSION_MAJOR}%.${_RED}%{TO_VERSION_MINOR}%$_NBLD.%{TO_VERSION_PATCH}%.%{TO_VERSION_FIX}%$_NORM"
         ErrorFrom="$_BOLD${FromVersion[.version.major]}.$_RED${FromVersion[.version.minor]}$_NBLD.${FromVersion[.version.patch]}.${FromVersion[.version.fix]}$_NORM"
      # Minor equal: must next consider Patch
      elif [[ ${FromVersion[.version.minor]} -eq %{TO_VERSION_MINOR}% ]]; then 
         # Patch greater is an error
         if [[ ${FromVersion[.version.patch]} -gt %{TO_VERSION_PATCH}% ]]; then
            Error="Patch"
            ErrorTo="${_BOLD}%{TO_VERSION_MAJOR}%.%{TO_VERSION_MINOR}%.${_RED}%{TO_VERSION_PATCH}%$_NBLD.%{TO_VERSION_FIX}%$_NORM"
            ErrorFrom="$_BOLD${FromVersion[.version.major]}.${FromVersion[.version.minor]}.$_RED${FromVersion[.version.patch]}$_NBLD.${FromVersion[.version.fix]}$_NORM"
         # Patch equal: must next consider Fix
         elif [[ ${FromVersion[.version.patch]} -eq %{TO_VERSION_PATCH}% ]]; then
            # Fix greater is an error; Fix equal is an error (update to same version)
            if [[ ${FromVersion[.version.fix]} -ge %{TO_VERSION_FIX}% ]]; then
               Error="Fix"
               ErrorTo="${_BOLD}%{TO_VERSION_MAJOR}%.%{TO_VERSION_MINOR}%.%{TO_VERSION_PATCH}%.${_RED}%{TO_VERSION_FIX}%$_NORM"
               ErrorFrom="$_BOLD${FromVersion[.version.major]}.${FromVersion[.version.minor]}.${FromVersion[.version.patch]}.$_RED${FromVersion[.version.fix]}$_NORM"
            fi
         fi
      fi
   fi

   if [[ -n $Error ]]; then
      cat <<EOF

${_RED}Cannot update the current installation${_NORM}

                                ${_BLUE}Major.Minor.Patch.Fix$_NORM
   Currently-installed version: $ErrorFrom
   This installer's version:    $ErrorTo

${_BOLD}Note:$_NORM the currently-installed version must be older than this installer's version.
EOF
      return 1
   fi
}

::rand()
{
   # Produce a random string as <Prefix><Suffix> with simple character range rules
   local ARGS=$(getopt -o n -l "newline" -n _escape -- "$@")
   eval set -- "$ARGS"

   # Define the default simple rules
   local PrefixPattern="a-z"
   local PrefixSize=3
   local SuffixPattern="0-9"
   local SuffixSize=5

   # Allow changing the rules
   while true ; do
      case "$1" in
      -P|--prefixpattern)  PrefixPattern="$2"; shift 2;;
      -p|--prefixsize)     PrefixSize="$2"; shift 2;;
      -S|--suffixpattern)  SuffixPattern="$2"; shift 2;;
      -s|--suffixsize)     SuffixSize="$2"; shift 2;;
      --)                  shift; break;;
      esac
   done

   # Create the Prefix
   local Prefix=
   if [[ $PrefixSize -gt 0 ]]; then
      Prefix=$(tr -dc "$PrefixPattern" </dev/urandom | head -c $PrefixSize)
   fi

   # Create the Suffix
   local Suffix=
   if [[ $SuffixSize -gt 0 ]]; then
      Suffix=$(tr -dc "$SuffixPattern" </dev/urandom | head -c $SuffixSize)
   fi

   # Return the random string
   echo -n "$Prefix$Suffix"
}

::extract()
{
   cd "$_installExeDir"

   if [[ -f $_image ]]; then
      echo "Extracting Update..."
      if hash pv 2>/dev/null ; then
         local Size=$(du -cbs "$_image" | tail -1 | awk '{print $1}')
         pv -s $Size < "$_image" | tar --numeric-owner --format=pax -xpf -
      else
         tar --numeric-owner --format=pax -xpf < "$_image"
      fi
   else
      echo "Extracting..."
      if hash pv 2>/dev/null ; then
         local Size=$(du -cbs "$_program" | tail -1 | awk '{print $1}')
         LC_ALL=C sed '1,/^__ARCHIVE_BELOW__/d' < "$_program" |
         pv -s $Size |
         tar --numeric-owner --format=pax -xpf -
      else
         LC_ALL=C sed '1,/^__ARCHIVE_BELOW__/d' < "$_program" |
         tar --numeric-owner --format=pax -xpf -
      fi
   fi

   # Rename executable and framework directory if executable name is changing
   [[ $_executable != $_defaultExecutable ]] &&
   {
      mv "image/usr/local/$_defaultExecutable/bin/$_defaultExecutable" "image/usr/local/$_defaultExecutable/bin/$_executable"
      mv "image/usr/local/$_defaultExecutable" "image/usr/local/$_executable"
   }

   chown -R --reference="$_installDir" bin
}

::create_start()
{
   cd "$_installExeDir"

   MachineName="$(::rand).$(hostname)"
   sed -i \
       -e "s|%{EXECUTABLE}%|$_installExeDir/image/usr/local/$_executable/bin/$_executable|" \
       -e "s|%{IMAGE_DIR}%|$_installExeDir/image|" \
       -e "s|%{MACHINE_NAME}%|$MachineName|" \
      bin/start
}

::install()
{
   # Create the installation directory
   mkdir -p "$_installExeDir"
   chown --reference="$_installDir" "$_installExeDir"

   # Extract the deployment container
   ::extract

   # Create the start file
   ::create_start
}

::update()
{
   local BackupVersion="$(date +"%Y-%m-%d.%H%M%S")"
   local _backupDir="$_installExeDir/.backup/$BackupVersion"

   # Backup the existing installation
   echo "Backing up the existing installation to: $_backupDir..."
   mkdir -p "$_backupDir"
   chown --reference="$_installDir" "$_installExeDir/.backup" "$_backupDir"

   # Do not move dot files: they are not part of the deployment
   mv "$_installExeDir"/* "$_backupDir"/.

   ::install

   # Overlay with persistent data files
   echo "Overlaying new image with persistent data..."
   (
      cd "$_backupDir/image/home/$_executable"
      tar --numeric-owner --format=pax -cpf - * ".$_executable"
   ) | 
   (
      cd "$_installExeDir/image/home/$_executable"
      tar --numeric-owner --format=pax -xpf -
   )
}

::main()
{
   # It is ncessary to parse this first so that the unprivileged _installDir can be determined
   ::getopt "$@" || return

   if [[ $(whoami) != root ]]; then
      if sudo -n true >/dev/null 2>&1; then
         sudo bash "$_program" --directory "$_installDir" "$@"
         return
      else
         echo "Error: Sudo access is required to run the installer"
         return 1
      fi
   fi

   ::init || return

   if $_performVersionCheck; then
      ::checkversion || return
   fi

   if $_update; then
      ::update
   else
      ::install
   fi
}

::main "$@"

exit

__ARCHIVE_BELOW__
