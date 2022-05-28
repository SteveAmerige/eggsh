#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:JSON:()
{
   :method

   printf -v "$info" "%s" '{}'

   $this:option -raw
   $this:option +envsubst

   $this:property array.ifs      ':'
   $this:property error.prefix   ''
   $this:property error.stack    false
   $this:property error.suffix   ''
   $this:property filter.tokey   selector
   $this:property match.type     exact
   $this:property save.prefix    ''
   $this:property save.type      none

   local -r OPTIONS=$(getopt -o f: -l "file:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local -a Files=()

   while true ; do
      case "$1" in
      -f|--file)     Files+=("$2"); shift 2;;
      --)            shift; break;;
      esac
   done

   for File in "${Files[@]}"; do
      $this:property error.prefix "Invalid JSON: $File"
      $this:readfile "$File"
   done
}

:JSON:readfile()
{
   :method

   :try {
      :persist $this $info

      local -r OPTIONS=$(getopt -o p:s: -l "prefix:,select" -n "${FUNCNAME[0]}" -- "$@")
      eval set -- "$OPTIONS"

      local Prefix=
      local Select='.'
      while true ; do
         case "$1" in
         -p|--prefix)   Prefix="$2"; shift 2;;
         -s|--select)   Select="$2"; shift 2;;
         --)            shift; break;;
         esac
      done

      local Filename="$1" Text=
      [[ -f $Filename ]] ||
      {
         $this:property error.text "Problem:  ^No such file: $Filename"
         $(exit 1)
      }

      Text="$(LC_ALL=C sed 's|^\s*[#%].*||' "$Filename"|jq -r "$Select" 2>&1)" ||
      {
         $this:property error.text "Problem:  ^$Text"
         $(exit 1)
      }

      if [[ -n $Prefix ]]; then
         Text="$(jq -n --slurpfile in <(echo "$Text") '."'"$Prefix"'" |= $in[0]')"
      fi

      if $this:option envsubst ; then
         Text="$(envsubst <<<"$Text")"
      fi

      local TextType
      TextType="$(jq -r type <<<"$Text")"

      if [[ ${!this} = null ]] ; then
         printf -v "$this" "%s" "$Text"
         printf -v "$info" "%s" "$(jq -cr ".type |= \"$TextType\"" <<<"${!info}")"
      else
         local ThisType
         $this:info -v ThisType .type

         case "$ThisType-$TextType" in
         "object-object")
            printf -v "$this" "%s" "$(jq -s -r '.[0] * .[1]' <(echo "${!this}") <(echo "$Text"))"
            ;;
         "array-array")
            printf -v "$this" "%s" "$(echo "${!this} ${Text}" | jq -csr add)"
            ;;
         *)
            Text="Incompatible merge: $TextType into $ThisType for file: $Filename"
            $this:property error.text "$($this:property error.prefix)\n$Text"
            $(exit 1)
            ;;
         esac
      fi
   } :catch {
      Text="
$_RED$_UNDERLINE[ERROR] :json:readfile EXCEPTION $_tryStatus CAUGHT ON LINE $_tryErrorLine$_NORMAL

"
      if [[ -n $($this:property error.prefix) ]]; then
         $this:property -av Text error.prefix
      fi
      $this:property -av Text error.text
      if [[ -n $($this:property error.suffix) ]]; then
         $this:property -av Text error.suffix
      fi
      Text+="$(::stacktrace)"
      $this:property error.text "$Text"
      $this:property error.stack true

      return $_tryStatus
   }
   return 0
}

:JSON:info()
{
   :method

   local -r OPTIONS=$(getopt -o pv: -l "pretty,variable:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Var=
   local Pretty=false

   while true ; do
      case "$1" in
      -p|--pretty)   Pretty=true; shift;;
      -v|--variable) Var="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   if [[ -n $Var ]] ; then
      printf -v "$Var" "%s" "$(jq -cr "$*" <<<"${!info}")"
   elif $Pretty ; then
      jq -Sr "$*" <<<"${!info}"
   else
      jq -cr "$*" <<<"${!info}"
   fi
}

:JSON:get()
{
   :method

   local -r OPTIONS=$(getopt -o pv: -l "pretty,variable:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Var=
   local Pretty=false

   while true ; do
      case "$1" in
      -p|--pretty)   Pretty=true; shift;;
      -v|--variable) Var="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   if [[ -n $Var ]] ; then
      printf -v "$Var" "%s" "$(jq -cr "$*" <<<"${!this}")"
   elif $Pretty ; then
      jq -Sr "$*" <<<"${!this}"
   else
      jq -cr "$*" <<<"${!this}"
   fi
}

:JSON:option()
{
   :method

   local Option="$1" State=

   if [[ -z $Option ]] ; then
      return 1
   elif [[ ${Option:0:1} =~ ^[+-]$ ]] ; then
      if [[ ${Option:0:1} = + ]] ; then
         State=true
      else
         State=false
      fi
      Option="${Option:1}"
      printf -v "$info" "%s" "$(jq -cr ".option.\"$Option\" |= $State" <<<"${!info}")"
      return 0
   else
      State="$(jq -cr ".option.\"$Option\"" <<<"${!info}")"
   fi

   [[ $State = true ]]
}

:JSON:property()
{
   :method

   local -r OPTIONS=$(getopt -o ajpsv: -l "append,color,json,prepend,string,variable:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Append=false
   local Prepend=false
   local Type=string
   local Color=false
   local Var= Value Result
   while true ; do
      case "$1" in
      -a|--append)   Append=true; shift;;
      -j|--json)     Type=json; shift;;
      -p|--prepend)  Prepend=true; shift;;
      -s|--string)   Type=string; shift;;
      -v|--variable) Var="$2"; shift 2;;

      --color)       Color=true; shift;;
      --)            shift; break;;
      esac
   done

   case $# in
   2)
      if [[ $Type = string ]] ; then
         Value="$(LC_ALL=C sed 's|"|\\&|g' <<<"$2")"
         Value='"'"$Value"'"' || Value="$2"
      fi

      printf -v "$info" "%s" "$(jq -cr ".property.\"$1\" |= $Value" <<<"${!info}")"
      ;;
   1)
      Result="$(jq -cr ".property.\"$1\"" <<<"${!info}" 2>/dev/null; printf x)"; Result="${Result%x}"
      if [[ -n $Var ]] ; then
         if $Prepend; then
            Result="$Result${!Var}"
         fi
         if $Append; then
            Result="${!Var}$Result"
         fi
         printf -v "$Var" "%s" "$Result"
      else
         if $Color ; then
            echo -e "$Result" | :highlight
         else
            echo -e "$Result"
         fi
      fi
      ;;
   *)
      echo "Usage ${FUNCNAME[0]} <property> [ <value> ]"
      return 1;;
   esac
}

:JSON:dump()
{
   :method

   echo "##################################################"
   echo "Instance data:"
   $this:get -p .
   echo "Instance info:"
   $this:info -p .
   echo "##################################################"
}

:JSON:select()
{
   :method

   local DefaultProvided=false Default= Match= Raw=false ResultType= SpecifiedSaveKey= Status=0 ToString=false
   local ArgKey ArgVal Element Filter JQDefs Key MatchSrc MatchSucceeded Result SavePrefix Text
   local -a Args=() ResultTypes=() JQOptions=()

   :try {
      :persist $this $info

      if $this:option raw ; then
         JQOptions+=( "-r" )
         Raw=true
      fi

      local -r OPTIONS=$(getopt -o d:v: \
         -l "arg:,default:,key:,match:,raw,savetype:,savevar:,tostring,type:" \
         -n "${FUNCNAME[0]}" -- "$@")
      eval set -- "$OPTIONS"

      local SaveType="$($this:property save.type)"
      local SaveTypes="none positional associative variable"
      local SaveVar="$($this:property save.var)"
      while true ; do
         case "$1" in
         -d|--default)
            DefaultProvided=true
            Default="$2"
            shift 2;;

         -v|--savevar)
            SaveVar="$2"
            SaveType=variable
            shift 2;;

         --arg)
            [[ $2 =~ ^[a-zA-Z][a-zA-Z0-9_]*= ]] ||
            {
               $this:property error.text "Bad option: -a $2 (not <key>=<value>)"
               $(exit 1)
            }
            ArgKey="$(LC_ALL=C sed 's|^\([^=]*\)=.*$|\1|' <<<"$2")"
            ArgVal="$(LC_ALL=C sed 's|^[^=]*=\(.*\)$|\1|' <<<"$2")"
            Args+=("--arg" "$ArgKey" "$ArgVal")
            shift 2
            ;;

         --key) SpecifiedSaveKey="$2"; shift 2;;

         --match)
            Match="$2"
            MatchSrc="$2"
            if [[ $($this:property match.type) = exact ]]; then
               Match="^($Match)$"
            fi
            shift 2;;

         --raw)
            [[ " ${JQOptions[@]} " =~ ' -r ' ]] || { JQOptions+=( "-r" ); Raw=true; }
            shift;;

         --savetype)
            if [[ ! " $SaveTypes " =~ " $SaveType " ]] ; then
               $this:property error.text "Bad option: --savetype $2 (must be one of none|associative)"
               $(exit 1)
            fi
            SaveType="$2"
            shift 2;;

         --tostring) ToString=true; shift;;

         --type)
            if [[ ! " null boolean number string array object " =~ " $2 " ]] ; then
               $this:property error.text "Bad option: --type $2 (must be one of null|boolean|number|string|array|object)"
               $(exit 1)
            fi
            ResultTypes+=( "$2" )
            shift 2;;

         --) shift; break;;
         esac
      done

      Filter="${1:-.}"
      JQDefs='def value(f):((f|tojson)//error("__JSON_BAD_FILTER"))|fromjson;'

      Result="$(jq -c "${JQOptions[@]}" "${Args[@]}" "$JQDefs value($Filter)" <<<"${!this}" 2>&1)" || Status=$?

      # Check to see if the filter is invalid
      if [[ $Result =~ "__JSON_BAD_FILTER" ]] ; then
         Text="Filter failed: $Filter"
         if [[ ${#Args[@]} -gt 0 ]]; then
            Text+="\nOptions: ${Args[@]}"
         fi
         $this:property error.text "$($this:property error.prefix)\n$Text"
         $(exit $Status)
      fi

      # Check to see if the filter returns a valid null: it might be invalid for simple path selection
      if [[ $Status -eq 0 ]] &&
         [[ $Result = null ]] &&
         [[ $Filter = $(grep -P '^\.([a-zA-Z_]+|"[^"]*"|\[[0-9]+\]|\.)*$' <<<"$Filter") ]] ; then
         Parent="$(LC_ALL=C sed 's#^\(.*\)\(\[\|\.\|\."[^"]*"\).*$#\1#' <<<"$Filter")"
         Key="$(LC_ALL=C sed -e 's|[][]|\\&|g' <<<"$Parent")"
         Key="$(LC_ALL=C sed -e 's|^\.||' <<<"${Filter#$Key}")"
         if [[ $Key =~ ^\[ ]] ; then
            Key="$(LC_ALL=C sed 's|^\[\(.*\)\]$|\1|' <<<"$Key")"
         else
            Key='"'"$Key"'"'
         fi
         [[ -n $Parent ]] || Parent='.'
         if ! jq -re "$Parent" <<<"${!this}" >/dev/null 2>&1 ||
            [[ $(jq -r "$Parent|has($Key)" <<<"${!this}" 2>/dev/null) = false ]] ; then
            # No parent, nor key, so check if default exists
            # Otherwise, the null result is actually in the JSON data, so it's not an error
            if $DefaultProvided; then
               Result="$Default"
               Status=0
            else
               $this:property error.text "Problem:  ^${_RED}Missing required JSON entry: $Filter$_NORMAL"
               $(exit 1)
            fi
         fi
      fi

      # Is the result required to be a certain type?
      ResultType="$(jq -r 'type' <<<"$Result" 2>/dev/null)" || ResultType='string'
      if [[ ${#ResultTypes[@]} -gt 0 ]] ; then
         [[ " ${ResultTypes[@]} " =~ " $ResultType " ]] ||
         {
            $this:property error.text "Problem:  ^Requirement not met for JSON selection: $Filter
Requires: ^Type must be one of: ${ResultTypes[@]}
Value:    ^$_RED$Result$_NORMAL"
            $(exit 1)
         }
      fi

      # Is the result required to match a Perl-style/grep regular expression?
      if [[ -n $Match ]] ; then
         MatchSucceeded=true
         case $ResultType in
         array)
            for Element in $(jq "${JQOptions[@]}" '.[]' <<<"$Result"); do
               grep -qP "$Match" <<<"$Element" || MatchSucceeded=false
            done
            ;;
         *) grep -qP "$Match" <<<"$Result" || MatchSucceeded=false
            ;;
         esac

         $MatchSucceeded ||
         {
            Text="Problem:  ^Requirement not met for JSON selection: $Filter
Requires: ^$MatchSrc
Value:    ^$_RED$Result$_NORMAL"
            if [[ ${#Args[@]} -gt 0 ]]; then
               Text+="\nOptions: ${Args[@]}"
            fi
            $this:property error.text "$Text"
            $(exit 1)
         }
      fi

      if $ToString ; then
         case "$ResultType" in
         array)
            Result="$(jq "${JQOptions[@]}" '.[]' <<<"$Result" | tr '\n' ' ')";;
         *) ;;
         esac
      fi

      # Check if the result is not valid
      if [[ $Status -eq 0 ]] ; then
         if $this:option envsubst ; then
            Result="$(envsubst <<<"$Result")"
         fi

         if [[ " $SaveTypes " =~ " $SaveType " ]] ; then
            [[ -n $SaveVar ]] ||
            {
               Text="The save.var property is not defined and is required for associative selections"
               if [[ ${#Args[@]} -gt 0 ]]; then
                  Text+="\nOptions:  ${Args[@]}"
               fi
               $this:property error.text "$Text"
               $(exit 1)
            }
            :persist "$SaveVar"
         fi

         SavePrefix="$($this:property save.prefix)"
         case "$SaveType" in
         "positional")
            [[ -v $SaveVar ]] || local -ga "$SaveVar"
            readarray -t $SavePrefix$SaveVar <<<"$Result"
            ;;
         "associative")
            [[ -v $SaveVar ]] || local -gA "$SaveVar"

            if [[ -n $SpecifiedSaveKey ]] ; then
               SaveKey="$SpecifiedSaveKey"
            else
               FilterToKey="$($this:property filter.tokey)"
               case "$FilterToKey" in
               *) SaveKey="$Filter";;
               esac
            fi

            SaveVar="$SaveVar['$SavePrefix$SaveKey']"
            printf -v "$SaveVar" "%s" "$Result"

            ;;
         "variable")
            [[ -v $SaveVar ]] || local -g "$SaveVar"
            printf -v "$SavePrefix$SaveVar" "%s" "$Result"
            ;;
         *) echo "$Result";;
         esac
      else
         Text="JSON Filter Error: $Filter"
         if [[ ${#Args[@]} -gt 0 ]]; then
            Text+="\nOptions:  ${Args[@]}"
         fi
         $this:property error.text "$Text"
         $(exit 1)
      fi
   } :catch {
      Text="
$_RED$_UNDERLINE[ERROR] :json:select EXCEPTION $_tryStatus CAUGHT ON LINE $_tryErrorLine$_NORMAL

"
      if [[ -n $($this:property error.prefix) ]]; then
         $this:property -av Text error.prefix
      fi
      $this:property -av Text error.text
      if [[ -n $($this:property error.suffix) ]]; then
         $this:property -av Text error.suffix
      fi
      Text+="$(::stacktrace)"
      $this:property error.text "$Text"
      $this:property error.stack true

      return $_tryStatus
   }

   return 0
}

:JSON:save()
{
   :method
}

:JSON:getsaved()
{
   :method

   :try {

   local -r OPTIONS=$(getopt -o i: -l "index:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Index=

   while true ; do
      case "$1" in
      -i|--index) Index="$2"; shift 2;;
      --)         shift; break;;
      esac
   done

   if [[ -z $1 ]] ; then
      Text="Problem:  ^The associative array subscript was not specified\n"

      $this:property error.text "$Text"
      $(exit 1)
   fi
   local SaveVar
   SaveVar="$($this:property save.var)"
   } :catch {
      Text="
$_RED$_UNDERLINE[ERROR] :json:getsaved EXCEPTION $_tryStatus CAUGHT ON LINE $_tryErrorLine$_NORMAL

"
      if [[ -n $($this:property error.prefix) ]]; then
         $this:property -av Text error.prefix
      fi
      $this:property -av Text error.text
      if [[ -n $($this:property error.suffix) ]]; then
         $this:property -av Text error.suffix
      fi
      Text+="$(::stacktrace)"
      $this:property error.text "$Text"
      $this:property error.stack true

      return $_tryStatus
   }

   return 0
}

::stacktrace()
{
   local Index=${1:-2}
   local -i frame=0
   local -i lastframe=${#BASH_SOURCE[@]}-1
   echo "Stack:^"
   for ((frame=$Index; frame < lastframe - 2; frame++)); do
      caller $frame
   done |
      LC_ALL=C sed '/Parser:execute,Traverse/,$d' |
      head -n -1 |
      LC_ALL=C sed -e "s# $__CacheScriptsFile##" -e 's/^/     /' -e 's/__obj__\([a-zA-Z0-9]*\)_[0-9]\+/\1/' |
      LC_ALL=C sed -e '/\s+$/d' -e '/::CallChainFunction/d'
}

:JSON:update()
{
   :method
   local Key="$1"
   local Value="$2"

   local Update="$(jq "$Key|=$Value" <<<"${!this}")"
   printf -v "$this" "%s" "$Update"
}

:JSON:toarray()
{
   :method

   local -r OPTIONS=$(getopt -o v: -l "variable:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Var=

   while true ; do
      case "$1" in
      -v|--variable) Var="$2"; shift 2;;
      --)            shift; break;;
      esac
   done

   [[ -v $Var ]] ||
   {
      :property error.text "Missing required option: -v <variable>"
      $(exit 1)
   }

   local SaveVar=$($this:property save.var)
   Indirect="$SaveVar['$1']"

   readarray -t $Var <<<"$(jq -r '.[]' <<<"${!Indirect}")"
}

:JSON:join()
{
   :method

   :JSON_join -j $this "$@"
}

:JSON_join()
{
   local -r OPTIONS=$(getopt -o f:j:s:p:v: -l "file:,json:,string:,prefix:,variable:,select:,stdout" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local -a Inputs=()
   local OutputType=variable
   local Prefix=
   local Var=
   local Select=
   while true ; do
      case "$1" in
      -f|--file)     Inputs+=( "file" "$2" ); shift 2;;
      -j|--json)     Inputs+=( "json" "$2" ); shift 2;;
      -s|--string)   Inputs+=( "string" "$2" ); shift 2;;

      -p|--prefix)   Prefix="$2"; shift 2;;
      -v|--variable) Var="$2"; shift 2;;

      --select)      Select="$2"; shift 2;;
      --stdout)      OutputType=stdout; shift;;
      --)            shift; break;;
      esac
   done

   [[ ${#Inputs[@]} -gt 0 ]] || return 0

   if [[ -z $Var ]] && [[ ${Inputs[0]} != json ]] && [[ $OutputType != stdout ]]; then
      echo "$FUNCNAME: -v must be specified or the first argument must be a :JSON instance"
      return 1
   fi

   local -i I
   local ResultIndirect
   if [[ -n $Var ]]; then
      I=0
      :new :JSON $Var = '{}'
      ResultIndirect="${!Var}"
   elif [[ $OutputType = stdout ]]; then
      I=0
      :new :JSON ResultIndirect = '{}'
   else
      ResultIndirect="${Inputs[1]}"
      I=2
   fi

   local Input1 Input2 Input2Indirect
   while ((I < ${#Inputs[@]})); do
      case ${Inputs[I]} in
      file)
         Input1="${!ResultIndirect}"
         :new :JSON f
         $f:readfile "${Inputs[I+1]}"
         Input2="${!f}"
         :destroy $f
         ;;
      json)
         Input1="${!ResultIndirect}"
         Input2Indirect="${Inputs[I+1]}"
         Input2="${!Input2Indirect}"
         ;;
      string)
         Input1="${!ResultIndirect}"
         Input2="$(:JSON_trim <<<"${Inputs[I+1]}")"
         ;;
      esac

      if [[ -n $Select ]]; then
         local SelectSuffix="${Select##*.}"
         local SelectPrefix="${Select%.$SelectSuffix}"
         [[ -n $SelectPrefix ]] || { SelectPrefix='.'; SelectSuffix="${Select#.}"; }
         Input2="$(jq -r "$SelectPrefix|to_entries|map(select(.key==\"$SelectSuffix\"))|from_entries" <(echo "$Input2"))"
      fi

      if [[ -n $Prefix ]]; then
         Input2="$(jq -n --slurpfile in <(echo "$Input2") '."'"$Prefix"'" |= $in[0]')"
      fi

      printf -v "$ResultIndirect" "%s" \
         "$(jq -Ssr '.[0] * .[1]' <(echo "$Input1") <(echo "$Input2"))"

      ((I+=2))
   done

   case $OutputType in
   variable)   ;;
   stdout)     printf "%s" "${!ResultIndirect}"
               :destroy $ResultIndirect
               ;;
   esac
}

:JSON_trim()
{
   LC_ALL=C sed 's|^\s*[#%].*||'
}

:JSON_validate()
{
   local -r OPTIONS=$(getopt -o qj:e: -l "quiet,json-var:,error-var:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Error= Var= ErrorVar=
   while true ; do
      case "$1" in
      -q|--quiet)       Quiet=true; shift;;
      -j|--json-var)    JSONVar="$2"; shift 2;;
      -e|--error-var)   ErrorVar="$2"; shift 2;;
      --)               shift; break;;
      esac
   done

   local File="$1"
   local JSON=
   local ErrorMessage=
   local Return=1          # Assume failure

   # Detect errors
   if [[ ! -f $File ]]; then
      ErrorMessage="File not found: %s" "$File"
   else
      # Strip off comments and annotations
      JSON="$(:sed 's|^\s*[#%].*||' "$File")"

      # Evaluate JSON for correctness
      if jq -r . <<<"$JSON" >/dev/null 2>&1; then
         # Valid JSON
         Return=0

      else
         # Invalid JSON
         if ! $Quiet; then
            # Prepare error message
            ErrorMessage="\
<h1>ERROR: Malformed JSON file:</h1> $File
$(jq -r . <<<"$JSON" 2>&1 >/dev/null | :sed 's|^parse error:|   |')"
         fi

         # Reset JSON to the empty string so that bad data are not saved to variables
         JSON=
      fi
   fi

   # Store results
   if [[ -n $JSONVar ]]; then
      printf -v "$JSONVar" "%s" "$JSON"
   fi

   if [[ -n $ErrorVar ]]; then
      printf -v "$ErrorVar" "%s" "$ErrorMessage"
   elif [[ -n $ErrorMessage ]]; then
      printf "%s\n" "$ErrorMessage" >&2
   fi

   # Return validation status
   return $Return
}

:JSON_flatten()
{
   local Options
   Options=$(getopt -o k -l "keysonly" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$Options"

   local KeysOnly=false
   while true ; do
      case "$1" in
      -k|--keysonly) KeysOnly=true; shift;;
      --)            shift; break;;
      *)             break;;
      esac
   done

   :new :JSON JSONObj

   printf -v "$JSONObj" "$(sed 's|^\s*#.*||')"

   + flatten "$@"

   for Key in "${!map[@]}"; do
      if $KeysOnly; then
         printf "%s\n" "$Key"
      else
         printf "%s=%q\n" "$Key" "${map[$Key]}"
      fi
   done | LC_ALL=C sort -u
}

:JSON:flatten()
{
   :method

   local -r OPTIONS=$(getopt -o d:m:q -l "delimiter:,mapname:,quotes" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Delimiter='.'
   local MapName=map
   local Quotes=
   while true ; do
      case "$1" in
      -d|--delimiter)      Delimiter="$2"; shift 2;;
      -m|--mapname)        MapName="$2"; shift 2;;
      -q|--quotes)         Quotes='\\"'; shift;;
      --)                  shift; break;;
      esac
   done

   local -a Array=()
   readarray -t Array <<<"$(
      jq -c -S --stream -n --arg delim $'\x01' \
         'reduce (inputs|select(length==2)) as $i ({}; .[[$i[0][]|tostring]|join($delim)] = $i[1])' \
         <<<"${!this}" |
      jq -c "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" |
      sed \
         -e 's|^"||' -e 's|"$||' \
         -e 's|\\u0001|\x01|g' -e 's|=|\x02|' \
         -e "s|\([^\x01x02]*[^a-zA-Z0-9_\x01\x02][^\x01]*\)\([\x01\x02]\)|$Quotes\1$Quotes\2|g" \
         -e 's|\x01\([0-9]\+\)\([\x01\x02]\)|[\1]\2|g' \
         -e 's|\x01\[|[|g' -e 's|\x02|\t|' -e "s|\x01|$Delimiter|g"
      )"

   if [[ ! -v $MapName ]]; then
      local -gA $MapName
   fi

   . <(
      IFS=$'\t'
      declare -A Arrays
      while read -r Key Value; do
         printf "$MapName[\"%s\"]=%q\n" "$Key" "$Value"
         if [[ $Key =~ ^.*\[[0-9]+\]$ ]]; then
            BaseKey="$(sed 's|^\(.*\)\[[0-9]\+\]$|\1|' <<<"$Key")"
            if [[ -n Arrays[$BaseKey] ]]; then
               ((Arrays[$BaseKey]++))
            else
               Arrays[$BaseKey]=1
            fi
         fi
      done <<<"$(printf "%s\n" "${Array[@]}")"
      for Key in ${!Arrays[@]}; do
         EscapedKey="$(sed 's|"|\\"|g' <<<"$Key")"
         printf "$MapName[\"%s\"]=%s\n" "$EscapedKey[#]" "${Arrays[$Key]}"
      done
   )
}

:JSON:dump()
{
   :method

   jq -rS . <<<"${!this}"
}
