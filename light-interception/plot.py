#!/usr/bin/python
import matplotlib.pyplot as plt
import signal
import argparse
import sys
import csv
import numpy as np
from scipy.optimize import curve_fit
from decimal import Decimal


def plot(x,y,**kwargs):
    label = kwargs.get('label', '-')
    xlabel = kwargs.get('xlabel', '')
    ylabel = kwargs.get('ylabel', '')
    title = kwargs.get('title', '')
    style = kwargs.get('style', '')
    colour = kwargs.get('colour', '')
    colours = kwargs.get('colours', '')
    fit_line = kwargs.get('fit_line', False)
    fit_curve = kwargs.get('fit_curve', False)
    bounds = kwargs.get('bounds', False)
    font_size = kwargs.get('font_size', 12)


    plt.rcParams.update({'font.size': font_size})

    x,y = order(x,y)

    if(fit_line):
        clamp_intercept = kwargs.get('clamp_intercept', False)
        slope,intercept,rsq=fitLineTo(np.array(x),np.array(y),clamp_intercept)
        #plt.plot([min(x),max(x)],[min(x)*slope+intercept,max(x)*slope+intercept],label="y=%.3gx+%.3g, R^2=%.2f" %(slope,intercept,rsq),linewidth=2.0)

    if(fit_curve):
        if(bounds):
            low_bounds,high_bounds=bounds.split(';')

            low = map(float,low_bounds.split(','))
            high = map(float,high_bounds.split(','))
            y_bar,a,b,c,rsq,res = fitCurveTo(np.array(x),np.array(y),bounds=(low,high))
        else:
            y_bar,a,b,c,rsq,res = fitCurveTo(np.array(x),np.array(y))#bounds=(low,high))

        #plt.plot(x,y_bar,label='y=%.3gx^(%.3g)+%.3g, r^2=%.2f' % (a,b,c,rsq),linewidth=2.0)

    if colours:
        print colours
        print len(colours),len(x)
        for i in range(len(x)):
            plt.plot(x[i],y[i],style+colours[i])
    else:
        plt.plot(x,y,style+colour,label=label)

    x_min,x_max=plt.xlim()

    if(fit_line):
        plt.plot([x_min,x_max],[x_min*slope+intercept,x_max*slope+intercept],'b',label="y=%.3gx+%.3g, R^2=%.2f" %(slope,intercept,rsq),linewidth=2.0)

    if(fit_curve):
        x_curve=np.linspace(x_min,x_max,num=100)

        y_curve=[]
        for x_ in x_curve:
            y_curve.append(curve(x_,a,b,c))

        plt.plot(x_curve,y_curve,'b',label='y=%.3gx^(%.3g)+%.3g, r^2=%.2f' % (a,b,0,rsq),linewidth=2.0)

    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    plt.title(title)
    plt.legend(bbox_to_anchor=(0, 1), loc='upper left')
    plt.show()
    plt.clf()

    #plt.plot(res,x,'p')
    #plt.show()

def order(X,Y):

    y_out = [x for y, x in sorted(zip(X, Y))]
    X.sort()

    return X,y_out



def fitLineTo(x,y,clamp_intercept=False):
    """
    <input> x:                  np array, holding x-axis points
    <input> y:                  np array, holding y-axis points
    <input> clamp_intercept:    if True, interception is clamped at 0

    <return>:   (slope, intercept, R^2) of least squares fit line to x,y
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

def curve(x,a,b,c):
    return a*x**b+c
res=[]
yhat=[]
def fitCurveTo(x,y,**kwargs):
    parameter_bounds = kwargs.get('bounds', '')

    if parameter_bounds:
        popt, pcov = curve_fit(curve,x,y,bounds=parameter_bounds,method='trf')
    else:
        popt, pcov = curve_fit(curve,x,y,method='lm',maxfev=9999)
    global yhat
    yhat=[]
    for val in x:
        yhat.append(curve(val,popt[0],popt[1],popt[2]))

    yhat=np.array(yhat)

    ybar = np.sum(y)/len(y)
    ssres = np.sum((yhat - y)**2)
    sstot = np.sum((y - ybar)**2)
    r_squared = 1- ssres/sstot

    global res
    res = (yhat - y)

    return yhat,popt[0],popt[1],popt[2],r_squared,res



def parse_args():
    description="""
Plotter
"""

    epilog="""


examples:

python plot.py 0 0 --csv=file.csv --csv-fields=x,y --fit-curve --style=p --font-size=22 --ylabel="Energy [kJ]" --xlabel="Time [s]" --title="My graph" --colour=g --curve-bounds="0,0,0;10,2,100"


""".format( script_name=sys.argv[0].split('/')[-1] )

    fmt=lambda prog: argparse.RawDescriptionHelpFormatter( prog, max_help_position=50 )

    parser = argparse.ArgumentParser( description=description,
                                      epilog=epilog,
                                      formatter_class=fmt )


    parser.add_argument('x', metavar='x', type=str, nargs=1,
                help='x, given as list of number in quotes, separated with white space e.g. "1 2 3 4"')

    parser.add_argument('y', metavar='y', type=str, nargs=1,
            	help='y, given as list of number in quotes, separated with white space e.g. "1 2 3 4"')

    parser.add_argument ("--xlabel", type=str, default='',
                 help="x-axis label")

    parser.add_argument ("--ylabel", type=str, default='',
                 help="y-axis label")

    parser.add_argument ("--label", type=str, default='',
                 help="data label")

    parser.add_argument ("--title", type=str, default='',
                 help="plot title")

    parser.add_argument ("--style", type=str, default='',
                 help="plot style, e.g. '*' plots asterisks")

    parser.add_argument ("--colour", type=str, default='',
                 help="plot colour")

    parser.add_argument ("--font-size", type=int, default=12,
                 help="description font size, default=12")

    parser.add_argument ("--fit-line", action="store_true",
                 help="fits line to data, minimizing the squared error.")

    parser.add_argument ("--fit-curve", action="store_true",
                 help="fits curve y=a*x^b+c to data, minimizing the squared error.")

    parser.add_argument ("--curve-bounds", metavar='<low_bounds;high_bounds>',type=str, default='',
                 help="Constraints for a,b,c in fitted curvet. E.g. '0,0,0;10,2,100' ")

    parser.add_argument ("--clamp-intercept", action="store_true",
                 help="clamps the intercept at 0 for fitted line")

    parser.add_argument ("--csv", type=str, default='',
                 help="Ignore x,y input and read from csv with format x,y\\nx,y...")

    parser.add_argument ("--csv-fields", type=str, default='',
                 help="If the first line of the csv file contain fields names, the two field names to be plotted can be given here, eg. field_x,field_y")


    args = parser.parse_args()

    return args


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

def fieldsFromCsv(csv_file,csv_fields):
    x=[]
    y=[]
    colours=[]

    csv_matrix=matrixFromCsv(csv_file)
    if csv_fields:
        x_field,y_field = csv_fields.split(',')

        fields=csv_matrix[0]
        x_index=fields.index(x_field)
        y_index=fields.index(y_field)
        #colours_index=fields.index(colour)
        start=1

    else:
        x_index=0
        y_index=1
        start=0

    for i in range(start,len(csv_matrix)):
        x.append(float(csv_matrix[i][x_index]))
        y.append(float(csv_matrix[i][y_index]))

    return x,y

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

    if(args.csv):
    	x=[]
    	y=[]
        colours=[]

        csv_matrix=matrixFromCsv(args.csv)
        if args.csv_fields:
            x_field,y_field = args.csv_fields.split(',')

            fields=csv_matrix[0]
            x_index=fields.index(x_field)
            y_index=fields.index(y_field)
            #colours_index=fields.index(colour)
            start=1

            

            #or i in range(start,len(matrixFromCsv(args.csv))):
            #    colours.append(csv_matrix[i][colours_index])

            if(not(args.xlabel) or not(args.ylabel)):
                args.xlabel=x_field
                args.ylabel=y_field
        else:
            x_index=0
            y_index=1
            start=0

    	for i in range(start,len(matrixFromCsv(args.csv))):
            x.append(float(csv_matrix[i][x_index]))
            y.append(float(csv_matrix[i][y_index]))
    else:
    	x = map(float,args.x[0].split(' '))
    	y = map(float,args.y[0].split(' '))


    plot(x,y,font_size=args.font_size,bounds=args.curve_bounds,fit_curve=args.fit_curve,colours=colours,label=args.label,xlabel=args.xlabel,ylabel=args.ylabel,colour=args.colour,style=args.style,title=args.title,fit_line=args.fit_line,clamp_intercept=args.clamp_intercept)

if __name__ == '__main__':
    main()

def planeFit(x1,x2,y):
    x1=np.array(x1)
    x2=np.array(x2)
    y=np.array(y)
    A = np.vstack([x1,x2,np.ones(len(x1))]).T

    lsq = np.linalg.lstsq(A,y)

    a,b,c = lsq[0]
    residuals = lsq[1]

    yhat=[]
    for i in range(len(x1)):
        yhat.append(a*x1[i]+b*x2[i]+c)

    yhat = np.array(yhat)
    ybar = np.sum(y)/len(y)

    ssres = np.sum((yhat - y)**2)
    sstot = np.sum((y - ybar)**2)

    r_squared = 1- ssres/sstot
    
    return a,b,c,residuals,r_squared

"""
main()

vol,yiel = fieldsFromCsv('interception_statistics_beta0.65.csv','volume,yield/size')
a,b,c,residuals,rsq = planeFit(vol,res,yiel)
print "r^2 a*vol+b*res+c = yield/size : %f" %(rsq)
vol,yiel = order(vol,yiel)
a,b,rsq=fitLineTo(yhat,yiel)
print rsq

vol,yiel = fieldsFromCsv('interception_statistics_beta0.65.csv','volume,yield/weight')
a,b,c,residuals,rsq = planeFit(vol,res,yiel)
print "r^2 a*vol+b*res+c = yield/weight : %f" %(rsq)
vol,yiel = order(vol,yiel)
a,b,rsq=fitLineTo(yhat,yiel)
print rsq

vol,yiel = fieldsFromCsv('interception_statistics_beta0.65.csv','volume,yield/count')
vol,yiel = order(vol,yiel)
a,b,c,residuals,rsq = planeFit(vol,res,yiel)
print "r^2 a*vol+b*res+c = yield/count : %f" %(rsq)

vol,yiel = order(vol,yiel)
a,b,rsq=fitLineTo(yhat,yiel)
print rsq
"""

