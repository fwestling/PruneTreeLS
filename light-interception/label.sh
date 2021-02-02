#!/bin/bash

## Stratified labelling utility
### Splits up a point cloud by height to add a binary label to it

export readonly name=$( basename $0 )

source $( type -p comma-application-util ) || (error "comma not installed")
function errcho { (>&2 echo "$name: $1") }
function error
{
    errcho "error: $1"
    exit 1
}

function go () {
  DIR="${BASH_SOURCE%/*}"
  echo "DIR: $DIR" >&2

  bin=$1
  fields=$2
  step=$3
  zd=$4

  echo "ZD: $zd">&2
  echo "ST: $step">&2

  cond="new_id<9"
  invcond="new_id==9"
  [[ $invert ]] && cond="new_id>=9"
  [[ $invert ]] && invcond="new_id<9"

  # temp=`mktemp -d`
  temp=temp
  [[ -d $temp ]] && rm -rf $temp
  mkdir $temp
  cd $temp
  cat |
  csv-eval --binary=$bin --fields=$fields "new_z=z+$zd;slice = abs(floor(new_z/$step))" --output-format=d,ui |
  csv-split --binary=$bin,d,ui --fields=`echo $fields|csv-fields clear`,,id
  if echo "$fields" | csv-fields has --fields=id
  then
    ev="where(id==1,1,new_id)"
    [[ $invert ]] && ev="where(id==1,9,new_id)"
    for f in *bin
    do
      cat $f | csv-eval --binary=$bin,d,ui --fields=$fields,,new_id "new_id=$ev" > $f.fnl
    done
    label-points *fnl --binary=$bin,d,ui --fields=`echo $fields | csv-fields clear --except x,y`,z,id >/dev/null
    cat *fnl | csv-eval --binary=$bin,d,ui --fields=$fields,new_z,new_id "id=where($cond,1,id);id=where($invcond,0,id);new_id=where($cond,1,0)" |
      view-points --binary=$bin,d,ui --fields=$fields,,scalar --colour=0:1,red:green --size=8000000 >/dev/null
    cat *fnl | csv-eval --binary=$bin,d,ui --fields=$fields,new_z,new_id "id=where($cond,1,id);id=where($invcond,0,id);new_id=where($cond,1,0)" |
    if [[ $extract ]]
    then
      csv-select --binary=$bin,d,ui --fields=$fields,,new_id "new_id;equals=1" |
      csv-shuffle --binary=$bin,d,ui --fields=$fields -o=$fields
    else
      csv-shuffle --binary=$bin,d,ui --fields=$fields,,new_id -o=$fields
    fi | cat

  else
     label-points *bin --binary=$bin,d,ui --fields=`echo $fields | csv-fields clear --except x,y`,z,id >/dev/null
     cat *.bin | csv-eval --binary=$bin,d,ui --fields=$fields,new_z,new_id "new_id=where($cond,1,0)" |
       view-points --binary=$bin,d,ui --fields=$fields,,scalar --colour=0:1,red:green --size=8000000 >/dev/null
     cat *.bin | csv-eval --binary=$bin,d,ui --fields=$fields,new_z,new_id "new_id=where($cond,1,0)" |
     if [[ $extract ]]
     then
       csv-select --binary=$bin,d,ui --fields=$fields,,new_id "new_id;equals=1" |
       csv-shuffle --binary=$bin,d,ui --fields=$fields -o=$fields
     else
       csv-shuffle --binary=$bin,d,ui --fields=$fields,,new_id -o=$fields,new_id
     fi | cat

  fi
  cd ..
  rm -rf $temp
}

function option-description
{
    cat <<eof
--binary=[<format>]; default=3d; Binary format of point cloud
--fields=[<fields>]; default=x,y,z; Fields of point cloud; must include at least x,y,z
--step-size=[<size>]; default=0.3; Size in Z to split point cloud into
--extract; Instead of appending an ID field, remove 0 points.
--invert; Appends 0 to ID<9 instead of 0
eof
}

function usage
{
    cat <<eof

    $name assists with labelling point clouds with a binary value.
    The point cloud is split up by height to simplify selection of occluded features.
    Post-processing, all ID's less than 9 are set to 1, all others to 0.
    This utility creates a temp directory which is deleted unless the utility fails.
    All created temp directories are wiped on reboot worst case.

usage: $name <pc> [options]

positional argument:
pc=<file>; Point cloud

options:
$( option-description  | sed 's/^/    /g' )

eof
    exit 1
}

if (( $( comma_options_has --help $@ ) || $( comma_options_has -h $@ ) )) ; then usage ; fi
options=$( option-description | comma-options-to-name-value "$@" ) || error "invalid command line options"
comma_path_value_to_var --prefix="options" <<< "$options"
eval "$( option-description | comma-options-to-name-value "$@" | comma_path_value_mangle )"

(( $( comma_options_has --extract "$@" ) )) && export readonly extract=true
(( $( comma_options_has --invert "$@" ) )) && export readonly invert=true

zDiff=0 # zDiff is used to compensate when a point cloud is close to 0 so IDs won't work

mean=$(cat $1 |
  csv-calc mean --binary=$options_binary --fields=`echo $fields | csv-fields clear --except z` |
  csv-from-bin d)
(( $(echo "$mean >= 0" | bc) )) && zDiff=10000
(( $(echo "$mean < 0" | bc) )) && zDiff=-10000


cat $1 | go $options_binary $options_fields $options_step_size $zDiff
