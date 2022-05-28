#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:getopts_init()
{
   local -r OPTIONS=$(getopt -o o:l:v: -l "optionchars:,longoptions:,variable:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local LongOptions=
   local -g __Getopt_ShortOptions=
   local -g __Getopt_OptionsVar=
   while true ; do
      case "$1" in
      -o|--optionchars) __Getopt_ShortOptions=$(:sed 's| ||g' <<<":$2-:"); shift 2;;
      -l|--longoptions) LongOptions="$2"; shift 2;;
      -v|--variable)    __Getopt_OptionsVar="$2"; shift 2;;
      --)               shift; break;;
      esac
   done

   unset __Getopt_LongOptions
   local -gA __Getopt_LongOptions

   if [[ -n $LongOptions ]] ; then
      local ShortOption LongOption
      local -i I=1
      for LongOption in ${LongOptions//,/ }; do
         ShortOption=${__Getopt_ShortOptions:I:1}
         __Getopt_LongOptions["$ShortOption"]="$LongOption"
         if [[ ${__Getopt_ShortOptions:I+1:1} = : ]]; then
            ((I+=2))
         else
            ((I++))
         fi
      done
   fi

   eval local -ga "$__Getopt_OptionsVar=(\"\$@\")"

   OPTIND=1
}

:getopts_next()
{
   local Var="$1"
   local -g __Getopt_OptChar
   local Indirect="$__Getopt_OptionsVar[@]"
   getopts "$__Getopt_ShortOptions" __Getopt_OptChar "${!Indirect}"
   Status=$?
   printf -v "$Var" "%s" "$__Getopt_OptChar"
   return $Status
}

:getopts_set()
{
   local Name="${OPTARG%%=*}"
   local Var="$1"

   if [[ $OPTARG =~ ^$Name= ]] ; then
      local Indirect="$__Getopt_OptionsVar[$(($OPTIND-2))]"
      Value="${!Indirect#*=}"
   else
      local Indirect="$__Getopt_OptionsVar[$(($OPTIND-1))]"
      Value="${!Indirect}"
      ((OPTIND++))
   fi

   printf -v "$Var" "%s" "$Value"
}

:getopts_skip()
{
   ((OPTIND--))
}

:getopts_redirect()
{
   local OptChar="$1"

   [[ -n ${__Getopt_LongOptions[$OptChar]} ]] || { ((OPTIND--)); return 1; }

   local Name
   if [[ ${__Getopt_LongOptions[$OptChar]} =~ : ]] ; then
      Name=${__Getopt_LongOptions[$OptChar]%%:}
      ((OPTIND-=2))
   else
      Name=${__Getopt_LongOptions[$OptChar]}
      ((OPTIND--))
   fi
   printf -v "$__Getopt_OptionsVar[$(($OPTIND-1))]" "%s" "--$Name"
}

:getopts_done()
{
   local Indirect="$__Getopt_OptionsVar[@]"
   local -a __Getopt_OptionsCopy=( "${!Indirect}" )
   unset "$__Getopt_OptionsVar"

   local -ga "$__Getopt_OptionsVar"
   local -i I=OPTIND-1

   for ((; I < ${#__Getopt_OptionsCopy[@]}; I++)); do
      printf -v "$__Getopt_OptionsVar[$(($I-$OPTIND+1))]" "%s" "${__Getopt_OptionsCopy[$I]}"
   done
}

:function_exists()
{
   local -r OPTIONS=$(getopt -o p: -l "package:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Package=

   while true ; do
      case "$1" in
      -p|--package)  Package="$2::"; shift 2;;
      --)            shift; break;;
      esac
   done

   local -r FUNCTION_TYPE=$(type -t "$Package$1")
   [[ $FUNCTION_TYPE = function ]]
}

:variable_exists()
{
   [[ -n ${!1+checkifset} ]]
}

:error()
{
   {
   local -a ARGS=()
   local -i i
   local -i first=${BASH_ARGC[1]}+${BASH_ARGC[0]}-1
   local -i last=${BASH_ARGC[0]}
   for ((i=$first; i >= $last; i--));do
      ARGS[first-i]=${BASH_ARGV[i]}
   done

   echo
   echo "$@"
   echo
   echo "Command:"
   echo "   ${FUNCNAME[1]} ${ARGS[@]}"
   echo
   echo "Stacktrace:"
   local -i frame
   local -i lastframe=${#BASH_SOURCE[@]}-1
   for ((frame=1; frame < lastframe - 2; frame++)); do
      caller $frame
   done | :sed 's/^/   /'
   }
}

:isnumeric()
{
   [[ $# = 1 ]] || return 1
   [[ $1 =~ ^-?[0-9]+$ ]]
}

# [-l <level>]
:echo()
{
   local EchoOptions=""
   local MsgLevel=2

   local -r OPTIONS=$(getopt -o l: -l "level:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   while true ; do
      case "$1" in
      -l|--level) :isnumeric "$2" || { :error "Invalid number: '$2'"; return 1; }
                  MsgLevel="$2"
                  shift; shift;;
      --)         shift; break;;
      esac
   done

   if [[ $MsgLevel -lt 0 ]]; then
      MsgLevel=$((-$MsgLevel))
      EchoOptions="-n"
   fi

   local Indent=''

   if [[ $_verboseness -gt 2 ]] ; then
      local TotalIndent=$((($MsgLevel - 2)*2))
      if [[ $TotalIndent -gt 0 ]]; then
         Indent=$(printf '%*s' $TotalIndent ' ')
      fi
   fi
   if [[ $MsgLevel -lt $_verboseness ]] ; then
      echo -e "$@" | :sed "s|^|$Indent|"
   elif [[ $MsgLevel -eq $_verboseness ]] ; then
      echo -e $EchoOptions "$@" | :sed "s|^|$Indent|"
   fi
}

:do()
{
   local MsgLevel=2
   local -r OPTIONS=$(getopt -o l: -l "level:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   while true ; do
      case "$1" in
      -l|--level) :isnumeric "$2" || { :error "Invalid number: '$2'"; return 1; }
                  MsgLevel="$2"
                  shift; shift;;
      --)         shift; break;;
      esac
   done

   if [[ $MsgLevel -le $_verboseness ]] ; then
      "$@"
   fi
}

:trim()
{
   :sed -e 's|^[[:space:]]*||' -e 's|[[:space:]]*$||'
}

# <type>
# Returns: 0 if a valid type, 1 otherwise
:istype()
{
   [[ $# = 1 ]] || return 1
   [[ $1 =~ ^(array|map|linkedmap)$ ]]
}

:isname()
{
   [[ $# = 1 ]] || return 1
   [[ $1 =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]
}

:isclassname()
{
   local Candidate="$1"

   [[ -n $Candidate ]] || return 1

   local LabelRE='[a-z]([a-zA-Z0-9-]?[a-zA-Z0-9])*'

   # Does the candidate have a package prefix?
   if [[ $Candidate =~ ^$LabelRE(\.$LabelRE)+:: ]] ; then
      PackagePrefix="${BASH_REMATCH[0]}"
      Candidate="${Candidate#$PackagePrefix}"
   fi

   [[ $Candidate =~ ^:?[A-Z][a-zA-Z0-9]*$ ]]
}

:ispackagename()
{
   [[ $# = 1 ]] || return 1

   local LabelRE='[a-z]([a-zA-Z0-9-]?[a-zA-Z0-9])*'
   [[ $1 =~ ^$LabelRE(\.$LabelRE)+$ ]]
}

:json_escape()
{
  python -c 'import json,sys; print (json.dumps(sys.stdin.read()))'|:sed 's|\\n||g'
}

:json_is_valid()
{
   python -c "import sys,json;json.loads(sys.stdin.read())" >/dev/null 2>&1
}

:sed()
{
   LC_ALL=C sed "$@"
}

:is_fqdn()
{
   local Candidate="$1"
   grep -q -P '^([a-zA-Z0-9](?:(?:[a-zA-Z0-9-]*|(?<!-)\.(?![-.]))*[a-zA-Z0-9]+)?)$' <<<"$Candidate"
}

:settings_update__INFO() { echo "Update the $_SETTINGS.sh file from the $_SETTINGS.json file"; }
:settings_update()
{
   local -r OPTIONS=$(getopt -o r -l "reset" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Reset=false
   while true ; do
      case "$1" in
      -r|--reset) Reset=true; shift;;
      --)         shift; break;;
      esac
   done

   local ReleasePackageSettingsFile DataPackageSettingsFile
   :new :JSON __PackageSettings = '{}'

   for Package in "${!__UnorderedPackages[@]}"; do
      DataPackageSettingsFile="$_dataPackagesDir/$Package/$_dataSettingsJSONFile"

      if $Reset || [[ ! -f $DataPackageSettingsFile ]]; then
         ReleasePackageSettingsFile="$_packagesDir/$Package/$_dataSettingsJSONFile"

         mkdir -p "$_dataPackagesDir/$Package"
         if [[ -f $ReleasePackageSettingsFile ]]; then
            cp "$ReleasePackageSettingsFile" "$DataPackageSettingsFile"
         else
            echo '{}' > "$DataPackageSettingsFile"
         fi
      fi

      $__PackageSettings:join -p "$Package" -f "$DataPackageSettingsFile"
   done

   $__PackageSettings:flatten -q -m _settings

   :persist_associative_array _settings | sort -t'"' -k2,3 > "$_dataSettingsArrayFile"
}

:persist_associative_array__HELP()
{
   :man -a "<sourceArray> [ <persistedArray> ]" "
DESCRIPTION
   Write to stdout the code necessary to persist the <sourceArray>.

   If <persistedArray> is specified, then use that name when persisting.
   This provides a simple means of renaming.
"
}

:persist_associative_array()
{
   local -a Keys

   # Check if the array exists, to protect against injection by passing a crafted string
   declare -p "$1" >/dev/null || return 1

   # Declaration
   printf "declare -A %s\n" "${2:-$1}"

   # Create a string with all the keys so we can iterate
   # because we can't use eval at for's declaration time.
   # we do it this way to allow for spaces in the keys, since that's valid
   eval "Keys=(\"\${!$1[@]}\")"

   local Key
   for Key in "${Keys[@]}"
   do
      # Key:
      printf "%s[\"${Key//\"/\\\\\"}\"]=" "${2:-$1}"

      # Value:
      # The extra quoting here protects against spaces within the element's value.
      # Injection doesn't work here but we still need to make sure there's consistency.
      eval "printf \"\\\"%s\\\"\n\" \"\${$1[\"${Key//\"/\\\"}\"]}\""
   done
}
