#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:package_order__INFO() { echo "Order packages"; }
:package_order__HELP()
{
   :man "
OPTIONS:
   -a|--arg <value>           Description [default: ]

DESCRIPTION:
   Description here

EXAMPLES:
   Example here                     : comment here
" | :highlight
}

:package_order()
{
   # Set package order context:
   #    . is the global context (no package qualifier)
   #    Any other value indicates a specific package name as the context
   local -i Index
   if [[ ${FUNCNAME[1]} = @ ]]; then
      Index=2
   else
      Index=1
   fi

   # Determine what '.' means: the global scope or, for __ORDER, the function's package scope
   if grep -q "::__ORDER$" <<<"${FUNCNAME[$Index]}"; then
      # We are called by a <packageName>::__ORDER function, so extract the <packageName>
      local PackageOrderContext="$(LC_ALL=C sed 's|::__ORDER||' <<<"${FUNCNAME[1]}")"
   else
      local PackageOrderContext="."
   fi

   local -r OPTIONS=$(getopt -o icp:1: -l "ignorecache,cache,package:,first:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local -a Packages=()
   local IgnoreCache=false
   local Cache=false
   while true ; do
      case "$1" in
      -i|--ignorecache) IgnoreCache=true; shift;;
      -c|--cache)       Cache=true; shift;;

      -p|--package)     [[ $2 =~ ^[a-zA-Z0-9.-]+$ ]] ||
                           { echo "Invalid package name: $2"; return 1; }
                        if [[ $2 = '.' ]]; then
                           Packages+=("$PackageOrderContext")
                        else
                           Packages+=("$2")
                        fi
                        shift 2;;
      -1|--first)       PackageOrderContext="$2"; shift 2;;
      --)               shift; break;;
      esac
   done

   local Package
   if [[ -n ${__OrderedPackages["$PackageOrderContext"]} ]] && ! $IgnoreCache && ! $Cache; then
      :package_order,List "$PackageOrderContext"
      return 0
   fi

   unset OrderedList
   local -A OrderedList
   local -a IndexedList=()
   local -i Index=0
   local -i SpecifiedIndex=0

   # First, add command-line packages (-p <package>) to the ordered list
   # Note: calls from a function are not affected by command-line packages
   if [[ ${#__CommandLinePackages[@]} -gt 0 ]] && [[ $PackageOrderContext = '.' ]]; then
      for Package in "${__CommandLinePackages[@]}"; do
         if [[ ! -n ${OrderedList["$Package"]} ]] && [[ -n ${__UnorderedPackages["$Package"]} ]]; then
            OrderedList["$Package"]=$Index
            IndexedList[$Index]="$Package"
            ((++Index))
         fi
      done
      SpecifiedIndex=$Index
   fi

   # Next, add the global scope only if (1) at the global scope
   # and (2) if specific positioning for the global scope is not specified
   if [[ $PackageOrderContext = '.' ]] && [[ ! " ${Packages[@]} " =~ ' . ' ]]; then
      OrderedList['.']=$Index
      IndexedList[$Index]='.'
      ((++Index))
   fi

   # Next, add function-option packages to the ordered list
   if [[ ${#Packages[@]} -gt 0 ]]; then
      local Extra=
      if [[ $PackageOrderContext != '.' ]]; then
         Extra="$PackageOrderContext"
      fi

      for Package in $Extra "${Packages[@]}"; do
         if [[ ! -n ${OrderedList["$Package"]} ]] && [[ -n ${__UnorderedPackages["$Package"]} ]]; then
            OrderedList["$Package"]=$Index
            IndexedList[$Index]="$Package"
            ((++Index))
         fi
      done
      SpecifiedIndex=$Index
   fi

   # Next, add any packages that are left in the unordered list
   for Key in "${!__UnorderedPackages[@]}"; do
      if [[ ! -n ${OrderedList["$Key"]} ]] && [[ $Key != '.' ]] && [[ $Key != $_corePackage ]]; then
         OrderedList["$Key"]=$Index
         IndexedList[$Index]="$Key"
         ((++Index))
      fi
   done

   # Last, add . and the core package
   for Key in '.' "$_corePackage"; do
      if [[ ! -n ${OrderedList["$Key"]} ]]; then
         OrderedList["$Key"]=$Index
         IndexedList[$Index]="$Key"
         ((++Index))
      fi
   done

   __OrderedPackages["$PackageOrderContext"]="${IndexedList[@]}"

   if $Cache; then
      if [[ $PackageOrderContext = '.' ]] ; then
         if [[ $SpecifiedIndex -gt 0 ]]; then
            if [[ -f $__OrderedPackagesFile ]]; then
               LC_ALL=C sed -i '/:package_order/d' "$__OrderedPackagesFile"
            fi

            {
            echo -n ":package_order"
            for Package in ${IndexedList[@]:0:SpecifiedIndex}; do
               echo -n " -p $Package"
            done
            echo
            } >> "$__OrderedPackagesFile"
         fi
      else
         if [[ -f $__OrderedPackagesFile ]]; then
            LC_ALL=C sed -i "/__OrderedPackages\['$PackageOrderContext'\]/d" "$__OrderedPackagesFile"
         fi

         echo "__OrderedPackages['$PackageOrderContext']='${IndexedList[@]}'" >> "$__OrderedPackagesFile"
      fi
   fi

   :package_order,List "$PackageOrderContext"
}

:package_order,List()
{
   [[ ${#__ListPackageOrder[@]} -gt 0 ]] || return 0
   if [[ " ${__ListPackageOrder[@]} " =~ ' all ' ]]; then
      __ListPackageOrder=("${!__OrderedPackages[@]}")
   fi

   local -i FunctionWidth=$(printf "%s\n" "${__ListPackageOrder[@]}" | wc -L)+1

   for Package in "${__ListPackageOrder[@]}"; do
      [[ -n ${__OrderedPackages["$Package"]} ]] || continue

      Ordering=${__OrderedPackages["$Package"]}
      printf "%-*s : %s\n" "$FunctionWidth" "$Package" "$Ordering" | :highlight

   done
}

:package__STARTUP()
{
   unset _packageDirs
   local -Ag _packageDirs

   # Allow ** searching
   local ResetGlobstar=$(shopt -p globstar)
   local ResetNullglob=$(shopt -p nullglob)
   shopt -s globstar nullglob

   cd "$_sourceDir"
   local Package Errors=
   while IFS= read -r Dir; do
      Package="$(basename "$Dir")"
      if [[ -z ${_packageDirs["$Package"]} ]]; then
         _packageDirs["$Package"]="$Dir"
      else
         Errors+="$Package: ${_packageDirs["$Package"]}\n$Package: $Dir"
      fi
   done <<<"$(/bin/ls -1d $_sourceDir/**/$_PACKAGES_DIR/*)"

   # Reset to previous settings
   $ResetNullglob
   $ResetGlobstar

   [[ -z $Errors ]] ||
   {
      echo "Identically-named packages are not allowed:"
      echo -e "$Errors" | column -t | LC_ALL=C sed 's|^|   |'
      return 1
   }
}

:package_prefix()
{
   local Package="$1"
   if [[ -n ${__UnorderedPackages[$Package]} ]]; then
      if [[ $Package = '.' ]]; then
         return 0
      else
         printf "%s" "$Package::"
      fi
   else
      return 1
   fi
}

:package_list()
{
   local Package
   for Package in ${!__UnorderedPackages[@]}; do
      if [[ $Package != '.' ]]; then
         echo "$Package"
      fi
   done | LC_ALL=C sort
}
