#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

help__INFO() { echo "How to get help on packages, components, and their commands"; }
help__HELP()
{
   :man -t "Overview on Help" -a "[OPTIONS] [<partialCommand>] ..." "
OPTIONS:
   -g                               ^Show the guide for the primary package
                                    This is the same as doing: <b>-p ${_settings[\".\".primary_package]}</b>

   -p|--package <package>           ^Show package-specific help
   -c|--component <component> ...   ^Show component-specific help

   -l|--list                        ^List commands and components
   -b|--begins-with                 ^Limit search to commands that begin with the <partialCommand>

DESCRIPTION:
   This help page provides general information on how to use help.

   <h2>Package Help
      Help for the primary package is provided to be a top-level guide and includes important
      information for using <b>$__</b> functionality.

      <b>Packages</b> are reversed fully-qualified domain names (reverse FQDNs) using
      reverse domain-name notation commonly in use in the internet.

   <h2>Component Help
      <b>Components</b> are those directories directly under a package directory.
      Components provide a logical hierarchy of commands within a package.

      If the <b>-c</b> option is used, then listings are limited to just those commands
      found within the specified component.

   <h2>Listing Help
      If the <b>-l</b> option is used, then provide a list of commands.
      If the <b>-c</b> option is not used, then also list the available components.

   <h2>Partial Command Help
      If a <partialCommand> is given, a listing of all commands that include <partialCommand>
      are listed. If the <b>-b</b> flag is used, then a listing of all commands that begin with
      <partialCommand> are listed.
      If there is only one match, then help for that match is shown.

EXAMPLES:
   $__ help -g           ^: Show the guide for the primary package
   $__ help -l           ^: List commands
   $__ help show         ^: List all commands including 'show'
   $__ help deploy files ^: List help for the 'deploy files' command
   $__ help -b consul    ^: List commands beginning with 'consul'"
}

help()
{
   if [[ $# -eq 0 ]]; then
      help__HELP
      return
   fi

   local OPTIONS
   local -a Args=( "$@" )
   OPTIONS=$(getopt -o egp:c:lbsv -l "exact,guide,package:,component:,list,begins-with,system,verbose" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local -a Packages=()
   local -a PackagePrefixes=()
   local -a Components=()
   local -a ComponentCandidates=()
   local HasPackagesFilter=true
   local HasComponentsFilter=true
   local List=false
   local PrimaryPackage=
   local Verbose=false
   local ShowSystemHelp=false
   local BeginsWith=false
   local ExactMatchOnly=false

   while true ; do
      case "$1" in
      -g|--guide)
         PrimaryPackage="${_settings[\".\".primary_package]}"
         shift;;

      -p|--package)
         if [[ ! " ${Packages[@]} " =~ " $2 " ]]; then
            Packages+=( "$2" )
         fi
         shift 2;;

      -c|--component)
         if [[ ! " ${ComponentCandidates[@]} " =~ " $2 " ]]; then
            ComponentCandidates+=( "$2" )
         fi
         shift 2;;

      -l|--list)        List=true; shift;;
      -b|--begins-with) BeginsWith=true; shift;;
      -s|--system)      ShowSystemHelp=true; shift;;
      -e|--exact)       ExactMatchOnly=true; shift;;
      -v|--verbose)     Verbose=true; shift;;
      --)               shift; break;;
      esac
   done

   help,BuildPackagesList
   if [[ ${#Packages[@]} -eq 0 ]]; then
      Packages=( $(:package_list) )
      HasPackagesFilter=false
   fi
   help,BuildPackagePrefixesList || return

   help,BuildComponentsList || return
   if [[ ${#Components[@]} -eq 0 ]]; then
      HasComponentsFilter=false
   fi

   help,ShowComponentOrPackageHelp || return

   # Look for function matches
   if $ShowSystemHelp; then
      local -a CandidateFunctionList=( $(compgen -A function |
         sed -e '/__/d' -e '/^::/d' -e '/,/d' -e '/[A-Z]/d'))
   else
      local -a CandidateFunctionList=( $(compgen -A function |
         sed -e '/__/d' -e '/^:/d' -e '/,/d' -e '/[A-Z]/d' -e '/^[+@.]/d'))
   fi

   help,ReduceByPackageMatches
   help,ReduceByComponentMatches
   help,ReduceByWordMatches "$@"
   help,ReduceByNoHelp

   if [[ ${#CandidateFunctionList[@]} -eq 0 ]]; then
      if $ShowSystemHelp; then
         echo "No help for: $@"
         return 1
      else
         help -e -s "${Args[@]}"
         return
      fi
   fi

   # Is there just one match (and list mode is off)?
   if [[ ${#CandidateFunctionList[@]} -eq 1 ]]; then
      if ! $List && :function_exists ${CandidateFunctionList}__HELP; then
         if ! $ExactMatchOnly || [[ $CandidateFunctionList = $(tr ' ' '_' <<<"$@") ]]; then
            ${CandidateFunctionList}__HELP;
         fi
         return 0
      fi
   elif $ExactMatchOnly; then
      echo "No help for: $@"
      return 1
   fi

   {
   echo "\n<h1>Commands"

   local -i FunctionWidth=$(printf "%s\n" "${CandidateFunctionList[@]}" | sed 's|^[^:]*::||' | wc -L)+1
   local Package=' '
   local NoAdditionalHelpFound=false
   local Function DisplayFunction NewPackage
   for Function in $(
         printf "%s\n" "${CandidateFunctionList[@]}" | grep "^[^:]*::" | LC_ALL=C sort
         printf "%s\n" "${CandidateFunctionList[@]}" | grep -v "^[^:]*::" | LC_ALL=C sort
         ); do
      DisplayFunction="$(sed -e 's|^[^:]*::\(.*\)|\1|' -e 's|_| |g' <<<"$Function")"
      NewPackage="$(
         PackageName="$(sed 's|^\([^:]*\)::.*|\1|' <<<"$Function")"
         [[ $PackageName = $Function ]] && PackageName=
         echo "$PackageName"
         )"
      if [[ $NewPackage != $Package ]]; then
         if [[ -n $NewPackage ]]; then
            echo "\nPACKAGE $NewPackage:"
         else
            echo "\nSYSTEM COMMANDS:"
         fi
         Package="$NewPackage"
      fi
      if :function_exists ${Function}__INFO; then
         if :function_exists ${Function}__HELP; then
            Info="^ $(${Function}__INFO)"
         else
            Info="^*$(${Function}__INFO)"
            NoAdditionalHelpFound=true
         fi
      else
         Info=
      fi
      printf "  %-*s %s\n" $FunctionWidth "$DisplayFunction" "$Info"
   done

   echo "\n   For command-specific help, type: <b>$__ help</b>, followed by the full command phrase"
   if $NoAdditionalHelpFound; then
      echo " * Commands marked with an asterisk have no additional help"
   fi

   if $List && [[ ${#ComponentCandidates[@]} -eq 0 ]]; then
      echo "\n<h1>Components\n"
      tr ' ' '\n' <<<"${!__ComponentPaths[@]}" | sed 's|.*/||' | LC_ALL=C sort -u | column | sed -e 's|^|  |' -e 's|$|^|'
   fi
   } | :highlight
}

help,BuildPackagesList()
{
   # Build the Packages list
   local Package
   if [[ -n $PrimaryPackage ]]; then
      # Ensure $PrimaryPackage is not included before adding it to the front
      Packages=( $PrimaryPackage $(
         for Package in "${Packages[@]}"; do
            if [[ $Package != $PrimaryPackage ]]; then
               echo "$Package"
            fi
         done
         )
      )
   fi
}

help,BuildPackagePrefixesList()
{
   # Build the PackagePrefixes list
   local Package Prefix
   for Package in "${Packages[@]}"; do
      Prefix="$(:package_prefix "$Package")"
      if [[ $? -ne 0 ]]; then
         echo "No such package: $Package"
         return 1
      fi
      if [[ -n $Prefix ]]; then
         PackagePrefixes+=( "$Prefix" )
      fi
   done
   PackagePrefixes+=( '' )
   return 0
}

help,BuildComponentsList()
{
   # Build the Components list
   local Candidate Found Package
   for Candidate in "${ComponentCandidates[@]}"; do
      Found=false
      if [[ -n ${__ComponentPaths[$Candidate]} ]]; then
         Components+=( "$Candidate" )
         Found=true
      else
         for Package in "${Packages[@]}"; do
            if [[ -n ${__ComponentPaths[$Package/$Candidate]} ]]; then
               Components+=( "$Package/$Candidate" )
               Found=true
            fi
         done
      fi
      if ! $Found; then
         echo "No such component: $Candidate"
         return 1
      fi
   done
   return 0
}

help,ShowComponentOrPackageHelp()
{
   # Package or Component help is to be shown if not explicitly requesting function listings
   # and if the Package or Component __HELP function is present.
   if ! $List && [[ $# -eq 0 ]]; then
      # Is Component-level help available?
      if [[ ${#Components[@]} -eq 1 ]]; then
         HelpFunction="$(sed "s|\(.*\)/\(.*\)|\1::component_\2__HELP|" <<<"${Components[0]}")"
         if :function_exists $HelpFunction; then
            $HelpFunction
            return
         fi
      fi
      if $HasPackagesFilter && [[ ${#Packages[@]} -eq 1 ]]; then
         HelpFunction="${PackagePrefixes[0]}package__HELP"
         if :function_exists $HelpFunction; then
            $HelpFunction
            return
         fi
      fi
   fi
   return 0
}

help,ReduceByPackageMatches()
{
   # Reduce the matches to only those that match a package
   local PackagePrefix
   if $HasPackagesFilter; then
      CandidateFunctionList=( $(
            for PackagePrefix in "${PackagePrefixes[@]}"; do
               if [[ -n $PackagePrefix ]]; then
                  grep "^$PackagePrefix" <<<"$(printf "%s\n" "${CandidateFunctionList[@]}")"
               fi
            done
         )
      )
   fi
}

help,ReduceByComponentMatches()
{
   local Component Function Functions
   # Reduce the matches to only those that match a component
   if $HasComponentsFilter; then
      Functions=( $(
         for Component in "${Components[@]}"; do
            declare -p __FunctionPath | sed -e 's|\[|\n&|g' | grep "^\[.*\]=.*$Component" |
               sed 's|^\[\([^]]*\)\].*|\1|'
         done
         )
      )
      CandidateFunctionList=( $(
         for Function in "${Functions[@]}"; do
            grep "$Function" <<<"$(printf "%s\n" "${CandidateFunctionList[@]}")"
         done
         )
      )
   fi
}

help,ReduceByWordMatches()
{
   local Prefix
   # Reduce the matches to only those that match any words provided
   if [[ $# -gt 0 ]]; then
      local -g Prefix
      :string_join -v Prefix -d '_' "$@"
      if [[ " ${CandidateFunctionList[@]} " =~ ' '.*::"$Prefix " ]]; then
         CandidateFunctionList=(
            $(
               grep "$Prefix$" <<<"$(printf "%s\n" "${CandidateFunctionList[@]}")"
            )
         )
      fi
      if ! $BeginsWith ; then
         Prefix="*$Prefix"
      fi

      # Convert glob to regex
      if [[ $Prefix =~ '*' ]]; then
         Prefix="$(sed 's|\*|.*|g' <<<"$Prefix")"
         if [[ ${Prefix:0:1} = '^' ]]; then
            Prefix="^[^:]*::${Prefix:1}\|$Prefix"
         else
            Prefix="^[^:]*::$Prefix\|$Prefix"
         fi
      else
         Prefix="^[^:]*::$Prefix\|^$Prefix"
      fi
      CandidateFunctionList=( $(
            grep "$Prefix" <<<"$(printf "%s\n" "${CandidateFunctionList[@]}")"
         )
      )
   fi
}

help,ReduceByNoHelp()
{
   CandidateFunctionList=(
      $(
      for Function in "${CandidateFunctionList[@]}"; do
         if ! :function_exists "${Function}__NOHELP"; then
            echo "$Function"
         fi
      done
      )
   )
}
