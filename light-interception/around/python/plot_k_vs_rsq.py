import sys
import csv
from scipy import stats
import matplotlib.pyplot as plt
import numpy as np

"""
Plots leaf transmission coefficient (k) vs. the R^2 from the model estimation of ceptometer measurements
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




def toDict(kvsr_list):
	"""
	Input: 		list of estimated PAR values for a certain ceptometer, transmission coeff, and time 
				[[PAR,cepto_id,datetime,k]....[]]

	Output:		dict[time][k] = [[PAR,cepto_id]]
	"""
	organised_dict={}
	for row in kvsr_list:
		par=float(row[0])
		cepto_id=int(row[1])
		date_time=row[2]
		transm_coeff=float(row[3])
		time=date_time[9:13]

		if(time in organised_dict):
			if(transm_coeff in organised_dict[time]):
				organised_dict[time][transm_coeff].append([par,cepto_id])
			else:
				organised_dict[time][transm_coeff] = [[par,cepto_id]]
		else:
			organised_dict[time] = {}
			organised_dict[time][transm_coeff] = [[par,cepto_id]]

	return organised_dict

def merge_times_rsq(organised_dict):
	"""
	Input: 		dict[time][k] = R^2
	Output:		dict[k] = mean R^2 for all times
	"""
	coeff_dict={}
	for time in organised_dict:
		for transm_coeff in organised_dict[time]:
			if transm_coeff in coeff_dict:
				coeff_dict[transm_coeff].append(organised_dict[time][transm_coeff])
			else:
				coeff_dict[transm_coeff] = [organised_dict[time][transm_coeff]]

	for coeff in coeff_dict:
		coeff_dict[coeff] = np.mean(coeff_dict[coeff])

	return coeff_dict


def get_rsq_per_coeff(organised_dict):
	"""
	Computes the R^2 value for transmission coefficients

	Input:		dict[time][k] = [[PAR,cepto_id]]
	Output: 	dict[k] = R^2 
	"""
	r_squared_dict={}
	linreg_x={}
	linreg_y={}
	x_plot={}
	y_plot={}
	time_count={} #test
	for time in organised_dict:
		#if(time == '0900'):
		#	continue
		if(time == '1030'):
			cepto_path="../ceptometer/ceptometer_"+time+"_nozero_nooutlier.n.csv"
		else:
			cepto_path="../ceptometer/ceptometer_"+time+"_nozero.n.csv"

		cepto_measurements=matrixFromCsv(cepto_path)
		for transm_coeff in organised_dict[time]:
			if not(transm_coeff in linreg_x):
				linreg_x[transm_coeff]=[]
				linreg_y[transm_coeff]=[]
				x_plot[transm_coeff]={}
				y_plot[transm_coeff]={}
				time_count[transm_coeff]={}

			if not(time in x_plot[transm_coeff]):
				x_plot[transm_coeff][time]=[]
				y_plot[transm_coeff][time]=[]
				time_count[transm_coeff][time]=0


			for i in range(len(cepto_measurements)):
				for j in range(len(organised_dict[time][transm_coeff])):
					if(int(cepto_measurements[i][1]) == organised_dict[time][transm_coeff][j][1]):
						#if(float(cepto_measurements[i][0]) < 200):
							#if(time_count[transm_coeff][time] < 2): #test
							#	time_count[transm_coeff][time] += 1
							#else:
							#	continue

						linreg_x[transm_coeff].append(float(cepto_measurements[i][0]))
						linreg_y[transm_coeff].append(organised_dict[time][transm_coeff][j][0])
						x_plot[transm_coeff][time].append(float(cepto_measurements[i][0]))
						y_plot[transm_coeff][time].append(organised_dict[time][transm_coeff][j][0])

	#slope, intercept, r_value, p_value, std_err = stats.linregress(linreg_x, linreg_y)
	#r_squared = r_value**2
	
	for transm_coeff in linreg_x:
		slope,intercept,r_squared = fitLineTo(np.array(linreg_x[transm_coeff]),np.array(linreg_y[transm_coeff]),True)


		
		r_squared_dict[transm_coeff] = r_squared

		
		# Save a plot!
		if '0900' in x_plot[transm_coeff]:
			plt.plot(x_plot[transm_coeff]['0900'],y_plot[transm_coeff]['0900'],'kp',label='Time of day: 09:00')
		plt.plot(x_plot[transm_coeff]['1030'],y_plot[transm_coeff]['1030'],'rD',label='Time of day: 10:30')
		plt.plot(x_plot[transm_coeff]['1200'],y_plot[transm_coeff]['1200'],'go',label='Time of day: 12:00')
		plt.plot(x_plot[transm_coeff]['1330'],y_plot[transm_coeff]['1330'],'bs',label='Time of day: 13:30')
		plt.plot(x_plot[transm_coeff]['1500'],y_plot[transm_coeff]['1500'],'mv',label='Time of day: 15:00')
		plt.plot([0,max(linreg_x[transm_coeff])],[intercept,max(linreg_x[transm_coeff])*slope + intercept],label="y=%.2fx+%.2f, R^2=%.2f" %(slope,intercept,r_squared))
		plt.ylim([0,2100])
		plt.xlim([0,2100])
		plt.title("Date: %s, Transmission=%f, clamped intercept (0,0)" %("all",transm_coeff))
		plt.xlabel('Ceptometer measurements, PAR')
		plt.ylabel('Model estimation, PAR')
		lgd=plt.legend(bbox_to_anchor=(0.5, -.1), loc='upper center', borderaxespad=0.,fancybox=True,ncol=2,frameon=False)
		plt.tight_layout()

		plt.savefig("figs/%s_tr%f_clamped.png" %("all",transm_coeff),bbox_extra_artists=(lgd,), bbox_inches='tight')
		plt.clf()
		
		
		

	return r_squared_dict

def get_rsq(organised_dict):
	"""
	Computes the R^2 value for separate times and transmission coefficients

	Input:		dict[time][k] = [[PAR,cepto_id]]
	Output: 	dict[time][k] = R^2 
	"""
	r_squared_dict={}
	for time in organised_dict:
		r_squared_dict[time]={}
		if(time == '1030'):
			cepto_path="../ceptometer/ceptometer_"+time+"_nozero_nooutlier.n.csv"
		else:
			cepto_path="../ceptometer/ceptometer_"+time+"_nozero.n.csv"
		cepto_measurements=matrixFromCsv(cepto_path)
		for transm_coeff in organised_dict[time]:
			linreg_x=[]
			linreg_y=[]

			for i in range(len(cepto_measurements)):
				for j in range(len(organised_dict[time][transm_coeff])):
					if(int(cepto_measurements[i][1]) == organised_dict[time][transm_coeff][j][1]):
						linreg_x.append(float(cepto_measurements[i][0]))
						linreg_y.append(organised_dict[time][transm_coeff][j][0])

			#slope, intercept, r_value, p_value, std_err = stats.linregress(linreg_x, linreg_y)
			#r_squared = r_value**2
			
			slope,intercept,r_squared = fitLineTo(np.array(linreg_x),np.array(linreg_y),True)


			
			r_squared_dict[time][transm_coeff] = r_squared

			"""
			# Save a plot!
			plt.plot(linreg_x,linreg_y,'p')
			plt.plot([0,max(linreg_x)],[intercept,max(linreg_x)*slope + intercept],label="y=%fx+%f, r^2=%f" %(slope,intercept,r_squared))
			plt.ylim([0,2100])
			plt.xlim([0,2100])
			plt.title("Date: %s, Transmission=%f, clamped intercept (0,0)" %(time,transm_coeff))
			plt.xlabel('Ceptometer measurements')
			plt.ylabel('Model estimation')
			plt.legend()
			plt.savefig("figs/%s_tr%f_clamped.png" %(time,transm_coeff))
			plt.clf()
			"""
			
			
			
			
	r_squared_dict['all']=merge_times_rsq(r_squared_dict)
	return r_squared_dict

def fitLineTo(x,y,clamp_intercept=False):
	"""
	<input> x:					np array, holding x-axis points
	<input> y:					np array, holding y-axis points
	<input> clamp_intercept:	if True, interception is clamped at 0

	<return>:	(slope, intercept, R^2) of least squares fit line to x,y
	"""

	if(clamp_intercept):
		x_c= x [:,np.newaxis]
		line, residuals, _ , _= np.linalg.lstsq(x_c, y)
		line=[line[0],0]
	else:
		x_c = np.vstack([x, np.ones(len(x))]).T
		line, residuals, _ , _= np.linalg.lstsq(x_c, y)
	# r-square
	p = np.poly1d(line)

	yhat = p(x)
	ybar = np.sum(y)/len(y)
	ssres = np.sum((yhat - y)**2)
	sstot = np.sum((y - ybar)**2)
	r_squared = 1- ssres/sstot

	if clamp_intercept:
		return line[0],0,r_squared
	else:
		return line[0],line[1],r_squared

def plot(r_squared_dict):
	x=[]
	y=[]
	for time in [sys.argv[2]]:
		for transm_coeff in r_squared_dict[time]:
			x.append(transm_coeff)
			y.append(r_squared_dict[time][transm_coeff])

	plt.plot(x,y,'p')
	plt.show()

def plot_per_coeff(r_squared_dict):
	x=[]
	y=[]

	for transm_coeff in r_squared_dict:
		x.append(transm_coeff)
		y.append(r_squared_dict[transm_coeff])

	plt.plot(x,y,'p')
	plt.ylim([0,0.8])
	plt.xlim([0,1])
	plt.title("Transmission coeff. vs R^2, clamped (0,0)")
	plt.xlabel("Transmission coefficient")
	plt.ylabel("R-squared")
	plt.show()


kvsr_path=sys.argv[1]

plot_per_coeff(get_rsq_per_coeff(toDict(matrixFromCsv(kvsr_path))))