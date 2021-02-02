#!/bin/bash

export readonly name=$( basename $0 )

source $( type -p comma-application-util ) || (error "comma not installed")
function errcho { (>&2 echo "$name: $1") }
function error
{
    errcho "error: $1"
    exit 1
}

function paraGo () {
    f=$1
    cepto_dir=$2
    result_policy=$3
    result_radius=$4
    time_steps=$5
    idx=$6
    nFiles=$7
    coeff=$8
    # pFlag=
    # opflag=
    prc=$(echo "$idx*100/$nFiles" | bc)
    
    d=$(echo "$f" | sed 's/\/cepto.bin//')
    sDate=$(echo "$f" | egrep -o "\/[0-9]{8}\/" | tr -d '/')
    sTime=$(echo "$f" | egrep -o "\-[0-9]{4}" | tr -d '-')
    treeName=$(echo "$f" | egrep -o "r[0-9]*t[0-9]*[ew]")
    row=$(echo "$treeName" | tr 'a-z' '.' | cut -d'.' -f2)
    tree=$(echo "$treeName" | tr 'a-z' '.' | cut -d'.' -f3)
    from=$(echo "$treeName" | egrep -o ".$")
    read_file="/home/fwes7558/data/labelled/$sDate/r$row-t$tree$from-labelled.bin"
    raytrace-cepto.sh $read_file --row=$row --tree=$tree --from=$from \
    --cepto-file=$cepto_dir/$sDate/$treeName-$sTime.csv --result-policy=$result_policy --result-radius=$result_radius \
    --output-dir=$d --openair-file=$cepto_dir/open-$sDate.csv --coeff=$coeff \
    --time-steps=$time_steps $flag $avFlag --no-show --no-trace --raytrace-scale=1 --no-snap --no-align 2>>recepto.log
    echo -en "$prc%, " >&2
}

function go () {
    out_dir=$1
    cepto_dir=$2
    time_steps=$3
    result_policy=$4
    result_radius=$5
    coeff=$6
    
    out_dir=$(echo "$out_dir" | tr '?' '*')
    files=$(find $out_dir -mindepth 2 -maxdepth 2 | grep -v \/cycles\/)
    # files=$(find $out_dir -regex '.*/cepto.bin')
    nFiles=$(echo "$files" | wc -l)
    idx=1
    [[ $no_open ]] && opflag="--no-open"
    [[ $planar ]] && pFlag="--planar"
    
    export -f paraGo
    # touch all.data.csv
    echo "$files" | parallel -n 1 paraGo {} $cepto_dir $result_policy $result_radius $time_steps {#} $nFiles $coeff
    echo "done" >&2
}

function option-description
{
    cat <<eof
--output-dir=[<directory>]; default=outputs; directory which contains raytrace data.  Should be organised as ./20161215/r8t12e-1500/{outputs-from-cepto-raytrace}
--cepto-dir=[<file>]; default=cepto-data/processed; directory in which processed ceptometer data can be found.
--result-policy=[<policy>]; default=density-mean; policy to use for result generation: must be "mean", "min", "max", "nearest", "median" or "optimal"
--result-radius=[<radius>]; default=0.1; radius (m) around actual cepto location to consider for result generation
--voxel-size=[<size>]; default=0.05; Size of voxels for thinned point cloud processing
--no-open; Don't perform openair calibration during postprocessing
--time-steps=[<N>]; default=1; Split time window into N sections
--planar; Remove ground and insert a regular planar grid
--raytrace-scale=[<scale>]; default=3; Scaling factor for raytracing
--coeff=[<coeff>]; default=0.80; Coefficient for transmission
eof
}

function usage
{
    cat <<eof

$name Performs a raytrace-cepto process on a set of data files.  These files are assumed to be outputs from raytrace-cepto which need to be rerun (not including alignment step)


usage: $name [options]

options:
$( option-description  | sed 's/^/    /g' )

eof
    exit 1
}

flag="--no-show"
avFlag=""

if (( $( comma_options_has --help $@ ) || $( comma_options_has -h $@ ) )) ; then usage ; fi
options=$( option-description | comma-options-to-name-value "$@" ) || error "invalid command line options"
comma_path_value_to_var --prefix="options" <<< "$options"
eval "$( option-description | comma-options-to-name-value "$@" | comma_path_value_mangle )"
(( $( comma_options_has --no-align "$@" ) )) && flag="--no-align"
(( $( comma_options_has --no-trace "$@" ) )) && flag="--no-trace"
(( $( comma_options_has --no-open "$@" ) )) && export readonly no_open=true
(( $( comma_options_has --average "$@" ) )) && avFlag="--average"
(( $( comma_options_has --validate-time "$@" ) )) && export readonly validate_time=true
(( $( comma_options_has --validate-date "$@" ) )) && export readonly validate_date=true
(( $( comma_options_has --validate-pointcloud "$@" ) )) && export readonly validate_pc=true
(( $( comma_options_has --distribute "$@" ) )) && export readonly distribute=true
(( $( comma_options_has --no-snap "$@" ) )) && export readonly no_snap=true
(( $( comma_options_has --planar "$@" ) )) && export readonly planar=true

set -e # Kill if anything errors out; we don't want it to run everything on bad datasets
touch rsquareds
go $options_output_dir $options_cepto_dir $options_time_steps $options_result_policy $options_result_radius $options_coeff
	local ceptoFile=$(getCepto $parFile $ceptoDir)
	# echo "$idx: $ceptoFile" >&2
	pts=$(cat $parFile |
		csv-join --fields=ta,sou,pos "$ceptoFile;fields=tb,sou,pos" |
		csv-sort --fields=,sou,pos | 
		csv-shuffle --fields=tim,sou,pos,opn,avg,s1,s2,s3,s4,s5,s6,s7,s8,TIM,SOU,POS,AVG,S1,S2,S3,S4,S5,S6,S7,S8 \
			--output-fields=tim,sou,pos,avg,AVG,opn |
		csv-eval --fields=,,x --format=,,ui "r=(x-1)/7" |
		csv-eval --fields=,,x --format=,,ui "r=(x-1)%7")
	avPts=""
	for sou in `seq 0 1`
	do
		for row in `seq $downLim $upLim`
		do
			for col in `seq $downLim $upLim`
			do
				rowLo=$(echo $row - $rad | bc)
				colLo=$(echo $col - $rad | bc)
				rowHi=$(echo $row + $rad | bc)
				colHi=$(echo $col + $rad | bc)
				# echo "===== PT: ($row,$col) =====" >&2
				echo "$pts" | csv-select --format=t,ui,ui,d,d,d,ui,ui --fields=,s,,,,,r,c "r;from=$rowLo;to=$rowHi" "c;from=$colLo;to=$colHi" "s;equals=$sou" |
				 csv-calc mean --format=t,ui,ui,d,d,d,ui,ui --fields=t,s,p,a,b,o,r,c 2>/dev/null |
				 csv-shuffle --fields=t,s,p,a,b,o,c,block --output-fields=t,s,p,a,b,o
			done
		done
	done |
	csv-eval --fields=tim,sou,pos,a,b,o "o=4" --format=t,d,d,d,d,d |

	# echo "$pts" |
	# 	csv-calc mean --format=ui,ui,d,d,d,ui,ui --fields=s,p,a,b,o,block,c 2>/dev/null | # Note: csv-calc is throwing an error because one tree has some weird invisible characters
	# 	csv-shuffle --fields=s,p,a,b,o,c,block --output-fields=p,a,b,o |
	# 	# csv-select --fields=,,,o --to=0.25 | # Un comment this to see only openair (or no openair) points
		# csv-paste "-" "value=$idx"
	label $idx $parFile $ceptoFile | interception $parFile $ceptoDir
}

# Takes the average of every N ceptometer locations, sampled randomly.
# For consistency, random sampling is done in south and north independently.
function neighrand() {
	# pair='[^,]+,[^,]+'
	local parFile=$1
	local idx=$2
	local ceptoDir=$3
	local n=$4
	local ceptoFile=$(getCepto $parFile $ceptoDir)
	# echo "$idx: $ceptoFile" >&2
	pts=$(cat $parFile |
		csv-join --fields=ta,sou,pos "$ceptoFile;fields=tb,sou,pos" |
		csv-sort --fields=,sou,pos | 
		csv-shuffle --fields=tim,sou,pos,opn,avg,s1,s2,s3,s4,s5,s6,s7,s8,TIM,SOU,POS,AVG,S1,S2,S3,S4,S5,S6,S7,S8 \
			--output-fields=tim,sou,pos,avg,AVG,opn)
	#"pts" is now t,s,p,a,b,o; we need to get to t,s,p,a,b,o, but averaged over N segments.
	# Copy pts N times so the number of points is definitely divisible by N.  This ensures all sample groups are equally sized.
	echo "$pts" |  csv-eval --format=t,ui,ui,d,d,d --fields=,,p,a,b, "x=p*a+p/(b+1)" | #Closest to random I can do without a bit more work...
		csv-sort --fields=t,s,p,a,b,o,x --fields=s,x |
		csv-paste "-" "line-number" | csv-eval --format=t,ui,ui,d,d,d,ui --fields=,,,,,,,l "l=floor(l/$n)" |
		csv-blocks group --fields=t,s,p,a,b,o,x,id |
		csv-calc mean --fields=t,s,p,a,b,o,,,block --format=t,ui,ui,d,d,ui,d,ui,ui |
		csv-shuffle --fields=t,s,p,a,b,o,blk -o=t,s,p,a,b,o | 
		csv-eval --fields=tim,sou,pos,a,b,o "o=4" --format=t,d,d,d,d,d |
		label $idx $parFile $ceptoFile | interception $parFile $ceptoDir 
}

# Extracts mean data for all datasets
function average() {
	# pair='[^,]+,[^,]+'
	local parFile=$1
	local idx=$2
	local ceptoDir=$3
	local ceptoFile=$(getCepto $parFile $ceptoDir)

	# echo "$idx: $ceptoFile" >&2
	#To find: cepto file (needs year, tree, etc.) 
	cat $parFile |
		csv-join --fields=ta,sou,pos "$ceptoFile;fields=tb,sou,pos" |
		csv-shuffle --fields=tim,sou,pos,opn,avg,s1,s2,s3,s4,s5,s6,s7,s8,TIM,SOU,POS,AVG,S1,S2,S3,S4,S5,S6,S7,S8 \
			--output-fields=tim,sou,avg,AVG | #Would include opn as a colouration thing, but csv-calc does not like it (in one particular case it screws up)
		# csv-calc mean,var --fields=id,a,b --format=ui,d,d | csv-shuffle --fields=mA,mB,vA,vB,id --output-fields=id,mA,mB,vA,vB |
		csv-calc mean,var --fields=t,p,a,b --format=t,ui,d,d | csv-shuffle --fields=mT,mP,mA,mB,vT,vP,vA,vB --output-fields=mT,mP,mA,mB,vA,vB |
		label $idx $parFile $ceptoFile | interception $parFile $ceptoDir
		# csv-shuffle --fields=p,a,b,i --output-fields=p,a,b,i,p,a,b,i
}

function dxdy() {
	echo "Nothing here...">&2
}

function runFunc () {
	local func=$1
	local tc=$2
	local out_dir=$3
	local dte=$4
	local tre=$5
	local tme=$6
	local cep_dir=$7
	local n=$8
	files=$(find $out_dir -regex .*$tc.*par\.csv |
		filter $dte $tre $tme)
	local idx=0
	echo -n "$tc "
	for f in `echo "$files"` 
	do
		# echo "$f" >&2
		idx=`expr $idx + 1`
		$func $f $idx $cep_dir $n 
	done | dataplot.py -x 2 -y 3 --noshow
}

function option-description
{
    cat <<eof
--output-dir=[<directory>]; default=outputs; directory which contains raytrace data.  Should be organised as ./20161215/r8t12e-1500/{outputs-from-cepto-raytrace}
--cepto-dir=[<file>]; default=cepto-data/processed; directory in which processed ceptometer data can be found.
--coeff=[<coefficient>]; default=0.80; transmission coefficient used for processing.
--tree=[<tree>]; default=all; e.g. "r55t15e", use to only plot a single tree
--date=[<date>]; default=all; e.g. "20160905", use to only plot a single date
--time=[<time>]; default=all; e.g. "1300", use to only plot a single time
--best; Process all available transmission coefficients, pick the one with the highest overall r^2 value
--no-show; Do not open the plot for viewing
--intercept; Use interception rather than straight-up values for comparison
--neighbours=[<neighbours>]; default=2; Size of neighbour search space.  Must be between 1 (=locations) and 8 (averages the full 14x7 grid) 
--save=[<savefile>]; default=''; Filename to save plot into 
--csv=[<csvfile>]; default='/dev/null'; Filename to save data into 
--blr; Use bayesian linear regression 
eof
}

function usage
{
    cat <<eof

$name Performs a raytrace-cepto process on a set of data files.  These files are assumed to be outputs from raytrace-cepto which need to be rerun (not including alignment step)

usage: $name [ segments | locations | average | neighbours | neighrand ] [options]
	
Operations:
	segments; Simulated vs measured data, one data point per cepto segment.
	locations; Simulated vs measured data, one data point per ceptometer.
	rows; Simulated vs measured data, one data point per row (average of that row's locations)
	neighbours; Simulated vs measured data, data points averaged between N nearest neighbours (average of that row's locations)
	average; Simulated vs measured data, mean & variance of all ceptometer data for each dataset
	neighrand; 
Options:
$( option-description  | sed 's/^/    /g' )

eof
    exit 1
}


flag="--no-align"
avFlag=""

if (( $( comma_options_has --help $@ ) || $( comma_options_has -h $@ ) )) ; then usage ; fi
options=$( option-description | comma-options-to-name-value "$@" ) || error "invalid command line options"
comma_path_value_to_var --prefix="options" <<< "$options"
eval "$( option-description | comma-options-to-name-value "$@" | comma_path_value_mangle )"
(( $( comma_options_has --no-align "$@" ) )) && export readonly find_best=true
(( $( comma_options_has --save "$@" ) )) && save_option="--savefile $options_save"
(( $( comma_options_has --no-show "$@" ) )) && show_option="--noshow"
(( $( comma_options_has --intercept "$@" ) )) && export readonly intercept=true

(( $( comma_options_has --blr "$@" ) )) && blrOpt="--blr"
# if [[ $best ]] 
# then
# 	tcList=$(find $options_output_dir -regex .*par.*csv | grep -o '0\.[0-9][0-9]' | sort | uniq)
# else 
tcList=$options_coeff
# fi
maxTC=`echo "$tcList" | head -1`


set -e # Kill if anything errors out; we don't want it to run everything on bad datasets
export -f getCepto
export -f runFunc
export -f filter 
export -f label
export -f interception

func=$1
[[ $func -eq neighbours ]] && [[ $options_neighbours == 0 ]] && func=segments
[[ $func -eq neighbours ]] && [[ $options_neighbours == 1 ]] && func=locations
[[ $func -eq neighbours ]] && [[ $options_neighbours == 8 ]] && func=average
export -f $func

if [ $func == "segments" -o $func == "locations" -o $func == "rows" -o $func == "neighbours" -o $func == "neighrand" ]
then
	[[ `echo "$tcList" | wc -l` == 1 ]] || maxTC=$(echo "$tcList" | parallel -n1 runFunc $func {} $options_output_dir $options_date $options_tree $options_time $options_cepto_dir $options_neighbours |
		sort -k2r | head -1 | cut -f1 -d' ')
	[ $func == segments ] && ttle='segment'
	[ $func == locations ] && ttle='cepto'
	[ $func == neighbours ] && ttle="${options_neighbours}x$options_neighbours"
#Input format = tim,sou,pos,a,b,opn,idx,dte,tme,tree,absTimeDiff
	find $options_output_dir -regex .*$options_coeff\.par\.csv | 
		filter $options_date $options_tree $options_time |
		parallel -n1 -j1 $func {} {#} $options_cepto_dir $options_neighbours | 
		# csv-select --format=t,ui,ui,d,d,ui,ui,ui,ui,ui,d --fields=,sou,,,,,,,,tree "sou;equals=1" "tree;not-equal=8" --or| tee $options_csv |
		csv-select --format=t,ui,ui,d,d,ui,ui,ui,ui,ui,d --fields=,sou,,,,,,,,tree "sou;equals=1"| tee $options_csv |
		# dataplot.py -y 2 -x 3 -c 9 -m 8 \
		# dataplot.py -y 3 -x 4 -c 1 -m 9 \ 
		# dataplot.py -y 3 -x 4 --plot hexbin \ --blr
		dataplot.py -y 3 -x 4 -c 8 -m 9 -s 5 -e 7 $blrOpt \
		--title "$ttle measurements Tree=$options_tree date=$options_date time=$options_time TC=$maxTC" \
			--xlabel "Measured PAR average" --ylabel "Simulated PAR average" \
			 --xlims 0 --ylims 0 --basic $save_option $show_option 

elif [ $func == "average" ]
then 
	[[ `echo "$tcList" | wc -l` == 1 ]] || maxTC=$(echo "$tcList" | parallel -n1 runFunc average {} $options_output_dir $options_date $options_tree $options_time $options_cepto_dir |  
		sort -k2r | head -1 | cut -f1 -d' ')
	find $options_output_dir -regex .*$maxTC\.par\.csv |
		filter $options_date $options_tree $options_time | 
		parallel -n1 -j1 average {} {#} $options_cepto_dir | tee "data.csv" |
		# fredplot.py 1 5 3 1 "Tree=$options_tree, date=$options_date, time=$options_time, TC = $maxTC"
		# dataplot.py -x 1,3 -y 2,4 -c 5,5 --title "Ceptometer averages TC=$maxTC","Ceptometer variance TC=$maxTC" \
		# dataplot.py -y 2 -x 3 -c 10 -m 9 --title "Full grid measurements TC=$maxTC" \

		dataplot.py -y 3 -x 4 -c 9 -e 8 -m 10 --title "Full grid measurements TC=$maxTC" \
			--ylabel "Simulated PAR average" --xlabel "Measured PAR average" --xlims 0,2500 --ylims 0,2500 --basic $save_option $show_option
elif [ $func == "dxdy" ]
then
	find $options_output_dir -regex .*optimal-dx.csv$ |
		filter $options_date $options_tree $options_time | 
		xargs -n 1 cat |
		dataplot.py -x 0 -y 1 -c 4 --title "dx/dy of optimal value, per-segment basis"		
elif [ $func == "opn" ] 
then
	export -f locations
	find $options_output_dir -regex .*$maxTC\.par\.csv |
		filter $options_date $options_tree $options_time | 
		parallel -n1 -j1 opn {} {#} $options_cepto_dir |
		dataplot.py -y 10 -x 4 -c 5 --basic --title "Full grid measurements TC=$maxTC" \

else
	error "Unknown operation"
fi