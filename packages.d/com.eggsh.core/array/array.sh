#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

Array:()
{
   local this="$1"; shift
   if [[ ${!this} = null ]]; then
      :declare $this '[]'
   fi
}

Array:show()
{
   local this="$1"; shift

   if [[ $# -gt 0 ]]; then
      echo -n "$1 "
   fi
   echo $(jq -r '.' <<< "${!this}")
}

# [<variable>]
Array:size()
{
   local this="$1"; shift
   local __Size=$(jq -r '. | length' <<< "${!this}")
   if [[ $# -eq 0 ]]; then
      echo "$__Size"
      return 0
   fi

   local Variable="$1"
   :isname "$Variable" || { :error "Invalid variable name: $Variable"; return 1; }
   printf -v "$Variable" "%s" "$__Size"
}

# [<index=-1> [<variable>]]
Array:get()
{
   local this="$1"; shift
   local -i Index=-1
   if [[ $# -gt 0 ]]; then
      Index="$1"
      shift
   fi
   if [[ $# -eq 0 ]]; then
      jq -r ".[$Index]" <<< "${!this}"
      return 0
   fi

   local Variable="$1"
   printf -v "$Variable" "%s" "$(jq -r ".[$Index]" <<< "${!this}"|tr -d '\n')"
}

Array:get_selector()
{
   echo '.'
}

# <index> <value>
Array:set()
{
   local this="$1"
   local -i Index="$2"
   local Value="$3"

   local -i Size
   $this:size Size

   [[ $Index -ge 0 ]] || Index+=$Size
   if ! [[ $Index -ge 0 && $Index -lt $Size ]]; then
      :error "Invalid index: $Index to Array:set"
      return 1
   fi

   printf -v "$this" "%s" "$(jq -r ".[$Index] |= $Value" <<< "${!this}"|tr -d '\n')"
}

# [<index=-1> [<variable>]]
Array:remove()
{
   local this="$1"; shift

   local -i Size
   $this:size Size

   local -i Index=Size-1

   case $# in
   0)
      printf -v "$this" "%s" "$(jq -r "del(.[$Index])" <<< "${!this}"|tr -d '\n')"
      ;;
   1)
      Index="$1"
      [[ $Index -ge 0 ]] || Index=Index+Size
      printf -v "$this" "%s" "$(jq -r "del(.[$Index])" <<< "${!this}"|tr -d '\n')"
      ;;
   2)
      $this:get $1 $2
      $this:remove $1
      ;;
   *)
      :error "Invalid number of arguments to Array:add"
      ;;
   esac
}

# [<index=-1>] <element>
Array:add()
{
   local this="$1"; shift

   local -i Size
   $this:size Size
   local -i Index=Size-1
   local Select=

   :getopts_init \
      -o "l    s:" \
      -l "last,select:" \
      -v Options -- "$@"

   local OptChar Select
   while :getopts_next OptChar; do
      case "$OptChar" in
      -) case "$OPTARG" in
         last)    Select="[$Index]";;
         select)  :getopts_set Select;;

         *)       :getopts_skip; break;;
         esac;;

      '?')  break;;
      *)    :getopts_redirect "$OptChar" || break;;
      esac
   done
   :getopts_done

   set -- "${Options[@]}"

   case $# in
   1)
      printf -v "$this" "%s" "$(jq -r ".$Select += [$1]" <<< "${!this}"|tr -d '\n')"
      ;;
   2)
      Index="$1"
      [[ $Index -ge 0 ]] || Index=Index+Size+1
      printf -v "$this" "%s" "$(jq -r ".$Select |= .[:$Index] + [$2] + .[$Index:]" <<< "${!this}"|tr -d '\n')"
      ;;
   *)
      :error "Invalid number of arguments to Array:add"
      ;;
   esac
}
