#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

::ArrayShow()
{
   # Check if <arrayName> is present
   if ! [[ $# -gt 0 && -n $1 ]]; then
      return 1
   fi
   
   # Ensure array exists
   local Array="__array_$1"; shift

   # Get from the reference array the size of the array
   eval local NEXT=\${#$Array[@]}

   # Iterate over the reference array, using bash indirection ${!NAME}
   # to access the value array
   local Indirect
   local -a Value
   local I
   for I in $(seq 0 $(($NEXT - 1))); do
      eval Indirect=\${$Array[$I]}
      echo -n "Value: $Indirect  "
      Value=("${!Indirect}")
      echo "${Value[@]}"
   done
}
