#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ __INFO() { echo "Framework-provided addons"; }
@ __HELP()
{
   echo "Top-level help"
}

@ file__INFO() { echo "File manipulation functions"; }
@ file__HELP()
{
   echo "Help for file functions"
}

# [-i <input>] [-o <output>] [-p <propertiesString> | -f <propertiesFile>] [-d <delimiter>]
file_tokenize__INFO() { echo "Perform token substitution on input"; }
file_tokenize__HELP()
{
   ! $_topicHelp && :man "
OPTIONS:
   -i|--input <input>   Source is taken to be the file <input> [default: stdin]
   -o|--output <output> Destination is taken to be the file <output> [default: stdout]
   -s|--string <string> Add a token definition of the form '<tokenname>=<tokenvalue>'
                        This option can be used multiple times.
   -f|--file <file>     Use token definitions found in <file>
   -t|--delimiter       Use the specified left token delimiter [default: '%{']

DESCRIPTION:
   Replace tokens found in a file with corresponding token values.
   A token is a name (syntax shown below) that is used in performing string substitution.

   $_BOLD${_RED}Note:$_NORMAL token names are defined as Bash variables, so it is very important to
   follow framework namespace conventions to prevent unintended side effects.

   When performing token substitution, the token name is used with additional characters
   that specify the substitution intent. In substitution constructs, token delimiters
   are used so that token substitution does not inadvertently replace content.
   A ${_BOLD}left token delimiter$_NORMAL may be specified, whose default is shown above.
   The ${_BOLD}right token delimiter$_NORMAL is the reverse of the left token delimiter.

HELP:
   $__ -l        : long help
   $__ -t syntax : topic help on 'syntax'"

   $_longHelp || ${_topic['syntax']:-false} && :man "
%{token}%
   Perform simple substitution. Replace the construct with the Bash variable \$token.

%{token[*]}%
%{token[*],<delim>|<pre>|<post>}%
   Perform inline array substitution. For Bash array variables, replace the construct
   with an expansion of the Bash array items.

   In addition, a delimiter <delim> can be optionally provided. If provided, then this
   is placed after each substitution except for the last one. If <pre> is specified,
   this string is placed before each substitution. If <post> is provided, it is placed
   after each subtitution and before any delimiter if present.

   For example, for the Bash array:

      declare -a example=('a 1' 'b 2' 'c 3')

   And, for the following construct in a file:

      The list is %{example[*], |'|')%.

   The resulting substitution would be:

      The list is 'a 1', 'b 2', 'c 3'.

%{token[n..m]}%
%{token[n..m],<delim>|<pre>|<post>}%
   Perform inline array substitution, limited to a specific range.  For Bash
   array variables, replace the construct with an expansion of the Bash array items.

   For the following construct in a file:

      The list is %{example[1..2], |'|')%.

   The resulting substitution would be:

      The list is 'b 2', 'c 3'.

%{token[@]}%
%{token[@],<delim>|<pre>|<post>}%
   Perform line-based array substitution. For Bash array variables, replace the construct
   with Bash array items, one per line, and duplicate surrounding context.

   For the following construct in a file:

      Item: %{example[@],|'|')%

   The resulting substitution would be:

      Item: 'a 1',
      Item: 'b 2',
      Item: 'c 3'

%{token[#]}%
%{token[#],<delim>|<pre>|<post>}%
   Perform array counting substitution. For Bash array variables, replace the construct
   with the count of array variables.

   For the following construct in a file:

      Count: %{example[#]|'|')%

   The resulting substitution would be:

      Count: '3'

%{label: condition}%
text
%{/label}%
   Perform condition substitution. For the specified Bash condition as is evaluated as:

      [[ condition ]]

   Only if the condition is true, then include the specified text.

SYNTAX:
   [a-zA-Z][a-zA-Z0-9_]*   : a token name"
}

file_tokenize()
{
   ### Process arguments
   ARGS=$(getopt -o i:o:s:f:d: -l "input:,output:,string:,file:,delimiter:" -n "${FUNCNAME[0]}" -- "$@")
   Depth='++++'
   eval set -- "$ARGS"

   local INPUTFILE=""
   local OUTPUTFILE=""
   local DL="%{"
   local -a PROPERTIES_FILES=()
   local PROPERTIES_STRING
   while true ; do
      case "$1" in
      -i|--input)       INPUTFILE=$(readlink -f "$2"); shift; shift;;
      -o|--output)      OUTPUTFILE=$(readlink -f "$2"); shift; shift;;
      -s|--string)      [[ -n $PROPERTIES_STRING ]] &&
                           PROPERTIES_STRING="$PROPERTIES_STRING\\n$2" ||
                           PROPERTIES_STRING="$2"
                        shift; shift;;
      -f|--file)        PROPERTIES_FILES=( "${PROPERTIES_FILES[@]}" $(readlink -f "$2") ); shift; shift;;
      -t|--delimiter)   DL="$2"; shift; shift;;
      --)               shift; break;;
      esac
   done

   # The middle and right delimiters are derived from the left delimiter
   # The right delimiter is the reverse of the left delimiter using bracketing counterparts
   local DR=$(rev <<<"$DL" | tr '()[]<>{}' ')(][><}{')
   # The middle delmiter strips off the first character of the left delimiter and
   # strips off the last character of the right delimiter
   local DM="${DR:0:-1}${DL:1}"
   # For single-character left delimiters, triple the delimiter to be the middle delimiter
   [[ -n $DM ]] || DM="$DL$DL$DL"

   [[ $DL != $DM ]] && [[ $DL != $DR ]] && [[ $DM != $DR ]] ||
      { echo "Delimiter complexity requirements are not met"; return 1; }

   [[ ${#PROPERTIES_FILES[@]} -gt 0 ]] || [[ -n $PROPERTIES_STRING ]] ||
      { echo "Missing required properties files or strings"; return 1; }

   local TMP_PROPERTIES_FILES=""

   if [[ -n $PROPERTIES_STRING ]] ; then
      local Restore_xpg_echo=$(shopt -p xpg_echo)
      shopt -s xpg_echo    # echo: set to allow escape sequences
      TMP_PROPERTIES_FILES=$(mktemp)
      echo $PROPERTIES_STRING > "$TMP_PROPERTIES_FILES"
      PROPERTIES_FILES=( "${PROPERTIES_FILES[@]}" "$TMP_PROPERTIES_FILES" )
      $Restore_xpg_echo
   else
      [[ ${#PROPERTIES_FILES[@]} -gt 0 ]] || return 1
   fi

   ### Define temporaries
   local TMP_INPUT=$(mktemp)
   local TMP_SED_FILE=$(mktemp)
   local Dl=$'\x01' Dr=$'\x02' Dm=$'\x03' Bs=$'\x04'

   # Define values for the tokens
   local PROPERTIES_FILE
   for PROPERTIES_FILE in "${PROPERTIES_FILES[@]}"; do
      [[ -n $PROPERTIES_FILE ]] && [[ -s $PROPERTIES_FILE ]] || continue
      source "$PROPERTIES_FILE"
   done

   ### PASS 1: Gather the input
   [[ -n $INPUTFILE ]] && cat "$INPUTFILE" > "$TMP_INPUT" || cat > "$TMP_INPUT"
   {
      [[ -n $INPUTFILE ]] && cat "$INPUTFILE" || cat
   } | LC_ALL=C sed -e "s|$DM|$Dm|g" -e "s|$DL|$Dl|g" -e "s|$DR|$Dr|g" > "$TMP_INPUT"

   ### PASS 2: Process Conditional BLocks
   # Discover the conditional block names
   local ConditionNames=$(grep "^${Dl}[A-Za-z][A-Za-z0-9_]*:.*${Dr}" "$TMP_INPUT" |
         LC_ALL=C sed "s|^${Dl}\([A-Za-z][A-Za-z0-9_]*\):.*${Dr}.*|\1|")

   # Include or exclude the conditional block
   cat /dev/null > "$TMP_SED_FILE"
   local ConditionName
   for ConditionName in $ConditionNames; do
      Condition=$(grep "^${Dl}$ConditionName:.*${Dr}" "$TMP_INPUT" |
      LC_ALL=C sed "s|^${Dl}$ConditionName:\(.*\)${Dr}.*|\1|")
      if eval [[ $Condition ]] ; then
      {
         echo "/${Dl}$ConditionName:.*${Dr}/d"
         echo "/${Dl}\\/$ConditionName${Dr}/d"
      } >> "$TMP_SED_FILE"
      else
         echo "/${Dl}$ConditionName:.*${Dr}/,/${Dl}\\/$ConditionName${Dr}/d" >> "$TMP_SED_FILE"
      fi
   done

   [[ -s $TMP_SED_FILE ]] && LC_ALL=C sed -i -f "$TMP_SED_FILE" "$TMP_INPUT"

   ### PASS 3: Find tokens in the file
   local Indirect             # Used for finding values of either string or array variables
   local -a ArrayValue        # Using indirection, store array values in ArrayValue
   local CandidateReplacement # The result of the built-up replacement, flattened to a string
   local CandidateFound       # Set to true when a token variable exists (even if empty)
   local CandidateType        # Used to distinguish replacements that require non-default handling
   local TokenInstance        # The full token, including control specifiers
   local -a TokenSpec         # A TokenInstance is an array of TokenSpecs
   local Token                # The token name only
   local Delimiter            # Array tokens can use a delimiter to separate replacements
   local -a Replacement       # Build up the array replacement in the Replacement variable
   local -i ArraySize         # The size of an array token

   local RequiredTokenSyntax='^[a-zA-Z_][a-zA-Z0-9_]*(\[(@|#|\*|[0-9]*|[0-9]*\.\.[0-9]*)\].*)?$'

   # Start off with an empty sed file
   cat /dev/null > $TMP_SED_FILE

   # Normalize the input and find all valid token instances (name + control specifiers)
   grep "$Dl.*$Dr" "$TMP_INPUT" |
   LC_ALL=C sed -e "s|[^$Dl]*$Dl\([^$Dr]*\)$Dr[^$Dl]*|\1\n|g" |
   LC_ALL=C sed '/^$/d' |
   sort -u |
   while IFS="" read -r TokenInstance ; do

      # For every unique token specification, try to do a replacement
      IFS="$Dm" read -ra TokenSpec <<<"$TokenInstance"

      CandidateReplacement=""
      CandidateFound=false
      CandidateType=""
      local -i i I StartIndex EndIndex
      local Balance PlaceBefore PlaceAfter Index IndexValue
      for ((i=0; i < ${#TokenSpec[@]}; i++)); do
         if [[ ${TokenSpec[i]} =~ $RequiredTokenSyntax ]] ; then
            Token=$(LC_ALL=C sed 's|\[.*||' <<<"${TokenSpec[i]}")
            :variable_exists "$Token" || continue
            CandidateFound=true

            Balance=$(LC_ALL=C sed -e 's|.*\]||' <<<"${TokenSpec[i]}")
            Delimiter=$(LC_ALL=C sed -e 's#\\|##g' -e 's#|.*##' -e 's##|#g' <<<"$Balance")
            Balance=$(LC_ALL=C sed -e 's#^.*\]##' -e 's#\\|##g' -e 's#^[^|]*|##' <<<"$Balance")
            if [[ $Balance =~ \| ]] ; then
               PlaceBefore=$(:sed_escape -n $(LC_ALL=C sed -e 's#|.*##' -e 's##|#g' <<<"$Balance"))
               PlaceAfter=$(:sed_escape -n $(LC_ALL=C sed -e 's#.*|##' -e 's##|#g' <<<"$Balance"))
            else
               PlaceBefore=''
               PlaceAfter=''
            fi

            Index=$(LC_ALL=C sed -r 's#^.*\[([^]]*)\].*$|^.*$#\1#' <<<"${TokenSpec[i]}")
            [[ $Index =~ ^[0-9]+$ ]] && { IndexValue="$Index"; Index=0; }
            case "$Index" in
            '#')
                  Indirect="$Token[@]"
                  ArrayValue=("${!Indirect}")
                  CandidateReplacement=${#ArrayValue[@]}
                  if [[ $CandidateReplacement -gt 0 ]] ; then
                     CandidateReplacement="$PlaceBefore${#ArrayValue[@]}$PlaceAfter$Delimiter"
                     break
                  else
                     continue
                  fi
                  ;;
            '*')
                  Indirect="$Token[@]"
                  ArrayValue=("${!Indirect}")
                  CandidateReplacement=''
                  ArraySize=${#ArrayValue[@]}
                  if [[ $ArraySize -gt 0 ]] ; then
                     Replacement=()
                     local -i I
                     for ((I=0; I<$ArraySize; I++)); do
                        Indirect="$Token[$I]"
                        if ((I < ArraySize-1)); then
                           Replacement[I]="$PlaceBefore${!Indirect}$PlaceAfter$Delimiter"
                        else
                           Replacement[I]="$PlaceBefore${!Indirect}$PlaceAfter"
                        fi
                     done
                     IFS=''
                     CandidateReplacement="${Replacement[*]}"
                     if [[ -n $CandidateReplacement ]] ; then
                        break
                     else
                        continue
                     fi
                  else
                     continue
                  fi
                  ;;
            '@')
                  Indirect="$Token[@]"
                  ArrayValue=("${!Indirect}")
                  CandidateReplacement=''
                  ArraySize=${#ArrayValue[@]}
                  if [[ $ArraySize -gt 0 ]] ; then
                     Replacement=()
                     for ((I=0; I<$ArraySize; I++)); do
                        Indirect="$Token[$I]"
                        if ((I < ArraySize-1)); then
                           Replacement[I]="${Bs}1"$PlaceBefore${!Indirect}$PlaceAfter"${Bs}2$Delimiter${Bs}n"
                        else
                           Replacement[I]="${Bs}1"$PlaceBefore${!Indirect}$PlaceAfter"${Bs}2"
                        fi
                     done
                     IFS=''
                     CandidateReplacement="${Replacement[*]}"
                     CandidateType="line"
                     if [[ -n $CandidateReplacement ]] ; then
                        break
                     else
                        continue
                     fi
                  else
                     continue
                  fi
                  ;;
            *'..'*)
                  Indirect="$Token[@]"
                  ArrayValue=("${!Indirect}")
                  CandidateReplacement=''
                  ArraySize=${#ArrayValue[@]}
                  StartIndex=$(echo "$Index" | LC_ALL=C sed 's|\(.*\)\.\..*|\1|')
                  EndIndex=$(echo "$Index" | LC_ALL=C sed 's|.*\.\.\(.*\)|\1|')

                  if [[ $StartIndex -lt $ArraySize ]] && [[ $EndIndex -lt $ArraySize ]] ; then
                     Replacement=()
                     for ((I=$StartIndex; I<=$EndIndex; I++)); do
                        Indirect="$Token[$I]"
                        if ((I < EndIndex)); then
                           Replacement[I-StartIndex]="$PlaceBefore${!Indirect}$PlaceAfter$Delimiter"
                        else
                           Replacement[I-StartIndex]="$PlaceBefore${!Indirect}$PlaceAfter"
                        fi
                     done
                     IFS=''
                     CandidateReplacement="${Replacement[*]}"
                     if [[ -n $CandidateReplacement ]] ; then
                        break
                     else
                        continue
                     fi
                  else
                     Continue
                  fi
                  ;;
            0)
                  Indirect="$Token[@]"
                  ArrayValue=("${!Indirect}")
                  CandidateReplacement=''
                  ArraySize=${#ArrayValue[@]}

                  if [[ $IndexValue -lt $ArraySize ]] ; then
                     Indirect="$Token[$IndexValue]"
                     CandidateReplacement="$PlaceBefore${!Indirect}$PlaceAfter$Delimiter"
                     if [[ -n $CandidateReplacement ]] ; then
                        break
                     else
                        continue
                     fi
                  else
                     continue
                  fi
                  ;;
            *)
                  Indirect="$Token"
                  CandidateReplacement="${!Indirect}"

                  if [[ -n $CandidateReplacement ]] ; then
                     break
                  else
                     continue
                  fi
                  ;;
            esac
         else
            echo "### Skipping Malformed token instance: '$TokenInstance'" >&2
         fi
      done

      if $CandidateFound ; then
         TokenInstance=$(:sed_escape -n "$TokenInstance")
         CandidateReplacement=$(:sed_escape -n "$CandidateReplacement" | LC_ALL=C sed "s|$Bs|\\\|"g)
         case $CandidateType in
         "line")
            echo "s\(.*\)$Dl$TokenInstance$Dr\(.*\)$CandidateReplacementg" >> $TMP_SED_FILE
            ;;
            
         *)
            echo "s$Dl$TokenInstance$Dr$CandidateReplacementg" >> $TMP_SED_FILE
            ;;
         esac
      fi

   done
   [[ -s $TMP_SED_FILE ]] && LC_ALL=C sed -i -f "$TMP_SED_FILE" "$TMP_INPUT"

   LC_ALL=C sed -i -e "s|$Dm|$DM|g" -e "s|$Dl|$DL|g" -e "s|$Dr|$DR|g" "$TMP_INPUT"

   ### PASS 4: Produce the output
   [[ -n $OUTPUTFILE ]] && mv "$TMP_INPUT" "$OUTPUTFILE" || cat "$TMP_INPUT"

   ### Cleanup
   [[ -f $TMP_INPUT ]] && rm -f "$TMP_INPUT"
   [[ -f $TMP_SED_FILE ]] && rm -f "$TMP_SED_FILE"
   [[ -f "$TMP_PROPERTIES_FILES" ]] && rm -f "$TMP_PROPERTIES_FILES"
}

file_tokenize_dir__INFO() { echo "Perform token substitution on files in a directory"; }
file_tokenize_dir__HELP()
{
    :man "
OPTIONS:
   -s|--src <dir>       Find files under the specified source directory> [default: .]
   -d|--dst <dir>       Tokenize files into the specified destination directory [default: .]

   -f|--propfile <file> The property <file> is to be used to define token values
   -p|--props <string>  The text <string> is to be used

   -r|--recurse         Recurse the source directory

DESCRIPTION:
   Find all files under the specified source directory and tokenize them
   to the specified target directory.

FILES:
   orig.json : If present, use this to specify how tokenization is to be performed.
   *.orig    : Use the simple transform: <file>.orig -> <file>.
               One of the options -f or -p is required."
}

file_tokenize_dir()
{
   ARGS=$(getopt -o c:S:D:or:f:ks:x: -l "control:,src:,dst:,overwrite,rules:,rulefile:,keep,string,exclude:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$ARGS"

   local Overwrite=false
   local Control=''
   local Src="."
   local Dst="."
   local Rules=''
   local RuleFile=''
   local Keep=false
   local PropertiesString=''
   local -a Exclude=()
   while true ; do
      case "$1" in
      -c|--control)     Control="$2"; shift 2;;
      -S|--src)         Src="$2"; shift 2;;
      -D|--dst)         Dst="$2"; shift 2;;
      -o|--overwrite)   Overwrite=true; shift;;
      -r|--rules)       Rules="$2"; shift 2;;
      -f|--rulefile)    RuleFile="$2"; shift 2;;
      -k|--keep)        Keep=true; shift;;
      -s|--string)      PropertiesString="$2"; shift 2;;
      -x|--exclude)     Exclude+=("--exclude=$2"); shift 2;;
      --)               shift; break;;
      esac
   done

   [[ -d $Src ]] || { echo "Source directory doesn't exist: $Src"; return 1; }
   [[ $Src != $Dst ]] && [[ -d $Dst ]] &&
      { $Overwrite || { echo "Destination directory cannot be overwritten"; return 1; } }
   local A B
   [[ -n $Rules ]]; A=$?
   [[ -n $RuleFile ]]; B=$?
   (( !A != !B )) || { echo "One of -r or -f must be used"; return 1; }
   [[ $Src != $Dst ]] &&
   {
      [[ ${Dst##$Src} = $Dst ]] ||
         {
            echo "The Destination directory cannot be a subdirectory of the Source directory:"
            echo "   Source:      $Src"
            echo "   Destination: $Dst"
            return 1
         }
   }

   if [[ -n $RuleFile ]] ; then
      Rules=$(:jq_select -x . < "$RuleFile" 2>/dev/null) || { echo "Malformed rule file: $RuleFile"; return 1; }
   else
      jq -r . <<<"$Rules" >/dev/null 2>&1 || { echo "Malformed rules provided"; return 1; }
   fi

   if [[ $Src != $Dst ]] ; then
      echo
      echo "Copying $Src to $Dst..."
      mkdir -p "$Dst"
      (cd "$Src"; tar cpf - "${Exclude[@]}" .) | (cd "$Dst"; tar xpf -)
      echo
   fi

   # Gather property files
   local Item
   local Properties=''
   for Item in $(:jq_select '.properties.common.absolute[]' <<<"$Rules"); do
      [[ -f $Item ]] && Properties="$Properties -f "$(readlink -f "$Item")""
   done
   for Item in $(:jq_select '.properties.common.src_relative[]' <<<"$Rules"); do
      [[ -f $Src/$Item ]] && Properties="$Properties -f "$(readlink -f "$Src/$Item")""
   done
   for Item in $(:jq_select '.properties.common.dst_relative[]' <<<"$Rules"); do
      [[ -f $Dst/$Item ]] && Properties="$Properties -f "$(readlink -f "$Dst/$Item")""
   done
   for Item in $(:jq_select '.properties."$Control".src_relative[]' <<<"$Rules"); do
      [[ -f $Src/$Item ]] && Properties="$Properties -f "$(readlink -f "$Src/$Item")""
   done
   for Item in $(:jq_select '.properties."$Control".dst_relative[]' <<<"$Rules"); do
      [[ -f $Dst/$Item ]] && Properties="$Properties -f "$(readlink -f "$Dst/$Item")""
   done
   if [[ -n PropertiesString ]] ; then
      local Restore_xpg_echo=$(shopt -p xpg_echo)
      TmpPropertiesFile=$(mktemp)
      echo "$PropertiesString" > "$TmpPropertiesFile"
      Properties="$Properties -f $TmpPropertiesFile"
      $Restore_xpg_echo
   fi

   # Rule #1: "files" is present: tokenize these
   local File Group Find Sed
   local -i I Groups
   echo "Performing token replacement and renaming common files..."
   :jq_select -v Groups '.files.common|length' <<<"$Rules"
   for ((I=0; I < Groups; I++)); do
      :jq_select -v Group ".files.common[$I]" <<<"$Rules"
      :jq_select -v Find '.find' <<<"$Group"
      :jq_select -v Sed '.sed' <<<"$Group"
      :jq_select -v Mv '.mv' <<<"$Group"

      local -a Files=()
      Files=(
         $(:jq_select '.[]' <<<"$Find" |
            while IFS='' read -r File; do
               find $Dst -name "$File" -type f
            done)
      )

      for Item in "${Files[@]}"; do
         New=$(LC_ALL=C sed -e "$Sed" <<<"$Item")
         if [[ $New != $Item ]] ; then
            [[ -n $Mv ]] && New="$(readlink -f "$(readlink -f "$(dirname "$New")/$Mv")/$(basename "$New")")"
            echo "Tokenize $Item as $New"
            file_tokenize -i "$Item" -o "$New" $Properties
            $Keep || rm -f "$Item"
         fi
      done
   done
   [[ $Groups -eq 0 ]] || echo

   :jq_select -v Groups '.directories.common|length' <<<"$Rules"
   for ((I=0; I < Groups; I++)); do
      :jq_select -v Group ".directories.common[$I]" <<<"$Rules"
      :jq_select -v Find '.find' <<<"$Group"
      :jq_select -v Sed '.sed' <<<"$Group"
      :jq_select -v Mv '.mv' <<<"$Group"

      local -a Dirs=()
      Dirs=(
         $(:jq_select '.[]' <<<"$Find" |
            while IFS='' read -r File; do
               find $Dst -name "$File" -type d
            done)
      )

      for Item in "${Dirs[@]}"; do
         New="$(basename "$(LC_ALL=C sed -e "$Sed" <<<"$Item")")"
         if [[ -n $Mv ]]; then
            rm -rf "$Mv/$New"
            mv "$Item" "$Mv/$New"
         fi
      done
   done

   # Rule #2: "$Control" is present: tokenize these
   echo "Performing token replacement and renaming $Control files..."
   :jq_select -v Groups ".files.\"$Control\"|length" <<<"$Rules"
   for ((I=0; I < Groups; I++)); do
      :jq_select -v Group ".files.\"$Control\"[$I]" <<<"$Rules"
      :jq_select -v Find '.find' <<<"$Group"
      :jq_select -v Sed '.sed' <<<"$Group"
      :jq_select -v Mv '.mv' <<<"$Group"

      local -a Items=()
      Items=(
         $(:jq_select '.[]' <<<"$Find" | while IFS='' read -r File; do
            find $Dst -name "$File"
         done)
      )

      for Item in "${Items[@]}"; do
         New=$(LC_ALL=C sed -e "$Sed" <<<"$Item")
         if [[ $New != $Item ]] ; then
            [[ -n $Mv ]] && New="$(readlink -f "$(readlink -f "$(dirname "$New")/$Mv")/$(basename "$New")")"
            echo "Tokenize $Item as $New"
            file_tokenize -i "$Item" -o "$New" $Properties
            $Keep || rm -f "$Item"
         fi
      done
   done
   echo

   rm -f "$TmpPropertiesFile"
}
