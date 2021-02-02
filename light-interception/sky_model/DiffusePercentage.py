import math
import datetime
import numpy as np
import sys

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



class DiffusePercentage(object):
	"""
	Computes the diffuse light percentage of global light, following the model from the paper:

	Modelling of diffuse solar fraction with multiple predictors (2010)
	by
	Ridley, Barbara
	Boland, John
	Lauret, Philippe
	"""

	def __init__(self,BOMparser,global_irradiance_class,verbose=True):
		self.BOMparser = BOMparser
		self.globalIrradiance = global_irradiance_class
		self.clearness_storage = {} #storage for clearness indexes, so won't have to compute them multiple times
		self.daily_clearness_storage = {} #storage for daily clearness indexes, so won't have to compute them multiple times
		self.verbose=verbose

	#################################################################################
	#									PUBLIC										#
	#################################################################################


	def diffusePart(self,date_time,sun_elevation,lat = -25.143641572052292, lon = 152.37746729565248, utc_offset = 10):
		if(self.__clearnessIndex(date_time,sun_elevation,lat,lon,utc_offset) < 0.001):
			return 1.0
		gamma = self.__gamma(date_time,lat,lon,utc_offset)

		return 1/(1 + math.exp(-5.38 + 6.63*self.__clearnessIndex(date_time,sun_elevation,lat,lon,utc_offset) + 0.006*self.__AST(date_time) \
			-0.007*(sun_elevation) + 1.75*self.__dailyClearnessIndex(date_time,lat,lon,utc_offset) +1.31*gamma))

	def directVal(self,date_time,sun_elevation,lat = -25.143641572052292, lon = 152.37746729565248, utc_offset = 10):
		if(self.__clearnessIndex(date_time,sun_elevation,lat,lon,utc_offset) < 0.001):
			return 1.0
		gamma = self.__gamma(date_time,lat,lon,utc_offset)

		return (0.006*4.38)/(0.006 + (4.38-0.006)*math.exp(-7.75*self.__clearnessIndex(date_time,sun_elevation,lat,lon,utc_offset) - 1.185*self.__AST(date_time) \
			-1.05*(90-sun_elevation) + 0.004*self.__dailyClearnessIndex(date_time,lat,lon,utc_offset) +0.003*gamma))


	#################################################################################
	#									PRIVATE										#
	#################################################################################


	def __equationOfTime(self,day_of_year):
		"""
		:param: day_of_year 	day of the year [1:365], 1st Jan -> day_of_year = 1
		:return: 				(solar time - mean solar time) in minutes

		Notes:
		--------
		As defined in:
		http://www.sws.bom.gov.au/Category/Educational/The%20Sun%20and%20Solar%20Activity/General%20Info/EquationOfTime.pdf
		Valid with <1% error years 1900-2100
		"""

		B = 360*(day_of_year-81)/365

		return 9.87*math.sin(math.radians(2*B))-7.67*math.sin(math.radians(B+78.7))

	def __gamma(self,time,lat, lon, utc_offset,hour_res=0.5):
		
		time_past = time - datetime.timedelta(hours=hour_res)
		sun_elevation_past, sun_azimuth = geosunposition.lat_long_to_elaz(lat,lon, time_past - datetime.timedelta(hours=utc_offset))

		time_future = time + datetime.timedelta(hours=hour_res)
		sun_elevation_future, sun_azimuth = geosunposition.lat_long_to_elaz(lat,lon, time_future - datetime.timedelta(hours=utc_offset))

		k_past = self.__clearnessIndex(time_past,sun_elevation_past,lat,lon,utc_offset)
		k_future = self.__clearnessIndex(time_future,sun_elevation_future,lat,lon,utc_offset)

		if(k_past == 0):
			return k_future
		elif(k_future == 0):
			return k_past
		else:
			return (k_past+k_future)/2

	def __clearnessIndex(self,date_time,sun_elevation,lat,lon,utc_offset):
		if(str(date_time) in self.clearness_storage):
			return self.clearness_storage[str(date_time)]

		if(sun_elevation < 0):
			self.clearness_storage[str(date_time)] = 0.0
			return 0.0

		I_global = self.globalIrradiance.get(date_time,lat,lon,utc_offset,self.verbose)

		I_extraterrestrial = self.__extraterrestrialIrradiance(date_time)*math.sin(math.radians(sun_elevation))

		if(I_extraterrestrial < I_global):
			if self.verbose:
				sys.stderr.write("Warning: global irradiance measurement higher than modelled extraterrestrial irradiance by %.2f W/m^2 at %s \n" % (I_global- I_extraterrestrial, date_time))
			self.clearness_storage[str(date_time)] = 1.0
			return 1.0

		self.clearness_storage[str(date_time)] = I_global/I_extraterrestrial
		return I_global/I_extraterrestrial


	def __extraterrestrialIrradiance(self,date):
		# http://agsys.cra-cin.it/tools/solarradiation/help/Earth-sun_distance.html
		day = date.timetuple().tm_yday
		return 1370*(1+0.033412*math.cos(math.pi*2*(day-3)/365))

	def __dailyClearnessIndex(self,date,lat = -25.143641572052292, lon = 152.37746729565248, utc_offset = 10,res_hours=0.5):
		date = date.replace(hour=0, minute=0)

		if(str(date) in self.daily_clearness_storage):
			return self.daily_clearness_storage[str(date)]

		global_sum = 0
		extraterrestrial_sum = 0

		for h in np.arange(0,24,res_hours):
			time = date + datetime.timedelta(hours=h)
			global_irr = self.globalIrradiance.get(time,lat,lon,utc_offset,self.verbose)
			sun_elevation, sun_azimuth = geosunposition.lat_long_to_elaz(lat,lon, time - datetime.timedelta(hours=utc_offset))
			
			if(not(global_irr == 0) and sun_elevation > 0):
				global_sum += global_irr
				extraterrestrial_sum += self.__extraterrestrialIrradiance(date)*math.sin(math.radians(sun_elevation))

		self.daily_clearness_storage[str(date)] = global_sum/extraterrestrial_sum

		return global_sum/extraterrestrial_sum

	def __apparentSolarTime(self,date_time):
		return date_time + datetime.timedelta(minutes=self.__equationOfTime(date_time.timetuple().tm_yday))

	def __AST(self,date_time):
		solar_time = self.__apparentSolarTime(date_time)

		return (solar_time.time().hour + solar_time.time().minute/float(60))






