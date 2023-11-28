#!/usr/bin/env bash

tmpdir=$(mktemp -d)
curr_dir=`pwd`

trap 'echo "removing directory $tmpdir ..." && rm -rf "${tmpdir}"' INT TERM

help(){

    cat <<EOF
HELP
EOF
}
option1="$1"
option2="$2"

if [ $# -eq 1 ]; then
  echo "one parameter just compile"
  [ "$option1" == "build" ] && mvn clean package && echo "Nothing to do bye" && exit 0
  phase="$option1"
elif [ $# -eq 2 ]; then
  echo "two parameters"
  [ "$option1" == "build" ] && mvn clean package
  phase="$option2"
else
  echo "Nothing to do" && exit 0
fi

runtime_test_dir="$curr_dir/spl-testfiles/runtime_tests"
semant_test_dir="$curr_dir/spl-testfiles/semant_errors"
syntax_error_test_dir="$curr_dir/spl-testfiles/syntax_errors"

codegen_test_dir="$curr_dir/spl-testfiles/runtime_tests"
assembler="$curr_dir/eco32tools/compile_s.sh"

java_ref_path="$curr_dir/java_ref"
c_ref_path="$curr_dir/eco32tools/bin"

user_c_compiler_path="__user_c_compiler_path__"
user_java_compiler_path="/home/csmk/Claude/Tools/Scratch/Compilerbaup/target"

tests_1=($(ls $runtime_test_dir | grep .*.spl))
tests_2=($(ls $semant_test_dir | grep .*.spl))
tests_3=($(ls $syntax_error_test_dir | grep .*.spl))
tests_4=($(ls $codegen_test_dir | grep .*.bin))

if [ "$phase" == "--tables" ]; then
  tests_dir="$runtime_test_dir"
  tests_dir_without_path="${tests_1[*]}"
elif [ "$phase" == "--semant" ]; then
  tests_dir="$semant_test_dir"
  tests_dir_without_path="${tests_2[*]}"
elif [ "$phase" == "--vars" ]; then
  tests_dir="$runtime_test_dir"
  tests_dir_without_path="${tests_1[*]}"
else
  tests_dir="$runtime_test_dir"
  tests_dir_without_path="${tests_1[*]}"
fi

echo "tests_dir: $tests_dir phase: $phase" | tee test_results.log

: '
execute cmd and return res and exit code 
'
compiler() {
    t_file="$1"
    t_dir="$2"
    res=""
    exit_code="0"

    prog_lang="$3"
    compiler_path="$4"
    if [ "$phase" == "--codegen" ]; then
	# redirect to output_dir
	output_file="${tmpdir}/${t_file}_own.s"
	output_file_without_ext="${tmpdir}/${t_file}_own"

	# compiler the test file
	if [ $prog_lang == "java" ]; then
	    java -jar $compiler_path "${t_dir}/${t_file}" "$output_file"
	else
	    $compiler_path "${t_dir}/${t_file}" "$output_file"
	fi

	# assemble to bin
	[ $? -eq 0 ] &&	"$assembler" "$output_file_without_ext"
	# exec and return exit code
	[ $? -eq 0 ] && res=$(echo "1 2 3 4 5 6 7 8 9" | "${c_ref_path}/sim" -l "${output_file_without_ext}.bin" -x -s 1)
	exit_code="$?"
    else
	if [ $prog_lang == "java" ]; then
	    res=$(java -jar "$compiler_path" "$phase" "$t_dir/$t_file" 2>&1)    
	else
	    res=$("$compiler_path" "$phase" "$t_dir/$t_file" 2>&1)
	fi
	exit_code="$?"
    fi
    case $phase in
	--semant)
	    echo "$exit_code"
	    ;;
	--codegen)
	    echo -e "$res \n $exit_code"
	    ;;
	*)
	    echo "$res"
	    ;;
    esac
  
}

run_user_java_compiler() {
    _res=`compiler $1 $2 "java" "$user_java_compiler_path/spl-0.1.jar" `
    echo $_res
}

run_user_c_compiler() {
    _res=`compiler $1 $2 "c" $user_c_compiler_path/spl`
    echo $_res
}

run_java_ref_compiler() {
    _res=`compiler $1 $2 "java" "$java_ref_path/spl-0.1.jar" `
    echo $_res
}

run_c_ref_compiler() {
    _res=`compiler $1 $2 "c" $c_ref_path/refspl`
    echo $_res
}


echo "YOUR TURN" | tee -a test_results.log
for f in ${tests_dir_without_path[*]}; do
  echo "$tests_dir/$f"
  if [ "$phase" == "--codegen" ] && [ "$f" == "lambda.spl" ]; then
    echo "0" >"${tmpdir}/${f}_own"
  else
    tmp_own_res=$(run_user_java_compiler "$f" "$tests_dir")
    echo "$tmp_own_res" >"${tmpdir}/${f}_own"
  fi

done


echo "REF TURN" | tee -a test_results.log
for f in ${tests_dir_without_path[*]}; do
  echo "$tests_dir/$f"
  if [ "$phase" == "--codegen" ] && [ "$f" == "lambda.spl" ]; then
    echo "0" >"${tmpdir}/${f}_ref"
  else
    tmp_ref_res=$(run_c_ref_compiler "$f" "$tests_dir")
    echo "$tmp_ref_res" >"${tmpdir}/${f}_ref"
  fi

done


passed=0
nbr_test=0
for f in ${tests_dir_without_path[*]}; do
  tmp_res=$(diff "${tmpdir}/${f}_own" "${tmpdir}/${f}_ref")
  if [ -z "$tmp_res" ]; then
    echo "TEST: $f $tmp_res is fine" | tee -a test_results.log
    passed=`expr $passed + 1`
  else
    echo -e "TEST: $f is not fine \n $tmp_res " | tee -a test_results.log
  fi
  nbr_test=`expr $nbr_test + 1`
done

#echo -e "\n TMPDIR $tmpdir"

#echo "removing directory $tmpdir ..."
echo "removing directory $tmpdir ..." && rm -rf "${tmpdir}"

echo -e "\nFINAL RES FOR $phase"
echo "PASSED ( $passed/$nbr_test )"


