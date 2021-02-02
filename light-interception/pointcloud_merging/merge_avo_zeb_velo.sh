#!/bin/bash

if [ $# -lt 5 ] 
then
	echo "usage: $0 row tree from binary dataset date"	
	exit 1
fi

row=$1
tree=$2
tree_from=$3
viewed_from=n
zeb_file=$4
dataset=$5
dte=$6
# get_tree=~/src/tree-crops/bundaberg/velodyne/get-tree

velo_trunks=~/data/trunks/avocado_trunks_velo.csv
zeb_trunks=~/data/trunks/avocado_zeb_trunks_dec2016.csv

tree_trunks_fields=$(head -1 $velo_trunks)

velo_trunk=$(tail -n+2 $velo_trunks | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/centre,y/centre,z/centre)
velo_west=$(tail -n+2 $velo_trunks | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/west,y/west,z/west)
velo_east=$(tail -n+2 $velo_trunks | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/east,y/east,z/east)
velo_north=$(tail -n+2 $velo_trunks | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/north,y/north,z/north)
# velo_extra=$(tail -n+2 $velo_trunks | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/extra,y/extra,z/extra)

# The problem with this approach: If zeb XOR velo is missing a trunk point, points-align fails horribly. \
# 	Maybe add in elsifs to drop in an empty point?  Or just remove these ifs altogether and add the point in?
if echo "${velo_trunk}" | grep '[0-9]' >/dev/null; then
	echo $velo_trunk >> __velo__
fi
if echo "${velo_west}" | grep '[0-9]' >/dev/null; then
	echo $velo_west >> __velo__
fi
if echo "${velo_east}" | grep '[0-9]' >/dev/null; then
	echo $velo_east >> __velo__
fi
if echo "${velo_north}" | grep '[0-9]' >/dev/null; then
	echo $velo_north >> __velo__
fi
# if echo "${velo_extra}" | grep '[0-9]' >/dev/null; then
# 	echo $velo_extra >> __velo__
# fi


zeb_trunk=$(tail -n+2 $zeb_trunks | csv-select --fields=$tree_trunks_fields "dataset;equals=$dataset" "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/centre,y/centre,z/centre)
zeb_west=$(tail -n+2 $zeb_trunks | csv-select --fields=$tree_trunks_fields "dataset;equals=$dataset" "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/west,y/west,z/west)
zeb_east=$(tail -n+2 $zeb_trunks | csv-select --fields=$tree_trunks_fields "dataset;equals=$dataset" "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/east,y/east,z/east)
zeb_north=$(tail -n+2 $zeb_trunks | csv-select --fields=$tree_trunks_fields "dataset;equals=$dataset" "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/north,y/north,z/north)
# zeb_extra=$(tail -n+2 $zeb_trunks | csv-select --fields=$tree_trunks_fields "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/extra,y/extra,z/extra)

if echo "${zeb_trunk}" | grep '[0-9]' >/dev/null; then
	echo $zeb_trunk > __zeb__
fi
if echo "${zeb_west}" | grep '[0-9]' >/dev/null; then
	echo $zeb_west >> __zeb__
fi
if echo "${zeb_east}" | grep '[0-9]' >/dev/null; then
	echo $zeb_east >> __zeb__
fi
if echo "${zeb_north}" | grep '[0-9]' >/dev/null; then
	echo $zeb_north >> __zeb__
fi
# if echo "${zeb_extra}" | grep '[0-9]' >/dev/null; then
# 	echo $zeb_extra >> __zeb__
# fi


transl=$(csv-paste "__velo__" "__zeb__" | points-align| cut -d, -f1-6)


x_trunk=$(echo $velo_trunk | cut -d ',' -f1)
y_trunk=$(echo $velo_trunk | cut -d ',' -f2)
x_from=$(echo "$x_trunk-15" | bc)
x_to=$(echo "$x_trunk+15" | bc)
y_from=$(echo "$y_trunk-9" | bc)
y_to=$(echo "$y_trunk+8" | bc)

# cat $zeb_file \
# | points-frame --binary=3d --fields=x,y,z --from $transl \
# | csv-select --binary=3d --fields=x,y,z "x;from=$x_from;to=$x_to" "y;from=$y_from;to=$y_to" \
# | points-to-voxels --binary=3d --fields=x,y,z --resolution=0.03 | csv-shuffle --binary=3ui,3d,ui --fields=x,y,z,cx,cy,cz --output-fields=cx,cy,cz,cz \
# | csv-thin 0.3 --size=$(csv-size 4d) > zeb_in_velo

## SPECIFIC FOR MASK GENERATION ##
cat $zeb_file \
| points-frame --binary=3d --fields=x,y,z --from $transl
## END OF MASK GENERATION


# cat $zeb_file \
# | points-frame --binary=3d --fields=x,y,z --from $transl \
# | tee ../georeferenced/$dte/r"$row"-t"$tree""$tree_from"-zeb-in-velo-frame.bin \
# | csv-select --binary=3d --fields=x,y,z "x;from=$x_from;to=$x_to" "y;from=$y_from;to=$y_to" \
# | points-to-voxels --binary=3d --fields=x,y,z --resolution=0.03 | csv-shuffle --binary=3ui,3d,ui --fields=x,y,z,cx,cy,cz --output-fields=cx,cy,cz,cz \
# | csv-thin 0.3 --size=$(csv-size 4d) > zeb_in_velo

# colour_start=$(cat zeb_in_velo | csv-calc min --binary=4d --fields=,,z | csv-from-bin d)
# colour_end=$(cat zeb_in_velo | csv-calc max --binary=4d --fields=,,z | csv-from-bin d)

# cat zeb_in_velo |
# 	view-points --binary=4d --fields=x,y,z,scalar --colour=$colour_start:$colour_end,jet
# ##visualise###
# $get_tree $row $tree $tree_from $viewed_from \
# | csv-select --binary=t,6d,2ui --fields=t,x,y,z "x;from=$x_from;to=$x_to" "y;from=$y_from;to=$y_to" \
# | points-to-voxels --binary=t,6d,2ui --fields=t,x,y,z --resolution=0.03 | csv-shuffle --binary=3ui,3d,ui --fields=x,y,z,cx,cy,cz --output-fields=cx,cy,cz,cz \
# | csv-thin 0.3 --size=$(csv-size 4d) | view-points "-;binary=4d;fields=x,y,z,scalar;colour=$colour_start:$colour_end,jet" "zeb_in_velo;binary=4d;fields=x,y,z,scalar;colour=$colour_start:$colour_end,jet" 

rm __velo__ __zeb__
