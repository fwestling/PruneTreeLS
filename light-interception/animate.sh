readonly no_trace=true
(( $( comma_options_has --avoid-trace "$@" ) )) && export readonly avoid_trace=true

(( $( comma_options_has --start-date "$@" ) )) || { echo "--start-date required" >&2 && exit; }
(( $( comma_options_has --end-date "$@" ) )) || { echo "--end-date required" >&2 && exit; }
set -e # Kill if anything errors out; we don't want it to run everything on bad datasets

[[ $options_trace_date == "NONE" ]] && options_trace_date=$options_start_date

go $1 $options_start_date $options_end_date $options_repeats $options_output_dir $options_latitude $options_longitude $options_utc_offset $options_coeff $options_voxel_size $options_voxel_weight $options_step_date $options_step_hours $options_weather_file $options_row $options_tree $options_from $options_raw_data $options_trace_date		echo "_" >&2 
	  fi
  done
  echo "finished?"
}

function option-description
{
    cat <<eof
--binary=[<format>]; default=3d; Binary format used in point clouds
--fields=[<fields>]; default=x,y,z; Point cloud fields, must include "x,y,z"
--single-date=[<date>]; Date when sky integration is to begin
--output-dir=[<file>]; default=outputs; directory to save outputs in
--coeff=[<coefficient>]; default=0.80; average transmission coefficient to use
--voxel-size=[<size>]; default=0.05; Size of voxels for thinned point cloud processing
--voxel-weight=[<weight>]; default=1; Minimum weight for voxel to count as solid matter
--latitude=[<latitude>]; default=-25.143641572052292; latitude of location on Earth where raytracing is happening.
--longitude=[<longitude>]; default=152.37746729565248; longitude of location on Earth where raytracing is happening.
--utc-offset=[<offset>]; default=10; UTC offset of location on Earth where raytracing is happening.
--weather-file=[<file>];default="/mnt/sequoia/u16/mantis-shrimp-data/datasets/bundaberg/weather/vantage-pro/weather-combined.txt"
--to-png; Flag sets program to generate png screenshots of each time
--bigsky=[<dir>]; Location of big skies; if defined, won't regenerate them.
eof
}

function usage
{
    cat <<eof

$name animates the activity of Samuel Orn's light model.  It does this by producing a sky model for every half hour from 6AM to 9PM on the given day,
raytracing the given point cloud for each of those times, and finally screen-capturing view-points of the sky and point cloud.

usage: $name <pc> [options]

positional argument:
point_cloud=<file>; binary point cloud containing visible ceptometer stakes to which the grid should be aligned.  PC should consist of georeferenced XYZ points only

mandatory arguments:
--single-date=[<date>]; Date of sky simulation

options:
$( option-description  | sed 's/^/    /g' )

eof
    exit 1
}

if (( $( comma_options_has --help $@ ) || $( comma_options_has -h $@ ) )) ; then usage ; fi
options=$( option-description | comma-options-to-name-value "$@" ) || error "invalid command line options"
comma_path_value_to_var --prefix="options" <<< "$options"
eval "$( option-description | comma-options-to-name-value "$@" | comma_path_value_mangle )"

(( $( comma_options_has --single-date "$@" ) )) || { echo "--single-date required" >&2 && exit; }
(( $( comma_options_has --to-png "$@" ) )) && export readonly toPng=true
# set -e # Kill if anything errors out; we don't want it to run everything on bad datasets

go $1 $options_binary $options_fields $options_single_date $options_output_dir $options_latitude $options_longitude $options_utc_offset $options_coeff $options_voxel_size $options_voxel_weight $options_weather_file $options_bigsky
