#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

# <name>
# Returns: 0 if a valid name and echoes internal name, 1 otherwise
::objname()
{
   local -r NAME="__obj_$1"
   if :isname "$1"; then
      echo "$NAME"
   else
      return 1
   fi
}
