#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:json_schema_to_data()
{
   local Options
   Options=$(getopt -o i:o:v: -l "input:,output:,variable:,indent-width:,line-width:" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$Options"

   local (.)_Input= (.)_Output= (.)_Var=
   local -i (-)_IndentWidth=3 (-)_LineWidth=80
   while true ; do
      case "$1" in
      -i|--input)       (.)_Input="$2"; shift 2;;
      -o|--output)      (.)_Output="$2"; shift 2;;
      -v|--variable)    (.)_Var="$2"; shift 2;;

      --indent-width)   (-)_IndentWidth="$2"
                        [[ $(-)_IndentWidth =~ ^[0-9]+$ ]] || { echo 'Indent width must be a number'; return 1; }
                        shift 2;;
      --line-width)     (-)_LineWidth="$2"
                        [[ $(-)_LineWidth =~ ^[0-9]+$ ]] || { echo 'Line width must be a number'; return 1; }
                        shift 2;;
      --)               shift; break;;
      esac
   done

   local (.)_schemaObj
   :new :JSON (.)_schemaObj
   + readfile "$(.)_Input"

   local (-)_Indent=
   local -i (-)_IndentIndex=0

   :json_schema_to_data,walk "${!(.)_schemaObj}" | sed 's|  *$||'

}

################################################################################ PRIVATE

# Perform a tree walk
:json_schema_to_data,walk()
{
   local (-)_Schema="$1"
   local (.)_PriorKey="$2"

   local (.)_Type (.)_ValueType (-)_Key
   local -a Keys=()
   local -i Index

   :jq_select -v (.)_Type -d '' '.type' <<<"$(-)_Schema"

   case "$(.)_Type" in
   object)
      echo "$(-)_Indent{"

      # Create the indent string
      (( (-)_IndentIndex++ ))
      printf -v "(-)_Indent" '%*s' $(( (-)_IndentWidth * (-)_IndentIndex )) ''

      :jq_select -a -v Keys '.properties|keys_unsorted[]' <<<"$(-)_Schema"
      for ((Index=0; Index < ${#Keys[@]}; Index++)); do
         (-)_Key=${Keys[Index]}
         :jq_select -v (.)_ValueType -d '' ".properties.\"$(-)_Key\".type" <<<"$(-)_Schema"

         # Perform a lookahead to obtain the items that will turn into comments
         case $(.)_ValueType in
         string|integer|boolean|null)
            :json_schema_to_data,EmitComments ".properties.\"$(-)_Key\"" 
            echo -n "$(-)_Indent\"$(-)_Key\": "
            ;;
         array|object)
            :json_schema_to_data,EmitComments ".properties.\"$(-)_Key\"" 
            echo "$(-)_Indent\"$(-)_Key\": "
            ;;
         esac

         :json_schema_to_data,walk "$(jq -r ".properties.\"$(-)_Key\"" <<<"$(-)_Schema")" "$(-)_Key" || return

         if (( Index == ${#Keys[@]} - 1 )); then
            echo
         else
            printf ',\n\n'
         fi
      done

      (( (-)_IndentIndex-- ))
      printf -v "(-)_Indent" '%*s' $(( (-)_IndentWidth * (-)_IndentIndex )) ''
      echo "$(-)_Indent}"
      ;;

   array)
      echo "$(-)_Indent["

      # Create the indent string
      (( (-)_IndentIndex++ ))
      printf -v "(-)_Indent" '%*s' $(( (-)_IndentWidth * (-)_IndentIndex )) ''

      local -i (.)_ArrayLength (.)_ItemIndex
      :jq_select -v (.)_ArrayLength -d '1' '.minItems' <<<"$(-)_Schema"

      local (.)_ArrayType
      (.)_ArrayType="$(jq -r '.items|type' <<<"$(-)_Schema" 2>/dev/null)"
      case "$(.)_ArrayType" in
      object)
         :jq_select -v (.)_ArrayType -d '' '.items.type' <<<"$(-)_Schema"
         if [[ $(.)_ArrayType != object && $(.)_ArrayType != array ]]; then
            :json_schema_to_data,EmitComments ".items"
         fi

         for (( (.)_ItemIndex=0; (.)_ItemIndex < (.)_ArrayLength; (.)_ItemIndex++ )); do
            :json_schema_to_data,walk "$(jq -r ".items" <<<"$(-)_Schema")" "$(.)_PriorKey" || return

            if (( (.)_ItemIndex < (.)_ArrayLength - 1 )); then
               echo ','
            fi
         done
         ;;

      array)
         (.)_ArrayLength="$(jq -r '.items|length' <<<"$(-)_Schema")"
         for (( (.)_ItemIndex=0; (.)_ItemIndex < (.)_ArrayLength; (.)_ItemIndex++ )); do
            :json_schema_to_data,EmitComments ".items[$(.)_ItemIndex]"

            :json_schema_to_data,walk "$(jq -r ".items[$(.)_ItemIndex]" <<<"$(-)_Schema")" "$(.)_PriorKey" || return

            if (( (.)_ItemIndex < (.)_ArrayLength - 1 )); then
               echo ','
            fi
         done
         ;;

      *)
         {
            printf "\n$_BOLD${_RED}ERROR:$_NORMAL JSON schema has malformed array:\n\n"
            jq -r . <<<"$(-)_Schema"
         } >&2
         return 1
         ;;
      esac

      (( (-)_IndentIndex-- ))
      printf -v "(-)_Indent" '%*s' $(( (-)_IndentWidth * (-)_IndentIndex )) ''
      echo "$(-)_Indent]"
      ;;

   string)
      local (.)_Default
      :jq_select -v (.)_Default -d '' '.default' <<<"$(-)_Schema"
      printf '%s' "\"$(.)_Default\""
      ;;

   integer)
      local (.)_Default
      :jq_select -v (.)_Default -d '0' '.default' <<<"$(-)_Schema"
      printf '%s' "$(.)_Default"
      ;;

   boolean)
      local (.)_Default
      :jq_select -v (.)_Default -d 'false' '.default' <<<"$(-)_Schema"
      printf '%s' "$(.)_Default"
      ;;

   null)
      local (.)_Default
      :jq_select -v (.)_Default -d 'null' '.default' <<<"$(-)_Schema"
      printf '%s' "$(.)_Default"
      ;;

   *)
      {
         printf "\n$_BOLD${_RED}ERROR:$_NORMAL JSON schema has unrecognized or missing type for $_BOLD$(.)_PriorKey$_NORMAL:\n\n"
         jq -r . <<<"$(-)_Schema"
      } >&2
      return 1
      ;;
   esac

   return 0
}

:json_schema_to_data,SelectFmt()
{
   local Options
   Options=$(getopt -o jr -l "joined,raw" -n "${FUNCNAME[0]}" -- "$@") || return
   eval set -- "$Options"

   local Joined=false
   local Raw=false
   while true ; do
      case "$1" in
      -j|--joined)   Joined=true; shift;;
      -r|--raw)      Raw=true; shift;;
      --)            shift; break;;
      esac
   done

   local Selector="${1:-.description}"
   local Var="${2:-Description:}"
   local Label="${3:-$Var:}"
   local Text

   if $Raw; then
      printf -v Text "$(jq "$Selector" <<<"$(-)_Schema" 2>/dev/null)"
   else
      :jq_select -v Text -d '' "$Selector" <<<"$(-)_Schema"
   fi
   [[ -n $Text ]] || { eval "$Var=()"; return; }

   if $Joined; then
      eval "$Var=( \"$(-)_Indent# $Label $Text\" )"
   elif $Raw; then
      readarray -t "$Var" <<<"$(-)_Indent# $Label
$(
         sed "s|^|$(-)_Indent#    |" <<<"$Text"
)"
   else
      readarray -t "$Var" <<<"$(-)_Indent# $Label
$(
         fmt -w "$(-)_LineWidth" <<<"$Text" |
         sed "s|^|$(-)_Indent#    |"
)"
   fi
}


:json_schema_to_data,EmitComments()
{
   local SelectorPrefix="$1"

   local -a (.)_Title (.)_Description
   local (.)_Required (.)_MinLength (.)_MaxLength (.)_Type (.)_Examples (.)_Format

   :json_schema_to_data,SelectFmt -j "$SelectorPrefix.title" (.)_Title "Title:"
   :json_schema_to_data,SelectFmt "$SelectorPrefix.description" (.)_Description "Description:"
   :json_schema_to_data,SelectFmt -r "$SelectorPrefix.examples[]" (.)_Examples "Examples:"

   :jq_select -v (.)_Required  -d false "$SelectorPrefix.required" <<<"$(-)_Schema"
   :jq_select -v (.)_MinLength -d ''    "$SelectorPrefix.minLength" <<<"$(-)_Schema"
   :jq_select -v (.)_MaxLength -d ''    "$SelectorPrefix.maxLength" <<<"$(-)_Schema"
   :jq_select -v (.)_Type      -d ''    "$SelectorPrefix.type" <<<"$(-)_Schema"
   :jq_select -v (.)_Format    -d ''    "$SelectorPrefix.format" <<<"$(-)_Schema"
   :jq_select -v (.)_ReadOnly  -d ''    "$SelectorPrefix.readonly" <<<"$(-)_Schema"

   # Emit pre-formatted Title and Description
   [[ ${#(.)_Title[@]} -eq 0 ]] || printf '%s\n' "${(.)_Title[@]}"
   [[ ${#(.)_Description[@]} -eq 0 ]] || printf '%s\n' "${(.)_Description[@]}"

   local -a (.)_Tags=()
   # Required
   ! $(.)_Required || (.)_Tags+=( Required )

   # Type and Format
   [[ -z $(.)_Type ]] || (.)_Tags+=( "Type: $(.)_Type" )
   [[ -z $(.)_Format ]] || (.)_Tags+=( "Format: $(.)_Format" )
   [[ -z $(.)_ReadOnly ]] || (.)_Tags+=( "ReadOnly: $(.)_ReadOnly" )

   # MinLength-MaxLength
   if [[ -n $(.)_MinLength && -n $(.)_MaxLength ]]; then
      if [[ $(.)_MinLength = $(.)_MaxLength ]]; then
         (.)_Tags+=( "Length: $(.)_MinLength" )
      else
         (.)_Tags+=( "Length: $(.)_MinLength-$(.)_MaxLength" )
      fi
   fi

   if [[ ${#(.)_Tags[@]} -gt 0 ]]; then
      printf '%s\n' "${(.)_Tags[@]}" | sed "s|^|$(-)_Indent# |"
   fi

   # Emit pre-formatted Examples
   [[ ${#(.)_Examples[@]} -eq 0 ]] || printf '%s\n' "${(.)_Examples[@]}"
}
