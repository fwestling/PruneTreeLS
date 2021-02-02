import sys
import csv
from scipy import stats
import matplotlib.pyplot as plt
import numpy as np
import matplotlib.cm as cm
import math
import operator

"""
Takes a file containing the coordinates of an offset ceptometer grid and the model's estimation of the
radiation in the grid and compares that to a given file with actual ceptometer readings. Produces a heatmap
to visualize which offset is producing the closest match (closest match determined by linear regression r^2 value)

Format of input .csv files:
	offset cepto. grid: 	offset_x,offset_y,radiation,ceptometerID
	real cepto measurem.:	radiation,ceptometerID
"""

def matrixFromCsv(file_csv):
	row_list = []
	col_list = []
	with open(file_csv, 'rt') as csvfile:
		read = csv.reader(csvfile)
		for row in read:
			for col in row:
				col_list.append(col)
			row_list.append(col_list)
			col_list=[]

	return row_list


def parseToDict(csv_list):
	organised_offsets={}

	for entry in csv_list:
		x=float(entry[2])
		y=float(entry[3])
		par=float(entry[0])
		cept_id=int(entry[1])

		if (x,y) in organised_offsets:
			organised_offsets[x,y].append([par,cept_id])
		else:
			organised_offsets[x,y]=[[par,cept_id]]

	return organised_offsets

def parseToDictNeg(csv_list):
	organised_offsets={}

	for entry in csv_list:
		x=-float(entry[2])
		y=-float(entry[3])
		par=float(entry[0])
		cept_id=int(entry[1])

		if (x,y) in organised_offsets:
			organised_offsets[x,y].append([par,cept_id])
		else:
			organised_offsets[x,y]=[[par,cept_id]]

	return organised_offsets

def rsquaredDict(organised_offsets,cepto_measurements):
	r_squared_dict = {}
	line_dict={}
	# Compute and store r^2
	for key in organised_offsets:
		linreg_x=[]
		linreg_y=[]
		for offset in organised_offsets[key]:
			cept_id_off=offset[1]

			for i in range(len(cepto_measurements)):
				if(int(cepto_measurements[i][1]) == cept_id_off):
					linreg_x.append(float(cepto_measurements[i][0]))
					linreg_y.append(offset[0])


		slope, intercept, r_value, p_value, std_err = stats.linregress(linreg_x, linreg_y)

		r_squared = r_value**2


		r_squared_dict[key]=r_squared
		line_dict[key] = (slope,intercept)



	max_key = max(r_squared_dict.iteritems(),key=operator.itemgetter(1))[0]
	slope = line_dict[max_key][0]
	intercept = line_dict[max_key][1]

	#print "%f\t%f\t%f\t%f\t%f" % (max_key[0],max_key[1],line_dict[max_key][0],line_dict[max_key][1],r_squared_dict[max_key])
	return r_squared_dict


def rsquaredDict2(organised_offsets_list,cepto_measurements_list):
	r_squared_dict = {}
	line_dict={}
	# Compute and store r^2
	key_temp = organised_offsets_list[0].copy()
	key_temp.update(organised_offsets_list[1])
	for key in key_temp:
		if(key[0] > 0.5 or key[0]<-0.5 or key[1] > 0.5 or key[1]<-0.5):
			continue
		linreg_x=[]
		linreg_y=[]
		for i in range(len(organised_offsets_list)):
			organised_offsets = organised_offsets_list[i]
			cepto_measurements = cepto_measurements_list[i]

			if key in organised_offsets:
				for offset in organised_offsets[key]:
					cept_id_off=offset[1]

					for i in range(len(cepto_measurements)):
						if(int(cepto_measurements[i][1]) == cept_id_off):
							linreg_x.append(float(cepto_measurements[i][0]))
							linreg_y.append(offset[0])


		slope, intercept, r_value, p_value, std_err = stats.linregress(linreg_x, linreg_y)

		r_squared = r_value**2


		r_squared_dict[key]=r_squared
		line_dict[key] = (slope,intercept)

	max_key = max(r_squared_dict.iteritems(),key=operator.itemgetter(1))[0]
	slope = line_dict[max_key][0]
	intercept = line_dict[max_key][1]

	rs_sq_copy=r_squared_dict.copy()
	
	while(slope > 1.3 or slope < 0.7 or abs(intercept) > 300 or abs(max_key[0]) > 0.3 or abs(max_key[1]) > 0.3):
		del rs_sq_copy[max_key]
		max_key = max(rs_sq_copy.iteritems(),key=operator.itemgetter(1))[0]
		slope = line_dict[max_key][0]
		intercept = line_dict[max_key][1]


	#print "Max r^2 value at:(x,y)=(%f,%f) \n r^2=%f \n (slope,intercept)=(%f,%f)" % (max_key[0],max_key[1],r_squared_dict[max_key],line_dict[max_key][0],line_dict[max_key][1])
	print "%f\t%f\t%f\t%f\t%f" % (max_key[0],max_key[1],line_dict[max_key][0],line_dict[max_key][1],r_squared_dict[max_key])


	return r_squared_dict

def createHeatMap(r_squared_dict,name="",c_lower=None,c_upper=None):
	x=[]
	y=[]
	r_sq_ordered=[]

	key_lst=r_squared_dict.keys()
	min_dim_x=min(key_lst,key=operator.itemgetter(0))[0]*100 ##ASSUMED TO BE NEGATIVE
	min_dim_y=min(key_lst,key=operator.itemgetter(1))[1]*100 ##ASSUMED TO BE NEGATIVE
	dim_x = max(key_lst,key=operator.itemgetter(0))[0]*100 - min_dim_x + 1
	dim_y = max(key_lst,key=operator.itemgetter(1))[1]*100 - min_dim_y + 1

	r_sq = np.zeros((dim_y,dim_x))

	for offset in r_squared_dict:
		r_sq_ordered.append(r_squared_dict[offset])
		x.append(offset[0])
		y.append(offset[1])
		r_sq[int(round(offset[1]*100-min_dim_y)),int(round(offset[0]*100-min_dim_x))]=r_squared_dict[offset]

	max_key = max(r_squared_dict.iteritems(),key=operator.itemgetter(1))[0]
	plt.imshow(r_sq, extent=(np.array(x).min(), np.array(x).max(), np.array(y).min(), np.array(y).max()),
	       cmap=cm.get_cmap('afmhot'),origin='lower')
	plt.clim(c_lower,c_upper)
	plt.colorbar()
	plt.xlabel("Offset x [m]")
	plt.ylabel("Offset y [m]")
	plt.title(name)
	plt.plot(max_key[0],max_key[1],'kx',label='Maximum r^2:'+str(r_squared_dict[max_key]) +' at ' + str(max_key))
	#plt.legend()
	#plt.savefig('heatmap' + name +'_05.png')
	plt.show()
	plt.clf()
	



def createCompoundHeatmap(offsets,cepto_measurements,direction,times):
	r_squared_dict={}
	for i in range(len(offsets)):
		offset_list=matrixFromCsv(offsets[i])
		cepto_measurements_list=matrixFromCsv(cepto_measurements[i])

		if(direction[i] == 'west'):
			organised_offsets = parseToDictNeg(offset_list)
		else:
			organised_offsets = parseToDict(offset_list)

		r_squared_dict_new=rsquaredDict(organised_offsets,cepto_measurements_list)
		#createHeatMap(r_squared_dict_new,times[i]+direction[i])

		for key in r_squared_dict_new:
			if abs(key[0]) <= 0.5 and abs(key[1]) <= 0.5:
				if not(key in r_squared_dict):
					r_squared_dict[key]=[]

				r_squared_dict[key].append(r_squared_dict_new[key])

	for key in r_squared_dict:
		r_squared_dict[key] = np.mean(r_squared_dict[key])

	createHeatMap(r_squared_dict,'R-squared alignment heatmap')

base_offsets="../ceptometer_verif_zeb/alignment"
base_cepto="../ceptometer"
date_times=['201602200900' ,'201602201030' ,'201602171200' ,'201602171330','201602171500']
offset_files=[]
cepto_files=[]
directions=[]
times=[]
for date_time in date_times:
	for direction in ['east','west']:
		time=date_time[8:12]
		if(time == '0900' and direction =='east'):
			continue
		elif(time == '1500' and direction =='west'):
			continue
		offset_file = base_offsets + "/cepto_grid_align1m_"+direction+"_cepto_"+ date_time +"_transm0.8_vsize0.1.csv"
		if(time=='1030'):
			cepto_file = base_cepto +"/ceptometer_"+time+"_nozero_nooutlier.n.csv"
		else:
			cepto_file = base_cepto +"/ceptometer_"+time+"_nozero.n.csv"
		offset_files.append(offset_file)
		cepto_files.append(cepto_file)
		directions.append(direction)
		times.append(time)

createCompoundHeatmap(offset_files,cepto_files,directions,times)
"""
if(len(sys.argv) == 5):
	offset_list1=matrixFromCsv(sys.argv[1])
	offset_list2=matrixFromCsv(sys.argv[2])
	cepto_measurements1=matrixFromCsv(sys.argv[3])
	cepto_measurements2=matrixFromCsv(sys.argv[4])

	#Reorganize...
	organised_offsets1 = parseToDict(offset_list1)
	organised_offsets2 = parseToDictNeg(offset_list2)
	
	r_squared_dict=rsquaredDict2([organised_offsets1,organised_offsets2],[cepto_measurements1,cepto_measurements2])
	#r_squared_dict=rsquaredDict(organised_offsets1,cepto_measurements1)
	#r_squared_dict2=rsquaredDict(organised_offsets2,cepto_measurements2)

	#for key in r_squared_dict:
	#	r_squared_dict[key] += r_squared_dict2[key]

else:
	offset_list=matrixFromCsv(sys.argv[1])
	cepto_measurements=matrixFromCsv(sys.argv[2])


	#Reorganize...
	organised_offsets = parseToDict(offset_list)
			
	r_squared_dict,line_dict=rsquaredDict(organised_offsets,cepto_measurements)

createHeatMap(r_squared_dict) #,float(sys.argv[3]),float(sys.argv[4]))
"""
