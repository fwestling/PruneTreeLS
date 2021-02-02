#!/bin/bash

scan=$1
trunks=$2
row=$3
tree=$4
tree_from=$5
dte=$6
viewed_from=n
dataset=jun16
tree_trunks_fields=$(head -1 $trunks)

if [[ $dte == 20160728 ]]
then
	dset=jun16
elif [[ $dte == 20160905 ]]
then
	dset=sep16
elif [[ $dte == 20161215 ]]
then
	dset=dec16
else #20170516
	dset=may17
fi

# Selecting the trunk points of the velo scan
velo_trunk=$(tail -n+2 $trunks | csv-select --fields=$tree_trunks_fields "dataset;equals=$dset" "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/centre,y/centre,z/centre)
velo_west=$(tail -n+2 $trunks | csv-select --fields=$tree_trunks_fields "dataset;equals=$dset" "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/west,y/west,z/west)
velo_east=$(tail -n+2 $trunks | csv-select --fields=$tree_trunks_fields "dataset;equals=$dset" "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/east,y/east,z/east)
velo_south=$(tail -n+2 $trunks | csv-select --fields=$tree_trunks_fields "dataset;equals=$dset" "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/extra,y/extra,z/extra)
velo_north=$(tail -n+2 $trunks | csv-select --fields=$tree_trunks_fields "dataset;equals=$dset" "row/number;equals=$row" "tree/number;equals=$tree" "tree/number-from;equals=$tree_from" "viewed-from;equals=$viewed_from" | csv-shuffle --fields=$tree_trunks_fields --output-fields=x/north,y/north,z/north)

echo "$velo_trunk,1" > __trunks__
echo "$velo_west,2" >> __trunks__
echo "$velo_east,3" >> __trunks__
echo "$velo_south,4" >> __trunks__
echo "$velo_north,5" >> __trunks__

# echo "ZVAL = $zVal"

zVal=`echo $velo_trunk | csv-shuffle --fields=,,z --output-fields=z`
zVal=`echo $zVal + 0.1 | bc`

# echo "Extraction point cloud: $scan"
# cat $scan | csv-from-bin 3d | points-join "__trunks__" --radius=100 | view-points --fields=x,y,z,,,,id --size=5000000 # To see voronoi
cat $scan | csv-from-bin 3d | points-join "__trunks__" --radius=100 | csv-select --fields=x,y,z,,,,i "i;equals=1" |
 csv-shuffle --fields=x,y,z --output-fields=x,y,z | csv-to-bin 3d | csv-select --binary=3d --fields=x,y,z "z;greater=$zVal"

# # cat $scan | csv-from-bin 3d | points-join "__trunks__" --radius=100 view-points --fields=x,y,z,,,,id --size=5000000 # To see voronoi
# cat $scan | csv-from-bin 3d | points-join "__trunks__" --radius=100 | csv-select --fields=x,y,z,,,,i "i;equals=1" |
#  csv-shuffle --fields=x,y,z,,,i --output-fields=x,y,z,i | csv-to-bin 4d | points-ground height --binary=4d --fields=x,y,z,id --radius=0.5 
# cat $scan |
# 	 csv-paste "-;binary=3ui,3d,ui" value="$velo_trunk;binary=3d" |  #Add in trunk point
# 	 points-calc distance --binary=3ui,3d,ui,3d --fields=,,,first/x,,,,second/x,, | # Calculate x distance from trunk
# 	 points-calc distance --binary=3ui,3d,ui,4d --fields=,,,,first/y,,,,second/y, | # Calculate y distance from trunk
# 	 points-calc distance --binary=3ui,3d,ui,5d --fields=,,,,,first/z,,,,second/z, | tee flarb | # Calculate Z distance from trunk
# 	 csv-select --binary=3ui,3d,ui,6d --fields=,,,,,z,,,,tz,dx,dy,dz "dx;less=$dx" "dy;less=$dy" "dz;greater=0.1" "z;greater=${trunk_points[2]}" | tee flarb | # Select only points on the tree
# 	 csv-shuffle --binary=3ui,3d,ui,6d --fields=_x,_y,_z,x,y,z,vw,,,,,,, --output-fields=_x,_y,_z,x,y,z,vw  
 	 # view-points  "-;binary=3ui,3d,ui;fields=,,,x,y,z,;title=masked" "$scan;binary=3ui,3d,ui;fields=,,,x,y,z,;title=original"
	 # tee >(view-points "-;binary=3ui,3d,2ui;fields=,,,x,y,z,;title=masked" "$scan;binary=3ui,3d,2ui;fields=,,,x,y,z,;title=original")
# cat $scan |
# 	 csv-paste "-;binary=3d" value="$velo_trunk;binary=3d" |  #Add in trunk point
# 	 points-calc distance --binary=3d,3d --fields=first/x,,,second/x,, | # Calculate x distance from trunk
# 	 points-calc distance --binary=3d,4d --fields=,first/y,,,second/y, | # Calculate y distance from trunk
# 	 points-calc distance --binary=3d,5d --fields=,,first/z,,,second/z, | tee flarb | # Calculate Z distance from trunk
# 	 csv-select --binary=3d,6d --fields=,,z,,,tz,dx,dy,dz "dx;less=$dx" "dy;less=$dy" "dz;greater=0.1" "z;greater=${trunk_points[2]}" | tee flarb | # Select only points on the tree
# 	 csv-shuffle --binary=3d,6d --fields=x,y,z,,,,,,, --output-fields=x,y,z  
	  
#	 csv-from-bin 3ui,3d,ui,3d,2d > __result__


# cat __result__

# rm __other__



## Compare to Samuel's mask ##
# Samuel's: 
# mask=/mnt/sequoia/u16/mantis-shrimp-data/processed/bundaberg/simpson/mango/ge1a/2015-11-24-fruit-set/zeb/segmented/masks/r7-t4n-zeb-in-velo-frame_mask
#./postprocessor.sh $mask 3ui,3d,ui vx,vy,vz,x,y,z,weight 0.1 ./r7-t4n-zeb-in-velo-frame.thin.energy.bin 3ui,3d,2ui,3d vx,vy,vz,x,y,z,w,uid,energy,e2,e3 0.05 ./r7-t4n-zeb-in-velo-frame.bin 3d x,y,z
# Fred's (from this script):
# ./extract.sh r7-t4n-zeb-in-velo-frame.thin.bin pointcloud_merging/mango_velo_points.csv >> r7-t4n-zeb-in-velo-frame.mask.bin
# mask=r7-t4n-zeb-in-velo-frame.mask.bin
#./postprocessor.sh $mask 3ui,3d,ui vx,vy,vz,x,y,z,weight 0.05 ./r7-t4n-zeb-in-velo-frame.thin.energy.bin 3ui,3d,2ui,3d vx,vy,vz,x,y,z,w,uid,energy,e2,e3 0.05 ./r7-t4n-zeb-in-velo-frame.bin 3d x,y,z

### Results: ###
# Samuel #
# Volume of the tree is:  11.871 m^3
# Energy captured by the tree is: 113642736.6316291 kJ
# Fred #
# Volume of the tree is:  12.0155 m^3
# Energy captured by the tree is: 107731616.4405878 kJ

# Volume: Fred's is 1.21% larger
# Energy: Fred's is 5.20% smaller