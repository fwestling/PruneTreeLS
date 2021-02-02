import sys
import numpy as np



def generateGrid(ID_start = 0,rows=12,columns=5,points_in_row = 8,res_x = 1,res_y = 0.8):
	"""
	Creates a grid to be used in ceptometer carification. Origin is at y=0 and x=<middle column>

	:param rows:			number of rows in the grid
	:param columns: 		number of columns in the grid
	:param points_inr_row:	number of points within each row
	:param ID_start:		number for unique row/col ID to start. Starts at this number at y=0 and x=min(x). 
							Counts up along x-dimension, per row.
	:param res_x:			step between columns
	:param res_y:			step between rows

	:return:				.csv-like format for bash (| tr -d '[]' | tr ';' '\n')

	"""
	points = []

	x_minmax = int(round(columns/2-0.5))

	
	for row in range(0,rows*points_in_row):
		for col in range(-x_minmax,x_minmax+1):
			x = col*res_x
			y = row*res_y/points_in_row
			ID = ID_start + int(row/points_in_row)*columns + col + x_minmax #Always pisitive int
			#points.append(['20101010T101010',x,y,0,0,0,0,0,0,ID])
			points.append([0,0,0,x,y,0,0,ID])
		

	"""
	# ADD UNDERLAYING 'BOARD' FOR SHADOW TO BE CAST ON
	for y in np.arange(0,rows+1,0.03):
		for x in np.arange(-x_minmax-2,x_minmax+2,0.03):
			#points.append(['20101010T101010',x,y,0.1,0,0,0,0,0,0])cd
			points.append([0,0,0,x,y,0,0,0])
	
	"""
	return ';'.join(map(str,points))

print (generateGrid(int(sys.argv[1]),int(sys.argv[2])))