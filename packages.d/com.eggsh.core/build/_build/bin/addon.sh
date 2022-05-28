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
   Options=$(getopt -o d:he:sx -l "directory:,help,executable:,skipversioncheck,update" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$Options"

   local -g _installDir="$HOME"
   local -g _executable="$_defaultExecutable"
   local -g _performVersionCheck=true
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

   # If called internally, then this is the location of the image file
   local -g _image="$1"

   # The installation directory must exist
   if [[ ! -d $_installExeDir ]]; then
      echo "Nothing to update found, expecting: $_installExeDir"
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

::install()
{
   # Extract the deployment container
   ::extract
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

::addon()
{
   local ImageDir="$_installExeDir/image"

   # Ensure the ownership is correct for added files
   chown -R --reference="$ImageDir/home/$_executable" "$ImageDir/usr/local/$_executable"

   cd "$ImageDir/usr/local/$_executable/packages.d"
   local Package
   for Package in *; do
      if [[ -f $Package/addon.sh ]]; then
         systemd-nspawn -q -D "$ImageDir" runuser -l "$_executable" -c "$_executable -p $Package __install_addon"
      fi
   done
}

::main()
{
   # It is necessary to parse this first so that the unprivileged _installDir can be determined
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

   ::addon
}

::main "$@"

exit

__ARCHIVE_BELOW__
