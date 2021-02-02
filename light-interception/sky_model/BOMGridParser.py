import sys, os
import matplotlib.pyplot as plt
import numpy as np
import matplotlib.cm as cm
import netCDF4
import math
import urllib
import datetime
import argparse
import signal
import subprocess
import requests

"""
#####################################################################################

BOMGridParser contains methods to retrieve and parse BOM radiation data.

Example:
--------------
date = datetime.datetime.strptime('20160401')
energy = BOMGridParser().solarRadFromBOM(date,-25,150)

<energy> now contains the total global solar radiation energy in MJ on a 1 m^2 horisontal 
surface on the 1st of April 2016 at latitude = -25 deg, longitude = 150 deg

#####################################################################################
"""

class BOMGridParser(object):
	def __init__(self,data_folder):
		if not os.path.exists(data_folder):
			os.makedirs(data_folder)

		self.BOM_files = {}
		self.data_folder=data_folder
		self.longitude_range=112.0,154.0
		self.latitude_range=-44.0,-10.0

	#################################################################################
	#									PUBLIC										#
	#################################################################################

	def solarRadFromBOM(self,date,lat,lon):
		"""
		:param date:		date in datetime.datetime format
    	:param lat: 		latitude in degrees
    	:param lon: 		longitude in degrees

    	:return: 	total global solar radiation energy in MJ on a 1 m^2 horisontal 
					surface 
		"""
		if(lat > max(self.latitude_range) or lat < min(self.latitude_range)):
			raise Exception("Latitude %s is out of range. Latitudes has to be in the range %.2f:%.2f" % (lat,self.latitude_range[0],self.latitude_range[1]))

		if(lon > max(self.longitude_range) or lon < min(self.longitude_range)):
			raise Exception("Longitude %s is out of range. Longitude has to be in the range %.2f:%.2f" % (lon,self.longitude_range[0],self.longitude_range[1]))

		solar_rad = self.__solarRadiationAtLatLong(lat,lon,date)

		return solar_rad



	def plotNCData(self,date):
		"""
		:param: nc_path:		file path to .nc file downloaded from BOM
		:param: date:	date to plot YYYYMMDD
		

		Notes:
		---------
		Plots the data of a day in <nc_file> 
		x axis = longitude
		y axis = latitude
		colour = solar rad
		"""
		day_of_month = date.day
		date = date.strftime('%Y%m%d')
		longitudes, latitudes, solar_radiance = self.__NCread(self.__getDataFromBOM(date))
		radiation = []


		for j in range(0,len(latitudes)):
			for i in range(0,len(longitudes)):
				if(solar_radiance[j][i] == "--"):
					radiation.append(float('nan'))
				else:
					radiation.append(solar_radiance[j][i])

		grid=np.array(radiation).reshape((len(latitudes),len(longitudes)))
		plt.imshow(grid, extent=(np.array(longitudes).min(), np.array(longitudes).max(), np.array(latitudes).min(), np.array(latitudes).max()),
	           interpolation='nearest', cmap=cm.jet)
		plt.colorbar()
		plt.xlabel("Longitude")
		plt.ylabel("Latitude")
		plt.title("Daily solar radiation [MJ] on: %s" % (date))
		plt.show()


	#################################################################################
	#									PRIVATE										#
	#################################################################################
	def __NCread(self,nc_file):
		"""
		Reads BOM data from .grid file. Stores parsed data in internal dictionairy if .grid has not been parsed previously.

		return: list[longitudes], list[latitudes],list[solar_radiance]
		"""


		if( not(nc_file in self.BOM_files) ):
			with open(nc_file,'r') as reader:
				solar_radiance = []
				nd="99999.90"
				for line in reader:
					data = line.split(" ")
					if data[0] == "":
						# This is a line of grid coordinates
						solar_radiance.append([float(x) if x != nd else '--' for x in data[1:-1]])
					elif data[0] == "ncols":
						ncols=int(data[1])
					elif data[0] == "nrows":
						nrows=int(data[1])
					elif data[0] == "xllcenter":
						xllcenter=float(data[1])
					elif data[0] == "yllcenter":
						yllcenter=float(data[1])
					elif data[0] == "cellsize":
						cellsize=float(data[1])
					elif data[0] == "nodata_value":
						nd=data[1].replace('\n','')

			longitudes = [(xllcenter + float(x)*cellsize) for x in range(ncols)]
			latitudes = [(yllcenter + float(x)*cellsize) for x in range(nrows)]

			self.BOM_files[nc_file] = {'longitudes' : 0}
			self.BOM_files[nc_file]['longitudes'] = longitudes
			self.BOM_files[nc_file]['latitudes'] = latitudes
			self.BOM_files[nc_file]['solar_radiance'] = solar_radiance

		return self.BOM_files[nc_file]['longitudes'],self.BOM_files[nc_file]['latitudes'],self.BOM_files[nc_file]['solar_radiance']

	def __solarRadiationAtLatLongFromNC(self,nc_file,lat,lon,day_of_month):
		"""
		return: solar rad. for given latitude, longitude and day of month
		"""

		longitudes, latitudes, solar_radiance = self.__NCread(nc_file)

		index_lat,index_lon = self.__lat_lon_index(latitudes,longitudes,lat,lon)

		return solar_radiance[index_lat][index_lon]

	def __solarRadiationAtLatLong(self,lat,lon,date):
		day = date.day
		date = date.strftime('%Y%m%d')

		data_path = self.__getDataFromBOM(date)
		solar_rad = self.__solarRadiationAtLatLongFromNC(data_path,lat,lon,day)

		#if(str(solar_rad) == "--"): # Quick and dirty hack: if data not available, try reloading
			#data_path = self.__reloadFromBOM(date)
			#solar_rad = self.__solarRadiationAtLatLongFromNC(data_path,lat,lon,day)

		if(str(solar_rad) == "--"):
			sys.stderr.write("Warning: no BOM solar radiation data found for %s at latitude: %.2f, longitude: %.2f" %(date,lat,lon))

		return solar_rad


	def __lat_lon_index(self,latitudes,longitudes,lat,lon):
		cell_size_lat = abs(latitudes[1]-latitudes[0])
		cell_size_lon = abs(longitudes[1]-longitudes[0])

		index_lat = int(np.round((max(latitudes)-lat)/cell_size_lat))
		index_lon = int(np.round((lon-min(longitudes))/cell_size_lon))

		return index_lat,index_lon


	
	def __getMaxIrradiance(self,day_energy, day_start, day_end):
		"""
		Gets the maximum irradiance [W/m^2], by assuming the irradiance over the day follows a sine
		(the area of the sine with peak value of max irradiance is the day energy). Formula can easily
		be derived using simple calculus (integration).

		Day start and day end are assumed to be given in hours
		"""

		return day_energy * math.pi / (2*3600*(day_end-day_start))*10**6

	
	def __computeTimespan(self,date):
		date=datetime.datetime.strptime(date,'%Y%m%d')

		first_day = date.replace(day=1)
		last_day = (first_day + datetime.timedelta(days=32)).replace(day=1) - datetime.timedelta(days=1)

		return first_day.strftime('%Y%m%d') + '-' + last_day.strftime('%Y%m%d')

	def __reloadFromBOM(self,date):
		"""
		Removes and reloads .nc file. Necessary since the file contains data for full month. 
		Hence, if recent data is downloaded only a portion of the month is covered in the file.
		Accessing data at a later date it might be necessary to delete the cached file and download the full file.
		"""
		fname=date+date+'.grid'

		if(self.data_folder == ""):
			path = fname
		else:
			path = self.data_folder + '/' + fname

		if(os.path.isfile(path)):
			os.remove(path)
			if path in self.BOM_files:
				del(self.BOM_files[path])
		
		return self.__getDataFromBOM(date)

	def __getDataFromBOM(self,date):
		"""
		Retrieves data from BOM's http server if not locally available

		:param: date:	string in format YYDDMM
		"""

		fname=date+date+'.grid'
		url = 'http://www.bom.gov.au/web03/ncc/www/awap/solar/solarave/daily/grid/0.05/history/nat/'+fname+'.Z'
		#print "Retrieving BOM data from " + url


		if(self.data_folder == ""):
			path = fname
		else:
			path = self.data_folder + '/' + fname

		sys.stderr.write("TEST\n")

		if(os.path.isfile(path)):
			return path

		sys.stderr.write("TEST2\n")
		if(self.data_folder == ""):
			subprocess.call(["wget", url])
		else:
			subprocess.call(["wget", "-P", self.data_folder, url])
		sys.stderr.write(path)

		subprocess.call(["uncompress", path+'.Z'])

		subprocess.call(["cp", path, "path"+".tmp"])

		return path



###########################################################################
#							TERMINAL INTERFACE				  	 		  #
###########################################################################

def generate_csv( args ):
	BOM = BOMGridParser(args.data_folder)
	date_time = datetime.datetime.strptime(args.date[0],'%Y%m%d')
	if(args.plot):
		BOM.plotNCData(date_time)

	return BOM.solarRadFromBOM(date_time,args.latitude[0],args.longitude[0])




def output_format( args ):
    return 'd'

def output_fields( args ):   
    return 'solar_energy'

def parse_args():
    description="""
Returns BOM's (Australian Bureau of Meteorology) daily solar radiation measurement (MJ/m^2) for given latitude, longitude and day.

More information: http://www.bom.gov.au/climate/austmaps/about-solar-maps.shtml
Data accessed at: http://rs-data1-mel.csiro.au/thredds/catalog/bawap/catalog.html
"""

    epilog="""
Required input fields are:

    date,latitude,longitude

examples:
    # Returns the daily solar radiation in MJ/m^2 at 4:th of April 2016, for given location in latitude and longitude.
    {script_name} 20160404 -25.2 152.1

    # Same as above, but before value is returned a graph showing the daily radiance for all of Australia the 4:th of April 2016 is shown. 
    # Note that the graph window needs to be closed for the function to proceed and return the solar radiation value.
    {script_name} 20160404 -25.2 152.1 --plot

""".format( script_name=sys.argv[0].split('/')[-1] )

    fmt=lambda prog: argparse.RawDescriptionHelpFormatter( prog, max_help_position=50 )

    parser = argparse.ArgumentParser( description=description,
                                      epilog=epilog,
                                      formatter_class=fmt )


    parser.add_argument('date', metavar='date', type=str, nargs=1,
                    help='date to retrieve measurement from, YYYYMMDD')

    parser.add_argument('latitude', metavar='latitude', type=float, nargs=1,
                    help='latitude in Australia')

    parser.add_argument('longitude', metavar='longitude', type=float, nargs=1,
                    help='longitude in Australia')

    parser.add_argument ("--data-folder", type=str, default='./bom',
                         help="path to where downloaded BOM data is to be stored, default: ./bom")

    parser.add_argument ("--output-fields", action="store_true",
                         help="list of the output fields for a given input")

    parser.add_argument ("--output-format", action="store_true",
                         help="list of the output types for a given input")

    parser.add_argument ("--plot", action="store_true",
                         help="plots the entire solar radiation map of Australia for the given day")

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