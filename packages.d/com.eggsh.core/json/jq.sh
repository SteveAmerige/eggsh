#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:jq_trim()
{
   LC_ALL=C sed 's|^\s*[#%].*||'
}

:jq_select()
{
   local -r OPTIONS=$(getopt \
      -o ad:h:jk:K:m::p:rs:v:V:xDEFM:T: \
      -l "array,default:,has:,join,key:,keyselector:,message::,prefix:,required,selector:,variable:,varerror:,exports,directory,exists,file,match:,test:" \
      -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Array=false
   local Default=@unset@
   local Has=
   local Error=false
   local Join=false
   local Key=
   local MsgVar='@unset@'
   local ReplaceExportedVariables=false
   local Prefix=
   local Required=false
   local Selector=
   local Var=

   local CheckDirectory=false
   local CheckExists=false
   local CheckFile=false
   local CheckMatch=
   local CheckTest=

   while true ; do
      case "$1" in
      -a|--array)       Array=true; shift;;                    # Store result in positional array
      -d|--default)     Default="$2"; shift 2;;                # On selection errors, use default value
      -h|--has)         Has="$2"; shift 2;;                    # Has key
      -j|--join)        Join=true; shift;;                     # Join lines (useful for arrays)
      -k|--key)         Key="$2"; shift 2;;                    # Store result in associative array with key
      -K|--keyselector) Selector=".$2"; Key="$(LC_ALL=C sed 's|"||g' <<<"$2")"; shift 2;; # Convenience to set Key and Selector
      -m|--message)     MsgVar="$2"; shift 2;;                 # -m[var]: On errors, emit message and details
      -p|--prefix)      Prefix="$2:"; shift 2;;                # Use as prefix for associative arrays
      -r|--required)    Required=true; shift;;                 # The selector must not return false or null
      -s|--selector)    Selector="$2"; shift 2;;               # Use selector to get results
      -v|--variable)    Var="$2"; shift 2;;                    # Store result only in $Var
      -V|--varerror)    Var="$2"; Error=true; shift 2;;        # Store result or error in $Var
      -x|--exports)     ReplaceExportedVariables=true; shift;; # Replace exported vars in result

      -D|--directory)   CheckDirectory=true; shift;;           # Test if result is a directory
      -E|--exists)      CheckExists=true; shift;;              # Test if result exists
      -F|--file)        CheckFile=true; shift;;                # Test if result is a file
      -M|--match)       CheckMatch="$2"; shift 2;;             # Test if result matches grep -P pattern
      -T|--test)        CheckTest="$2"; shift 2;;              # Test using provided [[ $CheckTest ]]
      --)               shift; break;;
      esac
   done

   local Input= Result= Status=0

   # Store the input
   Input=$(LC_ALL=C sed 's|^\s*#.*||')
   if $ReplaceExportedVariables; then
      Input="$(envsubst <<<"$Input")"
   fi

   if [[ -n $Has ]]; then

      [[ $(jq -r "has(\"$Has\")" <<<"$Input") = true ]]
      return
   fi

   # Use the explicitly-provided selector, otherwise explicitly-provided arg, otherwise '.'
   [[ -n $Selector ]] || Selector="${1:-.}"

   # Join
   if $Join; then
      Result="$(jq -r "$Selector | type" 2>/dev/null <<<"$Input")"
      if [[ $Result = array ]] ; then
         Selector="$Selector"' | join(" ")'
      else
         Result="Cannot join result: selector '$Selector' must select an array"
         Join='bad'
         Status=2
      fi
   fi

   if [[ $Join != bad ]]; then
      # Query the JSON using the selector
      Result="$(jq -r "$Selector" 2>/dev/null <<<"$Input")" || (exit 2)
      Status=$?
      if [[ $Result = null ]]; then
         Result=
         Status=2
      fi

      if [[ $Status -ne 0 ]]; then
         if $Required; then
            Result="Result for selector '$Selector' is required"
         else
            if [[ $Default = @unset@ ]]; then
               Result=
            else
               Result="$Default"
               Status=0
            fi
         fi
      fi

      if [[ $Status -eq 0 ]] ; then
         # If the result is valid, is it allowed?
         if [[ -n $CheckMatch ]] && ! grep -qP "$CheckMatch" <<<"$Result"; then
            Result="Selection result '$Selector=$Result' is not allowed. Requirement: $CheckMatch"
            Status=1
         fi
         if $CheckExists && [[ ! -e $Result ]]; then
            Result="Selection does not exist: $Result"
            Status=1
         fi
         if $CheckDirectory && [[ ! -d $Result ]]; then
            Result="Selection is not a directory $Result"
            Status=1
         fi
         if $CheckFile && [[ ! -f $Result ]]; then
            Result="Selection is not a file: $Result"
            Status=1
         fi
         if [[ -n $CheckTest ]]; then
            CheckTest="$(LC_ALL=C sed "s|\\\\1|$(:sed_escape -n "$Result")|" <<<"$CheckTest")"
            eval [[ $CheckTest ]] ||
               { Result="Selection does not pass test: $CheckTest"; Status=1; }
         fi
            
      else
         if $Error ; then
            Result="$(jq -r "$Selector" <<<"$Input" 2>&1 | LC_ALL=C sed 's|^null$||')"
         else
            Result=
         fi
      fi

      if [[ $Status -ne 0 ]] && [[ $MsgVar != @unset@ ]]; then
         if [[ -n $MsgVar ]]; then
            MsgVar="${MsgVar}ErrorMessage"
         else
            MsgVar="$(LC_ALL=C sed 's|[^a-zA-Z0-9_].*||' <<<"$Var")ErrorMessage"
         fi

         if [[ -v $MsgVar ]]; then
            echo "${!MsgVar}"
            if [[ -n $Result ]]; then
               echo "$Result"
            fi
         fi
      fi
   fi

   # Should  the result be stored in a variable?
   if [[ -n $Var ]] ; then
      # If the result is valid or errors should be stored...
      if [[ $Status -eq 0 ]] || $Error ; then
         if [[ -n $Key ]]; then
            Var="$Var['$Prefix$Key']"
         fi
         if $Array ; then
            # a positional array, or string
            readarray -t "$Var" <<<"$Result"
         else
            # a string
            printf -v "$Var" "%s" "$Result"
         fi
      fi
   else
      # If the result is valid or errors should be echoed...
      if [[ $Status -eq 0 ]] || $Error ; then
         echo "$Result"
      fi
   fi

   return $Status
}
