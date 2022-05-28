#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:enable_globstar()
{
   local -g __SHOPT_GLOBSTAR=$(shopt -p globstar)
   local -g __SHOPT_NULLGLOB=$(shopt -p nullglob)
   shopt -s globstar nullglob
}

:reset_globstar()
{
   $__SHOPT_GLOBSTAR
   $__SHOPT_NULLGLOB
}

:set_save()
{
   ! ((__SetSaveIndex++))
   _setSave[__SetSaveIndex]="$(set +o)"
}

:set_restore()
{
   if (( $__SetSaveIndex >= 0 )) ; then
      eval "${_setSave[$__SetSaveIndex]}"
      ! ((__SetSaveIndex--))
   fi
}

:shopt_save()
{
   ! ((__ShoptSaveIndex++))
   _shoptSave[__ShoptSaveIndex]="$(shopt -p)"
}

:shopt_restore()
{
   if (( $__ShoptSaveIndex >= 0 )) ; then
      eval "${_shoptSave[$__ShoptSaveIndex]}"
      ! ((__ShoptSaveIndex--))
   fi
}

:to_uri()
{
   local -r OPTIONS=$(getopt -o s:v: -l "suffix:,variable:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Suffix=
   local Variable=

   while true ; do
      case "$1" in
      -s|--suffix)   Suffix="$2"; shift 2;;
      -v|--variable) Variable="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   :shopt_save

   shopt -s extglob
   local Path="$1"

   if [[ $Path = /* ]] ; then
      Path="file://$Path"
   elif [[ $Path != [a-z]*([a-z0-9+.-])://* ]] ; then
      Path=''
   fi

   if [[ -n $Variable ]] ; then
      printf -v "$Variable" "%s" "$Path$Suffix"
   else
      echo "$Path$Suffix"
   fi

   :shopt_restore

   return 0
}

::describe()
{
   local Function="$1"
   shift

   if :function_exists ${Function}__INFO; then
      echo "${_BOLD}# DESCRIPTION: $_GREEN$(${Function}__INFO)$_NORMAL"
   fi

   if [[ -n ${__FunctionPath[$Function]} ]]; then
      echo -e "${_BOLD}# FILE:        ${__FunctionPath[$Function]}$_NORMAL"
   fi

   if :function_exists ${Function}__HELP; then
      echo "${_BOLD}# HELP:        ${_BLUE}Additional help is available$_NORMAL"
   fi

   if [[ $# -gt 0 ]]; then
      echo "${_BOLD}# ARGUMENTS:   $@$_NORMAL"
   fi

   echo

   declare -f "$Function"
}
