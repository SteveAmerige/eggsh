#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:set__INFO() { echo 'Write data to the persistent data settings file'; }
:set__HELP()
{
   local __DefaultTaxonomy="${_taxonomy:-no default}"

   :man "
OPTIONS:
   -t|--taxonomy <taxonomy>   ^Specify the taxonomy under which to write data (default: $__DefaultTaxonomy) 

DESCRIPTION:
   Write data to the persistent data settings file"
}

:set()
{
   local Options
   Options=$(getopt -o t: -l "taxonomy:" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$Options"

   local Var="Value"
   while true ; do
      case "$1" in
      -t|--taxonomy)    Taxonomy="$2"; shift 2;;
      --)               shift; break;;
      *)                break;;
      esac
   done

   # If the user has not specified a taxonomy, then use a default taxonomy
   if [[ -z $Taxonomy ]]; then
      Taxonomy="$_taxonomy"
   fi
}
