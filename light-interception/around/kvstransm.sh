#!/bin/bash

"""
Extracts the irradiances at the cepto grid file given the offset <x> and <y>
Stores in file with fields [irradiance,ceptoID,time,transmission_coeff]
"""
cepto_grid_file=$1
cept_fields=$2 #needs to contain x,y,z,ceptoID
cept_binary=$3
point_cloud_file=$4
point_cloud_fields=$5 #needs to contain x,y,z,irr
point_cloud_binary=$6
radius=$7
num_samples=$8
cepto_grid_file_west=$9
x=${10}
y=${11}
time_=${12}
transm=${13}


height_offset=-85.7081068051

#trunk east
trunk_x1=7219022.38536
trunk_y1=437228.909047
rotation1=-14
rot_x=3.5
rot_y=2

#trunk west
trunk_x2=$trunk_x1
trunk_y2=437213.909047
rotation2=$(echo "$rotation1 - 180" | bc)

# Convert luminance to PAR
eval_string='a=1.68*irr'

cat $point_cloud_file | csv-eval --binary=$point_cloud_binary --fields=$point_cloud_fields $eval_string \
| csv-shuffle --binary=$point_cloud_binary,d --fields=$point_cloud_fields,par --output-fields=$(echo $point_cloud_fields | csv-fields cut --fields irr),par \
> PAR

point_cloud_fields_new=$(echo $point_cloud_fields | csv-fields cut --fields irr),par

echo $pc "east" $x $y
cat $cepto_grid_file \
| points-frame --binary=$cept_binary --fields=$cept_fields --from="$x,$y,0" \
| points-frame --binary=$cept_binary --fields=$cept_fields --from "$trunk_x1,$trunk_y1,$height_offset,$(math-deg2rad $rot_x),$(math-deg2rad $rot_y),$(math-deg2rad $rotation1)" \
| points-join --binary=$cept_binary --fields=$cept_fields \
"PAR;binary=$point_cloud_binary;fields=$point_cloud_fields_new" --radius=$radius --all\
| csv-calc mean --fields=$(echo $cept_fields | csv-fields clear --except=ceptoID | sed "s#ceptoID#id#"),$(echo $point_cloud_fields_new| csv-fields clear --except=par) --binary=$cept_binary,$point_cloud_binary \
| csv-paste "-;binary=d,ui" "value=$time_,$transm;binary=t,d" | csv-from-bin d,ui,t,d >> out.csv 



echo $pc "west" $x $y
cat $cepto_grid_file_west \
| points-frame --binary=$cept_binary --fields=$cept_fields --from="$(echo "- $x"|bc),$(echo "- $y" | bc),0" \
| points-frame --binary=$cept_binary --fields=$cept_fields --from "$trunk_x2,$trunk_y2,$height_offset,$(math-deg2rad -$rot_x),$(math-deg2rad -$rot_y),$(math-deg2rad $rotation2)" \
| points-join --binary=$cept_binary --fields=$cept_fields \
"PAR;binary=$point_cloud_binary;fields=$point_cloud_fields_new" --radius=$radius --all \
| csv-calc mean --fields=$(echo $cept_fields | csv-fields clear --except=ceptoID | sed "s#ceptoID#id#"),$(echo $point_cloud_fields_new| csv-fields clear --except=par) --binary=$cept_binary,$point_cloud_binary \
| csv-paste "-;binary=d,ui" "value=$time_,$transm;binary=t,d" | csv-from-bin d,ui,t,d >> out.csv 