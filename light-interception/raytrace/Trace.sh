#!/bin/bash


# Updated raytrace by Fred, doesn't use temp files
function rayTrace()
{
	local pc=$1
	local sun_altitude=$2
	local sun_azimuth=$3
	local voxel_size=$4
	local write_file=$5
	local bin=$6
	local fields=$7
	local incident_intensity=$8
	declare -a transmittance_list=${9}

	local csv_eval_string=""
	local intensity_fields=""
	local count=0

	# Create eval string for all transmittances
	for transmittance in "${transmittance_list[@]}"
	do
		csv_eval_string="$csv_eval_string""transm$count=$incident_intensity*($voxel_size**2)/weight*($transmittance**ray-$transmittance**(ray+1));"
		intensity_fields="$intensity_fields""transm$transmittance,"
		count=$(echo "$count + 1" | bc)
	done
	intensity_fields=${intensity_fields::-1}
	csv_eval_string=${csv_eval_string::-1}
	local tr_bin="$count""d"

	local only_coord_fields=$(echo $fields | csv-fields clear --except=x,y,z)
	local cleared_fields=$(echo $fields | csv-fields clear)

	# Rotate z towards sun, voxelise, assign ID to z-columns, assign ID to voxels in ascending order in each voxel (NOTE: erases all but one point in each voxel)
	local points=$(
	cat $pc | points-frame --binary=$bin --fields=$only_coord_fields --from "0,0,0,0,0,$(math-deg2rad -$sun_azimuth)" \
	| points-frame --binary=$bin --fields=$only_coord_fields --from "0,0,0,0,$(math-deg2rad $(echo "-90 - $sun_altitude" | bc)),0" \
	| io-tee __ptv_w__ points-to-voxels --binary=$bin --fields=$fields --resolution=$voxel_size \
	| points-to-voxel-indices --binary=$bin --fields=$fields --resolution=$voxel_size \
	| base64)

	echo "$points" | base64 -d \
	| csv-shuffle --binary=$bin,3ui --fields=$fields,vx,vy,vz --output-fields=vx,vy,vz \
	| csv-sort --binary=3ui --fields=a,b,vz --order=b,a \
	| csv-blocks --binary=3ui group --fields=id,id,vz \
	| csv-sort --binary=3ui,ui --fields=c,d,a,b --order=b,a,c,d --reverse \
	| csv-blocks --binary=3ui,ui group --fields=id,id,id \
	| csv-calc --binary=3ui,2ui centre,size --fields=x,y,z,b,block \
	| csv-shuffle --binary=9ui --fields=x,y,z,b,w,,,, --output-fields=x,y,z,w,b \
	| csv-blocks --binary=5ui index --fields=vx,vy,vz,weight,block \
	| csv-shuffle --binary=3ui,3ui --fields=vx,vy,vz,weight,column,ray --output-fields=vx,vy,vz,column,ray,weight \
	| csv-join --binary=3ui,2ui,ui --fields=id,id,id <(echo "$points" | base64 -d)";fields=$cleared_fields,id,id,id;binary=$bin,3ui" \
	| csv-shuffle --binary=3ui,2ui,ui,$bin,3ui \
		--fields=vx2,vy2,vz2,column,ray,weight,$fields,vx1,vy1,vz1 \
		--output-fields=$fields,vx1,vy1,vz1,column,ray,weight \
	| csv-eval --binary=$bin,3ui,3ui --fields=$fields,vx,vy,vz,column,ray,weight $csv_eval_string 
}


function extractAndSum()
{
	local read_file=$1
	local bin=$2
	local fields=$3
	local bin_sum=$4
	local fields_sum=$5
	local write_file=$6

	cat | csv-shuffle --binary=$bin --fields=$fields --output-fields=$fields_sum,uniqueID >> __sums__

}

function sumIrradiances()
{
	local read_file=$1
	local hemisphere_altitude=$2
	local hemisphere_azimuth=$3
	local voxel_size=$4
	local bin=$5
	local fields=$6
	local initial_intensity=$7
	local transmittance_list=$8
	local sum_write_file=$9
	local bin_sum=${10}
	local field_sum=${11}

	rayTrace $read_file $hemisphere_altitude $hemisphere_azimuth $voxel_size integrate_temp $bin $fields $initial_intensity "$transmittance_list" |
	extractAndSum integrate_temp "$bin,3ui,3ui,""$bin_sum" "$fields,vx,vy,vz,col,ray,weight,""$field_sum" $bin_sum $field_sum $sum_write_file

	# rm integrate_temp
}

file=$1
declare -a elevation=$2
declare -a azimuth=$3
voxel_size=$4
bin=$5
fields=$6
leaf_transmittance_list=$7
write_file=$8
tr_bin=$9
intensity_fields=${10}
irradiance=${11}

echo $file
echo $voxel_size
echo $bin
echo $fields
echo "$leaf_transmittance_list"
echo $write_file
echo $tr_bin
echo $intensity_fields
echo $irradiance

kill
hemisphere_altitude=${elevation[$iteration]}
hemisphere_azimuth=${azimuth[$iteration]}
sumIrradiances $file $hemisphere_altitude $hemisphere_azimuth $voxel_size $bin $fields $irradiance "$leaf_transmittance_list" $write_file $tr_bin $intensity_fields
echo -n, $irradiance
	