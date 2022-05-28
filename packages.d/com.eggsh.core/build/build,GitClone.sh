#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

@ :build,GitClone()
{
   local (.)_ProjectDir="${(@)_BuildInfo[.git.project_dir]}"

   # TODO: Change this assert to an if/else and handle temporary-directory building
   [[ -d $(.)_ProjectDir ]] ||
      { echo "Missing directory for .git.project_dir"; return 1; }

   # For each package, clone the source code
   local (-)_Package
   for (-)_Package in ${(@)_BuildInfo['assemble']}; do
      local (.)_Clone="${(@)_BuildInfo[.packages.\"$(-)_Package\".git.clone]}"
      local (.)_Project="$(basename "$(.)_Clone")"
      local (.)_Revision="${(@)_BuildInfo[.packages.\"$(-)_Package\".git.revision]}"

      if [[ -n $(.)_TopLevel ]]; then
         (@)_BuildInfo[.packages.\"$(-)_Package\".git.tmpdir]=false
      else
         (@)_BuildInfo[.packages.\"$(-)_Package\".git.tmpdir]=true
      fi

      # TODO: Implement git clone
      # The present assumption is that the git project_dir already exists and is
      # populated with git projects. This feature will be completed in the future.

      # TODO: Update git repo
      [[ -d $(.)_ProjectDir/$(.)_Project/.git ]] ||
         { echo "Git project does not exist: $(.)_Project"; return 1; }
   done

   return 0
}
