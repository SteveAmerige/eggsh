#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

# Create instance of a shell class
# USAGE: :new <ClassName> <variable> [ <ConstructorOptions> ] [ { : [ <field> <json> ]+ | = <json> } ]
:new()
{
   # Validate the class name
   local Class="$1"
   [[ -n $Class ]] || { :error "Missing class"; return 1; }
   :isclassname "$Class" || { :error "Invalid class name: $Class"; return 1; }
   shift

   # Validate the variable name
   local Variable="$1"
   [[ -n $Variable ]] || { :error "Missing variable"; return 1; }
   :isname "$Variable" || { :error "Invalid variable name: $Variable"; return 1; }
   shift

   # Create new instance
   ::NewInstanceName $Class $Variable
   local Instance=${!Variable}

   # Save constructor options
   local -a ConstructorOptions=()
   while [[ $# -gt 0 ]] && [[ $1 != : ]] && [[ $1 != = ]] ; do
      ConstructorOptions+=( "$1" )
      shift
   done

   :new,Init "$Class" "$Instance" "$@"

   # Every class extends :Object
   :extends -i $Instance :Object

   # Call constructor
   if :function_exists $Class:; then
      $Class: $Instance "${ConstructorOptions[@]}"
   fi

   # Set chain to instance
   .. $Instance
}

:destroy()
{
   local Instance
   for Instance; do
      Instances="$(compgen -A variable "${Instance}_" | tr '\n' ' ')"
      unset $Instances $Instance
   done
}

:new,Init()
{
   local Class="$1"
   local Instance="$2"
   shift 2

   # An equal sign is used to specify an anonymous field value for the class
   if [[ $1 = = ]] ; then
      shift
      set -- : '' "$@"
   fi

   # Store any instance variables
   if [[ $1 = : ]]; then
      shift

      [[ $(($# % 2)) -eq 0 ]] || { :error ":new: field initializer is missing value"; return 1; }

      # Set unhandled instance variables
      local -i I
      local -i Last=$#
      for ((I=0; I < $Last; I+=2)); do
         if [[ -n $1 ]] ; then
            :declare $Instance "$1" "$2"
         else
            :declare $Instance "$2"
         fi
         shift 2
      done
   fi

   # Build class method references in instance
   local FunctionName
   local -a ClassMembers=()
   readarray -t ClassMembers < <(compgen -A function "$Class:")
   for FunctionName in "${ClassMembers[@]}"; do
      [[ $FunctionName != $Class: ]] || continue
      InstanceFunction=$Instance:${FunctionName#$Class:}
      :function_exists "$InstanceFunction" ||
      eval "$InstanceFunction() { $FunctionName $Instance \"\$@\"; }"
   done
}

# instance key value
:declare()
{
   case $# in
   3) local Instance="$1"
      local Field="$2"
      local Value="$3"

      eval "$Instance.$Field() { ::Accessor $Instance '$Field' \"\$@\"; }"
      printf -v "$Instance" "%s" $(jq -r ". += {\"$Field\":$Value}" <<< "${!Instance}")
      ;;

   2) local Instance="$1"
      local Value="$2"

      eval "$Instance() { ::Accessor $Instance '$Field' \"\$@\"; }"
      printf -v "$Instance" "%s" "$(jq -r ". |= $Value" <<< "${!Instance}")"
      ;;
   *) ;;
   esac
}

# Extend a shell class from another shell class
:extends()
{
   local -r OPTIONS=$(getopt -o i: -l "instance:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Instance=
   while true ; do
      case "$1" in
      -i|--instance) Instance="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   # Verify Class exists
   local Class="$1"
   [[ -n $Class ]] || { :error "Missing class"; return 1; }
   :isclassname "$Class" || { :error "Invalid class name: $Class"; return 1; }
   shift

   if [[ -z $Instance ]]; then
      Instance=${BASH_ARGV[$((${BASH_ARGC[0]}+${BASH_ARGC[1]}-1))]}
   fi

   :new,Init "$Class" "$Instance" "$@"

   # Call constructor
   if :function_exists $Class:; then
      $Class: $Instance
   fi
}

:this()
{
   local -i InstanceIndex=${BASH_ARGC[0]}+${BASH_ARGC[1]}-1
   local Instance=${BASH_ARGV[$InstanceIndex]}
   echo "$Instance"
}

# Set the instance for chaining
..()
{
   if [[ $# -eq 0 ]]; then
      set -- "$this"
   fi
   eval "::CallChainFunction() { local ChainInstance=\"\$1\"; shift; $1:\$ChainInstance \"\$@\"; }"
}

# Call a function via chaining
+()
{
   ::CallChainFunction "$@"
}

:()
{
   "$_program" "${_programOptions[@]}" "$@"
}

# ================================================== Private Functions

::NewInstanceName()
{
   local Class="$1"
   local Variable="$2"

   if [[ ${Class:0:1} = : ]]; then
      Class="_${Class:1}"
   fi

   local IndirectInstanceCount="__obj_${Class}_instances"
   :variable_exists "$IndirectInstanceCount" || local -ig "$IndirectInstanceCount"=0

   local -i Next=${!IndirectInstanceCount}+1
   printf -v "$IndirectInstanceCount" "%s" "$Next"

   printf -v "$Variable" "%s" "__obj_${Class}_$Next"
   printf -v "${!Variable}" "%s" 'null'
}

::Accessor()
{
   local Instance="$1"
   local Field="$2"
   shift 2

   if [[ $1 = = ]] ; then
      shift
      [[ $# = 1 ]] || { :error "No rhs on assignment"; return 1; }
      printf -v "$Instance" "%s" "$(jq -r ".$Field |= $1" <<< "${!Instance}")"
   else
      jq -r ".$Field" <<< "${!Instance}"
   fi
}

::CallInstanceFunction()
{
   local FunctionName="$1"
   local Instance="$2"
   shift 2

   .. $Instance
   $FunctionName $Instance "$@"
}
