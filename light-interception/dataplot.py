#!/usr/bin/python
import sys
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import axes3d
from scipy.stats import linregress
from copy import deepcopy
from linear_model import BayesianLinearModel
from sklearn.preprocessing import PolynomialFeatures
from scipy.optimize import curve_fit

import argparse #Can use getopts alternatively

#Fred# Alex' code for showing upper/lower bounds on model uncertainty
'''
f = lambda x, m, b: m*x + b
	#F# Optimal fit to data, returns parameters and covariance
    p, cov = curve_fit(f, xs, ys, [1., 1.])
    xi = np.linspace(np.min(xs), np.max(xs), 100)
    #F# Generate 10000 options for model, based on covariance.  Should be normally distributed.
    ps = np.random.multivariate_normal(p, cov, 10000)
    ysample = np.asarray([f(xi, *pi) for pi in ps])
    #F# Calculate lower and upper bound on model certainty (i.e. +- 2 std deviations)
    lower = np.mean(ysample, axis=0) - 2*np.std(ysample, ddof=1, axis=0)
    upper = np.mean(ysample, axis=0) + 2*np.std(ysample, ddof=1, axis=0)
    mu = f(xi, p[0], p[1])
    
    print("y_gt=x, pred=y (r2 / rmse): %.2f / %.2f" % (r2(y_gt=xs, y_pred=ys), rmse(y_gt=xs, y_pred=ys)))
    print("y_gt=y, pred=x (r2 / rmse): %.2f / %.2f" % (r2(y_gt=ys, y_pred=xs), rmse(y_gt=ys, y_pred=xs)))
    
    plt.scatter(xs, ys, s=1, c='k')
    plt.plot(xi, lower, 'r--', linewidth=0.5, zorder=0)
    plt.plot(xi, mu, 'r', linewidth=1., label="Bayesian linear best fit", zorder=0)
    plt.plot(xi, upper, 'r--', linewidth=0.5, zorder=0)
'''


def r_squared(y,y_est):
	y_mean = np.mean(y)
	#ss_regression = np.sum((y_est - y_mean)**2)
	ss_total = np.sum((y - y_mean)**2)
	ss_residual = np.sum((y - y_est)**2)
	
	return 1 - (ss_residual/ss_total) # see https://en.wikipedia.org/wiki/Coefficient_of_determination
	# return ss_regression/ss_total # see https://onlinecourses.science.psu.edu/stat501/node/255
	
def rmse(y,y_est):
	return np.sqrt( np.mean((y_est - y)**2) )

def rmse_bias_corrected(y,y_est):
	bias = np.mean(y_est) - np.mean(y)
	return np.sqrt( np.mean((y_est - y - bias)**2) )

class regressor:
	def __init__(self, x, y, intercept=False):
		def convert(i):
			if np.isscalar(i):
				return np.array([[i]])
			elif len(i.shape) == 1:
				return deepcopy(i)[np.newaxis].T
			else:
				return deepcopy(i)

		self.x = convert(x)
		self.y = convert(y)
		self.intercept = intercept

		polybasis = lambda x, p: PolynomialFeatures(p).fit_transform(x)
		if intercept:
			self.blm = BayesianLinearModel(basis=lambda x : polybasis(x,1))
		else:
			self.blm = BayesianLinearModel(basis=lambda x : x)

		self.blm.update(self.x,self.y)
		return
	
	def plot(self, ax):
		if self.intercept:
			slope = self.blm.location[1,0]
			intercept = self.blm.location[0,0]
		else:
			slope = self.blm.location[0,0]
			intercept = 0.0

		#todo: slope_sd = ?
		slope_sd=0.0
		#todo: intercept_sd = ?
		intercept_sd=0.0
			
		y_est = self.blm.predict(self.x)
		r2 = r_squared(self.y[:,0], y_est[:,0])
			  
		rmsebc = rmse_bias_corrected(self.x[:,0], (self.y[:,0]-intercept)/slope)
		#rmsebc = rmse_bias_corrected(self.y[:,0], y_est[:,0])
			   
		# plot data
		ax.plot(self.x[:,0], self.y[:,0], 'b.')
			
		# plot mean and +-2sd line
		x_pred = np.linspace( min(self.x[:,0]), max(self.x[:,0]), 100 )[:,np.newaxis]
		y_pred = self.blm.predict(x_pred,variance=True)
		y_mean = y_pred[0]
		y_95 = y_pred[1]
		print y_95
	
		for param in self.blm.random(10):
			if self.intercept:
				y_model_eg=x_pred[:,0]*param[1]+param[0]
			else:
				y_model_eg=x_pred[:,0]*param[0]
			#y_model_eg=np.polyval(param[::-1],x_pred)
			ax.plot(x_pred[:,0],y_model_eg,'c')
		ax.plot(x_pred[:,0],y_model_eg,'c',label='model examples')
		
		ax.plot(x_pred[:,0], y_mean, 'r',label='mean')
		ax.plot(x_pred[:,0], y_mean + y_95, 'g',label='obs 95%')
		ax.plot(x_pred[:,0], y_mean - y_95, 'g')
		ax.legend(loc='lower right')
		
		# annotate
		if self.intercept:
			text = 'y = ({:.5f}$\pm{:.5f}$)x + ({:.5f}$\pm${:.5f})\n$r^2$ = {:.5f}\nRMSEbc = {:.5f}'.format(slope, slope_sd, intercept, intercept_sd, r2, rmsebc)
		else:
			text = 'y = ({:.5f}$\pm{:.5f}$)x;\n$r^2$ = {:.5f}\nRMSEbc = {:.5f}'.format(slope, slope_sd, r2, rmsebc)

		ax.annotate(text, xy=(0.1, 0.9), xycoords='axes fraction', fontsize=13)  
		return

if __name__ == "__main__":

	# MARKERS = [None] * 100
	# MARKERS[8] = 'o'
	# MARKERS[45] = 'v'
	# MARKERS[55] = 's'
	MARKERS = {8:'\'o\'', 45:'\'v\'',100:'\'v\'', 55:'\'s\'',60:'\'s\''}
	EDGES = {8:'black',100:'red',55:'blue',60:'green',20160728:'red', 20160509:'orange', 20160905:'green', 20161215:'blue', 20170516:'grey'}

	parser = argparse.ArgumentParser()
	parser.add_argument('-x', "--xIndices", type=str,
		help='indices of X values, given as list of numbers, separated with commas e.g. "1,2,3,4"')
	parser.add_argument('-y', "--yIndices", type=str,
		help='indices of Y values, given as list of numbers, separated with commas e.g. "1,2,3,4"')
	parser.add_argument('-c', "--colours", type=str, nargs='?',
		help='indices of colourscale values, given as list of numbers, separated with commas e.g. "1,2,3,4"')
	parser.add_argument("-s", "--sizes", type=str, nargs='?',
		help='indices of point sizes, given as list of numbers, separated with commas e.g. "1,2,3,4"')
	parser.add_argument("-m", "--markers", type=str, nargs='?',
		help='indices of point markers, given as list of numbers, separated with commas e.g. "1,2,3,4"')
	parser.add_argument("-e", "--edgecolours", type=str, nargs='?',
		help='indices of edge colours, given as list of numbers, separated with commas e.g. "1,2,3,4"')
	parser.add_argument('-t', "--title", nargs='?', type=str,
		help='Graph titles, given as list of strings, separated with commas e.g. "Average","Variance"')
	parser.add_argument("--xlabel", nargs='?', type=str,
		help='X axis labels, given as list of strings, separated with commas e.g. "time(s)","x (m)"')
	parser.add_argument("--ylabel", nargs='?', type=str,
		help='Y axis labels, given as list of strings, separated with commas e.g. "time(s)","x (m)"')
	parser.add_argument("--xlims", type=str,
		help='X axis limits, given as list of strings, separated with commas e.g. 0,2000')
	parser.add_argument("--ylims", type=str,
		help='Y axis limits, given as list of strings, separated with commas e.g. 0,2000')
	parser.add_argument("--plot", nargs=1, default='scatter', type=str,
		help='plot type, e.g. plot, scatter')
	parser.add_argument("--noshow", action="store_true",
		help="Do not open a plot, but still report r^2")
	parser.add_argument("--blr", action="store_true",
		help="Use James' Bayesian Linear Regression")
	parser.add_argument("--basic", action="store_true",
		help="Plot best-fit and x=y lines")
	parser.add_argument("--heatmap", action="store_true",
		help="Do not open a plot, but still report r^2")
	parser.add_argument("--savefile", nargs='?', default='',
		help="Save plot to the given filename")
	args = parser.parse_args()

	DATA = np.genfromtxt(sys.stdin.readlines(), delimiter=',')

	xIdx = map(int,args.xIndices.split(','))
	yIdx = map(int,args.yIndices.split(','))
	if args.colours: cIdx = map(int,args.colours.split(','))
	if args.sizes: sIdx = map(int,args.sizes.split(','))
	if args.markers: mIdx = map(int,args.markers.split(','))
	if args.edgecolours: ecIdx = map(int,args.edgecolours.split(','))
	if args.title: titles = args.title.split(',')
	if args.xlabel: xlabels = args.xlabel.split(',')
	if args.ylabel: ylabels = args.ylabel.split(',')
	if args.xlims: xlims = args.xlims.split(',')
	if args.ylims: ylims = args.ylims.split(',')

	if (len(xIdx) != len(yIdx)):
		print "Number of indices for X (%d) and Y (%d) must be the same" % (len(xIdx), len(yIdx))
		sys.exit(2)

	if args.blr:
		x = DATA[:,xIdx[0]]
		y = DATA[:,yIdx[0]]
		f, ax = plt.subplots(1, 2, figsize=(12, 8))
		r0 = regressor(x, y, intercept=False)
		r0.plot(ax[0])
		ax[0].set_title('y=mx')
		print "y=mx:"
		print "location (mu):\n{}".format(r0.blm.location)
		print "dispersion (S):\n{}".format(r0.blm.dispersion)
		print "shape (alpha):\n{}".format(r0.blm.shape)
		print "scale (beta):\n{}".format(r0.blm.scale)

		xs = x
		ys = y
		f = lambda x, m, b: m*x + b
		#F# Optimal fit to data, returns parameters and covariance
		p, cov = curve_fit(f, xs, ys, [1., 1.])
		xi = np.linspace(np.min(xs), np.max(xs), 100)
		#F# Generate 10000 options for model, based on covariance.  Should be normally distributed.
		ps = np.random.multivariate_normal(p, cov, 10000)
		ysample = np.asarray([f(xi, *pi) for pi in ps])
		#F# Calculate lower and upper bound on model certainty (i.e. +- 2 std deviations)
		lower = np.mean(ysample, axis=0) - 2*np.std(ysample, ddof=1, axis=0)
		upper = np.mean(ysample, axis=0) + 2*np.std(ysample, ddof=1, axis=0)
		mu = f(xi, p[0], p[1])

		# print("y_gt=x, pred=y (r2 / rmse): %.2f / %.2f" % (r2(y_gt=xs, y_pred=ys), rmse(y_gt=xs, y_pred=ys)))
		# print("y_gt=y, pred=x (r2 / rmse): %.2f / %.2f" % (r2(y_gt=ys, y_pred=xs), rmse(y_gt=ys, y_pred=xs)))

		# plt.scatter(xs, ys, s=1, c='k')
		plt.plot(xi, lower, 'r--', linewidth=0.5, zorder=0)
		# plt.plot(xi, mu, 'r', linewidth=1., label="Bayesian linear best fit", zorder=0)
		plt.plot(xi, upper, 'r--', linewidth=0.5, zorder=0)

		#print "marg likelihood: {}".format(r0.log_marginal_likelihood())
		print
		r1 = regressor(x, y, intercept=True)
		r1.plot(ax[1])
		ax[1].set_title('y=mx+b')
		print "y=mx+b"
		print "location:\n{}".format(r1.blm.location)
		print "dispersion:\n{}".format(r1.blm.dispersion)
		print "shape:\n{}".format(r1.blm.shape)
		print "scale:\n{}".format(r1.blm.scale)
		#print "marg likelihood: {}".format(r1.log_marginal_likelihood())
		print 
		plt.show()
	else:

		fig = plt.figure(figsize=(12,8),dpi=100)

		for i in range(len(xIdx)):
			x = DATA[:,xIdx[i]]
			y = DATA[:,yIdx[i]]
			if args.colours: c = DATA[:,cIdx[i]]
			if args.markers: 
				mm=map(int,DATA[:,mIdx[i]])
				markers = np.vectorize(MARKERS.get)(mm)
			if args.edgecolours: 
				ee = map(int,DATA[:,ecIdx[i]])
				ec = np.vectorize(EDGES.get)(ee)
			if args.sizes: sizes = DATA[:,sIdx[i]]
			slope, intercept, r_value, p_value, slope_std_error = linregress(x, y)
			predict_y = intercept + slope * x
			y_prime = (y - intercept) / slope
			ax = fig.add_subplot(1,len(xIdx),(i+1))
			plotArgs = "x,y"
			if args.plot[0] == 's':
				func = "ax."+args.plot
			else:
				func = "ax."+args.plot[0]
			if args.colours: 
				plotArgs = plotArgs+",c=c,cmap='coolwarm'"

			if args.edgecolours:
				plotArgs = plotArgs+",edgecolors=ec"

			if args.sizes:
				plotArgs = plotArgs+",s=sizes"

			if args.plot[0] == 'hexbin':
				plotArgs = plotArgs+",gridsize=80,bins=10"
			if args.plot[0] == 'hist2d':
				plotArgs = plotArgs+",bins=80"

			if args.markers:
				for key,um in MARKERS.iteritems():
					mask = um == markers
					# mask is now an array of booleans that can be used for indexing  
					newArgs=(plotArgs.replace(',','[mask],')+'[mask]').replace(';',',')
					cax = eval(func+"("+newArgs.replace('coolwarm\'[mask]','coolwarm\'')+",marker="+um+", label=key)")
			else:
				cax = eval(func+"("+plotArgs.replace(';',',')+")")

			# Calculate R^2 for y=x
			#http://stackoverflow.com/questions/20115272/calculate-coefficient-of-determination-r2-and-root-mean-square-error-rmse-fo
			mse = np.mean((predict_y-y)**2) # rmse to bestfit line
			mse_2 = np.mean((y-x)**2) # rmse to y=x
			mse_prime = np.mean((y_prime-x)**2)

			ss_res = np.dot((y-x),(y-x))
			ymean=np.mean(y)
			ss_tot=np.dot((y-ymean),(y-ymean))
			rB = 1-ss_res/ss_tot

			if (args.basic): ax.plot(x,predict_y,'r-',label='BestFit, R^2=%f'%(r_value**2))
			if (args.basic): ax.plot(x,x,'g-')
			# if (args.basic): ax.plot(x,x,'g-',label='y=x, R^2=%f' % (rB))
			# if (args.basic): ax.legend(loc=4)
			if (args.title): plt.title(titles[i])
			if(args.xlabel): plt.xlabel(xlabels[i])
			if(args.ylabel): plt.ylabel(ylabels[i])
			if args.xlims: plt.xlim(eval(args.xlims));
			if args.ylims: plt.ylim(eval(args.ylims))


			#+++++++++based on Alex' code+++++++++#
			### Calculate and plot model uncertainty
			xs = x
			ys = y
			f = lambda x, m, b: m*x + b
			#F# Optimal fit to data, returns parameters and covariance
			p, cov = curve_fit(f, xs, ys, [1., 1.])
			xi = np.linspace(np.min(xs), np.max(xs), 100)
			#F# Generate 10000 options for model, based on covariance.  Should be normally distributed.
			ps = np.random.multivariate_normal(p, cov, 10000)
			ysample = np.asarray([f(xi, *pi) for pi in ps])
			#F# Calculate lower and upper bound on model certainty (i.e. +- 2 std deviations)
			lower = np.mean(ysample, axis=0) - 2*np.std(ysample, ddof=1, axis=0)
			upper = np.mean(ysample, axis=0) + 2*np.std(ysample, ddof=1, axis=0)
			mu = f(xi, p[0], p[1])

			# print("y_gt=x, pred=y (r2 / rmse): %.2f / %.2f" % (r2(y_gt=xs, y_pred=ys), rmse(y_gt=xs, y_pred=ys)))
			# print("y_gt=y, pred=x (r2 / rmse): %.2f / %.2f" % (r2(y_gt=ys, y_pred=xs), rmse(y_gt=ys, y_pred=xs)))

			# plt.scatter(xs, ys, s=1, c='k')
			plt.plot(xi, lower, 'r--', linewidth=0.5, zorder=0)
			# plt.plot(xi, mu, 'r', linewidth=1., label="Bayesian linear best fit", zorder=0)
			plt.plot(xi, upper, 'r--', linewidth=0.5, zorder=0)

			#-------------------------------------#


			# if args.colours: cbar = fig.colorbar(cax,ticks=[900,1200,1500])
			# if args.colours: cbar = fig.colorbar(cax)

			# print ('%f\t%f' % (rB, r_value**2))
			# print ('%d\t%d\t%d' % (slope, rB, r_value**2))
			print ('%f \t %f \t %f \t %f \t %f \t %f' % (slope, np.sqrt(mse), r_value**2, intercept, np.sqrt(mse_2),np.sqrt(mse_prime)))
		if args.savefile: plt.savefig(args.savefile)
		if not args.noshow: plt.show()