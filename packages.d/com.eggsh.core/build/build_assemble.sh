#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ __build_assemble__HELP()
{
   echo "HELP for (@)__build_assemble"
}

@ __build_assemble()
{
   local -r OPTIONS=$(getopt -o a:bs: -l "assembledir:,sourcedir:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local AssembleDir= SourceDir=
   while true ; do
      case "$1" in
      -a|--assembledir) AssembleDir="$2"; shift 2;;
      -s|--sourcedir)   SourceDir="$2"; shift 2;;
      --)               shift; break;;
      esac
   done

   # Copy source files into assemble directory
   (
      cd "$SourceDir"
      tar cpf - * 2>/dev/null
   ) |
   (
      cd "$AssembleDir"
      tar xpf -
   )

   return 0
}
