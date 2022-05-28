#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:Transform:Normalize()
{
   :method

   local File="$1"
   local Text

   # Status:
   #     0: Success
   #     1: Missing Delimiter Begin
   #     2: Missing Delimiter End
   awk \
      -v DB="$DB" -v DE="$DE" -v DF="$DB/$DE" \
      -v BB="$BB" -v BE="$BE" -v BC="$BC" \
      -v ESC='\\\\' -v OR='|' '
   BEGIN          {i=c=-1; RS=ESC DF OR ESC DB OR ESC "/" DE OR ESC DE OR DF OR DB OR "/" DE OR DE; RC=0}
   RT == DF       {
      ++i; ++c; d[i]=c; printf "%s%s%s%s/%s%s%s",$0,BB,d[i],BB,BE,d[i],BE
      --i
      next
   }
   RT == DB       {++i; ++c; d[i]=c; BlockTag=BB}
   RT == "/" DE   {BlockTag=BC}
   RT == DE       {BlockTag=BE}
   RT ~ /^\\/     {printf "%s%s",$0,RT; next}
   {
      if (i < 0 && BlockTag != "")
      {
         RC=or(RC,1)
         printf "(%s%s)",DE,$0
         BlockTag=""
         i=-1
         next
      }
      else if (BlockTag == BC)
      {
         printf "%s%s%s%s",$0,BE,d[i],BE
         ++i; ++c; d[i]=c
         printf "%s%s%s/%s%s%s",BB,d[i],BB,BE,d[i],BE
         --i

      }
      else
         printf "%s%s%s%s",$0,BlockTag,d[i],BlockTag
   }
   RT == DF       {--i; if (i == -1) BlockTag=""}
   RT == "/" DE   {--i; if (i == -1) BlockTag=""}
   RT == DE       {--i; if (i == -1) BlockTag=""}
   END            {
      if (i!=-1)
      {
         RC=or(RC,2)
         printf "%s",DB
      }
      exit RC
   }' "$File" |

   tr '\n' $'\x05'
}

:Transform:Unnormalize()
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

   local Result="$(
      printf "%s" "$1" | sed -e "s|$BB[^$BB]*$BB|$DB|g"  -e "s|$BE[^$BE]*$BE|$DE|g" -e "s|$NL|\n|g"
      printf x)"
   Result="${Result%x}"

   printf -v "$Var" "%s" "$Result" 
}

:Transform:SubProcess()
{
   :method

   local Var="$1"          # Resolve any nested transforms in the variable provided
   local SuffixVar="$2"    # Stores a unique suffix that is needed for recursion

   # To facilitate recursion without command substitution, a unique variable name must be used
   printf -v "$SuffixVar" "%s" "${!SuffixVar}_"

   + Process "$Var" "${!SuffixVar}" || return

   # After the recursion, undo the change
   local Indirect="$Var${!SuffixVar}"
   printf -v "$Var" "%s" "${!Indirect}"
   printf -v "$SuffixVar" "%s" "${!SuffixVar::-1}"

   return 0
}

:Transform:Process()
{
   :method

   local Var="$1"          # Store the result of the transform in this variable
   local Suffix="$2"       # If recursing, this will be non-empty

   local Input="${!Var}"

   local TransformIndex NextTransform BeforeTransform
   local FilterExpr Text NextFilterExpr Interpretation (@)_Normalized
   local -i NestingLevel

   # Start with no Result and no Context
   local Result=
   local ContextBefore=
   local ContextAfter=
   local EvaluateTextBlock=true
   local Modifier=

   while [[ -n $Input ]]; do
      # Could be terminal if there aren't at least 2 delimiters such as %{...}% or %{... %{
      if ! grep -q "$BB[^$BB]*$BB[^$BB]*$BB" <<<"$Input"; then
         # Did not find 2 delimiters. But, is 1 delimiter present? If so, this is an error.
         if grep -q "$BB" <<<"$Input"; then
            Input="$(sed "s|[^$BB]*$BB[^$BB]*$BB\(.*\)|\1|" <<<"$Input")"
            + Unnormalize -v (@)_Normalized "$Input"
            printf -v "$Var" "Unterminated transform detected at:\n\t'%s'\n" "${(@)_Normalized:0:30}"
            return 1
         fi

         # There are no delimiters left in Input. Just return the Input as the result.
         Result+="$Input"

         # The suffix will be empty at the top-recursion level
         printf -v "$Var$Suffix" "%s" "$Result"
         return 0
      fi

      # Get the index for this transform
      TransformIndex="$(sed "/$BB/{s|^[^$BB]*$BB\([^$BB]*\)$BB.*|\1|;q}; /$BB/!{q1}" <<<"$Input")"

      # Initially, split Input to find BeforeTransform and FilterExpr, leaving Input balance
      BeforeTransform="$(sed "s|\([^$BB]*\)$BB$TransformIndex$BB.*$BE$TransformIndex$BE.*|\1|" <<<"$Input")"
      FilterExpr="$(sed "s|[^$BB]*$BB$TransformIndex$BB\(.*\)$BE$TransformIndex$BE.*|\1|" <<<"$Input")"
      Input="$(sed "s|[^$BB]*$BB$TransformIndex$BB.*$BE$TransformIndex$BE\(.*\)|\1|" <<<"$Input")"

      while [[ ${FilterExpr:0:1} = '^' || $FilterExpr =~ ^':' || $FilterExpr =~ ^[a-zA-Z]+[a-zA-Z0-9_]*':' ]]; do
         if [[ ${FilterExpr:0:1} = '^' ]]; then
            # Disable transform evaluation of <text> block
            EvaluateTextBlock=false
            FilterExpr="${FilterExpr:1}"
         else
            # Apply <modifier> to <requestExpression>
            Modifier="${FilterExpr%%:*}"
            FilterExpr="${FilterExpr#*:}"
            :shopt_save
            shopt -s extglob
            FilterExpr="${FilterExpr##*( )}"
            :shopt_restore

            case "$Modifier" in
            bash|'')
               EvaluateTextBlock=false
               ;;
            *)
               ;;
            esac
         fi
      done

      # The part before the transform does not, by definition, include transforms.
      # So, it can be added to the Result.
      Result+="$BeforeTransform"

      + SubProcess FilterExpr Suffix || { printf "%q\n" "ERROR1: $FilterExpr" >&2; return 1; }

      # Found so far: %{...}%
      # Now, find closing <text>%{/}% and save optional <text> as Text
      NestingLevel=1
      NextTransform=
      Text=
      while [[ $NestingLevel -gt 0 && -n $Input ]]; do
         # It is an error if there is no end delimiter
         if ! grep -q "$BB" <<<"$Input"; then
            + Unnormalize -v (@)_Normalized "$Input"
            
            printf -v "$Var" "Unterminated transform detected at:\n\t'%s'\n" "${(@)_Normalized:0:30}"
            return 1
         fi
         # Scan every directive until the matching closing directive %{/}% is found
         NextTransform="$(sed "/$BB/{s|^[^$BB]*$BB\([^$BB]*\).*|\1|;q}; /$BB/!{q1}" <<<"$Input")"
         Text+="$(sed "s|\([^$BB]*\)$BB[^$BB]*$BB[^$BE]*$BE[^$BE]*$BE.*|\1|" <<<"$Input")"
         NextFilterExpr="$(sed "s|[^$BB]*$BB[^$BB]*$BB\([^$BE]*\)$BE[^$BE]*$BE.*|\1|" <<<"$Input")"
         Input="$(sed "s|[^$BB]*$BB[^$BB]*$BB[^$BE]*$BE[^$BE]*$BE\([^$BE]*\)|\1|" <<<"$Input")"

         # Change the NestingLevel: decrease for closing directive; increase otherwise
         if [[ $NextFilterExpr = '/' ]]; then
            ((NestingLevel--))
         else
            ((NestingLevel++))
         fi

         # Add NextFilterExpr if the closing directive has not yet been found
         if [[ $NestingLevel -ne 0 ]]; then
            Text+="$BB$NextTransform$BB$NextFilterExpr$BE$NextTransform$BE"
         fi
      done

      if $EvaluateTextBlock; then
         + SubProcess Text Suffix || { printf "%q\n" "ERROR2: $Text"; return 1; }
      fi

      # A full transform has been resolved: interpret it
      # To enable recursion without command substitution, store the result in a variable
      FilterExpr="$(printf "%sx" "$FilterExpr" | sed 's|\x05|\n|g')"
      FilterExpr="${FilterExpr%x}"
      Text="$(printf "%sx" "$Text" | sed 's|\x05|\n|g')"
      Text="${Text%x}"

      # ContextBefore is the text before the transform until and excluding a newline
      ContextBefore="${BeforeTransform#*$'\x05'}"

      # ContextAfter is Input up until and including a newline or up until and excluding $BB
      ContextAfter="$(printf "%s" "$Input" |
         sed -e "s|\([^\x05]*\x05\).*|\1|" -e "s|\([^$BB]*\)$BB.*|\1|" -e "s|\x05|\n|g"; printf x)"
      ContextAfter="${ContextAfter%x}"

      # It is the responsibility of the Interpret function to process the ContextAfter
      Input="${Input:${#ContextAfter}}"

      + InterpretTransform Interpretation "$FilterExpr" "$Text" "$ContextBefore" "$ContextAfter" "$Modifier"

      # And, now add the result of the transform into the Result stream
      Result+="$Interpretation"
   done

   # The suffix will be empty at the top-recursion level
   printf -v "$Var$Suffix" "%s" "$Result"

   return 0
}
