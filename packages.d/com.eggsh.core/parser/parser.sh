#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

# Parser initialization
Parser:Initialize()
{
   :new Array Parser_Input = '[]'

   local -ga Parser_Select=()
   local -ga Parser_ImplicitGroup=()
   local -g Parser_Condition="any"
   local -g Parser_ConditionHasBeenApplied="false"
   local -gr Parser_SIMPLE_SELECTOR='[-1]'
   local -gr Parser_GROUP_SELECTOR='[-1].do[-1]'
   local -gr Parser_ADD_NEW_GROUP='[-1].do'
   local -g Parser_ProcessedTokens=""
}

# Collect statementlist tokens into parse_input JSON structure
Parser:Collect()
{
   # If the line is empty or a comment, then skip it
   local -r COMMENT="^#.*"
   [[ -z $@ ]] || [[ $@ =~ $COMMENT ]] && return 0

   local -g Parser_Command="$*"
   local LastSelect

   # Parsing is delimited by TOKENs
   local TOKEN Parser_ModifiesGroup="false"
   for TOKEN in "$@"; do
      case "$TOKEN" in
      # Statement separator
      ','|';')
         [[ ${#Parser_Select[@]} -eq 0 ]] && continue
         Parser:collect,RemoveImplicitGroup
         Parser_Condition="any"
         ;;

      # Do next statement only if previous statement's return code is 0
      '+'|'&&')
         Parser:collect,RemoveImplicitGroup
         Parser_Condition="okay"
         ;;

      # Do next statement only if previous statement's return code is NOT 0
      '-'|'||')
         Parser:collect,RemoveImplicitGroup
         Parser_Condition="fail"
         ;;

      # Begin statement group
      '['|'{')
         $Parser_Input:add -s "$(printf "%s" "${Parser_Select[@]}")" '{"on":"'"$Parser_Condition"'","do":[]}'
         Parser_Select+=("$Parser_ADD_NEW_GROUP")
         Parser_Condition="any"
         ;;

      # End statement group
      ']'|'}')
         if [[ ${#Parser_Select[@]} -ge 2 ]] &&
            (  [[ ${Parser_Select[${#Parser_Select[@]}-1]} = "$Parser_SIMPLE_SELECTOR" ]] ||
               [[ ${Parser_Select[${#Parser_Select[@]}-1]} = "$Parser_GROUP_SELECTOR" ]]) &&
            [[ ${Parser_Select[${#Parser_Select[@]}-2]} = "$Parser_ADD_NEW_GROUP" ]]
         then
            unset Parser_Select[${#Parser_Select[@]}-1]
            unset Parser_Select[${#Parser_Select[@]}-1]
         else
            echo "[ERROR] Syntax error encountered processing '$TOKEN' after $Parser_ProcessedTokens"
            echo "${Parser_Select[@]}"
            jq -r . <<<"${!Parser_Input}"
            return 1
         fi
         ;;

      # Statement words and arguments
      *)    
         if [[ ${#Parser_Select[@]} -gt 0 ]] ; then
            LastSelect=${Parser_Select[${#Parser_Select[@]}-1]}
         else
            LastSelect=""
         fi

         if [[ $Parser_Condition != any ]] ; then
            # Handle condition
            if [[ $LastSelect = "$Parser_SIMPLE_SELECTOR" ]] || [[ $LastSelect = "$Parser_GROUP_SELECTOR" ]] ; then
               unset Parser_Select[${#Parser_Select[@]}-1]
            fi
            $Parser_Input:add -s "$(printf "%s" "${Parser_Select[@]}")" '{"on":"'"$Parser_Condition"'","do":[["'"$TOKEN"'"]]}'
            Parser_Select+=("$Parser_GROUP_SELECTOR")
            Parser_Condition="any"

         else
            # Handle condition
            if [[ -z $LastSelect ]] || [[ $LastSelect = "$Parser_ADD_NEW_GROUP" ]] ; then
               # Handle new group
               $Parser_Input:add -s "$(printf "%s" "${Parser_Select[@]}")" '[]'
               Parser_Select+=("$Parser_SIMPLE_SELECTOR")
            fi

            # Add new word
            $Parser_Input:add -s "$(printf "%s" "${Parser_Select[@]}")" "\"$(LC_ALL=C sed 's|"|\\"|g'<<<"$TOKEN")\""
         fi
         ;;
      esac
      Parser_ProcessedTokens="$Parser_ProcessedTokens $TOKEN"
   done
}

Parser:collect,RemoveImplicitGroup()
{
   local LastSelect
   if [[ ${#Parser_Select[@]} -gt 0 ]] ; then
      LastSelect=${Parser_Select[${#Parser_Select[@]}-1]}
   else
      LastSelect=""
   fi

   if [[ $LastSelect = "$Parser_SIMPLE_SELECTOR" ]] || [[ $LastSelect = "$Parser_GROUP_SELECTOR" ]] ; then
      unset Parser_Select[${#Parser_Select[@]}-1]
   fi
}

Parser:Execute()
{
   local -g Parser_ReturnStatus=0
   Parser_Select=("$($Parser_Input:get_selector)")
   Parser:execute,Traverse
}

Parser:execute,Traverse()
{
   local -g Parser_Selector="$(printf "%s" "${Parser_Select[@]}")"
   local Type=$(jq -r "$Parser_Selector|type" <<<"${!Parser_Input}")
   local -i Size I
   local LastSelect On
   local -g Parser_StatementIndex
   local -g Parser_StatementFunction
   local -ga Parser_StatementArgs

   case "$Type" in
   array)
      LastSelect=${Parser_Select[${#Parser_Select[@]}-1]}
      if [[ $LastSelect =~ ^\[[0-9]+\]$ ]] ; then
         local -a ParserStatement=()
         :jq_select -a -v ParserStatement "$Parser_Selector[]" <<<"${!Parser_Input}"

         @ "${ParserStatement[@]}"

      else
         Size=$(jq -r "$Parser_Selector|length" <<<"${!Parser_Input}")
         for ((I=0; I < Size; I++)); do
         Statement=$(jq -r "$Parser_Selector[]" <<<"${!Parser_Input}")
            Parser_Select+=("[$I]")
            Parser:execute,Traverse
            unset Parser_Select[${#Parser_Select[@]}-1]
         done
      fi
      ;;

   object)
      On=$(jq -r "$Parser_Selector.on" <<<"${!Parser_Input}")
      if [[ ($On = any) ||
            ($On = okay && $Parser_ReturnStatus = 0) ||
            ($On = fail && $Parser_ReturnStatus != 0) ]] ; then
         Parser_Select+=(".do")
         Parser:execute,Traverse
         unset Parser_Select[${#Parser_Select[@]}-1]
      fi
      ;;

   *)
      ;;
   esac
}

# Call egg function
@()
{
   # Determine the current package context based on the caller of this function
   if grep -q "^.\+::" <<<"${FUNCNAME[1]}" ; then
      local PackageOrderContext="$(LC_ALL=C sed 's|::.*||' <<<"${FUNCNAME[1]}")"
      local FunctionPrefix="$PackageOrderContext::"
   else
      local PackageOrderContext='.'
      local FunctionPrefix=''
   fi

   local Function=false
   local Variable=false
   local RebuildCache=false
   local Package=
   local Name=

   local -ag Options=()
   :getopts_init \
      -o "f        v:        p:       n:    r" \
      -l "function,variable:,package:,name:,rebuild" \
      -v Options -- "$@"

   local OptChar Arg
   while :getopts_next OptChar; do
      case "$OptChar" in
      -) case "$OPTARG" in
         function)   Function=true;;
         variable)   :getopts_set Name; Variable=true;;
         package)    :getopts_set Package;; # Show info for Package or use Package for resolution
         rebuild)    RebuildCache=true;;
         name)       :getopts_set Name;;

         *)       :getopts_skip; break;;
         esac;;

      '?')  break;;
      *)    :getopts_redirect "$OptChar" || break;;
      esac
   done
   :getopts_done

   $RebuildCache && rm -f "$__CacheScriptsFile"

   # If the user has not specified a command, then echo some information
   # Echo prefix if a function or variable prefix is requested
   if [[ ${#Options[@]} -eq 0 ]]; then
      # $(@ -p <package.name> -n <VarName>) -- Generate a variable name for a package: <package_name>__VarName
      [[ -n $Package ]] && { echo "${Package//./_}__$Name"; return; }

      # $(@ -f)FunctionName -- Generate a function name: <current.package.name>::FunctionName
      $Function && { echo "$PackageOrderContext::"; return; }

      # $(@ -v VarName) -- Generate a variable name for the current package: <current_package_name>__VarName
      $Variable && { echo "${PackageOrderContext//./_}__$Name"; return; }

      # $(@) -- Return the current package name: <current.package.name>
      echo "$PackageOrderContext"; return
   fi

   # Ensure package ordering is established
   if :function_exists "${FunctionPrefix}__ORDER" ; then
      # An explicit package ordering is requested
      "${FunctionPrefix}__ORDER"
   else
      # Implicit ordering is needed
      local -a OrderOptions=()
      if [[ -n $Package ]]; then
         local PrimaryPackage="$Package"
      else
         local PrimaryPackage="$PackageOrderContext"
      fi

      if $__CachePackage || [[ $PrimaryPackage != '.' ]]; then
         OrderOptions+=("-c")
      fi
      OrderOptions+=("-1" "$PrimaryPackage")
      if [[ -n ${__OrderedPackages['.']} ]]; then
         OrderOptions+=( $(printf -- " -p %s" ${__OrderedPackages['.']}) )
      fi

      :package_order "${OrderOptions[@]}"
   fi

   # Resolve function and arguments to specific package and call it (else complain)
   local Function FunctionCall
   local -i I J
   local FunctionFoundButNoHelp=false
   for ((I=${#Options[@]}; I > 0; I--)); do
      Function="$(printf "_%s" "${Options[@]:0:$I}")"
      Function="${Function:1}"

      for Prefix in ${__OrderedPackages["$PrimaryPackage"]} ; do
         [[ $Prefix = '.' ]] && Prefix='' || Prefix="$Prefix::"
         FunctionCall="$Prefix$Function"

#        if :function_exists "${FunctionCall}__DEFAULTS"; then
#           echo "IN DEFAULTS" >&2
#           . <(declare -f "${FunctionCall}__DEFAULTS" | sed -e '1,2d' -e '$d')
#        fi
         if :function_exists "$FunctionCall"; then
            if $__ShowHelp ; then
               :function_exists ${FunctionCall}__HELP && ${FunctionCall}__HELP || FunctionFoundButNoHelp=true
            elif $__EditSource; then
               vi +"/^@\s*$Function\s*(\s*)/" "${__FunctionPath[$FunctionCall]}"
            elif $__Describe; then
               ::describe "$FunctionCall" "${Options[@]:I}"
            else
               if $__BeforeAfterProcess && :function_exists ${FunctionCall}__BEFORE; then
                  ${FunctionCall}__BEFORE "${Options[@]:I}"
                  Parser_ReturnStatus=$?
               fi

               if [[ $Parser_ReturnStatus -eq 0 ]]; then
                  $__Debug && set -x
                  "$FunctionCall" "${Options[@]:I}"
                  Parser_ReturnStatus=$?
                  $__Debug && set +x

                  if $__BeforeAfterProcess && :function_exists ${FunctionCall}__AFTER; then
                     ${FunctionCall}__AFTER "${Options[@]:I}"
                     Parser_ReturnStatus=$?
                  fi
               fi
            fi
            return $Parser_ReturnStatus
         fi
      done
   done

   if $__ShowHelp ; then
      $FunctionFoundButNoHelp &&
         echo "Function is defined, but help is not found: $__ ${Options[@]}" ||
         echo "Help was not found and function is undefined: $__ ${Options[@]}"
   else
      echo "Command not found: $__ ${Options[@]}"
   fi

   Parser_ReturnStatus=1
   return $Parser_ReturnStatus
}

Parser:Finally()
{
   return $Parser_ReturnStatus
}
