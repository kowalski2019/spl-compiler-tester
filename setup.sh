#!/bin/bash

: '
 SETUP
'
curr_dir=`pwd`

comp_lang=`echo $SPL_COMPILER_CONF | cut -d: -f1`
comp_path=`echo $SPL_COMPILER_CONF | cut -d: -f2`

to_rm_0="# NOT TO BE RUN"
to_rm_1='echo "This script is no to be run. Please use'

if [ "$comp_lang" == "java" ]; then
    sed -e "s/__user_java_compiler_path__/$(echo $comp_path | sed -e 's/[\/&]/\\&/g')/" \
	-e "s/__comp_lang__/java/" "$curr_dir/tester_template.sh" | grep -v -e "$to_rm_0" -e "${to_rm_1}.*" > "$curr_dir/run_tests.sh"
else
    sed -e "s/__user_c_compiler_path__/$(echo $comp_path | sed -e 's/[\/&]/\\&/g')/" \
	-e "s/__comp_lang__/c/" "$curr_dir/tester_template.sh" | grep -v -e "$to_rm_0" -e "${to_rm_1}.*" > "$curr_dir/run_tests.sh"
fi

chmod +x "$curr_dir/run_tests.sh" && echo "Happy Hacking!"
