#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:Transform:()
{
   :method

   local DB='%{'        # Delimiter Begin
   local DE='}%'        # Delimiter End
   local MB='{'         # Middle Begin
   local ME='}'         # Middle End
   local BB=$'\x01'     # Block Begin
   local BE=$'\x02'     # Block End
   local BC=$'\x03'     # Block Close
   local CB=$'\x04'     # Count Begin
   local NL=$'\x05'     # Encoded Newline

   + [ DB : "$DB" , DE : "$DE" , MB : "$MB" , ME : "$ME" , BB : "$BB" , BE : "$BE" , BC : "$BC" , CB : "$CB" , NL : "$NL" ]

   printf -v "$info" '{}'
}

:Transform:map()
{
   :method

   local -r OPTIONS=$(getopt -o qa:f:m:s: -l "quotes,array:,file:,map:,string:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Map="map"
   local Quotes=

   while true ; do
      case "$1" in
      -q|--quotes)   Quotes='-q'; shift;;

      -a|--array)    Array="$2"; shift 2;;
      -f|--file)
         :new :JSON j
         + readfile "$2"
         + flatten -m "${this}_$Map" "$Quotes"
         shift 2;;

      -m|--mapname)  Map="map_$2"; shift 2;;
      -s|--string)   String="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   .. $this
}

:Transform_replace()
{
   :new :Transform t
   $t:replace "$@"
}

:Transform:replace()
{
   :method

   for Var in DB DE MB ME BB BE BC CB NL; do
      local $Var
      + [ $Var ] -v $Var
   done

   local -r OPTIONS=$(getopt -o i:s:m:o:v: -l "infile:,string:,map:,outfile:,stdout,variable:,debug::" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Debug=0
   local -a Inputs=()
   local -a Outputs=()
   local InFile OutFile OutFileDir OutFileBase

   while true ; do
      case "$1" in
      -i|--infile)
         InFile="$(readlink -f "$2")"
         if [[ ! -f $InFile ]]; then
            echo "$FUNCNAME: No such file: $InFile"
            return 1
         fi
         Inputs+=(file "$InFile")
         shift 2;;

      -s|--string)
         if [[ -n $2 ]]; then
            Inputs+=(string "$2")
         fi
         shift 2;;

      -m|--map)
         + [ '_' : "$(readlink -f "$2")" ] -m _Maps
         + map -f "$2"
         shift 2;;

      -o|--outfile)
         OutFile="$(readlink -f "$2")"
         if [[ -n $OutFile ]]; then
            OutFileDir="$(dirname "$OutFile")"
            OutFileBase="$(basename "$OutFile")"
            if [[ ! -d $OutFileDir ]]; then
               echo "$FUNCNAME: Cannot create $OutFileBase in non-existent directory: $OutFileDir"
            fi
            Outputs+=(file "$OutFile")
         fi
         shift 2;;

      --stdout)
         Outputs+=(stdout)
         shift;;

      -v|--variable)
         if [[ -n $2 ]]; then
            Outputs+=(variable "$2")
         fi
         shift 2;;

      --debug)
         if [[ -n $2 ]]; then
            Debug="$2"
         else
            Debug=1
         fi
         shift 2;;
      --)   shift; break;;
      esac
   done

   Input="$(mktemp)"

   local -i I=0
   while ((I < ${#Inputs[@]})); do
      case ${Inputs[I]} in
      file)    cat "${Inputs[I+1]}";;
      string)  echo -e "${Inputs[I+1]}";;
      esac
      I+=2
   done > "$Input"

   Normalized="$(+ Normalize "$Input")"
   Status=$?

   if [[ $Status -ne 0 ]]; then
      case $Status in
      1) echo "Unexpected delimiter end";;
      2) echo "Unterminated delimiter begin";;
      3) echo "Unexpected delimiter begin and end";;
      esac
      return $Status
   fi

   + Process Normalized
   Status=$?

   if [[ $Status -ne 0 ]]; then
      echo "Error: $Normalized"
      return $Status
   fi

   + Unnormalize -v Output -- "$Normalized"
   printf "%s" "$Output"

   rm -f "$Input"

#  if [[ ${#Outputs[@]} -eq 0 ]]; then
#     Outputs=(stdout)
#  fi
#  I=0
#  while ((I < ${#Outputs[@]})); do
#     case ${Outputs[I]} in
#     stdout)     cat "$Output"; ((I++));;
#     variable)   printf -v "${Outputs[I+1]}" "%s\n" "$(cat "$Output")"; I+=2;;
#     file)       cp "$Output" "${Outputs[I+1]}"; I+=2;;
#     esac
#  done
}
