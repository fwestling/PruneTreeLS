readonly no_trace=true
(( $( comma_options_has --avoid-trace "$@" ) )) && export readonly avoid_trace=true

(( $( comma_options_has --start-date "$@" ) )) || { echo "--start-date required" >&2 && exit; }
(( $( comma_options_has --end-date "$@" ) )) || { echo "--end-date required" >&2 && exit; }
set -e # Kill if anything errors out; we don't want it to run everything on bad datasets

[[ $options_trace_date == "NONE" ]] && options_trace_date=$options_start_date

go $1 $options_start_date $options_end_date $options_repeats $options_output_dir $options_latitude $options_longitude $options_utc_offset $options_coeff $options_voxel_size $options_voxel_weight $options_step_date $options_step_hours $options_weather_file $options_row $options_tree $options_from $options_raw_data $options_trace_dateusage: $name <pc> [options]
	
positional argument:
point_cloud=<file>; binary point cloud containing visible ceptometer stakes to which the grid should be aligned.  PC should consist of georeferenced XYZ points only

mandatory arguments:
--start-date=[<date>]; Date when sky integration is to begin
--end-date=[<date>]; Date when sky integration is to end

options:
$( option-description  | sed 's/^/    /g' )

eof
    exit 1
}

if (( $( comma_options_has --help $@ ) || $( comma_options_has -h $@ ) )) ; then usage ; fi
options=$( option-description | comma-options-to-name-value "$@" ) || error "invalid command line options"
comma_path_value_to_var --prefix="options" <<< "$options"
eval "$( option-description | comma-options-to-name-value "$@" | comma_path_value_mangle )"

(( $( comma_options_has --no-trace "$@" ) )) && export readonly no_trace=true
(( $( comma_options_has --avoid-trace "$@" ) )) && export readonly avoid_trace=true

(( $( comma_options_has --start-date "$@" ) )) || { echo "--start-date required" >&2 && exit; }
(( $( comma_options_has --end-date "$@" ) )) || { echo "--end-date required" >&2 && exit; }
set -e # Kill if anything errors out; we don't want it to run everything on bad datasets

[[ $options_trace_date == "NONE" ]] && options_trace_date=$options_start_date

go $1 $options_start_date $options_end_date $options_repeats $options_output_dir $options_latitude $options_longitude $options_utc_offset $options_coeff $options_voxel_size $options_voxel_weight $options_step_date $options_step_hours $options_weather_file $options_row $options_tree $options_from $options_raw_data $options_trace_date