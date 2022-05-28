#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

Parser:Dump()
{
   local Prefix=$(printf "%-15s %4s" "$1" $Parser_Condition)
   local Select="${Parser_Select[@]}"
   echo "                      | ${!Parser_Input}"
   echo "$Prefix  | $(printf "/%s/ " "${Parser_Select[@]}")"
   echo
}
