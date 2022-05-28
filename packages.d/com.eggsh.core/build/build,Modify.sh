#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ :build,Modify()
{
   # Are there any modifications to process?
   [[ $(jq -r 'type' <<<"${(@)_BuildInfo[.modify]}") = array ]] || return 0

   local -i (.)_Modifications
   (.)_Modifications="$(jq -r 'length' <<<"${(@)_BuildInfo[.modify]}")"

   (( $(.)_Modifications > 0 )) || return 0

   :highlight <<<"<green>### Performing Modifications...</green>\n"

   local -i (.)_ModificationIndex
   local -a (.)_Packages
   local (.)_ModificationType (.)_Modification (.)_Package

   for (( (.)_ModificationIndex=0; (.)_ModificationIndex < (.)_Modifications; (.)_ModificationIndex++ )); do
      (.)_ModificationType="$(jq -r ".[$(.)_ModificationIndex] | type" <<<"${(@)_BuildInfo[.modify]}")"
      (.)_Modification="$(jq -r ".[$(.)_ModificationIndex]" <<<"${(@)_BuildInfo[.modify]}")"

      case "$(.)_ModificationType" in
      string)
         if :function_exists -p "$_corePackage" "__build_modify_$(.)_Modification"; then
            (@)::__build_modify_$(.)_Modification --assembledir "$(+)_BuildDir"
         fi
         ;;
      object)
         (.)_Action="$(jq -r '.action' <<<"$(.)_Modification")"
         [[ -n $(.)_Action && $(.)_Action != null ]] || continue

         if [[ $(jq -r '.packages|type' <<<"$(.)_Modification") = array ]]; then
            readarray -t (.)_Packages < <(jq -r '.packages[]' <<<"$(.)_Modification")

            for (.)_Package in "${(.)_Packages[@]}"; do
               if :function_exists -p "$(.)_Package" "__build_modify_$(.)_Action"; then
                  @ -p "$(.)_Package" "__build_modify_$(.)_Action" --assembledir "$(+)_BuildDir"
               fi
            done
         fi
         ;;
      *)
         ;;
      esac
   done

   :highlight <<<"<green>### Done with Modifications.</green>\n"

   return 0
}
