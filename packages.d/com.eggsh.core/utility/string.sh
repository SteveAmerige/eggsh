#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:help_string__INFO()
{
   echo "Info here for :string"
}

:string_join()
{
   local -r OPTIONS=$(getopt -o a:d:v: -l "arrayname:,delimiter:,variable:" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local Delimiter=','
   local DelimiterEsc=','
   local Var=
   local ArrayName
   while true ; do
      case "$1" in
      -a|--arrayname)
         ArrayName="$2"
         shift 2;;
      -d|--delimiter)
         Delimiter="$2"
         DelimiterEsc="$(:sed_escape -n "$Delimiter")"
         shift 2;;
      -v|--variable)
         Var="$2"
         shift 2;;
      --)
         shift
         break;;
      esac
   done

   local Result
   if [[ -n $ArrayName ]] ; then
      [[ -v $ArrayName ]] || { echo "No array name was provided"; return 1; }

      ArrayName+='[@]'
      if [[ -n $Delimiter ]]; then
         printf -v Result "%s$Delimiter" "${!ArrayName}" | LC_ALL=C sed "s$DelimiterEsc$"
      else
         printf -v Result "%s" "${!ArrayName}"
      fi
   else
      if [[ -n $Delimiter ]]; then
         printf -v Result "%s$Delimiter" "$@"
         Result="$(LC_ALL=C sed "s$DelimiterEsc$" <<<"$Result")"
      else
         printf -v Result "%s" "$@"
      fi
   fi

   if [[ -n $Var ]]; then
      printf -v "$Var" "%s" "$Result"
   else
      printf "%s" "$Result"
   fi
}

:string_trim()
{
   LC_ALL=C sed -e 's|^[[:space:]]*||' -e 's|[[:space:]]*$||'
}

################################################################################ PROTECTED

:StringEscapeSed()
{
   :getopts_init     \
      -o "n"         \
      -l "newline"   \
      -v Options -- "$@"

   local OptChar Newline
   while :getopts_next OptChar; do
      case "$OptChar" in
      -) case "$OPTARG" in
         newline) Newline=true;;

         *)       :getopts_skip; break;;
         esac;;

      '?')  break;;
      *)    :getopts_redirect "$OptChar" || break;;
      esac
   done
   :getopts_done

   set -- "${Options[@]}"

   awk '{ gsub(/[][^$.*?+\\()&]/, "\\\\&"); print }' <<<"$*" |
   {
      $Newline && LC_ALL=C sed -- ':a;N;$!ba;s/\n/\\n/g' || cat
   }
}

# If it is necessary to escape a string so that sed does not treat
# the string as a regex, this function can used to preprocess.
# Typical usage would be:
:sed_escape()
{
   local -r OPTIONS=$(getopt -o n -l "--escape-newlines" -n "${FUNCNAME[0]}" -- "$@")
   eval set -- "$OPTIONS"

   local EscapeNewlines=false
   while true ; do
      case "$1" in
      -n|--escape-newlines)   EscapeNewlines=true; shift;;
      --)                     shift; break;;
      esac
   done

   awk '{ gsub(/[][^$.*?+\\()&]/, "\\\\&"); print }' <<<"$*" |
   {
      if $EscapeNewlines; then
         LC_ALL=C sed -- ':a;N;$!ba;s/\n/\\n/g'
      else
         cat
      fi
   }
}
