# spl-compiler-tester

## Step1 - Set the compiler type and PATH

```
export SPL_COMPILER_CONF="java:/home/dummy/compilerbau/java/target"
```

## Step2 - Run the Setup script

```
chmod +x setup.sh && ./setup.sh
```

## You can now run the generated file "__run_tests.sh__"

Eg:

Run 'scanner' tests
```
./run_tests.sh tokens
```

Run 'parser' tests
```
./run_tests.sh parse
```

Run 'absyn' tests
```
./run_tests.sh absyn
```

Run 'tables' tests
```
./run_tests.sh tables
```

Run 'semant' tests
```
./run_tests.sh semant
```

Run 'vars' tests
```
./run_tests.sh vars
```

Run 'codegen' tests
```
./run_tests.sh codegen
```
