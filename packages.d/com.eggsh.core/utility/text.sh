#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:h1()
{
   echo -e "\n${_BOLD}$_RED$*$_NORMAL\n"
}

:h2()
{
   echo -e "\n${_BOLD}$_BLUE$*$_NORMAL\n"
}

:man()
{
   local -r OPTIONS=$(getopt -o c:a:t:x: -l "command:,args:,title:,exclude:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Command="$(sed -e 's|__HELP$||' -e 's|_| |g' <<<"${FUNCNAME[1]}")"
   local Args=
   local Title=
   local -A Section
   Section[synopsis]="true"

   while true ; do
      case "$1" in
      -c|--command)     Command="$2"; shift 2;;
      -a|--args)        Args="$2"; shift 2;;
      -t|--title)       Title="\n<h1>$2\n"; shift 2;;
      -x|--exclude)     Section[$2]=false; shift 2;;
      --)               shift; break;;
      esac
   done

   local Text="$Title"
   if ${Section[synopsis]}; then
      Text+="\nSYNOPSIS: ^^$Command $Args\n"
   fi

   # If the calling function as a __HELP function, then auto-import the __INFO text if present
   if grep -q "__HELP$" <<<"${FUNCNAME[1]}"; then
      local InfoFunction="$(echo "${FUNCNAME[1]}" | LC_ALL=C sed -e 's|__HELP$|__INFO|')"
      if :function_exists $InfoFunction && ${Section["synopsis"]}; then
         Text+="   <green>$($InfoFunction)</green>\n"
      fi
   fi

   # Add the body text
   Text+="$@"

   # Highlight using the manual template
   :highlight -t man <<<"$Text"
}

:highlight()
{
   local -r OPTIONS=$(getopt -o t: -l "template:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Template=man
   while true ; do
      case "$1" in
      -t|--template) Template="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   case "$Template" in
   man)
      Rules=(
         # Highlight after ^^
         "s|\(.*\)^^\(.*\)|\1$_BOLD$_BLUE\2$_NORMAL|"

         # Highlight before ^
         "s|\(.*[^\]\)^|$_BOLD$_BLUE\1$_NORMAL|"
         "s|\(.*\)\\\\^|\1^|"

         # Auto-bolding of words beginning in column 1
         "s|^[a-zA-Z][^:]*:|$_BOLD&$_NORMAL|"

         # Bold
         "s|<b>|\x01|g"
         "s|</b>|\x02|g"
         "s|\x01\([^\x02]*\)\x02|$_BOLD\1$_NORMAL|g"
         "s|\x01\([^\x02]*\)|$_BOLD\1$_NORMAL|g"

         # Explicit colors: blue
         "s|<blue>|\x03|g"
         "s|</blue>|\x04|g"
         "s|\x03\([^\x04]*\)\x04|$_BOLD$_BLUE\1$_NORMAL|g"
         "s|\x03\([^\x04]*\)|$_BOLD$_BLUE\1$_NORMAL|g"

         # Explicit colors: cyan
         "s|<cyan>|\x05|g"
         "s|</cyan>|\x06|g"
         "s|\x05\([^\x06]*\)\x06|$_BOLD$_CYAN\1$_NORMAL|g"
         "s|\x05\([^\x06]*\)|$_BOLD$_CYAN\1$_NORMAL|g"

         # Explicit colors: green
         "s|<green>|\x07|g"
         "s|</green>|\x08|g"
         "s|\x07\([^\x08]*\)\x08|$_BOLD$_GREEN\1$_NORMAL|g"
         "s|\x07\([^\x08]*\)|$_BOLD$_GREEN\1$_NORMAL|g"

         # Explicit colors: magenta
         "s|<magenta>|\x09|g"
         "s|</magenta>|\x10|g"
         "s|\x09\([^\x10]*\)\x10|$_BOLD$_MAGENTA\1$_NORMAL|g"
         "s|\x09\([^\x10]*\)|$_BOLD$_MAGENTA\1$_NORMAL|g"

         # Explicit colors: red
         "s|<red>|\x11|g"
         "s|</red>|\x12|g"
         "s|\x11\([^\x12]*\)\x12|$_BOLD$_RED\1$_NORMAL|g"
         "s|\x11\([^\x12]*\)|$_BOLD$_RED\1$_NORMAL|g"

         # Explicit colors: yellow
         "s|<yellow>|\x13|g"
         "s|</yellow>|\x14|g"
         "s|\x13\([^\x14]*\)\x14|$_BOLD$_YELLOW\1$_NORMAL|g"
         "s|\x13\([^\x14]*\)|$_BOLD$_YELLOW\1$_NORMAL|g"

         # Heading tags for part of a line
         "s|<h1>\(.*\)</h1>|$_BOLD$_RED\U\1\E$_NORMAL|"
         "s|<h2>\(.*\)</h2>|$_BOLD$_BLUE\1$_NORMAL|"
         "s|<h3>\(.*\)</h3>|$_BOLD\1$_NORMAL|"
         "s|<h4>\(.*\)</h4>|$_BOLD$_GREEN\1$_NORMAL|"

         # Heading tags from tag to end of line
         "s|<h1>\(.*\)|$_BOLD$_RED\U\1\E$_NORMAL|"
         "s|<h2>\(.*\)|$_BOLD$_BLUE\1$_NORMAL|"
         "s|<h3>\(.*\)|$_BOLD\1$_NORMAL|"
         "s|<h4>\(.*\)|$_BOLD$_GREEN\1$_NORMAL|"

         # Automatic underlining for <variable> words
         "s|^<\([a-zA-Z]\+\)>|<$_UNDERLINE\1$_UNDERLINE_OFF>|g"
         "s|\([^\\]\)<\([a-zA-Z]\+\)>|\1<$_UNDERLINE\2$_UNDERLINE_OFF>|g"
         "s|\\\\<\([a-zA-Z]\+\)>|<\1>|g"
      )
      ;;
   *) echo "Unrecognized template: $Template"; return 1;;
   esac

   LC_ALL=C sed 's|\\n|\n|g' |
   LC_ALL=C sed "$(
   for ((I=0; I < ${#Rules[@]}; I++)); do
      printf "%s\n" "${Rules[I]}"
   done
)"
}

:var()
{
   local -r OPTIONS=$(getopt -o p: -l "package:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Package=
   while true ; do
      case "$1" in
      -p|--package)  Package="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   local Var="$1"
   if [[ -n $Package ]]; then
      Var="${_programNAME}_$(tr '.' '_' <<<"$Package")"
      eval echo "\${$Var[$1]}"
   elif [[ -v $Var ]]; then
      echo "${!Var}"
   fi
}

:align()
{
   local -r OPTIONS=$(getopt -o d: -l "delimiter:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Delimiter='|'
   while true ; do
      case "$1" in
      -d|--delimiter)   Delimiter="$2"; shift 2;;
      --)               shift; break;;
      esac
   done

   sed "s~$Delimiter~\x01~" | column -t -s $'\x01'
}

:array_sort()
{
   local OPTIONS
   OPTIONS=$(getopt -o l:ov: -l "locale:,stdout,variable:" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$OPTIONS"

   local Locale='C'
   local Stdout=false
   local Var=
   while true ; do
      case "$1" in
      -l|--locale)   Locale="$2"; shift 2;;
      -o|--stdout)   Stdout=true; shift;;
      -v|--variable) Var="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   [[ -n $Var ]] || { echo 'No variable name was specified'; return 1; }

   local Indirect="$Var[@]"
   local -a Copy=("${!Indirect}")
   [[ ${#Copy[@]} -gt 0 ]] || return 0
   readarray -t "$Var" <<<"$(printf "%s\n" "${!Indirect}" | LC_ALL="$Locale" sort)"

   if $Stdout; then
      printf '%s\n' "${!Indirect}"
   fi
}

:to_upper_key()
{
   local Key="$1"

   printf '%s' "$Key" |
   tr 'a-z' 'A-Z' |
   tr -c 'A-Z0-9_' '_'
}

:dump_associative_array,k()
{
   eval "echo \${!$1[@]}"
}

:dump_associative_array,v()
{
   local Var="$1"
   local Key="$(sed 's|"|\\"|g' <<<"$2")"
   eval "echo \${$Var[$Key]}"
}

:dump_associative_array()
{
   local Var="$1"
   local Key
   for Key in $(:dump_associative_array,k "$Var"); do
      echo "   $Key|= <b>$(:dump_associative_array,v "$Var" "$Key")</b>"
   done | sort -f | :align | :highlight
}
