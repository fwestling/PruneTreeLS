#!/bin/bash

#Adds synthetic ground and calculates interception

function ceptometerVerification()
{

	local read_file=$1
	local binary=$2
	local fields=$3
	local weather_data=$4
	local latitude=$5
	local longitude=$6
	local utc_offset=$7
	local date=$8
	local time_=$9
	local voxel_size=${10}
	local leaf_transmittance=${11}
	local sphere_samples=${12}
	local write_file=${13}
	local mask_file=${14}

	local height_offset=-85.7081068051

	# East side
	local trunk_x1=7219022.38536 
	local trunk_y1=437228.909047
	local rotation1=-14
	local rot_x=3.5
	local rot_y=2

	# West side
	local trunk_x2=$trunk_x1
	local trunk_y2=437213.909047
	local rotation2=$(echo "$rotation1 - 180" | bc)



	echo $(python python/synthetic_ground.py 1 6) | tr -d '[] ' | tr -d "'" | tr ';' '\n' > cepto_grid_1.tmp
	echo $(python python/synthetic_ground.py 101 6) | tr -d '[] ' | tr -d "'" | tr ';' '\n' > cepto_grid_2.tmp

	cat cepto_grid_1.tmp | points-frame --fields=,,,x,y,z --from "$trunk_x1,$trunk_y1,$height_offset,$(math-deg2rad $rot_x),$(math-deg2rad $rot_y),$(math-deg2rad $rotation1)" > cepto_grid.csv
	cat cepto_grid_2.tmp | points-frame --fields=,,,x,y,z --from "$trunk_x2,$trunk_y2,$height_offset,$(math-deg2rad -$rot_x),$(math-deg2rad -$rot_y),$(math-deg2rad $rotation2)" >> cepto_grid.csv

	rm cepto_grid_1.tmp cepto_grid_2.tmp

	csv-paste "$read_file;binary=$binary" "value=0;binary=ui" > __read_temp__ #csv-thin 0.1 --size=$(csv-size $binary,ui)
	cat cepto_grid.csv | csv-to-bin "$binary,ui" >> __read_temp__
	
	# Add unique ID to each point, in order to be able to do proper csv-join later 
	# (using the coordinates as a unique identifier won't do since rounding errors appear after rotating back and fourth
	#  timestamps are not unique either)
	local block_fields=$(echo "$fields,ceptoID" | csv-fields rename --fields x,y,z --to id,id,id)

	cat __read_temp__ | csv-blocks group --binary=$binary,ui --fields=$block_fields > uniqueID_data

	rm __read_temp__ cepto_grid.csv

	echo Added ceptometer grid
	
	cd ..
	./main.sh around/uniqueID_data --weather-file=$weather_data --latitude=$latitude --longitude=$longitude --start-date=$date --end-date=$date --single-time=$time_ --utc-offset=$utc_offset --binary="$binary,ui,ui" --fields="$fields,ceptoID,uniqueID"  --voxel-size=$voxel_size --transmittance="$leaf_transmittance" --sphere-repeats=$sphere_samples --write-file=$write_file --mask-file=$mask_file
}

ceptometerVerification $1 $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13} ${14}

