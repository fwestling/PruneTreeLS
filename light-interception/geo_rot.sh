#!/bin/bash

# Binary point cloud on stdin, arguments:
# 	bin, fields, degrees to rotate

bin=$1
fields=$2
deg=$3

[[ $deg == 0 ]] && cat && exit

xyzFields=`echo "$fields" | csv-fields clear --except=x,y,z`
pc=`cat | base64`


### This code isolates the 'tree' (in a very basic way) from everything around it
mean=`echo -n "$pc" | base64 -d | csv-calc mean --binary=$bin --fields=$xyzFields | csv-from-bin 3d`

### Now we take just the tree of interest and rotate it by the desired number of degrees.
invMean=`echo $mean | csv-eval --fields=x,y,z "x=-x;y=-y;z=-z"`

echo -n "$pc" | base64 -d | points-frame --binary=$bin --fields=$xyzFields --from="$invMean" |
points-frame --binary=$bin --fields=$xyzFields --from="0,0,0,0,0,$(math-deg2rad $deg)" |
points-frame --binary=$bin --fields=$xyzFields --from="$mean" 

