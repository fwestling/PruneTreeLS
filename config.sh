
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PATH=$(find $DIR -type d | grep -v ".git" | tr '\n' ':')$PATH

function rayTraceFromSky()
{
    local file=$1
    local bin=$2
    local fields=$3
    local voxel_size=$4
    local luminance_table=$5
    local res_hours=$6
    local sphere_samples=$7
    local write_file=$8
    
    uid_fields=$(echo $fields | sed "s/uniqueID/id/")
    
    declare -a irradiances=($(cat $luminance_table | csv-shuffle --fields=elev,azi,irr --output-fields=irr))
    declare -a elevation=($(cat $luminance_table | csv-shuffle --fields=elev,azi,irr --output-fields=elev))
    declare -a azimuth=($(cat $luminance_table | csv-shuffle --fields=elev,azi,irr --output-fields=azi))
    
    echo "Ray tracing from" ${#irradiances[@]} "sky segments" >&2
    
    echo -n "Calculating... have finished: " >&2
    
    export -f rayTrace
    
    seq 0 `expr ${#irradiances[@]} - 1` | parallel -n 1 \
    rayTrace $file \'"(${elevation[*]})"\' \'"(${azimuth[*]})"\' $voxel_size $bin $fields \'"(${irradiances[*]})"\' {} \
    | csv-calc sum --binary=2d,ui --fields=nrg,density,id \
    | csv-join --binary=2d,ui --fields=nrg,density,id "$file;fields=$uid_fields;binary=$bin" \
    | csv-shuffle --binary=2d,ui,$bin --fields=nrg,density,uid,$fields --output-fields=$fields,nrg,density \
    > $write_file
    
    echo -e "\nTo visualise:" >&2
    echo "cat $write_file | view-points \"--binary=$bin,d\" \"--fields=$fields,nrg\"" >&2
}

function rayTrace()
{
    
    local pc=$1
    declare -a elevation=$2
    declare -a azimuth=$3
    local voxel_size=$4
    local bin=$5
    local fields=$6
    declare -a irradiances=$7
    local iteration=$8
    local incident_intensity=${irradiances[$iteration]}
    local sun_altitude=${elevation[$iteration]}
    local sun_azimuth=${azimuth[$iteration]}
    
    elevation=$sun_altitude
    # (( echo "$elevation < 10" | bc -l )) && elevation=10 # Doesn't work anyway
    echo -n "$iteration, " >&2
    local csv_eval_string=""
    local new_eval_string=""
    local intensity_fields=""
    local count=0
    
    # Speed up later csv_eval by precomputing calculations which have the same value for every point.
    local precalc=$(echo "$incident_intensity,$voxel_size" | csv-eval --format=d,d --fields=i,s "x=i*(s**2)" | cut -d, -f3)
    # local precalc=$(echo "$incident_intensity,$voxel_size,$elevation" | csv-units --fields=,,x --from=deg --to=rad | csv-eval --format=d,d,d --fields=i,s,e "x=(i/math.sin(e))*(s**2)" | cut -d, -f4)
    
    local only_coord_fields=$(echo $fields | csv-fields clear --except=x,y,z)
    
    # Rotate z towards sun, voxelise, assign ID to z-columns, assign ID to voxels in ascending order in each voxel (NOTE: erases all but one point in each voxel)
    
    cat $pc | points-frame --binary=$bin --fields=$only_coord_fields --from "0,0,0,0,0,$(math-deg2rad -$sun_azimuth)" |
    points-frame --binary=$bin --fields=$only_coord_fields --from "0,0,0,0,$(math-deg2rad $(echo "-90 - $sun_altitude" | bc)),0" |
    points-to-voxel-indices --binary=$bin --fields=$fields --resolution=$voxel_size |
    csv-shuffle --binary=$bin,3ui --fields=$fields,vx2,vy2,vz2 --output-fields=vx2,vy2,vz2,tc,ac |
    csv-sort --binary=3ui,2d --fields=a,b,vz,tc,ac --order=b,a,vz --reverse |
    csv-blocks group --binary=3ui,2d --fields=id,id,id |
    csv-calc --binary=3ui,2d,ui mean,size --fields=x,y,z,tc,ac,block |
    csv-shuffle --binary=3ui,2d,6ui --fields=x,y,z,meanTC,meanAC,w --output-fields=x,y,z,meanTC,meanAC,w  | # effectively gets you "points-to-voxels"
    csv-blocks group --binary=3ui,2d,ui --fields=id,id,vz |
    csv-blocks index --binary=3ui,2d,2ui --fields=vx,vy,vz,mtc,mac,weight,block |  # vx,vy,vz,tc,weight,column,ray
    accumulate.py --binary=3ui,2d,3ui --fields=vx,vy,vz,tc,ac,weight,block,ray |
    csv-eval --binary=3ui,2d,3ui,d --fields=vx,vy,vz,meanTC,ac,weight,column,ray,acc_tc "nrg=$precalc/weight*ac*acc_tc;dns=$incident_intensity*ac*acc_tc" |
    # This next step involves some gross replication, but it's significantly faster than using base64 to store in a variable
    csv-join --binary=3ui,2d,3ui,3d --fields=id,id,id \
    <(cat $pc | points-frame --binary=$bin --fields=$only_coord_fields --from "0,0,0,0,0,$(math-deg2rad -$sun_azimuth)" |
        points-frame --binary=$bin --fields=$only_coord_fields --from "0,0,0,0,$(math-deg2rad $(echo "-90 - $sun_altitude" | bc)),0" |
        points-to-voxel-indices --binary=$bin --fields=$fields --resolution=$voxel_size |
    csv-shuffle --binary=$bin,3ui --fields=$fields,vx2,vy2,vz2 --output-fields=uniqueID,vx2,vy2,vz2,tc,ac)";fields=uniqueID,id,id,id,tc,ac;binary=ui,3ui,2d" |
    csv-shuffle --binary=3ui,2d,3ui,3d,ui,3ui,2d \
    --fields=vx2,vy2,vz2,m_tc,m_ac,weight,column,ray,acc_tc,nrg,dns,uniqueID,vx1,vy1,vz1,tc,ac \
    --output-fields=nrg,dns,uniqueID
}