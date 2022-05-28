#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:vi_diff__INFO() { echo "Recursively diff two directories and use vi to view differences"; }
:vi_diff()
{
   local Dir1="$1"
   local Dir2="$2"

   [[ -d $Dir1 ]] && [[ -d $Dir2 ]] ||
      { echo "The two arguments must be directories"; return 1; }

   local DiffFileList=$(mktemp)

   {
      echo "#!/bin/bash"
      diff -r -q "$Dir1" "$Dir2" 2>/dev/null |
      grep "^Files " |
      grep -v ".git/" |
      LC_ALL=C sed -e 's|^Files |vi -d |' -e 's| and | |' -e 's| differ||'
   } > "$DiffFileList"

   bash "$DiffFileList"

   rm -f "$DiffFileList"
}
