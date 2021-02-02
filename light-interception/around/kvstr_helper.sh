#!/bin/bash


date_array=(201602200900)

factor_array=(0.9 0.85 0.8 0.75 0.7 0.65 0.6 0.55 0.5 0.45 0.4 0.35 0.3 0.25 0.2 0.15 0.1)

x_offset=0.1
y_offset=-0.11

bin="3ui,3d,3ui,18d"
fields="vx,vy,vz,x,y,z,w,uniqueID,dc,m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16,m17,m18"

rm out.csv
for date in "${date_array[@]}"
do
	date_time=${date:0:8}"T"${date:8:12}
	echo $date_time
	count=1
	for factor in "${factor_array[@]}"
	do
		lum_fields=$(echo $fields | sed "s#m$count#lum#")
		#lum_fields=$fields
		count=$(echo "$count + 1" | bc)
		./kvstransm.sh ceptometer_grid3dui_east.bin "x,y,z,ceptoID" "3d,ui" ceptometer_verif_zeb/no_pc_grid/cepto_"$date"_transm0.9_0.5_0.5_ceptosundiffuse $lum_fields $bin 0.05 1138 ceptometer_grid3dui_west.bin $x_offset $y_offset $date_time $factor
	done
done
