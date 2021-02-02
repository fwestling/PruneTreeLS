#get the zeb scan (could be georef velo instead)
#pv /mnt/sequoia/u16/mantis-shrimp-data/datasets/bundaberg/simpson/mango/ge1/zeb1/2015-11-28/row-7w-tree-4n/2015-11-28_05-33-51.las | las-to-csv points | cut -d, -f1-3 | csv-to-bin 3d > row7w-t4n.bin

#note: the following assumes the alignment between zeb and velo has already been done, using view points and triple right click to mark trunk locations, which were saved in:
# ~/src/tree-crops/light-interception/pointcloud_merging/ csv files
# there should be one velo and one zeb file per orchard
# each file has one row per tree / alignment, e.g. 18 zeb scans means 18 rows
# they have a point on the base of the trunk for the target tree, tree to north/s/east etc and optionally one extra point
#~/src/tree-crops/light-interception/pointcloud_merging/merge_mango_zeb_velo.sh 7 4 n

#thin the data, using voxel weights
#~/src/tree-crops/light-interception/thin_data.sh ./r7-t4n-zeb-in-velo-frame.bin 3d x,y,z 0.1 4 0.05 0

# 15 repeats of sub-triangulation equates to approx 1100 nodes - can run sky model separately...
# step hours default 0,5, should be a multiple of weather station data interval, with 0.5 as min

#~/src/tree-crops/light-interception/main.sh \
#    ./r7-t4n-zeb-in-velo-frame.thin.bin \
#    --binary=3ui,3d,ui \
#    --fields=_x,_y,_z,x,y,z,_w \
#    --weather-file=/mnt/sequoia/u16/mantis-shrimp-data/datasets/bundaberg/weather/vantage-pro/weather_details.txt \
#    --latitude=-25.143641572052292 \
#    --longitude=152.37746729565248 \
#    --start-date=20150401 \
#    --end-date=20160401 \
#    --transmittance=0.65:0.7:0.75 \
#    --sphere-repeats=15 \
#    --write-file=./r7-t4n-zeb-in-velo-frame.thin.energy.bin

~/src/tree-crops/light-interception/main.sh ./r7-t4n-zeb-in-velo-frame.thin.bin --binary=3ui,3d,ui --fields=_x,_y,_z,x,y,z,_w  --weather-file=/mnt/sequoia/u16/mantis-shrimp-data/datasets/bundaberg/weather/vantage-pro/weather_details.txt  --latitude=-25.143641572052292 --longitude=152.37746729565248 --start-date=20150401  --end-date=20160401  --transmittance=0.65:0.7:0.75 --sphere-repeats=15   --write-file=./r7-t4n-zeb-in-velo-frame.thin.energy.bin

#pv ./r7-t4n-zeb-in-velo-frame.thin.energy.bin | csv-calc min,mean,max,percentile=0.05,percentile=0.95 --binary=3ui,3d,ui,ui,3d --fields=,,,,,,,,scalar,, | csv-from-bin 5d
#cat ./r7-t4n-zeb-in-velo-frame.thin.energy.bin | view-points --binary=3ui,3d,ui,ui,3d --fields=_x,_y,_z,x,y,z,_w,uniqueID,scalar,energy1,energy2 --colour=113.5817376104988:10854.33913273521


#currently, if requesting single time, end-time is ignored, and output is energy over one time step (e.g. 0.5h) duration
#todo: change this to be instantaneous power at the specified single time
#~/src/tree-crops/light-interception/main.sh \
#    ./r7-t4n-zeb-in-velo-frame.thin.bin \
#    --binary=3ui,3d,ui \
#    --fields=_x,_y,_z,x,y,z,_w \
#    --weather-file=/mnt/sequoia/u16/mantis-shrimp-data/datasets/bundaberg/weather/vantage-pro/weather_details.txt \
#    --latitude=-25.143641572052292 \
#    --longitude=152.37746729565248 \
#    --start-date=20150401 \
#    --end-date=20160401 \
#    --single-time=1200 \
#    --transmittance=0.65:0.7:0.75 \
#    --sphere-repeats=2 \
#    --write-file=./r7-t4n-zeb-in-velo-frame.thin.noon.bin

#produce the final volume and light energy numbers for the tree
#~/src/tree-crops/light-interception/postprocessor.sh /mnt/sequoia/u16/mantis-shrimp-data/processed/bundaberg/simpson/mango/ge1a/2015-11-24-fruit-set/zeb/segmented/masks/r7-t4n-zeb-in-velo-frame_mask 3ui,3d,ui vx,vy,vz,x,y,z,weight 0.1 ./r7-t4n-zeb-in-velo-frame.thin.energy.bin 3ui,3d,2ui,3d vx,vy,vz,x,y,z,w,uid,energy,e2,e3 0.05 ./r7-t4n-zeb-in-velo-frame.bin 3d x,y,z




#for geodesic sphere see geodesic_sphere
#for BOM data see BOMparser
#for a sky model, see SkyGenerator

#for cepto
#  1) estimate alignment of grid to lidar points, using view-points, a bit painful... no scripts for that.
#  2) cepto_raytrace: adds artificial planar ground to lidar points and runs main (note, calls synthetic_ground with first bit commented out) Run with many trans coefficients if doing step 6 below.
#  3) synthetic_ground: see commented out bit, use that to generate cepto points corresponding to grid locations where data was acquired (x,y,z,id) not actual cepto data
#
#  to calculate alignement heatmaps to optimise cepto position, do 4 and 5, optinally skip
#
#  4) cepto_align: uses points join to generate model PAR values for each point in the ceptogrid (from 3), according to the offset locations for exhaustive search, makes big file containing all that info
#  5) cept_align_heatmap: uses file from (4), to create heatmap by joining to real cepto data (id,value)
#
#  to calc optimal transmission coeffs
#  6) see kvstr_helper: this requires optimal x/y offset for cepto grid (can be from (5) or otherwise), requires steps (1) (2) (3) above to be done
#  7) plot_k_vs_rsq to see output of (6)


#for lidar comparisons, see zeb_velo_pc_comparison
 