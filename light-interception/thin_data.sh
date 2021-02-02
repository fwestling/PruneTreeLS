#!/bin/bash

function preProcessor()
{

#Thins by voxelisation and disregards voxels with weight smaller than threshold
# voxelise with larger size, reject points in voxels where voxel weight less than threshold
# for remaining points, voxelise with smaller size, and use voxel means for further processing


local read_file=$1
local bin=$2
local fields=$3
local v_size=$4
local w_thresh=$5
local v_size_thin=$6
local w_thresh_thin=$7


filterByVoxelWeight $read_file $bin $fields $w_thresh $v_size |
 points-to-voxels --binary=$bin --fields=$fields --resolution=$v_size_thin |
 csv-select --binary=3ui,3d,ui --fields=vx,vy,vz,cx,cy,cz,weight "weight;greater=$w_thresh_thin"
 #points-to-voxels --binary=$bin --fields=$fields --resolution=0.01

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
}

readonly _file=$1
readonly _bin=$2
readonly _fields=$3
readonly _v_size=$4
readonly _w_thresh=$5
readonly _v_size_thin=$6
readonly _w_thresh_thin=$7
preProcessor $_file $_bin $_fields $_v_size $_w_thresh $_v_size_thin $_w_thresh_thin # > ${_file%.bin}.thin.bin

#in_folder="../in/*"
#bin=3d
#fields=x,y,z
#v_size=0.1
#w_thresh=4
#v_size_thin=0.05
#w_thresh_thin=0
#out_folder=../out
#date_start=20150401
#date_end=20160401
#
#for file in $in_folder; do
#	echo $file
#	preProcessor $file $bin $fields $v_size $w_thresh $v_size_thin $w_thresh_thin > __downsampled__
#	./main.sh __downsampled__ --binary=3ui,3d,ui --fields=_x,_y,_z,x,y,z,_w --weather-file=data/weather_details.txt --latitude=-25.143641572052292 --longitude=152.37746729565248 --start-date=$date_start --end-date=$date_end --transmittance=0.65:0.7:0.75 --sphere-repeats=15 --write-file="$out_folder"/processed_"$(basename $file)"
#	rm __downsampled__ sky_temp
#done
