#!/bin/bash
########################################################
#  © Copyright 2005-2018 Server Science Incorporated.  #
#  Licensed under the Apache License, Version 2.0.     #
########################################################

:yaml_to_json()
{
   local File="$1"

   ruby -ryaml -rjson -e 'puts JSON.dump(YAML::load(STDIN.read))' < "$File"
}

:json_to_yaml()
{
   local File="$1"

   ruby -ryaml -rjson -e 'puts YAML.dump(JSON.parse(STDIN.read))' < "$File"
}
