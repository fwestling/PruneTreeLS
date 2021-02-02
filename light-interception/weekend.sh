#!/bin/bash
rep=5

echo "Ceptoff data files!!" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir ceptoff --cepto-dir cepto-data/processed/ --repeats=$rep

echo "Starting voxel trials (all are repeats=$rep)" >&2
echo "Size: 0.025, Weight: 1" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-025-1/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.025 --voxel-weight=1
echo "Size: 0.01, Weight: 1" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-01-1/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.01 --voxel-weight=1


exit
#Additional test scripts 17 May
echo "Starting voxel trials (all are repeats=$rep)" >&2
echo "Size: 0.100, Weight: 64" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-1-64/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.1 --voxel-weight=64
echo "Size: 0.25, Weight: 8" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-25-8/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.25 --voxel-weight=8
echo "Size: 0.25, Weight: 16" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-25-16/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.25 --voxel-weight=16
echo "Size: 0.25, Weight: 32" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-25-32/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.25 --voxel-weight=32
echo "Size: 0.25, Weight: 64" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-25-64/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.25 --voxel-weight=64

echo "Size: 0.100, Weight: 64" >&2
~/src/tree-crops/light-interception/visAll.sh plots/voxels/1-64 vox-outputs-1-64
echo "Size: 0.25, Weight: 8" >&2
~/src/tree-crops/light-interception/visAll.sh plots/voxels/25-8 vox-outputs-25-8
echo "Size: 0.25, Weight: 16" >&2
~/src/tree-crops/light-interception/visAll.sh plots/voxels/25-16 vox-outputs-25-16
echo "Size: 0.25, Weight: 32" >&2
~/src/tree-crops/light-interception/visAll.sh plots/voxels/25-32 vox-outputs-25-32
echo "Size: 0.25, Weight: 64" >&2
~/src/tree-crops/light-interception/visAll.sh plots/voxels/25-64 vox-outputs-25-64

echo "Size: 0.100, Weight: 4" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-1-4/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.1 --voxel-weight=4
echo "Size: 0.100, Weight: 4" >&2
~/src/tree-crops/light-interception/visAll.sh plots/voxels/1-4 vox-outputs-1-4


exit
# Weekend scripts 13/14 May
# r 	time (est)
# 5		45m
# 10	192m
# 15	417m

#Estimated time below = 20 hrs
# Real time = 1159 min, 19.3 hrs


# Validation dates & times (as well as a permanent outputs-r15)
echo "Basic, repeats = 5" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir outputs-r5/ --cepto-dir cepto-data/processed/ --repeats=5
echo "Basic, repeats = 10" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir outputs-r10/ --cepto-dir cepto-data/processed/ --repeats=10
echo "Basic, repeats = 15" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir outputs-r15/ --cepto-dir cepto-data/processed/ --repeats=15
echo "Validating geometry, repeats=5" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir validation_geom/ --cepto-dir cepto-data/processed/  --no-align --repeats=5
echo "Validating times, repeats=5" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir validation_times/ --cepto-dir cepto-data/processed/ --validate-time --repeats=5
echo "Validating dates, repeats=5" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir validation_dates/ --cepto-dir cepto-data/processed/ --validate-date --repeats=5

# Voxel size trials
echo "Starting voxel trials (all are repeats=$rep)" >&2
echo "Size: 0.025, Weight: 4" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-025-4/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.025 --voxel-weight=4
echo "Size: 0.025, Weight: 8" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-025-8/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.025 --voxel-weight=8
echo "Size: 0.025, Weight: 16" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-025-16/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.025 --voxel-weight=16
echo "Size: 0.050, Weight: 8" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-05-8/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.05 --voxel-weight=8
echo "Size: 0.050, Weight: 16" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-05-16/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.05 --voxel-weight=16
echo "Size: 0.050, Weight: 32" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-05-32/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.05 --voxel-weight=32
echo "Size: 0.100, Weight: 8" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-1-8/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.1 --voxel-weight=8
echo "Size: 0.100, Weight: 16" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-1-16/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.1 --voxel-weight=16
echo "Size: 0.100, Weight: 32" >&2
time ~/src/tree-crops/light-interception/bulk-raytrace.sh --output-dir vox-outputs-1-32/ --cepto-dir cepto-data/processed/ --repeats=$rep --voxel-size=0.1 --voxel-weight=32

echo "!!! Finally fucking done !!!" >&2