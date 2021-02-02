#!/bin/bash


# Gets a ceptometer 'subgrid' - i.e. the 8 segments for each of the 49 points.
function cepto-subgrid() {
	local truth=$1
	local corr=$2
	fullgrid=''

	i=1
	for y in `seq 6.4 0.8 11.2`
	do
		for x in `seq 6 -1 0`
		do
			segment=0
			# fullgrid="$fullgrid\n$south,$i,$segment,$x,$y,0"
			for seg in `seq 0 0.1 0.7`
			do
				segment=`expr $segment + 1`
				s=`echo $y - $seg | bc`
				fullgrid="$fullgrid\n0,$i,$segment,$x,$s,0"
			done
			i=`expr $i + 1`
		done
	done
	i=1
	for y in `seq 4.8 -0.8 0`
	do
		for x in `seq 6 -1 0`
		do
			segment=0
			# fullgrid="$fullgrid\n$south,$i,$segment,$x,$y,0"
			for seg in `seq 0 0.1 0.7`
			do
				segment=`expr $segment + 1`
				s=`echo $y + $seg | bc`
				fullgrid="$fullgrid\n1,$i,$segment,$x,$s,0"
			done
			i=`expr $i + 1`
		done
	done

	frame=$(csv-paste <(echo "$truth") <(echo "$corr") | points-align | cut -d, -f1-6)

	echo -e "$fullgrid" | points-frame --fields=side,num,segment,x,y,z --from $frame #|
	#view-points --fields=scalar,,x,y,z --weight=4
}


# Gets the cepto grid - the 49 points from which the ceptometer was measured, on each side of the tree.
function cepto-grid() {
	local truth=$1
	local corr=$2
	fullgrid=''
	i=1
	for y in `seq 6.4 0.8 11.2`
	do
		for x in `seq 6 -1 0`
		do
			if [ $x == 0 -o $x == 6 -o $y == 11.2 ]
			then
				for z in `seq -0.5 0.01 0.5` 
				do
					fullgrid="$fullgrid\n0,$i,0,$x,$y,$z"
				done
			else 
				fullgrid="$fullgrid\n0,$i,0,$x,$y,0"
			fi
			i=`expr $i + 1`
		done
	done
	i=1
	for y in `seq 4.8 -0.8 0`
	do
		for x in `seq 6 -1 0`
		do
			if [ $x == 0 -o $x == 6 -o $y == 0 ]
			then
				for z in `seq -0.5 0.01 0.5` 
				do
					fullgrid="$fullgrid\n1,$i,0,$x,$y,$z"
				done
			else 
				fullgrid="$fullgrid\n1,$i,0,$x,$y,0"
			fi
			i=`expr $i + 1`
		done
	done
	y=5.6
	for x in `seq 6 -1 0`
	do
		for z in `seq -0.5 0.01 0.5` 
		do
			fullgrid="$fullgrid\n1,$i,0,$x,$y,$z"
		done
	done

	frame=$(csv-paste <(echo "$truth") <(echo "$corr") | points-align | cut -d, -f1-6)

	echo -e "$fullgrid" | points-frame --fields=side,num,segment,x,y,z --from $frame #|

	# frame=$(csv-paste <(echo "$truth") <(echo "$corr") | points-align | cut -d, -f1-6)

	# echo -e "$fullgrid" |
	# points-frame --fields=side,num,segment,x,y,z --from $frame #|
	#view-points --fields=scalar,,x,y,z --weight=4



}

if [ $# -lt 2 ] 
then
	echo "Usage: $0 point-cloud.thin.bin rownum"
	exit
fi

read_file=$1 #Should be a VOXELISED point cloud with standard 3ui,3d,ui format
rownum=$2

# pc=$(cat $read_file | csv-paste "-;binary=3ui,3d,ui" value="0;binary=ui" | base64)

## Truth for r45t24w ##
truth45=$(cat << eof
7219272.807623595,435553.5599589142,-104.4072339730969
7219272.07750389,435559.5297531876,-104.514893091929
7219261.735967129,435552.1362957748,-104.2153471407414
7219261.037312239,435558.0163306984,-104.3876884465039
eof
)
## Truth for r55t15e ##
truth55=$(cat << eof
7219340.062044694,435862.5197361171,-94.70769271259725
7219339.456001832,435868.3827605903,-94.75242742901266
7219329.390403702,435860.7554133594,-95.47321257745445
7219328.497480228,435866.6758988559,-95.29764714097202
eof
)
## Truth for r8t12e ##  ##To measure: NW,NE,SW,SE
truth8=$(cat << eof
7218824.96232391,435790.8011523091,-104.6639006281767
7218824.213832622,435796.4570118391,-104.9138915384684
7218814.060387349,435789.2200612032,-104.9000549758349
7218813.301924234,435795.0890242063,-105.1260452712451
eof
)

truth8j=$(cat << eof
7218827.118050159,435790.2979781987,-104.0586391142929
7218826.028148235,435796.0743863942,-103.7429338149155
7218816.004370273,435788.5877168538,-103.5441934517944
7218814.985844196,435794.4868305089,-103.192971562537
eof
)
corr=$(cat << eof
0,11,0
6,11,0
0,0,0
6,0,0
eof
)
export -f cepto-subgrid

#nasty fix, but I don't care
touse="truth$rownum"
truth="${!touse}" 
cepto-grid "$truth" "$corr" > r${rownum}posts.csv
# exit

cepto-subgrid "$truth" "$corr" > r${rownum}grid.csv
# exit
ceptogrid=$(cepto-subgrid "$truth" "$corr" | csv-shuffle --fields=s,i,seg,x,y,z --output-fields=x,y,z |
	points-to-voxels --fields=x,y,z --resolution=0.1 |
	csv-paste "-" "line-number" | csv-eval --fields=,,,,,,,i "i = i + 1" | # Have to add 1 to line numbers, so they're separate to the 0 in PC
	csv-to-bin 3ui,3d,2ui | base64)

cat <(cat $read_file | csv-paste "-;binary=3ui,3d,ui" value="0;binary=ui") <(echo "$ceptogrid" | base64 -d) > row${rownum}.cepto.thin.bin
# cat $read_file
# cat <(cat $read_file | csv-paste "-;binary=3ui,3d,ui" value="0;binary=ui" ) <(echo "$ceptogrid" | base64 -d)


## To extract the cepto points after running raytrace:
# cat r8sub-id.csv | # r8sub-id.csv being subgrid with linenumber+1
#  csv-to-bin 3ui,3d,ui |
#  csv-join --binary=3ui,3d,ui --fields=,,,,,,id "energy-with-cepto-r8.bin;binary=3ui,3d,3ui,d;fields=,,,,,,,,id" |
#  csv-shuffle --binary=3ui,3d,ui,3ui,3d,3ui,d --fields=a,b,c,x,y,z,,,,,,,,,,,e --output-fields=a,b,c,x,y,z,e 
## To view
# cat cepto-nrg.csv |
#  view-points \
#  "-;fields=,,,x,y,z,scalar;colour=0:0.5,hot;weight=5"\
#  "energy-with-cepto-r8.bin;binary=3ui,3d,3ui,d;fields=,,,x,y,z,,,,scalar;colour=0:0.5,hot"

# Gets a ceptometer 'subgrid' - i.e. the 8 segments for each of the 49 points.
function cepto-subgrid-orig() {
	local truth=$1
	local corr=$2
	fullgrid=''

	i=1
	for y in `seq 7 1 13`
	do
		for x in `seq 6 -1 0`
		do
			segment=0
			# fullgrid="$fullgrid\n$south,$i,$segment,$x,$y,0"
			for seg in `seq 0.1 0.1 0.8`
			do
				segment=`expr $segment + 1`
				s=`echo $y - $seg | bc`
				fullgrid="$fullgrid\n0,$i,$segment,$x,$s,0"
			done
			i=`expr $i + 1`
		done
	done
	i=1
	for y in `seq 6 -1 0`
	do
		for x in `seq 6 -1 0`
		do
			segment=0
			# fullgrid="$fullgrid\n$south,$i,$segment,$x,$y,0"
			for seg in `seq 0.1 0.1 0.8`
			do
				segment=`expr $segment + 1`
				s=`echo $y + $seg | bc`
				fullgrid="$fullgrid\n1,$i,$segment,$x,$s,0"
			done
			i=`expr $i + 1`
		done
	done

	frame=$(csv-paste <(echo "$truth") <(echo "$corr") | points-align | cut -d, -f1-6)

	echo -e "$fullgrid" | points-frame --fields=side,num,segment,x,y,z --from $frame #|
	#view-points --fields=scalar,,x,y,z --weight=4
}

