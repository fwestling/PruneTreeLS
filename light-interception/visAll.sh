#!/bin/bash

export readonly name=$( basename $0 )

source $( type -p comma-application-util ) || (error "comma not installed")
function errcho { (>&2 echo "$name: $1") }
function error
{
    errcho "error: $1"
    exit 1
}

function paraGo () {
    f=$1
    cepto_dir=$2
    result_policy=$3
    result_radius=$4
    time_steps=$5
    idx=$6
    nFiles=$7
    coeff=$8
    # pFlag=
    # opflag=
    prc=$(echo "$idx*100/$nFiles" | bc)
    
    d=$(echo "$f" | sed 's/\/cepto.bin//')
    sDate=$(echo "$f" | egrep -o "\/[0-9]{8}\/" | tr -d '/')
    sTime=$(echo "$f" | egrep -o "\-[0-9]{4}" | tr -d '-')
    treeName=$(echo "$f" | egrep -o "r[0-9]*t[0-9]*[ew]")
    row=$(echo "$treeName" | tr 'a-z' '.' | cut -d'.' -f2)
    tree=$(echo "$treeName" | tr 'a-z' '.' | cut -d'.' -f3)
    from=$(echo "$treeName" | egrep -o ".$")
    read_file="/home/fwes7558/data/labelled/$sDate/r$row-t$tree$from-labelled.bin"
    raytrace-cepto.sh $read_file --row=$row --tree=$tree --from=$from \
    --cepto-file=$cepto_dir/$sDate/$treeName-$sTime.csv --result-policy=$result_policy --result-radius=$result_radius \
    --output-dir=$d --openair-file=$cepto_dir/open-$sDate.csv --coeff=$coeff \
    --time-steps=$time_steps $flag $avFlag --no-show --no-trace --raytrace-scale=1 --no-snap --no-align 2>>recepto.log
    echo -en "$prc%, " >&2
}

function go () {
    out_dir=$1
    cepto_dir=$2
    time_steps=$3
    result_policy=$4
    result_radius=$5
    coeff=$6
    
    out_dir=$(echo "$out_dir" | tr '?' '*')
    files=$(find $out_dir -mindepth 2 -maxdepth 2 | grep -v \/cycles\/)
    # files=$(find $out_dir -regex '.*/cepto.bin')
    nFiles=$(echo "$files" | wc -l)
    idx=1
    [[ $no_open ]] && opflag="--no-open"
    [[ $planar ]] && pFlag="--planar"
    
    export -f paraGo
    # touch all.data.csv
    echo "$files" | parallel -n 1 paraGo {} $cepto_dir $result_policy $result_radius $time_steps {#} $nFiles $coeff
    echo "done" >&2
}

function option-description
{
    cat <<eof
--output-dir=[<directory>]; default=outputs; directory which contains raytrace data.  Should be organised as ./20161215/r8t12e-1500/{outputs-from-cepto-raytrace}
--cepto-dir=[<file>]; default=cepto-data/processed; directory in which processed ceptometer data can be found.
--result-policy=[<policy>]; default=density-mean; policy to use for result generation: must be "mean", "min", "max", "nearest", "median" or "optimal"
--result-radius=[<radius>]; default=0.1; radius (m) around actual cepto location to consider for result generation
--voxel-size=[<size>]; default=0.05; Size of voxels for thinned point cloud processing
--no-open; Don't perform openair calibration during postprocessing
--time-steps=[<N>]; default=1; Split time window into N sections
--planar; Remove ground and insert a regular planar grid
--raytrace-scale=[<scale>]; default=3; Scaling factor for raytracing
--coeff=[<coeff>]; default=0.80; Coefficient for transmission
eof
}

function usage
{
    cat <<eof

$name Performs a raytrace-cepto process on a set of data files.  These files are assumed to be outputs from raytrace-cepto which need to be rerun (not including alignment step)


usage: $name [options]

options:
$( option-description  | sed 's/^/    /g' )

eof
    exit 1
}

flag="--no-show"
avFlag=""

if (( $( comma_options_has --help $@ ) || $( comma_options_has -h $@ ) )) ; then usage ; fi
options=$( option-description | comma-options-to-name-value "$@" ) || error "invalid command line options"
comma_path_value_to_var --prefix="options" <<< "$options"
eval "$( option-description | comma-options-to-name-value "$@" | comma_path_value_mangle )"
(( $( comma_options_has --no-align "$@" ) )) && flag="--no-align"
(( $( comma_options_has --no-trace "$@" ) )) && flag="--no-trace"
(( $( comma_options_has --no-open "$@" ) )) && export readonly no_open=true
(( $( comma_options_has --average "$@" ) )) && avFlag="--average"
(( $( comma_options_has --validate-time "$@" ) )) && export readonly validate_time=true
(( $( comma_options_has --validate-date "$@" ) )) && export readonly validate_date=true
(( $( comma_options_has --validate-pointcloud "$@" ) )) && export readonly validate_pc=true
(( $( comma_options_has --distribute "$@" ) )) && export readonly distribute=true
(( $( comma_options_has --no-snap "$@" ) )) && export readonly no_snap=true
(( $( comma_options_has --planar "$@" ) )) && export readonly planar=true

set -e # Kill if anything errors out; we don't want it to run everything on bad datasets
touch rsquareds
go $options_output_dir $options_cepto_dir $options_time_steps $options_result_policy $options_result_radius $options_coeff
