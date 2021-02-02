--fields=uid,nrg,sou,seg,pos -o=sou,pos,nrg,seg | # Clean up data a bit more  ## at this point, we have sou,pos,nrg,seg...
    sed 's/,[1-7]$/;/' | sed 's/,8$/:/' | tr '\n' ',' | sed 's/;,[01],[0-9]*,/,/g' | tr ':' '\n' | sed 's/^,//' |  # Remove most line breaks to generate standard form
    csv-eval --fields=,,a,b,c,d,e,f,g,h --format=2ui,8d "avg=(a+b+c+d+e+f+g+h)/8" | # Calculate average
    csv-shuffle --fields=sou,pos,q,w,e,r,t,y,u,i,avg -o=sou,pos,avg,q,w,e,r,t,y,u,i | # Finalise standard form
    csv-paste "-" "value=0" |
    csv-join --fields=sou,pos "$cepto_file;fields=t,sou,pos" |
    csv-shuffle --fields=sou,pos,q,w,e,r,t,y,u,i,o,opn,tim -o=tim,sou,pos,opn,q,w,e,r,t,y,u,i,o \
    > $dataDir/nrg.$tc.kj.partial.csv
    
    # PAR conversion using openair data
    okj=$(cat $outDir/open.$tTime.nrg.csv)
    
    
    ratio="opar/($voxel_size*$voxel_size*$okj)"
    [[ $policy == "density-mean" ]] && ratio="opar/$okj"
    # echo "Ratio: $ratio" >&2
    # echo "Open file: <$open_file>" >&2
    [[ $no_open ]] && ratio="1.72"
    # [[ $no_open ]] && ratio="180"
    # [[ $no_open ]] && ratio="1.72"
    cat $dataDir/nrg.$tc.kj.partial.csv | csv-sort --fields=t |
    csv-time-join --nearest "$open_file" |
    csv-eval --fields=,,,,savg,s1,s2,s3,s4,s5,s6,s7,s8,,opar \
    --format=t,ui,ui,ui,9d,t,d \
    "savg=savg*($ratio);\
	  s1=s1*($ratio);s2=s2*($ratio);s3=s3*($ratio);s4=s4*($ratio);\
    s5=s5*($ratio);s6=s6*($ratio);s7=s7*($ratio);s8=s8*($ratio);ratio=$ratio" |
    csv-shuffle --fields=tim,sou,pos,opn,q,w,e,r,t,y,u,i,o -o=tim,sou,pos,opn,q,w,e,r,t,y,u,i,o \
    > $dataDir/nrg.$tc.par.partial.csv
    
    rm -f $dataDir/allMatches.csv
}

# real	804m39.718s
# user	3874m58.912s
# sys	1320m33.848s

function go () {
    pc=$1
    row=$2
    tree=$3
    from=$4
    repeats=$5
    outDir=$6
    cepto_file=$7
    open_file=$8
    myTC=$9
    voxel_size=${10}
    voxel_weight=${11}
    rotate_deg=${12}
    stretch_n=${13}
    time_steps=${14}
    geo_rot_deg=${15}
    result_policy=${16}
    result_radius=${17}
    ray_vox_scale=${18}
    
    # echo "pc = $pc" >&2
    # echo "row = $row" >&2
    # echo "tree = $tree" >&2
    # echo "from = $from" >&2
    # echo "repeats = $repeats" >&2
    # echo "outDir = $outDir" >&2
    # echo "cepto_file = $cepto_file" >&2
    # echo "open_file = $open_file" >&2
    # echo "myTC = $myTC" >&2
    # echo "voxel_size = $voxel_size" >&2
    # echo "voxel_weight = $voxel_weight" >&2
    # echo "rotate_deg = $rotate_deg" >&2
    # echo "stretch_n = $stretch_n" >&2
    # echo "time_steps = $time_steps" >&2
    # echo "geo_rot_deg = $geo_rot_deg" >&2
    # echo "result_policy = $result_policy" >&2
    # echo "result_radius = $result_radius" >&2
    # echo "ray_vox_scale = $ray_vox_scale" >&2
    
    echo "outdir = $outDir" >&2
    [[ -d $outDir ]] || mkdir $outDir
    rm -rf $outDir/data-*
    filtRes=$(echo "$voxel_size * $ray_vox_scale" | bc)  # multiplying by 3 guarantees no aliasing holes, right?
    # weather_data="/mnt/sequoia/u16/mantis-shrimp-data/datasets/bundaberg/weather/vantage-pro/weather-combined.txt"
    weather_data="weather-combined.txt"
    latitude=-25.143641572052292
    longitude=152.37746729565248
    transmitList=`seq 0 0.05 0.95 | tr '\n' ':'`
    leaf_transmittance_list="(`echo "$transmitList" | tr ':' ' '`)" #Specific array notation required for raytrace
    mask="masks/r${row}-t${tree}${from}-zeb-in-velo-frame_mask"
    TT=$(echo $transmitList | tr ':' '\n')
    local intensity_fields=""
    local csv_eval_string=""
    local count=0
    for transmittance in `echo "$TT"`
    do
        intensity_fields="$intensity_fields""energy$transmittance,"
        count=$(echo "$count + 1" | bc)
    done
    intensity_fields=${intensity_fields::-1}
    
    local tr_bin="$count""d"
    
    # Alignment (or not, depending)
    # if [[ $no_align ]]
    if [[ $no_align || $no_trace ]]
    then
        echo "Skipping alignment" >&2
    else
        echo "Performing alignment" >&2
        [[ $planar ]] && pFlag="--planar"
        label-cepto.sh "$pc" --fields=x,y,z,t --binary=3d,ui --coeff=$myTC --rotate=$rotate_deg --geo-rot=$geo_rot_deg --stretch=$stretch_n --output-dir=$outDir --weight=$voxel_weight --resolution=$voxel_size --verbose $pFlag > $outDir/cepto.bin
        (echo "fields=i,j,k,x,y,z,w,cid,tc,ac";echo "binary=3ui,3d,2ui,2d") | name-value-convert --to json > cepto.json
        # label-cepto.sh "$pc" --fields=x,y,z,t --binary=3d,ui --coeff=$myTC --rotate=$rotate_deg --geo-rot=$geo_rot_deg --stretch=$stretch_n --output-dir=$outDir --weight=$voxel_weight --resolution=$voxel_size --verbose --view > $outDir/cepto.bin
        # csv-calc mean --fields=,,,x,y,z --binary=3ui,3d,2ui > $outDir/openair.bin
        # echo "Did the alignment succeed? (y/n)" >&2
        # read answer
        # if [ $answer == "y" -o $answer == "Y" ]
        # then
        # 	echo "Continuing to raytracing..." >&2
        # else
        # 	exit
        # fi
    fi
    
    
    #Calculate date & time(s)
    ts=$(cat $cepto_file |
        csv-shuffle --fields=t, -o=t |
        csv-time --from iso --to seconds | csv-calc mean --format=d |
    csv-time --from seconds --to iso)
    
    sTime=$(echo $ts | cut -f2 -dT | cut -c1-4)
    mTime=$(echo $sTime | cut -c3-4 | sed s/^0//)
    hTime=$(echo $sTime | cut -c1-2)
    # if [[ mTime -ge 30 ]]
    # then
    # 	sTime="${hTime}30"
    # else
    # 	sTime="${hTime}00"
    # fi
    sDate=$(echo $ts | cut -f1 -dT)
    
    # ## Validation, Date ##
    if [[ $validate_date ]]
    then
        [[ $sDate == '20160728' ]] && sDate=20160905
        [[ $sDate == '20160905' ]] && sDate=20161215
        [[ $sDate == '20161215' ]] && sDate=20170516
        [[ $sDate == '20170516' ]] && sDate=20160728
    fi
    # ######################
    
    if [[ $time_steps == "min" ]]
    then
        timeset="0"
        elif [[ $time_steps == "max" ]]; then
        timeset="1"
    else
        seqVal=`echo $time_steps | csv-eval --format=d --fields=x "x=1/(x+1)"`
        timeset=`seq 0 $seqVal 1 | tail -n+2 | head -n-1`
    fi
    
    for perc in `echo $timeset`
    do
        tTime=$(cat $cepto_file | csv-time --fields=t --from=iso --to=seconds |
            csv-calc percentile=$perc --fields=t --format=d |
            csv-time --from=seconds --to=iso |
        cut -dT -f2 | cut -c1-4)
        rawTime=$tTime
        mTime=$(echo $tTime | cut -c3-4 | sed s/^0//)
        hTime=$(echo $tTime | cut -c1-2)
        # ## Validation, Time ##
        if [[ $validate_time ]]
        then
            hTime=$(echo $hTime | sed 's/^0//')
            hTime=$(echo 5 + $hTime | bc)
            [[ hTime -ge 16 ]] && hTime=$(echo "$hTime - 8" | bc)
            [[ hTime -lt 10 ]] && hTime="0$hTime"
            [[ mTime -lt 10 ]] && mTime="0$mTime"
            rawTime="$hTime$mTime"
        fi
        # ######################
        
        if [[ mTime -ge 45 ]]
        then
            hTime=`expr $hTime + 1`
            [[ $hTime -lt 10 ]] && hTime="0$hTime"
            # tTime="${hTime}30"
            tTime="${hTime}00"  #yyFix this and rerun.
        elif [[ mTime -ge 15 ]]
        then
            tTime="${hTime}30"
        else
            tTime="${hTime}00"
        fi
        # echo "$tTime" >&2
        [[ $no_snap ]] && tTime=$rawTime # Testing something (not rounding)
        dataDir="$outDir/data-$sDate-$tTime"
        [[ -d $dataDir ]] && rm -rf $dataDir
        mkdir $dataDir
        # ## Run Samuel's Raytracing ##
        
        if [[ $no_trace ]]
        then
            echo "Skipping raytrace" >&2
        else
            if [[ -f $outDir/nrg.$coeff.bin ]]
            then
                echo "Skipping raytrace; nrg.$coeff.bin already exists" >&2
            else
                
                echo "Computing sky..." >&2
                # SkyGenerator.py $sDate $sDate $latitude $longitude $weather_data $repeats --step-days=1 --step-hours=0.5 --utc-offset=10\
                # SkyGenerator.py $sDate $sDate $latitude $longitude $weather_data $repeats --step-days=1 --step-hours=0.5 --single-time=$tTime --utc-offset=10\
                
                # If doing manual distribution of diffuse component, do it here.
                diffuse="0"
                [[ $no_snap ]] && snapFlag="--no-snap"
                if [[ $direct_only ]]
                then
                    SkyGenerator.py $sDate $sDate $latitude $longitude $weather_data $repeats --step-days=1 --step-hours=0.5 --single-time=$tTime --utc-offset=10 $snapFlag\
                    | csv-units --fields=elev,azi --from=rad --to=deg | tee >(csv-calc sum --format=3d --fields=,,n) | tail -2 | tr '\n' ',' | sed -e 's/,$/\n/' | csv-shuffle --fields=a,b,,c -o=a,b,c > $outDir/sky.csv
                else
                    SkyGenerator.py $sDate $sDate $latitude $longitude $weather_data $repeats --step-days=1 --step-hours=0.5 --single-time=$tTime --utc-offset=10 $snapFlag\
                    | csv-units --fields=elev,azi --from=rad --to=deg > $outDir/sky.csv
                fi
                echo "...done! Moving on to computation of interception." >&2
                # Add unique ID to each point, in order to be able to do proper csv-join later
                # (using the coordinates as a unique identifier won't do since rounding errors appear after rotating back and fourth)
                echo -n "Calculating openair values..." >&2
                # cat $outDir/openair.bin | csv-blocks group --binary=3d --fields=id,id,id > $outDir/uniqueID_data
                # rayTraceFromSky $outDir/uniqueID_data "3d,ui" "x,y,z,uniqueID" $voxel_size "$leaf_transmittance_list" __sky__ 0.5 $repeats $outDir/open.$tTime.nrg.$coeff.bin 2>/dev/null 1>/dev/null
                cat $outDir/sky.csv | csv-calc sum --fields=,,e --format=3d > $outDir/open.$tTime.nrg.csv
                echo "Done!" >&2
                
                # cat $outDir/cepto.bin | csv-select --binary=3ui,3d,2ui --fields=,,,,,,,i --from=1 | csv-sort --binary=3ui,3d,2ui --fields=,,,,,,,id -u > cpts.bin
                
                # cat $outDir/cepto.bin | csv-select --binary=3ui,3d,2ui --fields=,,,,,,,i --equals=0 |
                # cat "-" cpts.bin | csv-blocks group --binary=3ui,3d,2ui --fields=vx,vy,vz,id,id,id,vw,cid > $outDir/uniqueID_data
                idFrom=2000
                [[ $planar ]] && idFrom=2001
                cat $outDir/cepto.bin | csv-select --binary=3ui,3d,2ui,2d --fields=,,,,,,,i "i;equals=0" "i;from=$idFrom" --or |
                csv-eval --binary=3ui,3d,2ui,2d --fields=vx,vy,vz,x,y,z,vw,cid,tc,ac "tc=where(cid==0,$coeff,tc); 	ac=where(cid==0,1-$coeff,ac)" | ## Update coefficient to most recent value
                csv-blocks group --binary=3ui,3d,2ui,2d --fields=vx,vy,vz,id,id,id,vw,cid,tc,ac > $outDir/uniqueID_data
                # rayTraceFromSky $outDir/uniqueID_data "3ui,3d,3ui" "vx,vy,vz,x,y,z,vw,cid,uniqueID" $voxel_size "$leaf_transmittance_list" __sky__ $voxel_size $repeats $outDir/nrg.$coeff.bin
                # rayTraceFromSky $outDir/uniqueID_data "3ui,3d,2ui,2d,ui" "vx,vy,vz,x,y,z,vw,cid,tc,ac,uniqueID" $voxel_size $outDir/sky.csv 0.5 $repeats $outDir/nrg.$coeff.bin
                ## Samuel didn't raytrace at the same voxel size as the point cloud ; does it work better that way?
                rayTraceFromSky $outDir/uniqueID_data "3ui,3d,2ui,2d,ui" "vx,vy,vz,x,y,z,vw,cid,tc,ac,uniqueID" $filtRes $outDir/sky.csv 0.5 $repeats $outDir/nrg.$coeff.bin
                (echo "fields=i,j,k,x,y,z,w,cid,tc,ac,uid,nrg,dns";echo "binary=3ui,3d,2ui,2d,ui,2d") | name-value-convert --to json > nrg.json
                ## Postprocessor calculates the volume & total absorbed energy
                # postprocessor.sh $mask_file 3ui,3d,ui vx,vy,vz,x,y,z,vw $write_file "$binary,ui,$tr_bin" "$fields,uid,$intensity_fields" 0.05
                
                rm $outDir/uniqueID_data
                
                # cat $outDir/nrg.$coeff.bin |
                #  points-ground extract --fields=,,,x,y,z --radius=0.25 --binary=3ui,3d,3ui,$tr_bin |
                #  csv-select --binary=3ui,3d,3ui,$tr_bin --fields=,,,,,,,id --from=1 --to=1850 | csv-from-bin 3ui,3d,3ui,$tr_bin |
                #  cat "-" <(cat $outDir/nrg.$coeff.bin | csv-select --binary=3ui,3d,3ui,$tr_bin --fields=,,,,,,,id --from=1 --to=1850|
                #     csv-from-bin 3ui,3d,3ui,$tr_bin) |
                #  sort | uniq -c | sed 's/^ *//' | tr ' ' , > $outDir/nrg-pts.$tTime.csv
            fi
        fi
        cat $outDir/nrg.$coeff.bin |
        csv-select --binary=3ui,3d,2ui,2d,ui,2d --fields=,,,,,,,id --from=2000 |
        csv-shuffle --binary=3ui,3d,2ui,2d,ui,2d --fields=vx,vy,vz,x,y,z,w,cid,tc,ac,uid,nrg,density -o=vx,vy,vz,x,y,z,w,cid,uid,nrg,density |
        csv-from-bin 3ui,3d,3ui,2d > $outDir/nrg-gnd.$coeff.$tTime.csv
        echo "fields=i,j,k,x,y,z,w,cid,uid,nrg,density" | name-value-convert --to json > $outDir/nrg-gnd.$coeff.$tTime.json
        # exit # Until I rewrite the next section
        # ## Grab postprocessing volume & energy ##
        
        # volume=$(cat $outDir/log.txt | grep "Volume" | cut -f2 -d: | tr -d ' ')
        # totalEnergies=$(cat $outDir/log.txt | grep "Energy" | cut -f2 -d: | sed 's/^ //' | tr ' ' ',')
        
        ## Process point cloud into just ceptometer-energies ##
        # cat $outDir/nrg.$coeff.bin | csv-select --binary=3ui,3d,3ui,$tr_bin --fields=,,,,,,,i --from=1 | csv-from-bin 3ui,3d,3ui,$tr_bin > $outDir/nrg-pts.csv
        
        echo "Processing energy data" >&2
        toStdForm $myTC $outDir d energy$myTC $open_file $dataDir $cepto_file $tTime $voxel_size $result_policy $result_radius
    done
    echo "combining partial data">&2
    # Combine all partial standards together
    dataDir="$outDir/combined-data-$sDate"
    [[ -d $dataDir ]] || mkdir $dataDir
    for file in `find $outDir | grep "\.$myTC\.par"`
    do
        # Add a 'diff' field to every point, combine it into allPar
        t=$(echo "$file" | egrep -o "\-[0-9]{4}\/nrg" | sed -r 's/(\-)|(\/)|(nrg)//g')
        cat $file | csv-shuffle --fields=t,sou,pos -o=t,sou,pos,t | cut -dT -f1,2 | csv-paste "-" "value=${t}00" |
        sed -r 's/(.*),/\1T/' | csv-time --fields=a,,,b --from=iso --to=seconds | csv-eval --fields=a,,,b --format=d,,,d "c=abs(a-b)" |
        csv-join --fields=,sou,pos "$file;fields=,sou,pos" | csv-shuffle --fields=,,,,dff,tim,sou,pos,opn,q,w,e,r,t,y,u,i,o -o=tim,dff,sou,pos,opn,q,w,e,r,t,y,u,i,o
    done |
    csv-sort --fields=tim,dff --order=dff,tim |
    csv-join --fields=tim,dff,sou,pos --first-matching "$cepto_file;fields=,sou,pos" |
    csv-shuffle --fields=tim,dff,sou,pos,opn,q,w,e,r,t,y,u,i,o -o=tim,sou,pos,opn,q,w,e,r,t,y,u,i,o > $dataDir/nrg.$myTC.par.csv
    
    # Add bounding times because csv-time-join is like that...
    nTime=`echo $sTime - 600 | bc`
    [[ "$nTime" -lt "1000" ]] && nTime="0$nTime"
    time_iso="${sDate}T${nTime}"
    echo "$time_iso,0" > $outDir/open.sim.par.csv
    
    for file in `find $outDir | grep "open\.[012]"`
    do
        echo "$file" >&2
        open_tme=`echo "$file" | egrep -o '\.[0-9]*\.' | tr -d '.'`
        open_dte=`echo "$file" | egrep -o '\/[0-9]*\/' | tr -d '/'`
        time_iso="${open_dte}T${open_tme}"
        # ratio="1.72/($voxel_size*$voxel_size)"
        ratio="1.72"
        cat $file |
        csv-paste "-" "value=$time_iso" |
        csv-shuffle --fields=e,t -o=t,e |
        csv-eval --fields=,e --format=t,d "e=e*$ratio"
    done |
    csv-sort --fields=tim,nrg --order=tim >> $outDir/open.sim.par.csv
    nTime=`echo $sTime + 600 | bc`
    time_iso="${sDate}T${nTime}"
    echo "$time_iso,0" >> $outDir/open.sim.par.csv
    
    rm -f $outDir/nrg-gnd* # nrg-gnd can be reproduced every time lol
}


function option-description
{
    cat <<eof
--row=[<row>]; default=8; Orchard row in which tree exists
--tree=[<tree>]; default=12; Number of trees from the end of the row
--from=[<direction>]; default=e; Direction from which tree number is counted
--repeats=[<complexity>]; default=5; number of sphere-repeats with which to run raytracing.
--output-dir=[<directory>]; default=outputs; name of directory in which to save output files
--cepto-file=[<file>]; default=cepto-data/processed/20161215/r8t12.1300.csv
--openair-file=[<file>]; default=cepto-data/processed/open-20161215.csv
--coeff=[<coefficient>]; default=0.50; transmission coefficient to use for foliage points
--result-policy=[<policy>]; default=density-mean; policy to use for result generation: must be "mean", "min", "max", "nearest", "median" or "optimal"
--result-radius=[<radius>]; default=0.2; radius (m) around actual cepto location to consider for result generation
--voxel-size=[<size>]; default=0.03; Size of voxels for thinned point cloud processing
--voxel-weight=[<weight>]; default=1; Minimum weight for voxel to count as solid matter
--no-align; Skip alignment step; output-dir/cepto.coeff.bin must exist from a previous alignment. Mostly for debugging purposes
--coeff-align-only; Only update coefficient in alignment
--no-trace; Skip alignment and raytracing steps; output-dir/nrg.coeff.bin must exist from a previous raytrace. Mostly for debugging purposes/changing the postprocess
--no-show; Do not show the r^2-plot at the end
--validate-time; Run with the wrong times.
--validate-date; Run with the wrong dates.
--rotate=[<degrees>]; default=0; Rotate tree of interest by this many degrees.
--geo-rot=[<degrees>]; default=0; amount in degrees by which to rotate the entire point cloud
--stretch=[<times>]; default=0; Stretch tree rows by this many iterations (should be 0-3 max).
--no-open; Do not perform open-air calibration
--time-steps=[<N>]; default=1; Split time window into N sections
--no-snap; Place sun in the right place
--planar; Remove ground and insert a regular planar grid
--null-offset; Do not offset ceptometers to optimal value
--raytrace-scale=[<scale>]; default=2; Scaling factor for raytracing
--direct-only; All light comes from the sun node, no light from anywhere else.
eof
}

function usage
{
    cat <<eof

$name assists with modelling ceptometer measurements using Samuel Orn's light model.  First the user is prompted to select ceptometer grid stakes to align
the simulated grid.  The program then runs the raytracing and processes the output into a standard form.

usage: $name <pc> [options]

positional argument:
point_cloud=<file>; binary point cloud containing visible ceptometer stakes to which the grid should be aligned.  PC should consist of georeferenced XYZ points only

options:
$( option-description  | sed 's/^/    /g' )

eof
    exit 1
}

if (( $( comma_options_has --help $@ ) || $( comma_options_has -h $@ ) )) ; then usage ; fi
options=$( option-description | comma-options-to-name-value "$@" ) || error "invalid command line options"
comma_path_value_to_var --prefix="options" <<< "$options"
eval "$( option-description | comma-options-to-name-value "$@" | comma_path_value_mangle )"

(( $( comma_options_has --no-align "$@" ) )) && export readonly no_align=true
(( $( comma_options_has --coeff-align-only "$@" ) )) && export readonly coeff_align=true
(( $( comma_options_has --no-trace "$@" ) )) && export readonly no_trace=true
(( $( comma_options_has --no-open "$@" ) )) && export readonly no_open=true
(( $( comma_options_has --validate-time "$@" ) )) && export readonly validate_time=true
(( $( comma_options_has --validate-date "$@" ) )) && export readonly validate_date=true
(( $( comma_options_has --no-snap "$@" ) )) && export readonly no_snap=true
(( $( comma_options_has --planar "$@" ) )) && export readonly planar=true
(( $( comma_options_has --null-offset "$@" ) )) && export readonly null_offset=true
(( $( comma_options_has --direct-only "$@" ) )) && export readonly direct_only=true

set -e # Kill if anything errors out; we don't want it to run everything on bad datasets

go $1 $options_row $options_tree $options_from $options_repeats $options_output_dir $options_cepto_file $options_openair_file $options_coeff $options_voxel_size $options_voxel_weight $options_rotate $options_stretch $options_time_steps $options_geo_rot $options_result_policy $options_result_radius $options_raytrace_scale
set -e # Kill if anything errors out; we don't want it to run everything on bad datasets
touch rsquareds
go $options_repeats $options_output_dir $options_cepto_dir $options_coeff $options_voxel_size $options_voxel_weight $options_rotate $options_stretch $options_time_steps $options_geo_rot $options_result_policy $options_result_radius $options_raytrace_scale $flag $avFlag 
