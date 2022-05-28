#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

# Interpret a transform
:Transform:InterpretTransform()
{
   :method

   local (@)_T_Var="$1"
   local (@)_T_FilterExpr="$2"
   local (@)_T_Text="$3"
   local (@)_T_ContextBefore="$4"
   local (@)_T_ContextAfter="$5"
   local (@)_T_Modifier="$6"

   local -a (@)_Result=()
   local (@)_Filter (@)_NextFilterType
   local (@)_T_FilterExprOrig="$(@)_T_FilterExpr"

   # Pull type out of FilterExpr and trim the remainder
   local (@)_T_Type="${(@)_T_FilterExpr:0:1}"

   if [[ $(@)_T_Type =~ [@*] ]]; then
      if [[ $(@)_T_Type = '@' ]]; then
         (@)_T_Type=line
      else
         (@)_T_Type=char
      fi
      (@)_T_FilterExpr="$(echo -n "${(@)_T_FilterExpr:1}" | :trim)"
   else
      (@)_T_Type=char
   fi

   case "${(@)_T_FilterExpr:0:1}" in
   '#')
      (@)_Result+=("$(@)_T_Text")
      (@)_T_Type=line
      ;;

   '!')
      (@)_T_FilterExpr="$(echo -n "${(@)_T_FilterExpr:1}" | :trim)"
      + ExecuteFilterExpr "Transform.$(@)_T_FilterExpr"
      ;;

   *)
      # Store the filter expression
      local -i (@)_FilterIndex=0

      # Normalize the filter expression, changing medial delimiters to control characters
      (@)_T_FilterExpr="$(
         sed -e 's#}\s*{#\x01#g' -e 's#}\s*||\s*{#\x01#g' -e 's#}\s*&&\s*{#\x02#g' <<<"$(@)_T_FilterExpr")"
      (@)_NextFilterType=$'\x01'

      # An empty filter expression is a shorthand for calling the :env function
      if [[ -z $(@)_T_FilterExpr ]]; then
         (@)_T_FilterExpr="env()"
         (@)_T_Type=line
      elif [[ $(@)_T_FilterExpr = '.' ]]; then
         (@)_T_FilterExpr="source()"
         (@)_T_Type=line
      fi

      # Store individual filters in the unnamed transform (Transform._)
      while [[ -n $(@)_T_FilterExpr ]]; do
         (@)_Filter="$(sed 's|\([^\x01\x02]*\).*|\1|' <<<"$(@)_T_FilterExpr")"
         if [[ -n $(@)_Filter ]]; then
            + [ "$(@)_FilterIndex" : "$(@)_NextFilterType$(@)_Filter" ] -m _Filter
            (@)_NextFilterType="${(@)_T_FilterExpr:${#(@)_Filter}:1}"

            (@)_T_FilterExpr="${(@)_T_FilterExpr:${#(@)_Filter}+1}"
            (((@)_FilterIndex++))
         else
            (@)_T_FilterExpr=
         fi
      done

      + [ '#' : "$(@)_FilterIndex" ] -m _Filter

      if [[ $(@)_FilterIndex -gt 0 ]]; then
         + ExecuteFilterExpr
      fi
      ;;
   esac

   + [ Type : "$(@)_T_Type" ] -m Context 

   :string_join -v "$(@)_T_Var" -a "(@)_Result" -d ''
}

:Transform:ExecuteFilterExpr()
{
   :method

   local (@)_Count
   + [ '#' ] -m _Filter -v (@)_Count 
   if [[ -z $(@)_Count ]]; then
      return
   fi

   local -i I=0
   local (@)_T_Op

   for ((I=0; I<$(@)_Count; I++)); do
      local FilterItem
      + [ "$I" ] -m _Filter -v FilterItem 

      local (@)_T_Op="${FilterItem:0:1}"
      (@)_Filter="${FilterItem:1}"

      if [[ $(@)_T_Op = $'\x01' ]]; then
         (@)_T_Op=fallback
      else
         (@)_T_Op=chain
      fi

      if [[ ($(@)_T_Op = fallback && ${#(@)_Result[@]} -eq 0) ||
            ($(@)_T_Op = chain && ${#(@)_Result[@]} -gt 0) ]]; then
         + ExecuteFilter
      fi
   done

   if [[ ${#(@)_Result[@]} -eq 0 ]]; then
      if [[ -n $(@)_T_Text ]]; then
         (@)_Result=( "%{$(@)_T_FilterExprOrig}%$(@)_T_Text%{/}%$(@)_T_ContextAfter" )
      else
         (@)_Result=( "%{$(@)_T_FilterExprOrig/}%$(@)_T_ContextAfter" )
      fi
   fi
}

:Transform:ExecuteFilter()
{
   :method

   local Res
   local -a (@)_T_Args=()
   local -i ArgCount
   local NextArg

   while
      if [[ ${(@)_Filter:0:1} = '<' ]]; then
         (@)_Filter="-i ${(@)_Filter:1}"
      elif [[ ${(@)_Filter:0:1} = '>' ]]; then
         (@)_Filter="-o ${(@)_Filter:1}"
      fi
      [[ ${(@)_Filter:0:1} = '-' ]]
   do
      ArgCount=${#(@)_T_Args[@]}
      readarray -O $ArgCount -t (@)_T_Args < <(echo "$(@)_Filter" | xargs -n 1 printf "%s\n" 2>/dev/null | head -2)
      NextArg="${(@)_T_Args[ArgCount+1]}"
      (@)_Filter="$(sed \
         -e "s|^-[-a-z]*\s*\"\{0,1\}$NextArg\"\{0,1\}\s*||" \
         -e "s|^-[-a-z]*\s*'\{0,1\}$NextArg'\{0,1\}\s*||" <<<"$(@)_Filter")"
   done

   local (@)_T_Before= (@)_T_After= (@)_T_Separator= (@)_T_Default= (@)_T_Name= (@)_Input (@)_Output

   :getopts_init \
      -o "b:      a:     s:         d:       n:    i:     o:" \
      -l "before:,after:,separator:,default:,name:,input:,output:" \
      -v (@)_T_Options -- "${(@)_T_Args[@]}"

   local OptChar
   while :getopts_next OptChar; do
      case "$OptChar" in
      -) case "$OPTARG" in
         before)     :getopts_set (@)_T_Before;    + [ Before    : "$(@)_T_Before" ]    -m Context;;
         after)      :getopts_set (@)_T_After;     + [ After     : "$(@)_T_After" ]     -m Context;;
         separator)  :getopts_set (@)_T_Separator; + [ Separator : "$(@)_T_Separator" ] -m Context;;
         default)    :getopts_set (@)_T_Default;   + [ Default   : "$(@)_T_Default" ]   -m Context;;
         name)       :getopts_set (@)_T_Name;      + [ Name      : "$(@)_T_Name" ]      -m Context;;
         input)      :getopts_set (@)_T_Input;     + [ Input     : "$(@)_T_Input" ]     -m Context;;
         output)     :getopts_set (@)_T_Output;    + [ Output    : "$(@)_T_Output" ]    -m Context;;

         *)          :getopts_skip; break;;
         esac;;

      '?')  break;;
      *)    :getopts_redirect "$OptChar" || break;;
      esac
   done
   :getopts_done

   if [[ $Debug -ge 1 ]]; then
      local -A Symbol=([line]='@' [char]='*')
      local DebugText="$(printf "%s" "<$(@)_T_Text>" | tr '\n' $' ')"
      local DebugContext="$(printf "%s" "($(@)_T_ContextBefore|$(@)_T_ContextAfter)" | tr '\n' ' ')"
      local DebugInfo="$(printf "%s%s+%s" "${Symbol[$(@)_T_Type]}" "$DebugText" "$DebugContext")"
      echo "$DebugInfo" >&2
   else
      local DebugInfo=""
   fi

   case "$(@)_T_Modifier" in
   bash)
      (@)_Filter="bash($(@)_Filter)"
      ;;
   *)
      ;;
   esac

   local ActionType=
   if [[ $(@)_Filter = '.'* ]]; then
      ActionType='json'
   elif [[ $(@)_Filter = '$'* ]]; then
      (@)_Filter="${(@)_Filter:1}"
      ActionType='BashVar'
   elif [[ $(@)_Filter = '&'* ]]; then
      (@)_Filter="${(@)_Filter:1}"
      ActionType='TransformVar'
   else
      ActionType='function'
   fi

   + ExecuteFilter,$ActionType
}

:Transform:ExecuteFilter,json()
{
   :method

   local -i Count
   local Result=

   local Selector="$(envsubst <<< "${(@)_Filter:1}")"

   if + [].exists "$Selector" ; then
      + [ "$Selector" ] -v Result

      (@)_Result=( "$Result$(@)_T_ContextAfter" )

   elif + [].exists "$Selector[#]"; then
      + [ "$Selector[#]" ] -v Count
      for ((I=0; I<$Count; I++)); do
         + [ "$Selector[$I]" ] -v Result
         (@)_Result+="$(@)_T_Before$Result$(@)_T_After"
         if ((I + 1 < Count)); then
            (@)_Result+="$(@)_T_Separator$(@)_T_ContextAfter$(@)_T_ContextBefore"
         elif ((I < Count)); then
            (@)_Result+="$(@)_T_ContextAfter"
         fi
      done
   fi
}

:Transform_env()
{
   echo "IN :env" >&2
}

:Transform_source()
{
   :method
   ..

   local Text ContextBefore ContextAfter

   + [ Text ] -m Context -v Text
   + [ ContextBefore ] -m Context -v ContextBefore
   + [ ContextAfter ] -m Context -v ContextAfter

   TmpFile="$(mktemp)"
   OutFile="$(mktemp)"
   printf "%s" "$(@)_T_Text" > "$TmpFile"
   chmod 755 "$TmpFile"
   source "$TmpFile" > "$OutFile"
   (@)_Result=( "$(cat "$OutFile")${ContextAfter#$'\n'}" )
   rm -f "$TmpFile" "$OutFile"
}

:Transform:ExecuteFilter,function()
{
   :method

   + [ TextNL : "$(@)_T_Text" ] -m Context
   + Unnormalize -v (@)_T_Text "$(@)_T_Text"
   + [ Text : "$(@)_T_Text" ] -m Context

   + [ ContextBefore : "$(@)_T_ContextBefore" ] -m Context
   + [ ContextAfter : "$(@)_T_ContextAfter" ] -m Context

   local (@)_FilterNL FunctionName FunctionArgs
   (@)_FilterNL="$(tr '\n' $'\x01' <<<"$(@)_Filter")"
   FunctionName="$(sed 's|^\([a-zA-Z_][a-zA-Z0-9_]*\).*|\1|' <<<"$(@)_FilterNL")"
   FunctionArgs="$(sed -e 's|[a-zA-Z_][a-zA-Z0-9_]*\s*\(.*\)|\1|' -e 's|\x01|\n|g' <<<"$(@)_FilterNL")"
#  echo "1#####$FunctionName######"
#  echo "2#####$FunctionArgs######"
   if :function_exists "$FunctionName"; then
      "$FunctionName" "$this" "$FunctionArgs"
   elif :function_exists ":Transform_$FunctionName"; then
      ":Transform_$FunctionName" "$this" "$FunctionArgs"
   elif :function_exists ":Transform:$FunctionName"; then
      ":Transform:$FunctionName" "$this" "$FunctionArgs"
   fi
}

:Transform:ExecuteFilter,BashVar()
{
   :method

   # TBD: handle array types (Right now, this function handles only non-array variables)
   if :variable_exists "$(@)_Filter"; then
      (@)_Result=( "${!(@)_Filter}$(@)_T_ContextAfter" )
   fi
}

:Transform:ExecuteFilter,TransformVar()
{
   :method

   echo "TransformVar"
}

:Transform:if()
{
   :method

   local Name='_' Condition="$1"

   if [[ $Condition =~ ^\s*'-n' || $Condition =~ ^\s*--name ]]; then
      Name="$(sed -e 's#^\s*\(-n\|--name\)\s*##' <<<"$Condition" | grep -o "^[a-zA-Z_][a-zA-Z0-9_]*")"
      Condition="$(sed -e "s#^\s*\(-n\|--name\)\s*$Name\s*##" <<<"$Condition")"
   fi

   if [[ -z $Name ]]; then
      Name='_'
   fi

   # Execute the condition in a subshell so that any variable changes are not brought back to this shell
   Enum="$(source <(printf "%s" "$Condition"))"
   Status=$?

   # Store the return status
   + [ $Name : $Status ] -m Condition

   # If the enum string is not explicitly provided, use the string equivalent of the return status
   if [[ -z $Enum ]]; then
      [[ $Status -eq 0 ]] && Enum='true' || Enum='false'
   fi

   # Store the enum string
   + [ $Name : "$Enum" ] -m Enum
   + [ $Name : 'false' ] -m EnumUsed

#  echo "Name: '$Name enum: $Enum"

   if [[ $Status -eq 0 ]]; then
      local Text ContextAfter
      + [ Text ] -m Context -v Text
      + [ ContextAfter ] -m Context -v ContextAfter
      Text="${Text#$'\n'}"
      (@)_Result=( "$Text${ContextAfter#$'\n'}" )
   else
      (@)_Result=( '' )
   fi
}

:Transform:case()
{
   :method

   local -r OPTIONS=$(getopt -o n:esrdfa1i -l "name:,enum,status,regex,default,final,additional,firstmatch,invert" -n "${FUNCNAME[0]}" -- $*)
   eval set -- "$OPTIONS"

   local Name='_' UseStatus=false UseRegex=false IsDefaultCase=false IsFinalCase=false AdditionalMatchIsOkay=true InvertCase=false
   while true ; do
      case "$1" in
      -n|--name)        Name="$2"; shift 2;;
      -e|--enum)        UseStatus=false; shift;;
      -s|--status)      UseStatus=true; shift;;
      -r|--regex)       UseRegex=true; shift;;
      -d|--default)     IsDefaultCase=true; shift;;
      -f|--final)       IsDefaultCase=true; IsFinalCase=true; shift;;
      -a|--additional)  AdditionalMatchIsOkay=true; shift;;
      -1|--firstmatch)  AdditionalMatchIsOkay=false; shift;;
      -i|--invert)      InvertCase=true; shift;;
      --)               shift; break;;
      esac
   done

   local EnumUsed Enum Status
   + [ "$Name" -m EnumUsed -v EnumUsed

   if $IsDefaultCase; then
      [[ $EnumUsed = 'false' || $IsFinalCase = 'true' ]]
   else
      if $UseStatus; then
         + [ "$Name" ] -m Condition -v Enum
      else
         + [ "$Name" ] -m Enum -v Enum
      fi

      if $UseRegex ; then
         [[ $Enum =~ $* && ( $AdditionalMatchIsOkay = true || $EnumUsed = false ) ]]
      else
         [[ $Enum = $*  && ( $AdditionalMatchIsOkay = true || $EnumUsed = false ) ]]
      fi
   fi
   Status=$?

   if $InvertCase; then
      [[ $Status -ne 0 ]]
      Status=$?
   fi

   if [[ $Status -eq 0 ]]; then
      # Mark this condition as having been used
      + [ "$Name" : 'true' ] -m EnumUsed

      local Text ContextAfter
      + [ Text ] -m Context -v Text
      + [ ContextAfter ] -m Context -v ContextAfter
      Text="${Text#$'\n'}"
      (@)_Result=( "$Text${ContextAfter#$'\n'}" )
   else
      (@)_Result=( '' )
   fi
}

:Transform:for()
{
   :method

   if [[ $@ =~ [a-zA-Z][a-zA-Z0-9_]*' '*'in' ]]; then
      local ForName="$1"
      shift 2
      echo "## FOR '$ForName' in '$@'"
      echo "## B'$ContextBefore' T'$Text' A'$ContextAfter'"
   fi
}

:Transform:bash()
{
   :method

   + [ Text ] -m Context -v Text

   local Program="$*"

   local TextFile="$(mktemp)"
   echo -n "$Text" > "$TextFile"
   Program="$(sed 's|%TEXT%|+ text|g' <<<"$Program")"

   printf "%s" "$Program" >&2
   (@)_Result=$(. <(printf "%s" "$Program") )$(@)_T_ContextAfter

   rm -f "$TextFile"
}

:Transform:text()
{
   :method

   local Sub="$(envsubst <<<"$Text")"
   local Map=
#  + [ '_' ] -m _Maps -v Map
#  echo "Map: $Map" >&2

   :Transform_replace -s "$Sub" -m $HOME/transform/t/data.json | tr '\n' $'\x01' | sed 's|^\x01||' | tr $'\x01' '\n'
}
