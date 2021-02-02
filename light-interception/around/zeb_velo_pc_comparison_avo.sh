#!/bin/bash


#Compares where matter is captured within two pointclouds. 
#Originally designed to compare velodyne and zeb scans, to see which areas both sensors capture and which areas only one 
#of them captures


velo=$1
velo_bin=$2
velo_fields=$3
velo_wtresh=$4
zeb=$5
zeb_bin=$6
zeb_fields=$7
zeb_wtresh=$8
voxel_res=$9
corr_points_velo=/home/samuel/handheld_lidar/correspinding_points_velo.csv
corr_points_zeb=/home/samuel/handheld_lidar/corresponding_points_zeb.csv
out_folder=${10}

#"vz;to=-1050" 
cat $velo \
| points-to-voxels --binary=$velo_bin --fields=$velo_fields --resolution=$voxel_res --origin=0,0,0 \
| csv-select --binary=3i,3d,ui --fields=vx,vy,vz,x,y,z,w "w;greater=$velo_wtresh" "x;from=7218814;to=7218825" "y;from=435785;to=435797" \
> velo_voxelised.bin

#cat $zeb | points-frame --binary=$zeb_bin --fields=$zeb_fields --from=$(csv-paste "$corr_points_velo" "$corr_points_zeb" | points-align) \
cat $zeb | points-to-voxels --binary=$zeb_bin --fields=$zeb_fields --resolution=$voxel_res --origin=0,0,0 \
| csv-select --binary=3i,3d,ui --fields=vx,vy,vz,x,y,z,w "w;greater=$zeb_wtresh" "x;from=7218814;to=7218825" "y;from=435785;to=435797"  \
> zeb_voxelised.bin

cat velo_voxelised.bin \
| csv-join --binary=3i,3d,ui --fields=id,id,id "zeb_voxelised.bin;binary=3i,3d,ui;fields=id,id,id" --not-matching --unique\
> "$out_folder"/only_velo.bin

cat zeb_voxelised.bin \
| csv-join --binary=3i,3d,ui --fields=id,id,id "velo_voxelised.bin;binary=3i,3d,ui;fields=id,id,id" --not-matching --unique\
> "$out_folder"/only_zeb.bin

cat zeb_voxelised.bin \
| csv-join --binary=3i,3d,ui --fields=id,id,id "velo_voxelised.bin;binary=3i,3d,ui;fields=id,id,id" --matching --unique\
> "$out_folder"/zeb_and_velo.bin

cat zeb_voxelised.bin \
| csv-join --binary=3i,3d,ui --fields=id,id,id "velo_voxelised.bin;binary=3i,3d,ui;fields=id,id,id" --not-matching --unique\
> "$out_folder"/only_zeb.bin

cat zeb_voxelised.bin \
| csv-join --binary=3i,3d,ui --fields=id,id,id "velo_voxelised.bin;binary=3i,3d,ui;fields=id,id,id" --matching --unique\
> "$out_folder"/zeb_and_velo.bin

cat velo_voxelised.bin | csv-eval --binary=3i,3d,ui --fields=vx,vy,vz,x,y,z,w 'a=vx*0.1;b=vy*0.1;c=vz*0.1' > "$out_folder"/velo_voxel_dupli.bin 

cat zeb_voxelised.bin | csv-eval --binary=3i,3d,ui --fields=vx,vy,vz,x,y,z,w 'a=vx*0.1;b=vy*0.1;c=vz*0.1' > "$out_folder"/zeb_voxel_dupli.bin 

mv zeb_voxelised.bin "$out_folder"/zeb_voxelised.bin
mv velo_voxelised.bin "$out_folder"/velo_voxelised.bin

cd $out_folder
start_c=-115
end_c=-102
view-points "zeb_voxelised.bin;binary=3i,3d,ui;fields=x,y,z,,,scalar;colour=$start_c:$end_c,jet" \
"velo_voxelised.bin;binary=3i,3d,ui;fields=x,y,z,,,scalar;colour=$start_c:$end_c,jet" \
"only_zeb.bin;binary=3i,3d,ui;fields=x,y,z,,,scalar;colour=$start_c:$end_c,jet" \
"only_velo.bin;binary=3i,3d,ui;fields=x,y,z,,,scalar;colour=$start_c:$end_c,jet" \
"zeb_and_velo.bin;binary=3i,3d,ui;fields=x,y,z,,,scalar;colour=$start_c:$end_c,jet"