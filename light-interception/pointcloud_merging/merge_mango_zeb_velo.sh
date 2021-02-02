#!/bin/bash

row=$1
tree=$2
tree_from=$3
zeb_pc=row"$row"w-t"$tree""$tree_from".bin

viewed_from=w
get_tree=~/src/tree-crops/bundaberg/velodyne/get-tree

# Tree trunk files contain points for certain specified tree trunks, header contains field labels. 
tree_trunks_zeb=~/src/tree-crops/light-interception/pointcloud_merging/mango_zeb_points.csv
tree_trunks_velo=~/src/tree-crops/light-interception/pointcloud_merging/mango_velo_points.csv
tree_trunks_fields=$(head -1 $tree_trunks_zeb)

# Selecting the trunk points of the zeb scan
zeb_trunk=$(tail -n+2 $tree_trunks_zeb | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/centre,y/centre,z/centre)
zeb_west=$(tail -n+2 $tree_trunks_zeb | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/west,y/west,z/west)
zeb_south=$(tail -n+2 $tree_trunks_zeb | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/south,y/south,z/south)
zeb_north=$(tail -n+2 $tree_trunks_zeb | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/north,y/north,z/north)
zeb_top=$(tail -n+2 $tree_trunks_zeb | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/top,y/top,z/top)

# Store the zeb trunk points into "__this__" if they exist
echo $zeb_trunk > __this__
if echo "${zeb_west}" | grep '[0-9]' >/dev/null; then
	echo $zeb_west >> __this__
fi
if echo "${zeb_south}" | grep '[0-9]' >/dev/null; then
	echo $zeb_south >> __this__
fi
if echo "${zeb_north}" | grep '[0-9]' >/dev/null; then
	echo $zeb_north >> __this__
fi
if echo "${zeb_top}" | grep '[0-9]' >/dev/null; then
	echo $zeb_top >> __this__
fi

# Selecting the trunk points of the velo scan
velo_trunk=$(tail -n+2 $tree_trunks_velo | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/centre,y/centre,z/centre)
velo_west=$(tail -n+2 $tree_trunks_velo | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/west,y/west,z/west)
velo_south=$(tail -n+2 $tree_trunks_velo | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/south,y/south,z/south)
velo_north=$(tail -n+2 $tree_trunks_velo | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/north,y/north,z/north)
velo_top=$(tail -n+2 $tree_trunks_velo | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/top,y/top,z/top)

# Store the velo trunk points into "__other__" if they exist
echo $velo_trunk > __other__
if echo "${velo_west}" | grep '[0-9]' >/dev/null; then
	echo $velo_west >> __other__
fi
if echo "${velo_south}" | grep '[0-9]' >/dev/null; then
	echo $velo_south >> __other__
fi
if echo "${velo_north}" | grep '[0-9]' >/dev/null; then
	echo $velo_north >> __other__
fi
if echo "${velo_top}" | grep '[0-9]' >/dev/null; then
	echo $velo_top >> __other__
fi

# points-align provides the transformation necessary to align a point cloud (__this__) with a reference point cloud (__other__).
transl=$(csv-paste "__other__" "__this__" | points-align | cut -d, -f1-6)

# points-frame is then used to perform the required translation and rotation
cat $zeb_pc \
| points-frame --binary=3d --fields=x,y,z --from="$transl" \
| tee r"$row"-t"$tree""$tree_from"-zeb-in-velo-frame.bin \
| csv-thin 0.1 --size=$(csv-size 3d) | csv-shuffle --binary=3d --fields=x,y,z --output-fields=x,y,z,z > zeb_in_velo

##visualise###
$get_tree $row $tree $tree_from $viewed_from \
| csv-thin 0.1 --size=$(csv-size t,6d,2ui) | csv-shuffle --binary=t,6d,2ui --fields=t,x,y,z --output-fields=x,y,z,z | view-points "-;binary=4d;fields=x,y,z,scalar;colour=-86:-80,jet" "zeb_in_velo;binary=4d;fields=x,y,z,scalar;colour=-86:-80,jet" 

rm zeb_in_velo __this__ __other__
