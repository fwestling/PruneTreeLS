import csv
import operator
import os

def parseWeatherFile(file_path):
	"""
	Parses ASCII weather file collected from a 'Davis. Vantage pro 2' weather station

	Returns a dictionairy, where data can be accesses as dict['date']['time']['field'],
	where date has format YYYYDDMM and time is 24h time as HH:MM and field is the field 
	wanted __without__ whitespaces (fields are the headlines of the columns in the ASCII file)

	Notes:
	---------
	This function merely parses the file and arranges its data in an easily accessible dictionairy
	All entries in the dictionairy are stored as strings and it is up to the user to check whether 
	there is actually any data for the given field, time and date (no data is usually represented 
	by the string '---')

	Example:
	---------

	parseWeatherFile('Weather details.txt')['20150321']['22:00']['SolarRad.']

	returns the solar radiation (string) at 10 pm on the 21st of March 2015, 
	given that Weather details.txt holds data for that time and date

	"""
	lines = []
	with open(file_path) as tsv:
	    for line in csv.reader(tsv, dialect="excel-tab"):
	    	lines.append(line)

	fields = map(operator.add,lines[0],lines[1])
	for i in range(0,len(fields)):
		fields[i] = fields[i].replace(" ", "") #Remove spaces, for consistency
	
	out_dict = {}
	time_dict = {}
	previous_date = lines[2][0]
	for row in range(2,len(lines)):
		date = toYYMMDD(lines[row][0])
		time = to24hTime(lines[row][1])

		field_dict ={}
		for col in range(2,len(lines[row])):
			field = fields[col]
			field_dict.update({field:lines[row][col]})

		if(date == previous_date):
			time_dict.update({time: field_dict})
		else:
			out_dict.update({previous_date: time_dict})
			time_dict = {time: field_dict}
			previous_date = date

	out_dict.update({previous_date: time_dict})

	return out_dict

def to24hTime(time):
	# Add zero at beginning
	if(len(time) < 7):
		time = '0'+time

	hour = time[0:2]

	if(time[-1] == 'a'): #am
		if( hour == '12'):
			return '00'+time[2:5]
		else:
			return time[0:len(time)-2]
	else:
		if(hour == '12'):
			return time[0:len(time)-2]
		else:
			return str(int(hour)+12) + time[2:5]

def toYYMMDD(date):
	day = date[0:2]
	month = date[3:5]
	year = '20'+date[6:8]

	return year + month + day