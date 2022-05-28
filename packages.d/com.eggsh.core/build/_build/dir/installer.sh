#!/bin/bash

::getopt()
{
   local -gr _program="$(readlink -f "${BASH_SOURCE[0]}")"
   local -gr __=$(basename "$_program")
   local -gr _invocationDir="$(readlink -f .)"
   local -gr _originalProductName="%{DEFAULT_EXECUTABLE}%"

   local -r OPTIONS=$(getopt -o d:hn:s -l "directory:,help,name:,skipversioncheck" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   # Defaults
   local -g _destDir="$HOME"
   local -g _productName=""
   local -g _skipVersionCheck=false

   while true ; do
      case "$1" in
      -d|--directory)
         _destDir="$2"
         [[ -d $_destDir ]] || { echo "Destination directory does not exist: $_destDir"; return 1; }
         _destDir="$(readlink -f "$2")"
         shift 2;;
      -h|--help)
         ::help
         shift;;
      -n|--name)
         _productName="$2"
         if [[ $_productName = "/"* ]] ||
            [[ $_productName = "./"* ]] ||
            [[ $_productName = "../"* ]] ; then
            _destDir=$(dirname "$(readlink -f "$_productName")")
            _productName=$(basename "$_productName")
         fi
         shift 2;;
      -s|--skipversioncheck)
         _skipVersionCheck=true
         shift;;
      --)
         shift
         break;;
      esac
   done

   [[ -n $_productName ]] || _productName="$_originalProductName"

   if [[ -e $_destDir/$_productName ]] ; then
      echo "Product already exists: $_destDir/$_productName"
      exit 1
   fi
}

::checkversion()
{
   local Version Major Minor Patch
   IFS=. read Version Major Minor Patch < <(uname -r | LC_ALL=C sed -e 's|\(.*-[0-9]*\).*|\1|' -e 's|-|.|')

   local Number='^[0-9]+$'

   [[ $Version =~ $Number ]] && [[ $Major =~ $Number ]] && [[ $Minor =~ $Number ]] && [[ $Patch =~ $Number ]] ||
      { echo "Operating system kernel numbering is not numeric: $(uname -r)"; exit 1; }
   [[ $Version -eq 3 ]] && [[ $Major -eq 10 ]] && [[ $Minor -eq 0 ]] && [[ $Patch -ge 327 ]] ||
      { echo "Operating system kernel version must be at or after 3.10.0-327"; exit 1; }

   [[ -f /etc/os-release ]] &&
   {
      Name=$(grep '^NAME=' /etc/os-release | LC_ALL=C sed -e 's|^NAME=||' -e 's|"||g')
      [[ $Name = "CentOS Linux" ]] || [[ $Name = "Red Hat Enterprise Linux"* ]] ||
         { echo "Operating system must be CentOS or Red Hat Enterprise Linux"; exit 1; }
   }
}

::help()
{
   echo "
OPTIONS:
   -d|--directory <dir>    The directory to which output is written [default: $HOME]
   -n|--name <name>        Build a product named <name> [default: $_originalProductName]
   -s|--skipversioncheck   Skip the version check

                           WARNING: Use this option ONLY if you are absolutely sure
                           that your operating system meets installation requirements.
                           This option is present to future-proof this installer for
                           operating system releases that do not follow version numbering
                           standards that were in place when this installer was made.

   -h|--help               Show this help

DESCRIPTION:
   Extract the archive to <dir>/<name>, by default:
   
      $HOME/$_originalProductName"
   exit 0
}

::install()
{
   ::getopt "$@"

   $_skipVersionCheck || ::checkversion

   mkdir -p "$_destDir/$_productName"
   cd "$_destDir/$_productName"

   local Size=$(du -cbs "$_program" | tail -1 | awk '{print $1}')
   LC_ALL=C sed '1,/^__ARCHIVE_BELOW__/d' < "$_program" |
   pv -s $Size |
   sudo tar --numeric-owner --format=pax -xpf -

   # Rename executable and framework directory if product name is changing
   [[ $_productName != $_originalProductName ]] &&
      mv "bin/$_originalProductName" "bin/$_productName"
}

::install "$@"

exit 0

__ARCHIVE_BELOW__
