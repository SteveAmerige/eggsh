#!/bin/bash

##### SCRIPT DIRECTORY CODE ORGANIZATION
# <package>/<component>/<unit>
#
##### NAMESPACE PROTECTION
# <scope> NAME       VISIBILITY                      FILE/DIRECTORY: ALLOWED CHARACTERS
#   @     Package    Any file in the package,        [a-z0-9][a-z0-9-\.]* with additional domain naming constraints
#   +     Component  Any file in the same component  [a-z0-9%]+
#   -     Unit       Any file in the same unit,      <file>.sh or <dir>/**/<file>.sh where <dir> and <file> is [^_\.]+
#   .     Function   Only within a function          n/a
#
# <scope_decl> ::= '@'   | '+'   | '-'               Declare Package, Component, and Unit namespace scopes
# <scope_ref>  ::= '(@)' | '(+)' | '(-)' | '(.)'     Reference Package, Component, Unit, and Function namespace scopes
#
##### FUNCTION DECLARATIONS
# <scope_decl> public_api() {...}                    Filename: public_api.sh
# <scope_decl> public_api,PrivateSubroutine() {...}  Filename: public_api.sh if not otherwise shared
# <scope_decl> PrivateAPI() {...}                    Filename: PrivateAPI.com for shared functions
#
##### FUNCTION REFERENCES
# <scope_ref>::public_api                 For example: (@)::public_api (+)::public_api
# <scope_ref>::PrivateAPI                 For example: (@)::PrivateAPI (+)::PrivateAPI (-)::PrivateAPI
#
##### VARIABLE DECLARATIONS AND REFERENCES
# <scope_ref>_public_api                  For example: (@)_public_api (+)_public_api
# <scope_ref>_PrivateAPI                  For example: (@)_PrivateVar (+)_PrivateVar (-)_PrivateVar (.)_PrivateVar
#
##### CLASS DECLARATIONS
# ClassName:() {:method; :extends <Class>; ...}    Constructor example: Animal:() { :method; :extends Taxonomy; ...}
# ClassName:public_api() {:method; ...}            Method example: Animal:show_taxonomy() { :method; ... }
# ClassName:PrivateAPI() {:method; ...}            Method example: Animal:GetPedigreeJSON() { :method; ... }
#
##### INSTANCE DEFINITIONS AND USE
# :new ClassName (.)_InstanceName         Create an instance of ClassName
# $(.)_InstanceName:public_api            Call the public api method
# _ public_api                            Chain the last-referenced instance to call a method
#
##### EXCEPTION HANDLING
# :try { :persist <variable-list>; ... } :catch { ... }     Run :try block in subshell, persisting named variables

# Annotations begin in column 1 with the ^ symbol and create, replace, update, or delete functions.
^word arg1 arg2 arg3 --option1 --option2 --option3
^help <<EOF
:man ""
EOF
@ mine()
{
   # Assume the following compilation moment in time: File being compiled: com.p/c/u/d/f.sh
   # To prevent transforming the idioms below, prefix with a backslash. For example, \(@)::x becomes (@)::x
   echo "---------------------------   PACKAGE SCOPE"
   echo "Package Name                  (@)"                          # com.p
   echo "Package Function              (@)::x"                       # com.p::x
   echo "Package Variable              (@)_var"                      # com_p__var
   echo "Core Package Function         (@@)::x"                      # com.eggsh.core::x
   echo "External Package Name         (@:com.acme)"                 # com.acme
   echo "External Package Function     (@:com.acme)::x"              # com.acme::x
   echo "Core Package Variable         (@@)_var"                     # com.eggsh.core__var
   echo "External Package Variable     (@:com.acme)_var"             # com_acme__var

   echo "---------------------------   COMPONENT SCOPE"
   echo "Component Function            (+)::x"                       # com.p:c::x
   echo "Other Component Function      (+:cc)::x"                    # com.p:cc::x
   echo "Component Variable            (+)_var"                      # com_p___c__var
   echo "Other Component Variable      (+:cc)_var"                   # com_p___cc__var
   echo "Core Component Function       (++:cc)::x"                   # com.eggsh.core:cc::x
   echo "External Component Function   (+:com.acme:cc)::x"           # com.acme:cc::x
   echo "External Component Variable   (+:com.acme:cc)_var"          # com_acme___cc__var

   echo "---------------------------   UNIT SCOPE"
   echo "Unit Function                 (-)::x"                       # com.p:c:u::x
   echo "Unit Variable                 (-)_var"                      # com_p___c___u__var
   echo "Other Unit Function           (-:uu)::x"                    # com.p:c:uu::x
   echo "Other Unit Variable           (-:uu)_var"                   # com_p___c___uu__var

   echo "---------------------------   FUNCTION"
   echo "Function Variable             (.)_var"                      # com_p___c___u__mine__var

   echo "---------------------------   PATHS"
   echo "Package Path                  (@/)"                         # /.../com.p
   echo "Component Path                (+/)"                         # /.../com.p/c
   echo "File's Directory              (/)"                          # /.../com.p/c/u/d
   echo "File's Path                   (=)"                          # /.../com.p/c/u/d/f.sh
}

# Component Function Declaration
#+ test_it() { echo "Component Scope Function Declaration"; }

# Unit Function Declaration
#- test_it() { echo "Unit Scope Function Declaration"; }

# TODO: Hooks and Callbacks

#  += <hook> <callback> [ <static-args> ]          : Add a callback to a hook with static args
#  -= <hook> <callback>                            : Delete a callback from a hook
#  =  <hook> [ <dynamic-args> ]                    : Call all callbacks registered against a hook with dynamic args
#
#  =do <command> <args>                            : Other hook & callback functionality (TBD)
#  =do rearrange <hook> --callback <cb> --before <cb1>
