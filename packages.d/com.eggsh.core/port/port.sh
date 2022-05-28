#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:port_is_used()
{
   if [[ $_WHOAMI != root ]]; then
      :sudo_available || { echo "The user must have sudo access to run this command"; return 1; }

      sudo $_program :port is used "$@"
   fi

   local Options
   Options=$(getopt -o h:p: -l "host:,port:" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$Options"

   local Host='localhost'
   local Port='80'
   while true ; do
      case "$1" in
      -h|--host)     Host="$2"; shift 2;;
      -p|--port)     Port="$2"; shift 2;;
      --)            shift; break;;
      *)             break;;
      esac
   done

   (
      exec 73<>/dev/tcp/$Host/$Port
      local Status=$?
      exec 73>&-
      exec 73<&-
      exit $Status
   ) &>/dev/null
}

:port_is_available()
{
   if [[ $_WHOAMI != root ]]; then
      :sudo_available || { echo "The user must have sudo access to run this command"; return 1; }

      local STAT
      sudo $_program :port is available "$@"
      STAT=$?
      echo "STAT: $STAT" >&2
      return $STAT
   fi

   local Options
   Options=$(getopt -o h:p: -l "host:,port:" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$Options"

   local Host='localhost'
   local Port='80'
   while true ; do
      case "$1" in
      -h|--host)     Host="$2"; shift 2;;
      -p|--port)     Port="$2"; shift 2;;
      --)            shift; break;;
      *)             break;;
      esac
   done

   local -a ReservedServicePorts=()
   ReservedServicePorts=(
      $(
         grep -o "^[a-zA-Z0-9_-]\+\s*[0-9]\+/tcp" /etc/services |
         sed -r 's|[^ ]* *([0-9]*)/tcp|\1|' |
         sort -n
      )
   )

   # A non-zero status indicates the port is available
   # And, we also check that the port is not reserved
   ! :port_is_used -h "$Host" -p "$Port" && [[ (! " ${ReservedServicePorts[@]} " =~ " $Port ") ]]
}

:port_next_available()
{
   if [[ $_WHOAMI != root ]]; then
      :sudo_available || { echo "The user must have sudo access to run this command"; return 1; }

      sudo $_program :port next available "$@"
      return
   fi

   local Options
   Options=$(getopt -o h:p:m:M:sv: -l "host:,port:,min:,max:,system,variable:" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$Options"

   local Host='localhost'
   local -i Port=80
   local -i Min=1025
   local -i Max=32767
   local -i AllowedMin=1025
   local -i AllowedMax=32767
   local System=false
   local Var=

   while true ; do
      case "$1" in
      -h|--host)     Host="$2"; shift 2;;
      -p|--port)     Port="$2"; shift 2;;
      -m|--min)      Min="$2"; shift 2;;
      -M|--max)      Max="$2"; shift 2;;
      -s|--system)   System=true; shift;;
      -v|--variable) Var="$2"; shift 2;;
      --)            shift; break;;
      *)             break;;
      esac
   done

   # System ports must be explicitly allowed
   if $System; then
      AllowedMin=1
   fi

   # Check Min
   if [[ ! $Min =~ ^[1-9][0-9]*$ ]] || (( Min < AllowedMin || Min > AllowedMax )); then
      echo "Invalid minimum port: $Min (allowed minimum is $AllowedMin)"
      return 1
   fi

   # Check Max
   if [[ ! $Max =~ ^[1-9][0-9]*$ ]] || (( Max < AllowedMin || Max > AllowedMax )); then
      echo "Invalid maximum port: $Max (allowed maximum is $AllowedMax)"
      return 1
   fi

   local -i PortToCheck="$Min"
   while
      (( PortToCheck <= Max )) &&
      ! :port_is_available -h "$Host" -p "$PortToCheck"
   do
      (( PortToCheck++ ))
   done

   if (( PortToCheck == Max )); then
      return 1
   else
      if [[ -n $Var ]]; then
         printf -v "$Var" "%s" "$PortToCheck"
      else
         echo "$PortToCheck"
      fi

      return 0
   fi
}
