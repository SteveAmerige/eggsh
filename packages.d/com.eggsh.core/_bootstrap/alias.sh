#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

alias :method='local this="$1"; local info="$1_info"; shift; ..'

# :try/:catch - see implementation of :persist and ::trap
alias :try=$'
   if ((__TryLevel >= 0)); then
      set +e
   fi
   ((__TryLevel++))
   __TryLocals[$__TryLevel]="$(local | :sed "s/=.*//" | tr "\n" " ")"
   __TryPersist[$__TryLevel]="$(mktemp)"
   if (( $__TryLevel > 0 )) && grep -q " " <<<"${__TryPersist[$(($__TryLevel - 1))]}"; then
      __TryPersist[$__TryLevel]+=" $(:sed "s|^[^ ]* ||" <<<"${__TryPersist[$(($__TryLevel - 1))]}")"
   fi
   (
   set -e
   trap "::trap \${LINENO} ${__TryLevel}; " ERR
   '

alias :catch=$'
   ::trap \${LINENO} ${__TryLevel}
   )
   source "${__TryPersist[$__TryLevel]%% *}"
   rm -f "${__TryPersist[$__TryLevel]%% *}"
   unset __TryPersist[$__TryLevel]
   unset __TryLocals[$__TryLevel]
   if ((__TryLevel-- >= 1)); then
      set -e
   fi
   (( $_tryStatus == 0 )) ||
   '
shopt -s expand_aliases                # Expand aliases in functions
