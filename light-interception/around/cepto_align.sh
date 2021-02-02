#!/bin/bash

"""
Inputs
---------
<cepto_grid_file>	:	point cloud binary file which contains the ceptometer grid. Required fields: x,y,z,ceptoID
<point_cloud_file>	:	point cloud binary file which irradiances has been appended to. Should also contain artificial ground.
						Required fields: x,y,z,irr (see cepto_raytrace.sh to generate)
<radius>			:	Search radius for points-join

Output
---------
File containing the average par of the points within <radius> from each point within <cepto_grid_file>, summed by ceptoID.

In other words, the file contains the fields [par,ceptoID, offset_x, offset_y], where par is the PAR value for the ceptometer 
with ID ceptoID, when the grid is offset by (x,y)

"""
cepto_grid_file=$1
cept_fields=$2
cept_binary=$3
point_cloud_file=$4
point_cloud_fields=$5
point_cloud_binary=$6
radius=$7
cepto_grid_file_west=$8


"""
Position of tree trunk in <point_cloud_file> and what rotations are needed to put <cepto_grid_file> at the initial guess
"""
height_offset=-85.7081068051
trunk_x1=7219022.38536
trunk_y1=437228.909047
rotation1=-14
rot_x=3.5
rot_y=2

trunk_x2=$trunk_x1
trunk_y2=437213.909047
rotation2=$(echo "$rotation1 - 180" | bc)

# Convert irradiance to PAR
eval_string='par=1.68*irr/'

# List of files to be processed
base_path=ceptometer_verif_zeb/no_pc_grid/
point_cloud_files=(cepto_201602200900_transm0.5_vsize0.1 cepto_201602171500_transm0.2_vsize0.1 cepto_201602171330_transm0.2_vsize0.1 cepto_201602171200_transm0.2_vsize0.1 cepto_201602201030_transm0.2_vsize0.1)

for pc in "${point_cloud_files[@]}"
do
	echo $pc
	file="$base_path""$pc".bin
	cat $file | csv-eval --binary=$point_cloud_binary --fields=$point_cloud_fields $eval_string \
	| csv-shuffle --binary=$point_cloud_binary,d --fields=$point_cloud_fields,par --output-fields=$(echo $point_cloud_fields | csv-fields cut --fields irr),par \
	> PAR

	point_cloud_fields_new=$(echo $point_cloud_fields | csv-fields cut --fields irr),par

	rm cepto_grid_align1m_east_"$pc".csv
	rm joined_east_"$pc".bin
	for x in $(seq -0.5 .01 0.5) 
	do 
		for y in $(seq -0.7 .01 0.7)
		do
			echo $pc "east" $x $y
			cat $cepto_grid_file \
			| points-frame --binary=$cept_binary --fields=$cept_fields --from="$x,$y,0" \
			| points-frame --binary=$cept_binary --fields=$cept_fields --from "$trunk_x1,$trunk_y1,$height_offset,$(math-deg2rad $rot_x),$(math-deg2rad $rot_y),$(math-deg2rad $rotation1)" \
			| points-join --binary=$cept_binary --fields=$cept_fields \
			"PAR;binary=$point_cloud_binary;fields=$point_cloud_fields_new" --radius=$radius --all\
			| tee joined_east_"$x"_"$y".bin \
			| csv-calc mean --fields=$(echo $cept_fields | csv-fields clear --except=ceptoID | sed "s#ceptoID#id#"),$(echo $point_cloud_fields_new| csv-fields clear --except=par) --binary=$cept_binary,$point_cloud_binary \
			| csv-paste "-;binary=d,ui" "value=$x,$y;binary=d,d" | csv-from-bin d,ui,2d >> cepto_grid_align1m_east_"$pc".csv 

			rm joined_east_"$x"_"$y".bin
		done
	done

	rm cepto_grid_align1m_west_"$pc".csv
	rm joined_west_"$pc".bin
	for x in $(seq -0.5 .01 0.5) 
	do 
		for y in $(seq -0.7 .01 0.7)
		do
			echo $pc "west" $x $y
			cat $cepto_grid_file_west \
			| points-frame --binary=$cept_binary --fields=$cept_fields --from="$x,$y,0" \
			| points-frame --binary=$cept_binary --fields=$cept_fields --from "$trunk_x2,$trunk_y2,$height_offset,$(math-deg2rad -$rot_x),$(math-deg2rad -$rot_y),$(math-deg2rad $rotation2)" \
			| points-join --binary=$cept_binary --fields=$cept_fields \
			"PAR;binary=$point_cloud_binary;fields=$point_cloud_fields_new" --radius=$radius --all\
			| tee joined_west_"$x"_"$y".bin \
			| csv-calc mean --fields=$(echo $cept_fields | csv-fields clear --except=ceptoID | sed "s#ceptoID#id#"),$(echo $point_cloud_fields_new| csv-fields clear --except=par) --binary=$cept_binary,$point_cloud_binary \
			| csv-paste "-;binary=d,ui" "value=$x,$y;binary=d,d" | csv-from-bin d,ui,2d >> cepto_grid_align1m_west_"$pc".csv 

			rm joined_west_"$x"_"$y".bin
		done
	done
done


rm PAR