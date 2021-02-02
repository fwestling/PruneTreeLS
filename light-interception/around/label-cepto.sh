#!/bin/bash

# Utility to validate performance of segmentation scripts

export readonly name=$( basename $0 )

source $( type -p comma-application-util ) || (error "comma not installed")
function errcho { (>&2 echo "$name: $1") }
function error
{
    errcho "error: $1"
    exit 1
}

function doCloud_finished() {
    pc=$1
    bin=$2
    fields=$3
    script=$4
    vs=$5
    rad=$6
    trunks=$7
    indir=$8
    groundID=$9
    
}

function go_real() {
    indir=$1
    bin=$2
    fields=$3
    vs=$425
    rad=$5
    script=$6
    trunks=$7
    groundID=$8
    all_clouds=$(find $indir -regex ".*\.bin")
    
    export -f doCloud
    
    # This loop can be parallelised (though I don't have the RAM for it...)
    for cloud in `echo "$all_clouds"`
    do
        filename=$(echo $cloud | sed 's/.*\///')
        
        [[ $verbose ]] && echo "============ $filename ============" >&2
        
        # treeName=`echo "$pc" | sed 's/.*finished\///' | tr '/' ','`
        treeName=`echo "$pc" | sed 's/$indir\///' | tr '/' ','`
        echo -n "$filename,"
        TRUNKS=`mktemp`
        cat /mnt/data/trunks.csv | grep "simpsons" | cut -d, -f9- > $TRUNKS
        #$script $pc --binary=$bin --fields=$fields --voxel-size=$vs --radius=$rad --trunks=$trunks --dataset="," --ground-id=$groundID $verbosity |
        graph-op segment $cloud --binary=$bin --fields=$fields --voxel-size=$vs --radius=$rad --trunks=$trunks --dataset="," --ground-id=$groundID |
        csv-select -b=$bin,ui -f=$fields,pred/seg "cl;not-equal=$groundID" | # Don't compare to ground...we only want to see how the trees have been distinguished.
        # csv-select -b=$bin,ui -f=$fields,pred/seg "cl;greater=0" | # Don't compare to ground...we only want to see how the trees have been distinguished.
        csv-shuffle -b=$bin,ui -f=$fields,pred/seg -o=seg,pred/seg |
      csv-from-bin 2ui | python <(cat << END
  import sys
  import numpy as np
  from sklearn.metrics.cluster import v_measure_score
  DATA = np.genfromtxt(sys.stdin.readlines(), delimiter=',')
  print v_measure_score(DATA[:, 0], DATA[:, 1])
  END
    )
done

# echo "$all_clouds" | parallel -n1 -j1 doCloud {} $bin $fields $script $vs $rad $trunks

}

function option-description
{
    cat <<eof
--input-dir=[<directory>]; default=/mnt/data/training/finished; Directory containing point clouds to measure against
--binary=[<format>]; default=3d,2ui,d; Binary format used in point clouds
--fields=[<fields>]; default=x,y,z,cl,seg,h; Point cloud fields, must include "x,y,z,seg"
--voxel-size=[<size>]; default=0.1; voxel size to use to speed up computation.
--script=[<script>]; default=segment-simplistic; Script to test
--radius=[<radius>]; default=0.2; radius to use for graph edge computation.
--trunk-file=[<file>]; default=/mnt/data/trunks.csv; file containing trunks
--ground-id=[<UID>]; default=2; ID (cl) of ground points
--verbose, -v; Output progress to stderr
eof
}

function usage
{
    cat <<eof

$name Runs a given script for tree segmentation and validates if it works satisfactorily.

usage: File $name [options]

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

set -e # Kill if anything errors out; we don't want it to run everything on bad datasets

go_real $options_input_dir $options_binary $options_fields $options_voxel_size $options_radius $options_script $options_trunk_file $options_ground_id
