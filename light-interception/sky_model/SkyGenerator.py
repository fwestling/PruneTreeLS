#!/usr/bin/python

import sys
from os import path
import os
import math
import operator
from decimal import Decimal
import argparse
import signal
import datetime
import copy
import importlib
import numpy as np
import subprocess

sys.dont_write_bytecode = True

try:
	import geosunposition
except Exception as e:
	try:
		os.symlink(subprocess.check_output(["which", 'geo-sun-position']).rstrip(),'geosunposition.py')
		import geosunposition
	except Exception as e:
	    print "Error:", e
	    print "Check that snark utility geo-sun-position is properly installed"
	    sys.exit( 1 )

sys.path.append( path.dirname( path.dirname( path.abspath(__file__) ) ) )
from geodesic_sphere import GeodesicSphere
import WeatherParser
import BOMGridParser
import GlobalIrradiance
import DiffusePercentage


def getTimespanSky(date_start, date_end, latitude,longitude,weather_file,bom_folder,utc_offset = 10,num_samples = 50, res_days = 1, res_hours = 0.5,verbose=False,cartesian_output=False,radius=1):

	"""
	:param date_start:		string YYMMDD of when the timespan is to start
	:param date_end:		string YYMMDD of when the timespan is to end
	:param latitude: 		latitude in degrees of point on earth
    :param longitude: 		longitude in degrees of point on earth
    :param weather_file:    vantage pro weather ascii file
    :param bom_folder:      folder to cache BOM weather data
    :param utc_offset:		UTC timezon +offset in hours
    :param num_samples:		How many times geodesic sphere (discretised hemisphere) is to be divided.
	:param res_days: 		resolution (step) of days within the timespan [integer]
	:param res_hours: 		resolution (step) of hours within the timespan [float] NOTE: Has to be divisable by 0.5, 
							as weather data is collected at 30 min interval at the farm

	:return: 	List containing the total discretised sky during given timespan. Each datum in the list holds
				radiance in W/(m^2*st) for that sky segment.

	"""

	if(Decimal(str(res_hours)) % Decimal('0.5') != 0):
		raise Exception("Hour resolution must be divisable by 0.5, current resolution is: %f" % (res_hours))

	BOMparser = BOMGridParser.BOMGridParser(bom_folder)
	globalIrradiance = GlobalIrradiance.GlobalIrradiance(weather_file,BOMparser)
	diffusePercentage = DiffusePercentage.DiffusePercentage(BOMparser,globalIrradiance,verbose)

	hemisphere = GeodesicSphere.generateSamplesSpherical_upper(num_samples)
	timespan = timeSpan(date_start,date_end,res_days,res_hours)
	total_sky = [0]*len(hemisphere)

	for day in timespan:
		daily_sky = [0]*len(hemisphere)
		for time in day:
			sun_elevation, sun_azimuth = geosunposition.lat_long_to_elaz( latitude, longitude, time - datetime.timedelta(hours=utc_offset))
			if(sun_elevation > 0):
				sys.stderr.write("Timespan "+str(time) + "\n")
				global_irradiance = globalIrradiance.get(time,latitude,longitude,utc_offset,verbose)
				diffuse_percentage = diffusePercentage.diffusePart(time,sun_elevation,latitude,longitude,utc_offset)
				sky = getSky(time,sun_elevation, sun_azimuth,hemisphere,diffuse_percentage,global_irradiance,verbose)

				daily_sky = map(operator.add,daily_sky,sky)

		total_sky = map(operator.add,daily_sky,total_sky)

	for i in range(len(total_sky)):
		total_sky[i] *=res_hours*3.6 #Energies in kJ <- Sam  # (kJ -> W)? <- Fred

	return addCoordinates(num_samples,cartesian_output,total_sky,radius)

def getSkyAtDate(date, latitude, longitude, num_samples, weather_file,bom_folder,utc_offset = 10,verbose=False,cartesian_output=False,radius=1,no_snap=False):
	"""
	Gets sky at date and time specified in datetime.datetime object <date>. Mostly used for debugging purposes. 
	"""
	BOMparser = BOMGridParser.BOMGridParser(bom_folder)
	globalIrradiance = GlobalIrradiance.GlobalIrradiance(weather_file,BOMparser)
	diffusePercentage = DiffusePercentage.DiffusePercentage(BOMparser,globalIrradiance,verbose)
	


	date_time = datetime.datetime.strptime(date,'%Y%m%d%H%M')
	hemisphere = GeodesicSphere.generateSamplesSpherical_upper(num_samples)
	sun_elevation, sun_azimuth = geosunposition.lat_long_to_elaz( latitude, longitude, date_time - datetime.timedelta(hours=utc_offset))
	if(sun_elevation < 0):
		return [0]
	sys.stderr.write("%f, %f\n" %(sun_elevation,sun_azimuth))

	diffuse_percentage = diffusePercentage.diffusePart(date_time,sun_elevation,latitude,longitude,utc_offset)
	direct_irr_est = diffusePercentage.directVal(date_time,sun_elevation,latitude,longitude,utc_offset)
	global_irradiance = globalIrradiance.get(date_time,latitude,longitude,utc_offset,verbose)
	direct_irradiance = global_irradiance*(1 - diffuse_percentage)

	sky = getSky(date_time, sun_elevation, sun_azimuth ,hemisphere,diffuse_percentage,global_irradiance,direct_irr_est,verbose,nosnap=no_snap)
	if no_snap:
		fullsky = addCoordinates(num_samples,cartesian_output,sky,radius)
		return appendSunNode(cartesian_output,fullsky,sun_elevation,sun_azimuth,direct_irradiance)
	else:
		return addCoordinates(num_samples,cartesian_output,sky,radius)

def getSky(date, sun_elevation, sun_azimuth,hemisphere,diffuse_percentage,global_irradiance,direct_irr_est,verbose=False,nosnap=False):
	"""
	:param date:				datetime in datetime.datetime format
	:param sun_elevation: 		sun elevation in degrees
	:param sun_azimuth: 		sun azimuth in degrees (measured north -> east)
	:param hemisphere:			discretised hemisphere: list containing elevation and azimuth angles in 
								radians, e.g. [[elev1,azi1],...,[elevN,aziN]]
	:param utc_offset:			UTC timezon +offset in hours
	:param weather data:		Parsed weather data. Dict['date']['time']['field']
	:param latitude: 			latitude in degrees of point on earth
    :param longitude: 			longitude in degrees of point on earth

	:return: 	List containing a discretised sky at given datetime. Each datum in the list holds
				radiance in W/(m^2*st) for that sky segment.
	"""

	direct_irradiance = global_irradiance*(1 - diffuse_percentage)
	diffuse_irradiance = global_irradiance * diffuse_percentage

	sky = getDiffuseSky(diffuse_irradiance,hemisphere,sun_elevation,sun_azimuth,diffuse_percentage)

	# Add the direct component
	sun_index,error = GeodesicSphere.closestIndexOnDescretisedSphere(hemisphere,[math.radians(sun_elevation),math.radians(sun_azimuth)])
	if verbose:
		sys.stderr.write('Snap error at %s is: %f degrees\n' %(date.strftime('%Y-%m-%d %H:%M'),error))

	
	
	if(sun_elevation < 10): #If elevation is really small, the direct component becomes illconditionally large
		sun_elevation = 10
	# z = math.radians(90-sun_elevation)
	# am = 1/(math.cos(z)+0.50572*math.pow((96.07995-z),-1.6364))

	if not nosnap: # instantaneous
			## This is what it WAS (/)
		# sky[sun_index] += direct_irradiance/(math.sin(math.radians(sun_elevation))) ###USE THIS FOR NOT-CEPTOMETERS, i.e. INTEGRATE
			## This is what Fred made it - it looks like it works better, but IS IT CORRECT??? (*)
		# sky[sun_index] += direct_irradiance*(math.sin(math.radians(sun_elevation)))
			## is this better??
		sky[sun_index] += direct_irradiance # (++) ###USE THIS FOR CEPTOMETERS, THEY READ HORIZONTAL COMPONENTS

	# sky[sun_index] += direct_irr_est
	# sky[sun_index] += direct_irradiance/(math.cos(math.radians(sun_elevation)))
	# sys.stderr.write('%f,%f,%f,%f\n' %(global_irradiance,diffuse_irradiance,direct_irradiance,(direct_irradiance/(math.sin(math.radians(sun_elevation))))))
	return sky
	# return uniformSky(hemisphere, global_irradiance)


def addCoordinates(num_samples,cartesian_output,sky,radius=1):
	if(cartesian_output):
		cart_hemisphere = GeodesicSphere.generateSamplesCartesian_upper(num_samples,radius)
		for i in range(len(sky)):
			sky[i] = [cart_hemisphere[i][0],cart_hemisphere[i][1],cart_hemisphere[i][2],sky[i]]
	else:
		hemisphere = GeodesicSphere.generateSamplesSpherical_upper(num_samples)
		for i in range(len(sky)):
			sky[i] = [hemisphere[i][0],hemisphere[i][1],sky[i]]

	return sky

def appendSunNode(cartesian_output,sky,sun_elevation,sun_azimuth,direct_irr,radius=1):
	if (cartesian_output):
		std.err.write('Not yet implemented');
	else:
        # Make sure angles are always positive (boost whines otherwise...)
		if(sun_azimuth < 0):
			sun_azimuth += 360
		sky.append([math.radians(sun_elevation),math.radians(sun_azimuth),direct_irr]) # (++) ###USE THIS FOR CEPTOMETERS, THEY READ HORIZONTAL COMPONENTS
		# if(sun_elevation < 10): #If elevation is really small, the direct component becomes illconditionally large
		# 	sun_elevation = 10
		#sky.append([math.radians(sun_elevation),math.radians(sun_azimuth),direct_irradiance/(math.sin(math.radians(sun_elevation)))])
	return sky

def timeSpan(date_start,date_end,res_days,res_hours):
	"""
	:param date_start:		string YYMMDD of when the timespan is to start
	:param date_end:		string YYMMDD of when the timespan is to end
	:param res_days: 		resolution (step) of days within the timespan [integer]
	:param res_hours: 		resolution (step) of hours within the timespan [float]

	:return: 	list containing datetime.datetime in format:
				[[start_date_time1,...,start_date_timeN], ... , [end_date_time1,...,send_date_timeN]]
	"""

	date_start = datetime.datetime.strptime(date_start,'%Y%m%d')
	date_end = datetime.datetime.strptime(date_end,'%Y%m%d')

	if date_start > date_end:
		raise Exception("Start date is later than end date. Start date: %s, end date: %s" % (date_start,date_end))

	next_date = date_start
	only_dates = []
	while(next_date <= date_end):
		only_dates.append(next_date)
		next_date = only_dates[-1] + datetime.timedelta(days=res_days)

	
	dates = []
	for date in only_dates:
		hour = 0
		datetimes = []
		while(hour < 24):
			int_hour = int(hour)
			int_min = int((hour - int_hour)*60)
			date = date.replace(hour=int_hour, minute=int_min)

			datetimes.append(copy.deepcopy(date))

			hour += res_hours

		dates.append(datetimes)

	return dates



def getDiffuseSky(diffuse_irradiance,hemisphere,sun_elevation,sun_azimuth,diffuse_part):
	"""
	Distributes the diffuse irradiance over the sky
	"""

	luminances = getRelativeLuminances(hemisphere,math.radians(sun_elevation),math.radians(sun_azimuth),diffuse_part)

	return normByDiffuseIrradiance(luminances,diffuse_irradiance,hemisphere)
	# return deadSky(hemisphere, diffuse_irradiance)

def uniformSky(hemisphere, diffuse_irradiance):
	luminances = []
	everyval = diffuse_irradiance / len(hemisphere)
	for angle_pair in hemisphere:
		luminances.append(everyval)
	return luminances

def deadSky(hemisphere, diffuse_irradiance):
	luminances = []
	everyval = 0
	for angle_pair in hemisphere:
		luminances.append(everyval)
	return luminances

def normByDiffuseIrradiance(luminances, diffuse_illuminance,hemisphere):
	assert(len(luminances) == len(hemisphere))
	# Multiply all luminances by sin here to simplify loops
	for i in range(0,len(luminances)):
		elevation = hemisphere[i][0]
		luminances[i] *= math.sin(elevation) 

	illuminance = 0
	for i in range(0,len(luminances)):
		illuminance += luminances[i] #normal???

	normFactor = diffuse_illuminance/illuminance

	for i in range(0,len(luminances)):
		luminances[i] *= normFactor # * math.sin(elevation) ???? Sin in both places or neither

	return luminances

def toCsv(python_list):
    csv = []
    for item in python_list:
        csv.append(','.join(map(str,item)))

    return '\n'.join(csv)



###########################################################################
#					DISTRIBUTION OF DIFFUSE LIGHT		  	 		  	  #
###########################################################################
"""
Luminosity calculation as described by the paper:
'CIE GENERAL SKY STANDARD DEFINING LUMINANCE DISTRIBUTIONS'
by Darula and Kittler (2002)

Calculates the luminosity for the sky at elevation <theta> [deg] and azimuth <phi> [deg]
over the luminosity at zenith
I.e. output is lum(theta,phi)/lum(90,phi)
"""

def luminosity(sun_altitude,sun_azimuth,theta,phi,diffuse_part):
	# Angular distance between sun and hemisphere point
	angular_dist = math.acos( math.sin(sun_altitude)*math.sin(theta) + math.cos(sun_altitude)*math.cos(theta)*math.cos(sun_azimuth - phi) )

	# Set sky parameters, describing if overcast, clear etc. 
	# For standard skies, there is a table showing parameter values in [Darula and Kittler (2002)]
	# sys.stderr.write("%f\n" % diffuse_part)
	if(diffuse_part < 0.25): #Clear sky (type 12)
		# sys.stderr.write("12\n")
		a = -1
		b = -0.32
		c = 10
		d = -3
		e = 0.45
	elif(diffuse_part < 0.5): # Intermediate sky (type 11)
		# sys.stderr.write("11\n")
		a = -1.0
		b = -0.55
		c = 10
		d = -3.0
		e = 0.45
	elif(diffuse_part < 0.75): # Intermediate sky (type 7)
		# sys.stderr.write("7\n")
		a = 0.0
		b = -1.0
		c = 5
		d = -2.5
		e = 0.3
	else: #Cloudy sky (type 1)
		# sys.stderr.write("1\n")
		a = 4
		b = -0.70
		c = 2
		d = -1.5
		e = 0.15

	luminosity = scatteringIndicatrix(angular_dist,c,d,e)*luminosityGradiation(math.pi/2-theta,a,b)

	return luminosity

# NOTE: input is in radians
def luminosityGradiation(Z,a,b):
	return 1 + a*math.exp(b/math.cos(Z))

# NOTE: input is in radians
def scatteringIndicatrix(xsi,c,d,e):
	return 1 + c*(math.exp(d*xsi) - math.exp(d*math.pi/2)) + e*math.pow(math.cos(xsi),2)

def getRelativeLuminances(discretised_sphere, sun_altitude,sun_azimuth,diffuse_part):

	luminances = []
	for angle_pair in discretised_sphere:
		luminances.append(luminosity(sun_altitude,sun_azimuth,angle_pair[0],angle_pair[1],diffuse_part))

	return luminances


###########################################################################
#							TERMINAL INTERFACE				  	 		  #
###########################################################################

def generate_csv(args):
	if(args.single_time):
		return toCsv(getSkyAtDate(args.date_start+args.single_time, args.latitude, args.longitude,args.repeats,os.path.abspath(args.weather_file), os.path.abspath(args.bom_folder), args.utc_offset,args.verbose,args.output_cartesian,args.radius,args.no_snap))
	else:
		return toCsv(getTimespanSky(args.date_start, args.date_end, args.latitude,args.longitude, os.path.abspath(args.weather_file), os.path.abspath(args.bom_folder), args.utc_offset,args.repeats, args.step_days, args.step_hours, args.verbose, args.output_cartesian, args.radius))

def output_format( args ):
	if(args.output_cartesian):
		return 'd,d,d,d'
	else:
		return 'd,d,d'

def output_fields( args ):
	if(args.output_cartesian):
		return 'x,y,z,irradiance'
	else:
		return 'elevation,azimuth,irradiance'

def parse_args():
    description="""
Generates composite sky over given timespan. Sky is a discretised hemisphere, holding the global irradiance in each datum if single time, the energy in kJ if over a time span
"""

    epilog="""
Required input fields are:
    date_start, date_end, latitude, longitude, weather_file,repeats

    Outputs composite sky in a .csv list containing the irradiance for each hemisphere datum and
    corresponding elevation and azimuth in radians  

examples:
    # Returns the composite sky for 20160404-20160501, with default=30 minute timesteps
    {script_name} 20160404 20160501 -25.2 152.1 weather.txt 10

    # Returns the sky on 2016-04-04 at 10:30 in cartesian coordinates
    {script_name} 20160404 20160501 -25.2 152.1 weather.txt 10 --single-time=1030 --output-cartesian
""".format( script_name=sys.argv[0].split('/')[-1] )

    fmt=lambda prog: argparse.RawDescriptionHelpFormatter( prog, max_help_position=50 )

    parser = argparse.ArgumentParser( description=description,
                                      epilog=epilog,
                                      formatter_class=fmt )


    parser.add_argument('date_start', metavar='date_start', type=str,
                    help='start date of timespan, YYYYMMDD')

    parser.add_argument('date_end', metavar='date_end', type=str,
                    help='end date of timespan, YYYYMMDD')

    parser.add_argument('latitude', metavar='latitude', type=float,
                    help='latitude on earth')

    parser.add_argument('longitude', metavar='longitude', type=float,
                    help='longitude on earth')

    parser.add_argument('weather_file', metavar='weather_file', type=str,
                	help='path to ASCII file containing data from farm weather station')

    parser.add_argument('--bom_folder', metavar='bom_folder', default='./bom', type=str,
                    help='path to cached BOM weather data')

    parser.add_argument('repeats', metavar='repeats', type=int,
                help='repeats in sphere generation')

    parser.add_argument( "--utc-offset", metavar="<float>",type=float, default=10,
                     help='''UTC timezone offset (for the datetimes in the input), defualt=10''' )

    parser.add_argument( "--step-days", metavar="<int>", type=int, default=1,
                 help='''Step in days between dates, default=1''' )

    parser.add_argument( "--step-hours", metavar="<float>", type=float, default=0.5,
             help='''Step in hours within a day, has to be multiple of 0.5, default=0.5''' )

    parser.add_argument( "--single-time", metavar="<string>", type=str, default=None,
             help='''Outputs the sky on <date_start> at the specified time (HHMM)''' )

    parser.add_argument ("--output-cartesian", action="store_true",
                     help="outputs the sky coordinates as cartesians (radius = 1), instead of spherical angles")
    
    parser.add_argument ("--no-snap", action="store_true",
                     help="adds a new sun node at exactly the right position rather than snapping to the nearest node")

    parser.add_argument ("--radius", metavar="<float>",type=float, default=1,
                     help="sets the radius if --output-cartesian is set, default=1")

    parser.add_argument ("--output-fields", action="store_true",
                         help="list of the output fields for a given input")

    parser.add_argument ("--output-format", action="store_true",
                         help="list of the output types for a given input")

    parser.add_argument ("-v","--verbose", action="store_true",
                         help="output additional information during run")

    args = parser.parse_args()

    return args

def main():
    # Reset SIGPIPE and SIGINT to their default OS behaviour.
    # This stops python dumping a stack-trace on ctrl-c or broken pipe.
    signal.signal( signal.SIGPIPE, signal.SIG_DFL )
    s = signal.signal( signal.SIGINT, signal.SIG_DFL )
    # but don't reset SIGINT if it's been assigned to something other
    # than the Python default
    if s != signal.default_int_handler:
        signal.signal( signal.SIGINT, s )

    args = parse_args()

    if args.output_fields:
        print output_fields( args )
        sys.exit( 0 )

    if args.output_format:
        print output_format( args )
        sys.exit( 0 )

    print generate_csv(args)

if __name__ == '__main__':
    main()


