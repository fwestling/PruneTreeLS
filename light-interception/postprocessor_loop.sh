#!/bin/bash


output_file=interception_statistics_mango.csv



mask_bin=3ui,3d,ui
mask_fields=vx,vy,vz,x,y,z
mask_vsize=0.1

processed_bin=3ui,3d,2ui,3d
processed_fields=vx,vy,vz,x,y,z,w,uid,energy,irr2,irr3
processed_vsize=0.05

original_bin=3d
original_fields=x,y,z

extractscript="postprocessor.sh"

yield_statistics=yield_statistics_avo.csv
yield_fields=$(head -1 $yield_statistics)

######for avocado########

#dataset=avo/gw1234/2015-11-2x
#row_number_from=s
#mask_folder="/home/samuel/avocado_zeb/cropped/masks"
#original_folder="/home/samuel/avocado_zeb/georeferenced"
#folder="/home/samuel/Documents/light_interception/out/avocado/*"

#######for mango#######
dataset=mango/ge1/2015-11-24
row_number_from=w
mask_folder="/home/samuel/mango_zeb/cropped/masks"
original_folder="/home/samuel/mango_zeb/georeferenced"
folder="/home/samuel/Documents/light_interception/out/mango/*"

echo "dataset,row/number,row/number-from,tree/number,tree/number-from,volume,interception,yield/weight,yield/count,yield/size" > $output_file

for file in $folder; do
	echo $file
	file_name=$(basename $file)
	row_number=$(echo ${file_name:11:2} | grep -o -E '[0-9]+' | head -1 | sed -e 's/^0\+//')
	tree_number=$(echo ${file_name:14:3} | grep -o -E '[0-9]+' | head -1 | sed -e 's/^0\+//')
	tree_from=$(echo ${file_name:15:3} | grep -o -E '[a-zA-Z]' | head -1 | sed -e 's/^0\+//')

	mask_name=r"$row_number"-t"$tree_number""$tree_from"-zeb-in-velo-frame_mask
	original_name=r"$row_number"-t"$tree_number""$tree_from"-zeb-in-velo-frame.bin

	volume_interception=$(./$extractscript "$mask_folder/$mask_name" $mask_bin $mask_fields $mask_vsize \
	$file $processed_bin $processed_fields $processed_vsize \
	"$original_folder/$original_name" $original_bin $original_fields)

	#yield_stats=$(tail -n+2 $yield_statistics \
	#	| csv-select --fields=$yield_fields "row/number;equals=$row_number" "tree/number;equals=$tree_number" "tree/number-from;equals=$tree_from" \
	#	| csv-shuffle --fields=$yield_fields --output-fields=weight,fruit_count,avg_size)

	echo "$dataset,$row_number,$row_number_from,$tree_number,$tree_from,$volume_interception" >> $output_file
done
