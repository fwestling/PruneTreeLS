readonly no_trace=true
(( $( comma_options_has --avoid-trace "$@" ) )) && export readonly avoid_trace=true

(( $( comma_options_has --start-date "$@" ) )) || { echo "--start-date required" >&2 && exit; }
(( $( comma_options_has --end-date "$@" ) )) || { echo "--end-date required" >&2 && exit; }
set -e # Kill if anything errors out; we don't want it to run everything on bad datasets

[[ $options_trace_date == "NONE" ]] && options_trace_date=$options_start_date

go $1 $options_start_date $options_end_date $options_repeats $options_output_dir $options_latitude $options_longitude $options_utc_offset $options_coeff $options_voxel_size $options_voxel_weight $options_step_date $options_step_hours $options_weather_file $options_row $options_tree $options_from $options_raw_data $options_trace_date