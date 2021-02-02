sion coefficient to use
--voxel-size=[<size>]; default=0.05; Size of voxels for thinned point cloud processing
--voxel-weight=[<weight>]; default=4; Minimum weight for voxel to count as solid matter
--latitude=[<latitude>]; default=-25.143641572052292; latitude of location on Earth where raytracing is happening.
--longitude=[<longitude>]; default=152.37746729565248; longitude of location on Earth where raytracing is happening.
--utc-offset=[<offset>]; default=10; UTC offset of location on Earth where raytracing is happening.
--step-date=[<step>]; default=1; day-level resolution of sky generation
--step-hours=[<step>]; default=0.5; hourly resolution of sky generation
--no-trace; Skip raytracing step; output file must exist from a previous raytrace. Mostly for debugging purposes/changing the postprocess
--avoid-trace; Skip raytracing if possible; If output file exists, do nothing. Mostly for debugging purposes/changing the postprocess
--weather-file=[<file>];default="/mnt/sequoia/u16/mantis-shrimp-data/datasets/bundaberg/weather/vantage-pro/weather-combined.txt"
--pc-dir=[<directory>];default="georeferenced"; directory where georeferenced point clouds can be found
--row=[<row>]; default=8; Orchard row in which tree exists
--tree=[<tree>]; default=12; Number of trees from the end of the row
--from=[<direction>]; default=e; Direction from which tree number is counted
eof
}

function usage
{
    cat <<eof

$name assists with modelling ceptometer measurements using Samuel Orn's light model.  First the user is prompted to select ceptometer grid stakes to align
the simulated grid.  The program then runs the raytracing and processes the output into a standard form.

usage: $name [options]


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

go $1 $options_start_date $options_end_date $options_repeats $options_output_dir $options_latitude $options_longitude $options_utc_offset $options_coeff $options_voxel_size $options_voxel_weight $options_step_date $options_step_hours $options_weather_file $options_row $options_tree $options_from $options_pc_dir
