#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

::Init()
{
   _BLACK="$(tput setaf 0)"
   _RED="$(tput setaf 1)"
   _GREEN=$(tput setaf 2)
   _YELLOW=$(tput setaf 3)
   _BLUE=$(tput setaf 4)
   _MAGENTA=$(tput setaf 5)
   _CYAN=$(tput setaf 6)
   _WHITE=$(tput setaf 7)

   _NORMAL=$(tput sgr0)
   _BOLD=$(tput bold)
   _REVERSE=$(tput smso)
   _UNDERLINE=$(tput smul)
   _UNDERLINE_ON=$(tput smul)
   _UNDERLINE_OFF=$(tput rmul)

   _BG_YELLOW=$(printf '\e[48;5;%dm' 226)
   _BG_RED=$(printf '\e[48;5;%dm' 160)
   _BG_GREEN=$(printf '\e[48;5;%dm' 40)

   _ECHO_TO_LOG=false
   _HOSTNAME=$(hostname | :sed 's/\..*//')
   _VERBOSENESS=2
   local -gx _WHOAMI="$(whoami)"

   if :function_exists :build_get_release_name; then
      _releaseName=$(:build_get_release_name)
   else
      _releaseName=
   fi
}

::InitBuildCache()
{
   echo "Compiling $__ functions..." >&2

   # Disable interrupts
   trap '' INT

   local -Ag __FunctionPath __FunctionOrder
   local -ig __FunctionIndex=0
   local -ag __StartupFunctions __ShutdownFunctions

   # Remove existing compiled files
   rm -f "$__CacheScriptsFile" "$__CacheFunctionsFile" "$__UnorderedPackagesFile"

   # Gather the absolute paths of all package.d directories
   local -a __PackagesDDirs=()
   ::InitBuildCache,GetPackageDDirs

   # Perform pre-compilation initialization
   > "$__CacheAnnotationsFile"
   echo "#!/bin/bash" > "$__CacheScriptsFile"
   echo "declare -A __UnorderedPackages" > "$__UnorderedPackagesFile"

   # Iterate over all files that are concatenated to form the cache file.
   local __PackagesDDir
   cd "$_releaseDir"
   for __PackagesDDir in "${__PackagesDDirs[@]}" ; do
      ::init_BuildCacheForPackagesDDir
   done

   # Perform post-compilation finalization
   echo "__UnorderedPackages['.']='true'" >> "$__UnorderedPackagesFile"

   ::InitBuildCache,ProcessAnnotations          # Process collected annotations
   ::InitBuildCache,GenerateFunctionsToPath     # Generate map of functions to path
   ::InitBuildCache,GenerateStartup             # Generate function to execute startup functions
   ::InitBuildCache,GenerateShutdown            # Generate function to execute shutdown functions

   trap INT                                     # Clear
}

::InitBuildCache,GetPackageDDirs()
{
   if [[ $_distributionType = source ]] ; then
      # If the distribution is a source distribution, then assume that
      # all source projects are at the same directory level and the package directories
      # will be directly under them.
      readarray -t __PackagesDDirs < <(
         cd "$_sourceDir"
         find * -mindepth 1 -maxdepth 1 -name "$_PACKAGES_DIR" -type d -exec readlink -f "{}" \;
      )
   else
      # If the distribution is a release distribution, then there will be only a packages directory.
      __PackagesDDirs=( "$_packagesDir" )
   fi
}

::InitBuildCache,GenerateStartup()
{
   # Generate function to execute all startup functions
   cat >> "$__CacheScriptsFile" << EOF

# Generated

::CallStartupFunctions()
{
   local -a StartupFunctions=(
$(
   for I in "${__StartupFunctions[@]}" ; do
      echo "      '$I'"
   done
)
   )

   local I
   for I in "\${StartupFunctions[@]}"; do
      if :function_exists "\$I"; then
         "\$I" || Parser_ReturnStatus=1
      fi
   done

   return \$Parser_ReturnStatus
}
EOF
}

::InitBuildCache,GenerateShutdown()
{
   # Generate function to execute all shutdown functions
   cat >> "$__CacheScriptsFile" << EOF

# Generated

::CallShutdownFunctions()
{
   local -a ShutdownFunctions=(
$(
   for I in "${__ShutdownFunctions[@]}" ; do
      echo "      '$I'"
   done
)
   )

   local I
   for I in "\${ShutdownFunctions[@]}"; do
      if :function_exists "\$I"; then
         "\$I" || Parser_ReturnStatus=1
      fi
   done

   return \$Parser_ReturnStatus
}
EOF
}

::InitBuildCache,ProcessAnnotations()
{
   # Process Annotations
   if [[ -s $__CacheAnnotationsFile ]]; then
      # cat "$__CacheAnnotationsFile"
      true
   fi
}

::InitBuildCache,GenerateFunctionsToPath()
{
   # Generate Functions to Path Mapping
   echo "declare -A __FunctionPath" > "$__CacheFunctionsFile"
   local I
   for I in "${!__FunctionPath[@]}" ; do
      echo "${__FunctionOrder[$I]} $I ${__FunctionPath[$I]}"
   done | LC_ALL=C sort -nf | :sed -e 's|^[^ ]* ||' -e "s|^\([^ ]*\) *\(.*\)|__FunctionPath['\1']='\2'|" >> "$__CacheFunctionsFile"
}


::init_BuildCacheForPackagesDDir()
{
   local -a __Dirs __Packages=() __Components=() __Units=() __Files=()
   local    __Dir  __Package     __Component     __Unit     __File
   local           __PackagePath __ComponentPath __UnitPath __FilePath __FileDir
   local __ComponentPathRelative __UnitPathRelative __FilePathRelative

   local __FunctionDir __PackageAsVar __ComponentAsVar __UnitAsVar
   local -A __ComponentPaths

   # Get the directories directly under $PackagesBaseDir
   local -a __Dirs=()
   readarray -t __Dirs < <(
      cd "$__PackagesDDir"
      find . -mindepth 1 -maxdepth 1 -type d  | # directories directly under $__PackagesDDir
      sed 's|^\./||' |                          # remove the leading ./ from the find results
      LC_ALL=C sort                             # sort the results
   )

   # Packages are those directories that are FQDNs
   local __Dir
   for __Dir in "${__Dirs[@]}"; do
      if :is_fqdn "$__Dir"; then
         __Packages+=( "$__Dir" )
      fi
   done

   local __TmpCacheFile=$(mktemp)

   # For each package in $__PackagesDDir, do...
   for __Package in "${__Packages[@]}"; do
      __PackageAsVar="$(printf '%s' "$__Package" | tr -c 'a-zA-Z0-9_' '_')"

      # Add this package to the list of unordered packages
      if ! grep -q "^__UnorderedPackages\['$__Package'\]='true'$" "$__UnorderedPackagesFile"; then
         echo "__UnorderedPackages['$__Package']='true'" >> "$__UnorderedPackagesFile"
      fi

      # Gather the package components
      readarray -t __Components < <(
         cd "$__PackagesDDir/$__Package"
         find . -mindepth 1 -maxdepth 1 -name '_*' -prune -o -type d -print | sed 's|^\./||'
      )

      shopt -s globstar nullglob
      for __Component in "${__Components[@]}"; do
         __ComponentAsVar="$(printf '%s' "$__Component" | tr -c 'a-zA-Z0-9_' '_')"
         __ComponentPaths[$__Package/$__Component]=true
         
         readarray -t __Units < <(
            cd "$__PackagesDDir/$__Package/$__Component"
            find . -mindepth 1 -maxdepth 1 -name '_*' -prune -o -print | sed 's|^\./||'
         )

         for __Unit in "${__Units[@]}"; do
            __UnitAsVar="$(printf '%s' "$__Unit" | tr -c 'a-zA-Z0-9_' '_')"
            readarray -t __Files < <(
               find "$__PackagesDDir/$__Package/$__Component/$__Unit" -name '_*' -prune -o -type f -name '*.sh' -print
            )

            # Absolute Paths
            __PackagePath="$__PackagesDDir/$__Package"
            __ComponentPath="$__PackagePath/$__Component"
            __UnitPath="$__ComponentPath/$__Unit"
            __FileDir="$(dirname "$__File")"

            # Relative Paths
            __ComponentPathRelative="$__Package/$__Component"
            __UnitPathRelative="$__ComponentPathRelative/$__Unit"
            __UnitName="$(tr -c '[a-zA-Z0-9_]' '_' <<<"$__Unit")"

            for __File in "${__Files[@]}"; do
               __FilePathRelative="$(dirname "${__File#$__PackagesDDir/}")" 
               __FunctionDir="$(dirname "$__File")"
               ::init_BuildCacheAddFile
            done
         done
      done
   done

   [[ ! -f $__TmpCacheFile ]] || rm -f "$__TmpCacheFile"

   cat > "$__ComponentsFile" << xxxENDxxx
#!/bin/bash
declare -A __ComponentPaths
$(
   for __ComponentPath in ${!__ComponentPaths[@]}; do
      echo "__ComponentPaths[$__ComponentPath]=true"
   done | LC_ALL=C sort
)
xxxENDxxx
}

::init_BuildCacheAddFile()
{
   # Process replacements of idioms
   local __VarPackage="$(tr -c '[a-zA-Z0-9_]' '_' <<<"${__Package}")"
   local __VarComponent="$(tr -c '[a-zA-Z0-9_]' '_' <<<"${__VarPackage}__$__Component")"
   local __VarFile
   printf -v __VarFile '%s' "$(sed 's|/|___|' <<<"${__FilePathRelative%.sh}" | sed 's|/|___|' | tr -c '[a-zA-Z0-9_]' '_')"

   local CustomComponentScopedMarker=$'____CUST_COMP_VAR____'
   local ThisComponentScopedMarker=$'____THIS_COMP_VAR____'

   local ThisFileScopedMarker=$'____THIS_FILE_VAR____'

   local CustomPackageFunctionScopedMarker=$'____CUST_FUNC_VAR____'
   local ThisPackageFunctionScopedMarker=$'____THIS_FUNC_VAR____'

   {
      echo
      echo "# source $__File"

      sed "
         s#\(^\|[^\]\)(++:\([^:)]*\))#\1(+:$_corePackage:\2)#
      " "$__File" |

      sed "
         s#\(^\|[^\]\)(@@)_#\1${_corePackageAsVar}__#g
         s#\(^\|[^\]\)(@@)#\1$_corePackage#g
         s#\(^\|[^\]\)(+:\([^:)]\+\))::#\1$__Package:\2::#g
         s#\(^\|[^\]\)(+:\([^:)]\+\))_#\1${__PackageAsVar}___\2__#g
         s#\(^\|[^\]\)(+:\([^:]\+\):\([^)]\+\))::#\1\2:\3::#g
         s#\(^\|[^\]\)(-)::#\1${__Package}:${__Component}:${__Unit}::#g
         s#\(^\|[^\]\)(-)_#\1${__PackageAsVar}___${__ComponentAsVar}___${__UnitAsVar}__#g
         s#\(^\|[^\]\)(-:\([^:)]\+\))::#\1$__Package:$__Component:\2::#g
         s#\(^\|[^\]\)(-:\([^:)]\+\))_#\1${__PackageAsVar}___${__ComponentAsVar}___\2__#g
         s#\(^\|[^\]\)(@/)#\1$__PackagePath#g
         s#\(^\|[^\]\)(+/)#\1$__ComponentPath#g
         s#\(^\|[^\]\)(/)#\1$__FileDir#g
         s#\(^\|[^\]\)(=)#\1$__File#g
      " |

      # PACKAGE-SCOPED VAR
      # (@:<package.name>)_<var_name> to <package_name>__<var_name>
      awk -v RS='(^|[^\\\\])\\(@:[^)]+\\)_' -v Separator="__" '
         {ORS=gensub(/\(@:|\s*\)_/,"","g",gensub(/\./,"_","g",RT) Separator)}
         1' | sed 's|__$||' |

      # COMPONENT-SCOPED VAR
      # (+:<component>)_<var_name> to <package_name>___<component_name>___<var_name>
      awk -v RS='(^|[^\\\\])\\(\\+:[^)]+\\)_' -v Separator="$CustomComponentScopedMarker" '
         {ORS=gensub(/:/, "___", "g", gensub(/\(\+:|\s*\)_/,"","g",gensub(/\./,"_","g",RT) Separator))}
         1' | sed "s|$CustomComponentScopedMarker$||" |

      :sed "
         # Begin by removing any leading comments in the file
         /^\s*#/d
         /^\s*$/d

         # Now, perform the recurring transformations on the rest of the file
         :rest

         # Beginning of line transforms
         s|^@\s\+|$__Package::|
         s|^+\s\+|$__Package:$__Component::|
         s|^-\s\+|$__Package:$__Component:$__Unit::|

         s#\(^\|[^\]\)(@)_#\1${__VarPackage}_#g
         s#\(^\|[^\]\)(@)#\1$__Package#g

         s#\(^\|[^\]\)(+):#\1$__Package:$__Component:#g

         s#\(^\|[^\]\)(\.)_#\1${ThisPackageFunctionScopedMarker}_#g
         s#\(^\|[^\]\)(+)_#\1${__VarComponent}_#g
         s#\(^\|[^\]\)(-)_#\1${__VarFile}_#g

         s#\(^\|[^\]\)(@:\([^)]\+\))/#\1\2/#g

         # Package scope custom function: (@:com.acme)::func_name
         s#\(^\|[^\]\)(@:\([^)]\+\))\($\|\([^_\\]\)\|\\\\\(.\)\)#\1\2\4\5#g

         # Escaped idioms
         s#\\\\(@)#(@)#g
         s#\\\\(@:\([^)]*\))#(@:\1)#g
         s#\\\\(@@)#(@@)#g
         s#\\\\(+)#(+)#g
         s#\\\\(+\(+\?\):\([^)]*\))#(+\1:\2)#g
         s#\\\\(-)#(-)#g
         s#\\\\(-:\([^)]*\))#(-:\1)#g
         s#\\\\(\.)#(.)#g
         s#\\\\(@/)#(@/)#g
         s#\\\\(+/)#(+/)#g
         s#\\\\(/)#(/)#g
         s#\\\\(=)#(=)#g
         s#\\\\\((@:[^)]*):\)#\1#g
         s#\\\\\((@:[^)]*)_\)#\1#g
         s#\\\\\((+:[^)]*)_\)#\1#g
         s#\\\\\((-:[^)]*)_\)#\1#g

         # Grab the next line and continue processing the rest of the file
         n
         b rest
         " |
      awk \
         -v Marker="$ThisPackageFunctionScopedMarker" \
         -v AnnotFile="$__CacheAnnotationsFile" \
         -v Package="$__Package" \
         -v File="$__File" \
         -v FilePathRelative="$__FilePathRelative" \
      '
      # Some utility functions
      function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
      function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
      function trim(s) { return rtrim(ltrim(s)); }

      # Does a line begin with the annotation operator?
      /^\^/ {
         # If this is a new contiguous annotation, increment functionVariationIndex
         if (annotIndex == 0) functionVariationIndex++
         annotIndex++
         if (match($0, /<<([a-zA-Z0-9_]+)$/, endMark))
         {
            sub(/<<[a-zA-Z0-9_]+$/, "")
            annotText[annotIndex] = ""
            while ((getline nextLine) > 0)
            {
               annotText[annotIndex] = annotText[annotIndex] nextLine "\n"

               if (nextLine ~ endMark[1])
                  break
            }
            annotTextMarker[annotIndex] = endMark[1]
         }
         else
         {
            annotText[annotIndex] = ""
            annotTextMarker[annotIndex] = ""
         }

         annotArgs[annotIndex] = substr($0, 2)
         next
      }
      # Is the line following an annotation a function definition?
      /^[a-zA-Z_:]+\s*(\s*)/ && annotIndex {
         ind = match($0, "[[:space:](]");
         fname = trim(substr($0, 1, ind-1))
         for (i = 1; i <= annotIndex; i++)
         {
            if (length(annotText[i]) == 0)
                print "::annotateFunction " fname " " fname "^" functionVariationIndex " " trim(annotArgs[i]) >> AnnotFile
            else
            {
               print "::annotateFunction --text " fname " " fname "^" functionVariationIndex " " trim(annotArgs[i]) " <<" annotTextMarker[i] >> AnnotFile
               printf "%s", gensub(Marker, gensub(/[^a-zA-Z0-9_]/, "_", "g", fname) "_", "g", annotText[i]) >> AnnotFile
            }
         }
         print fname "^" functionVariationIndex substr($0, ind);
         annotIndex = 0;
         next;
      }
      {  if (annotIndex != 0)
         {
            for (i = 1; i <= annotIndex; i++)
            {
               if (substr(annotArgs[i], 1, 1) == "@")
               {
                  if (length(annotText[i]) == 0)
                     print "::annotatePackage " Package " " trim(substr(annotArgs[i], 2)) >> AnnotFile
                  else
                  {
                     print "::annotatePackage --text " Package " " trim(substr(annotArgs[i], 2)) " <<" annotTextMarker[i] >> AnnotFile
                     print annotText[i] >> AnnotFile
                  }
               }
               else if (substr(annotArgs[i], 1, 1) == "+")
               {
                  if (length(annotText[i]) == 0)
                     print "::annotateComponent " FilePathRelative " " trim(substr(annotArgs[i], 2)) >> AnnotFile
                  else
                  {
                     print "::annotateComponent --text " FilePathRelative " " trim(substr(annotArgs[i], 2)) " <<" annotTextMarker[i] >> AnnotFile
                     print annotText[i] >> AnnotFile
                  }
               }
               else if (substr(annotArgs[i], 1, 1) == "-")
                  if (length(annotText[i]) == 0)
                     print "::annotateFile " File " " trim(substr(annotArgs[i], 2)) >> AnnotFile
                  else
                  {
                     print "::annotateFile --text " File " " trim(substr(annotArgs[i], 2)) " <<" annotTextMarker[i] >> AnnotFile
                     print annotText[i] >> AnnotFile
                  }
               else
               {
                  print "Invalid annotation in file: " File > "/dev/stderr"
                  print "   " trim(annotArgs[i]) > "/dev/stderr"
               }
            }
            functionVariationIndex--
            annotIndex = 0
         }

         if (substr($0,1,2) == "\\^")
            print substr($0,2)
         else
            print
      }
      '
   } > "$__TmpCacheFile"

   # Files beginning with : are not subject to function modification
   if [[ $(basename "$__File" | cut -c1) = : ]]; then
      cat "$__TmpCacheFile" >> "$__CacheScriptsFile"
   else
      local -ag FunctionNames
      FunctionNames=(
         $(
            bash <(cat "$_bootstrapDir/alias.sh"; cat "$__TmpCacheFile"; echo 'declare -F') 2>&1 |
            grep '^declare -f' |
            :sed 's|.* ||'

            # If an error is detected, provide some helpful feedback
            if [[ $? -ne 0 ]]; then
               echo "No functions or error detected in file: $__File" >&2
               { cat "$_bootstrapDir/alias.sh"; cat "$__TmpCacheFile"; } | cat -nv >&2
               bash <(cat "$_bootstrapDir/alias.sh"; cat "$__TmpCacheFile"; echo 'declare -F') >&2
            fi
         )
      )

      local Function FunctionVarThis
      for FunctionName in "${FunctionNames[@]}"; do
         if Function="$(
            bash <(
               cat "$_bootstrapDir/alias.sh"
               cat "$__TmpCacheFile"
               echo "declare -f $FunctionName"
            ) 2>/dev/null |
            {
               if [[ $FunctionName =~ ^[^:].*:: ]]; then
                  FunctionVarThis="$(
                     sed -e "s|::|::_${__Component}___${__UnitName}_|" \
                         -e 's|\^.*||' -e 's|[^a-zA-Z0-9_]|_|g' <<<"$FunctionName"
                  )_"
               else
                  FunctionVarThis="$(
                     sed -e 's|\^.*||' -e 's|[^a-zA-Z0-9_]|_|g' <<<"$FunctionName"
                  )_"
               fi
               sed \
                  -e "s|$CustomComponentScopedMarker|__|g" \
                  -e "s|$ThisPackageFunctionScopedMarker|$FunctionVarThis|g"
            }
         )" ; then
            echo "$Function" >> "$__CacheScriptsFile"
         else
            echo "Function '$FunctionName' contains special characters and must be placed in a file beginning with a :" >&2
            echo "FILE: $__File" >&2
         fi
      done
   fi

   local FunctionName
   for FunctionName in $(
      bash <(cat "$_bootstrapDir/alias.sh"; cat "$__TmpCacheFile"; echo "typeset -F") 2>&1 |
      grep '^declare -f' |
      :sed 's|.* ||'
      )
   do
      if (  # Unqualified Function: <function_name>
            [[ $FunctionName =~ ^:?[a-z_][a-z0-9_]*(__STARTUP|__SHUTDOWN)?$ ]] ||
            # Package Function: <top-level.domain.name>::<function_name>
            [[ $FunctionName =~ ^[a-z][a-z0-9.-]*:::?[a-z_][a-z0-9_]*(__STARTUP|__SHUTDOWN)?$ ]] ||
            # Method Names: <ClassName>:<method_name>
            [[ $FunctionName =~ ^:?[A-Z][a-zA-Z0-9_]*:[a-z_][a-z0-9_]*(__STARTUP|__SHUTDOWN)?$ ]]
         ) && [[ ! $FunctionName =~ ^:?help ]] ; then

         # The function name is going to be indexed

         # It is either a startup function
         if [[ $FunctionName =~ __STARTUP$ ]] ; then
            __StartupFunctions+=( "$FunctionName" )

         # Or it is a shutdown function
         elif [[ $FunctionName =~ __SHUTDOWN$ ]] ; then
            __ShutdownFunctions+=( "$FunctionName" )

         # Or it is a public function
         else
            __FunctionPath["$FunctionName"]=$(readlink -f "$__File")
            __FunctionOrder["$FunctionName"]=$__FunctionIndex
            ((__FunctionIndex++))
         fi
      fi
   done
}

::annotatePackage()
{
   if [[ $1 = '--text' ]]; then
      local __AnnotateTextInput=true
      shift
   else
      local __AnnotateTextInput=false
   fi

   local __AnnotatePackage="$1"
   shift

   # Remaining args are the package annotation command
}

::annotateComponent()
{
   if [[ $1 = '--text' ]]; then
      local __AnnotateTextInput=true
      shift
   else
      local __AnnotateTextInput=false
   fi

   local __AnnotateComponent="$1"
   shift

   # Remaining args are the component annotation command
}

::annotateFile()
{
   if [[ $1 = '--text' ]]; then
      local __AnnotateTextInput=true
      shift
   else
      local __AnnotateTextInput=false
   fi

   local __AnnotateFile="$1"
   shift

   # Remaining args are the file annotation command
}

::annotateFunction()
{
   if [[ $1 = '--text' ]]; then
      local __AnnotateTextInput=true
      shift
   else
      local __AnnotateTextInput=false
   fi

   local __AnnotateOriginalFunction="$1"
   local __AnnotateDefinedFunction="$2"
   shift 2

   # Remaining args are the function annotation command
}
