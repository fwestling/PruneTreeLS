#!/bin/bash

function getTree()
{
	local tree_mask=$1
	local mask_bin=$2
	local mask_fields=$3

	local processed=$4
	local processed_bin=$5
	local processed_fields=$6

	local vsize=$7
	local trans=$8
	local outFile=$9
	#Note:  Mask voxel size should be the same as processed voxel size!

	cat $tree_mask | csv-join --binary=$mask_bin --fields=$mask_fields "$processed;binary=$processed_bin;fields=$processed_fields" \
	| csv-shuffle --binary=$mask_bin,$processed_bin --fields=$mask_fields,$processed_fields --output-fields=$processed_fields \
	> $outFile

	# echo "Volume of the tree (m^3) is: " $(volume $tree_mask $mask_bin $mask_fields $vsize)
	# echo "Energy captured by the tree (kJ) is:" $(energy out.bin $processed_bin $processed_fields $trans) 

	echo -e "$(volume $tree_mask $mask_bin $mask_fields $vsize)\t$(energy $outFile $processed_bin $processed_fields $trans)"
	# echo "Masked tree with energy can be found in out.bin, using $processed_bin $processed_fields"
}

function volume()
{
	local read_file=$1
	local bin=$2
	local fields=$3
	local v_size=$4

	local cleared_fields=$(echo $fields | csv-fields clear)
	# echo ""
	# echo $fields
	# echo $bin

	cat $read_file \
	| csv-paste "-;binary=$bin" "line-number" | tee __vol__ \
	| csv-calc max --binary=$bin,ui --fields=$cleared_fields,linenum \
	| csv-eval --binary=ui --fields=num "volume=(num+1)*$v_size**3" \
	| csv-shuffle --binary=ui,d --fields=num,vol --output-fields=vol \
	| csv-from-bin d
}

function energy()
{
	local file=$1
	local bin=$2
	local fields=$3 #must contain energy fields labeled 'e*'
	local trans=$4
	# cat $file | csv-calc sum --binary=$bin --fields=$(echo $fields | csv-fields clear --except=`echo $fields | grep -o "energy[0-9]*" | tr '\n' ','`)| csv-from-bin d
	cat $file | csv-calc sum --binary=$bin --fields=$(echo $fields | csv-fields clear --except="energy${trans}")| csv-from-bin d
}

function filterByVoxelWeight()
{
	local read_file=$1
	local binary=$2
	local fields=$3
	local min_points=$4
	local voxel_size=$5

	cat $read_file | points-to-voxels --binary=$binary --fields=$fields --resolution=$voxel_size \
	| csv-select --binary=3ui,3d,ui --fields=vx,vy,vz,cx,cy,cz,weight "weight;greater=$min_points" > __filtered__

	cat $read_file | points-to-voxel-indices --binary=$binary --fields=$fields --resolution=$voxel_size \
	| csv-join --binary=$binary,3ui --fields=$fields,id,id,id "__filtered__;binary=3ui,3d,ui;fields=id,id,id" \
	| csv-shuffle --binary=$binary,3ui,3ui,3d,ui --fields=$fields,vx1,vy1,vz1,vx2,vy2,vz2,cx,cy,cz,w --output-fields=$fields
	rm __filtered__
}

getTree $1 $2 $3 $4 $5 $6 $7 $8 $9