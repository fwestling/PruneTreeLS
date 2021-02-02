#!/bin/bash
source comma-application-util


# Takes in a (maybe?) voxelised point cloud, appends ground point flag and height.
# Fields taken in must include x,y,z
function append_ground {
	bin=$1
	fields=$2
	# scalarFields=$(echo $fields | csv-fields rename --fields=z --to=scalar)
	# idFields=$(echo $fields | csv-fields rename --fields=vx,vy,vz --to=id,id,id)

	points-ground height --up=-z --fields=$fields --binary=$bin --radius=2
}

# Extracts x,y,z points, voxelises, appends ground, then joins back with original using voxel indices.
function go {
	read_file=$1
	bin=$2
	fields=$3
	xyzfields="x,y,z"
	voxfields="vx,vy,vz,x,y,z,vw"
	xyzbin="3d"
	voxbin="3ui,3d,ui"

	# cat $1
	# Add voxel indices for later rejoining of points

	# cat $read_file |
	# csv-paste "-;binary=$bin" "line-number" | 
	# csv-thin 0.1 --binary=$bin,ui |
	# append_ground $bin,ui $fields,l | # Append ground flag and height
	# csv-join --binary="$bin,ui,d" --fields="$fields,id,height" \
	# 	<(cat $read_file| csv-paste "-;binary=$bin" "line-number")";fields=$fields,id,h;binary=$bin,ui" | #rejoin to the original points
	# csv-shuffle --binary="$voxbin,ui,d,$binary,ui" --fields="$fields,,height,$fields," \
	# 	--output-fields="$fields,height"
	cat $read_file |
	csv-shuffle --binary=$bin --fields=$fields --output-fields=$xyzfields | # Ensure we only have x, y, z
	points-to-voxels --binary=$xyzbin --fields=$xyzfields --resolution=0.1 | # Convert to voxels for faster processing
	append_ground $voxbin $voxfields | # Append ground flag and height
	csv-join --binary="$voxbin,d" --fields="id,id,id,x,y,z,w,height" \
		<(cat $read_file| points-to-voxel-indices --binary=$bin --fields=$fields --resolution=0.1)";fields=$fields,id,id,id;binary=$bin,3ui" | #rejoin to the original points
	csv-shuffle --binary="$voxbin,d,$binary,3ui" --fields="$voxfields,height,$fields,vx1,vx2,vx3" \
		--output-fields="$fields,height"
	

}

# Appends ground.  Go straight to append_ground?
function go-novox {
	binary=$1
	fields=$2
	voxfields="vx,vy,vz,x,y,z,vw"
	voxbin="3ui,3d,ui"
	cat $read_file |
	csv-shuffle --binary=$bin --fields=$fields --output-fields=$voxfields | # Ensure we only have vx,vy,vz,x,y,z,vw
	append_ground $voxbin $voxfields | # Append ground flag and height
	csv-join --binary="$voxbin,ui,d" --fields="id,id,id,x,y,z,w,ground,height" \
		"$read_file;fields=id,id,id;binary=$bin" | #rejoin to the original points
	csv-shuffle --binary="$voxbin,ui,d,$binary,3ui" --fields="$voxfields,ground,height,$fields,vx1,vx2,vx3" \
		--output-fields="$fields,ground,height"
}

function options_description()
{
	cat << EOF

	Description:
------------------------------

Computes the height above the ground plane of the given point cloud.  This is a helper function for points-ground height 
which computes the height at reasonable speeds given a non-thinned point cloud.

	Positional argument:
------------------------------
 read_file; input point cloud file

	Mandatory arguments:
------------------------------
--binary,-b=<binary>; binary format
--fields,-f=<fields>; fields; x,y,z mandatory

	Non mandatory:
------------------------------
--help,-h; show this help and exit
--no-voxels,-v; no voxelisation required (run on all points, or already voxelised)

	Examples:
------------------------------
./ground.sh pointcloud.bin --binary=3d --fields=x,y,z
would output a pointcloud with --binary=3d,ui,d --fields=x,y,z,ground,height 

./ground.sh pointcloud.thin.bin -v --binary=3ui,3d,ui --fields=vx,vy,vz,x,y,z,vw
would output a pointcloud with --binary=3ui,3d,ui,ui,d --fields=vx,vy,vz,x,y,z,vw,ground,height 

EOF
}

function variable_desc()
{
		cat << EOF
--binary,-b=<binary>; binary format
--fields,-f=<fields>; fields; x,y,z mandatory
--help,-h; show this help and exit
--no-voxels,-v; do not voxelise (default=0)
EOF
}

if  (( $(comma_options_has --help $@) )) || (( $(comma_options_has -h $@) )) ; then
	options_description
	exit
fi

comma_path_value_to_var < <( variable_desc | comma-options-to-name-value $@ | grep -v '^"' )

if [ -z $no_voxels ]
then 
	go $1 $binary $fields 
else 
	go-novox $1 $binary $fields 
fi

