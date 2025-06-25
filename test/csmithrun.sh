for ((i = 1; i <= $1; i++)); do
    printf -v padded "%05d" "$i"
    echo "cfiles/$padded.c"
    ./csmith \
        -o cfiles/$padded.c\
        -s $padded\
        --probability-configuration csmith.prob\
        --quiet\
        --max-funcs 1\
        --max-array-dim 1\
        --no-jumps\
        --no-argc\
        --no-unions\
        --no-pointers\
        --no-packed-struct\
        --no-pre-incr-operator\
        --no-pre-decr-operator\
        --no-global-variables\
        --no-embedded-assigns\
        --no-comma-operators\
        --max-expr-complexity 2\
        --max-block-depth 3\

done
