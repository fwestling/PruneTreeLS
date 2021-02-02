  featFormat=$(echo $featFields | sed 's/\b\w*\b/d/g')
    
    dBin=$(echo $fields | sed 's/\b\w*\b/d/g')
    
    [[ -d $infile ]] && error "Directory classification not yet supported"
    prep_file $infile $method $indir $bin $fields $fs $es $gs $gr $verbose |
    if `echo $fields | csv-fields has --fields=cl`
    then
        csv-select --binary=$bin,$featFormat --fields=$fields,$featFields "cl;less=2"
    else
        cat
    fi |
    csv-from-bin $bin,$featFormat |
    parallel -n 160000 --block 32M --pipe ~/src/tree-crops/phenotyping-lidar/trunk-classification/trunk-skl classify -m=$model -f=$(echo $fields | csv-fields clear),$featFields |
    # Remove weird formatting
    csv-to-bin $dBin,$featFormat,d | csv-from-bin $dBin,$featFormat,d |
    # Return as-is
    csv-to-bin $bin,$featFormat,ui |
    csv-shuffle -b=$bin,$featFormat,ui -f=$fields,$featFields,pred -o=$fields,pred |
    if [[ $show ]]
    then
        tee >(view-points "-;binary=$bin,ui;fields=$fields,id;size=20000000")
    else
        cat
    fi
}

function baseline() {
    infile=$1
    bin=$2
    fields=$3
    fs=$4
    es=$5
    gs=$6
    gr=$7
    indir=$8
    method="graph"
    
    echo "$infile" >&2
    
    featFields=$(get_fields $method $es)
    featFormat=$(echo $featFields | sed 's/\b\w*\b/d/g')
    
    prep_file $infile $method $indir $bin $fields $fs $es $gs $gr $verbose |
    if `echo $fields | csv-fields has --fields=cl`
    then
        csv-select --binary=$bin,$featFormat --fields=$fields,$featFields "cl;less=2"
    else
        cat
    fi |
    csv-eval --binary=$bin,$featFormat --fields=$fields,$featFields "pred=where(score==1,1,0)" --output-format=ui |
    csv-shuffle -b=$bin,$featFormat,ui -f=$fields,$featFields,pred -o=$fields,pred |
    if [[ $show ]]
    then
        tee >(view-points "-;binary=$bin,ui;fields=$fields,id;size=20000000")
    else
        cat
    fi
}

function bl-validate() {
    method="graph"
    indir=$1
    bin=$2
    fields=$3
    fSize=$4
    eSize=$5
    gSize=$6
    gRad=$7
    setSize=$8
    
    # Get list of files to test
    echo "$method" | egrep -qi "graph" && cores=1 || cores=8 #I don't have enough RAM to parallel graph...
    featFields=$(get_fields $method $eSize)
    featFormat=$(echo $featFields | sed 's/\b\w*\b/d/g')
    
    all_sets=`find $indir -regex ".*\.bin" | shuf`
    lines=`echo "$all_sets" | wc -l | csv-eval --fields=x --format=d "x=round(x*$prop)"`
    test=`echo "$all_sets" | head -$lines`
    
    echo "$test" | parallel -n 1 -j $cores baseline {} $bin $fields $fSize $eSize $gSize $gRad $indir |
    csv-sort -b=$bin,ui -f=$(echo $fields | csv-fields clear --except=cl),b |
    csv-calc size -b=$bin,ui -f=$(echo $fields | csv-fields clear --except x,cl | csv-fields rename --fields=x,cl --to=a,id),block |
    csv-from-bin 3ui |
    csv-calc sum --format=3ui --fields=a,id --append |
    csv-calc sum --format=4ui --fields=a,,id --append |
    csv-eval --format=5d --fields=tp,gt,pred,tpfn,tpfp "prec=where(gt==pred,tp/tpfp,0);rec=where(gt==pred,tp/tpfn,0);f=where(gt==pred,(2*prec*rec)/(prec+rec),0)" 2>/dev/null |
    csv-calc sum --format=5ui,3d --fields=,id,,,,p,r,f #| tee /dev/stderr
    
    [[ $verbose ]] && echo "Results acquired!" >&2
    
}

function go() {
    op=$1
    method=$2
    indir=$3
    bin=$4
    fields=$5
    iter=$6
    prop=$7
    fs=$8
    es=$9
    setsize=${10}
    algo=${11}
    gs=${12}
    gr=${13}
    modelDir=${14}
    
    [ -d $modelDir ] || mkdir -p $modelDir
    
    model=$modelDir/trained.model
    case "$op" in
        classify)
            [ -f $modelDir/algorithm.txt ] && algo=`cat $modelDir/algorithm.txt`
            [ -f $modelDir/fSize.txt ] && fs=`cat $modelDir/fSize.txt`
            [ -f $modelDir/eSize.txt ] && es=`cat $modelDir/eSize.txt`
            [ -f $modelDir/gSize.txt ] && gs=`cat $modelDir/gSize.txt`
            [ -f $modelDir/gRad.txt ] && gr=`cat $modelDir/gRad.txt`
            [ -f $modelDir/method.txt ] && method=`cat $modelDir/method.txt`
            [ -f $model ] || error "Model file $model not found"
            infile=$indir
            [ -d $infile ] && infile=`find $indir | grep ".*bin$" | tail -3 | head -1`
            classify $method $infile $bin $fields $fs $es $gs $gr $model $indir $verbose
        ;;
        train)
            train $method $indir $bin $fields $prop $fs $es $setsize $algo $gs $gr $model
            echo "$algorithm" > $modelDir/algorithm.txt
            echo "$fs" > $modelDir/fSize.txt
            echo "$es" > $modelDir/eSize.txt
            echo "$gs" > $modelDir/gSize.txt
            echo "$gr" > $modelDir/gRad.txt
            echo "$method" > $modelDir/method.txt
        ;;
        validate)
            validate $method $indir $bin $fields $iter $prop $fs $es $setsize $algo $gs $gr $model
            echo "$algorithm" > $modelDir/algorithm.txt
            echo "$fs" > $modelDir/fSize.txt
            echo "$es" > $modelDir/eSize.txt
            echo "$gs" > $modelDir/gSize.txt
            echo "$gr" > $modelDir/gRad.txt
            echo "$method" > $modelDir/method.txt
        ;;
        baseline)
            [ -f $modelDir/algorithm.txt ] && algo=`cat $modelDir/algorithm.txt`
            [ -f $modelDir/fSize.txt ] && fs=`cat $modelDir/fSize.txt`
            [ -f $modelDir/eSize.txt ] && es=`cat $modelDir/eSize.txt`
            [ -f $modelDir/gSize.txt ] && gs=`cat $modelDir/gSize.txt`
            [ -f $modelDir/gRad.txt ] && gr=`cat $modelDir/gRad.txt`
            [ -f $modelDir/method.txt ] && method=`cat $modelDir/method.txt`
            [ -f $model ] || error "Model file $model not found"
            infile=$indir
            [ -d $infile ] && infile=`find $indir | grep ".*bin$" | tail -3 | head -1`
            baseline $infile $bin $fields $fs $es $gs $gr $indir
        ;;
        baseval)
            [ -f $modelDir/algorithm.txt ] && algo=`cat $modelDir/algorithm.txt`
            [ -f $modelDir/fSize.txt ] && fs=`cat $modelDir/fSize.txt`
            [ -f $modelDir/eSize.txt ] && es=`cat $modelDir/eSize.txt`
            [ -f $modelDir/gSize.txt ] && gs=`cat $modelDir/gSize.txt`
            [ -f $modelDir/gRad.txt ] && gr=`cat $modelDir/gRad.txt`
            [ -f $modelDir/method.txt ] && method=`cat $modelDir/method.txt`
            [ -f $model ] || error "Model file $model not found"
            bl-validate $indir $bin $fields $fs $es $gs $gr $setsize
        ;;
    esac
    
    [[ $verbose ]] && echo "" >&2
}

function option-description
{
    cat <<eof
--method=[<method>]; default=ma; Classification method to use [ma|sffi|graph|ma-graph|sffi-graph|ma-stat|sffi-stat|graph-stat|ma-graph-stat|sffi-graph-stat|vic|vic-graph]
--input-dir=[<directory>]; default="/mnt/data/training/finished/"; Directory or single file containing point cloud/s to operate on
--binary=[<format>]; default=3d,2ui,d; Binary format used in point clouds
--fields=[<fields>]; default=x,y,z,cl,seg,height; Point cloud fields, must include "x,y,z,cl"
--iterations=[<iterations>]; default=10; Number of iterations of Monte-Carlo cross-validation.
--test-size=[<proportion>]; default=0.2; Between 0 and 1, proportion to use for test (versus training).
--filter-size=[<size>]; default=0.2; Size to parse filter down to for eigenvalue calculation
--eigen-size=[<radius>]; default=0.45; Eigenvalue radius for eigenvalue calculation
--graph-size=[<size>]; default=0.05; Size to voxelise to for graphing
--graph-radius=[<radius>]; default=0.1; Radius for graphing
--n-points=[<size>]; default=200; Number of examples of each class (from each tree) to use for training.
--learning=[<algorithm>]; default=svm; Learning algorithm to use (gmm|svm)
--model=[<directory>]; default=model; Directory to save model details
--verbose, -v; Output progress to stderr
--show, -s; Visualise the output of the run
eof
}

function usage
{
    cat <<eof

$name Runs a given script for trunk classification and validates if it works satisfactorily.

usage: File $name [train | classify | validate | baseline | baseval ] [options]

Operations:
  train; train an algorithm on an input directory
  classify; given a pre-trained model in --model, classify a point cloud
  validate; train a model, run it on test data, compute characteristics
  baseline;
  baseval;

options:
$( option-description  | sed 's/^/    /g' )

eof
    exit 1
}

if (( $( comma_options_has --help $@ ) || $( comma_options_has -h $@ ) )) ; then usage ; fi
options=$( option-description | comma-options-to-name-value "$@" ) || error "invalid command line options"
comma_path_value_to_var --prefix="options" <<< "$options"
eval "$( option-description | comma-options-to-name-value "$@" | comma_path_value_mangle )"

(( $( comma_options_has --verbose "$@" ) )) && export readonly verbose=true
(( $( comma_options_has --model "$@" ) )) || options_model=$(mktemp -d)

export -f classify
export -f baseline
export -f add_eigen
export -f add_graph
export -f get_fields
export -f prep_file
export -f add_height
export -f add_weight
# set -e # Kill if anything errors out; we don't want it to run everything on bad datasets
if `echo "classify,train,validate,baseline,baseval" | egrep -q "\b$1\b"`
then
  go $(echo "classify,train,validate,baseline,baseval" | egrep -oi "\b$1\b") $options_method $options_input_dir $options_binary $options_fields $options_iterations \
    $options_test_size $options_filter_size $options_eigen_size $options_n_points $options_learning $options_graph_size $options_graph_radius $options_model
else
  error "No valid operation provided: [ classify | train | validate | baseline | baseline-validate ]"
fi

(( $( comma_options_has --model "$@" ) )) || rm -rf $options_model
