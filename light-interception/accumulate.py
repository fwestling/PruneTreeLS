#!/usr/bin/python
import sys
import comma
import numpy as np
import argparse
import itertools


description = """
hello
"""

notes_and_examples = """
hi
"""

def prepare_options(args):
    if args.binary:
        args.first_line = ''
        args.format = comma.csv.format.expand(args.binary)
        args.binary = True
    else:
        args.first_line = comma.io.readlines_unbuffered(1, sys.stdin)
        args.format = comma.csv.format.guess_format(args.first_line)
        args.binary = False
        print >> sys.stderr, __name__ + ": guessed format", args.format

class stream(object):
	def __init__(self, args):
		self.args = args
		self.csv_options = dict(full_xpath=False,
								binary=self.args.binary,
								flush=self.args.flush,
								delimiter=self.args.delimiter,
								precision=self.args.precision)
		self.initialize_input()

	def initialize_input(self):
		self.nonblank_input_fields = filter(None, self.args.fields)
		if not self.nonblank_input_fields:
			raise StandardError("specify input stream fields, e.g. --fields=x,y")
		self.block = False
		if "block" in self.args.fields:
			self.block = True
		types = comma.csv.format.to_numpy(self.args.format)
		self.input_t = comma.csv.struct(self.args.fields, *types)
		self.input = comma.csv.stream(self.input_t, **self.csv_options)
		self.output_t = comma.csv.struct('acc', 'float64')
		self.output = comma.csv.stream( self.output_t, tied=self.input, **self.csv_options) 

def process(stream):
	accumulated = 1
	prev_block = False
	for events in stream.input.iter(size=1):
		output = np.empty( events.size, dtype=stream.output_t )
		if stream.block:
			if (events['block'] != prev_block):
				accumulated = 1
			prev_block = events['block']
		output['acc'] = accumulated
		accumulated = accumulated * events['tc']
		stream.output.write( output )

def main():
	try:
		comma.csv.time.zone('UTC')
		parser = argparse.ArgumentParser(description=description,epilog=notes_and_examples)
		comma.csv.add_options( parser )
		args = parser.parse_args()
		prepare_options(args)
		process(stream(args))
	except StandardError as e:
		import traceback
		traceback.print_exc(file=sys.stderr)
		sys.exit(1)

if __name__ == '__main__':
	main()

# point_t = comma.csv.struct( 'x,y,z', 'float64', 'float64', 'float64' )
# event_t = comma.csv.struct( 't,coordinates', 'datetime64[us]', point_t)

# fields = ',coordinates/y,coordinates/z,,,t,coordinates/x,,'
# format = ','.join( comma.csv.format.to_numpy( 'i,d,d,s[3],s[7],t,d,ui,ui' ) )
# input_stream = comma.csv.stream( event_t, fields=fields, format=format )

# output_t = comma.csv.struct( 'min,max', 'float64', 'float64' )
# output_stream = comma.csv.stream( output_t, binary=True, tied=input_stream )

# for events in input_stream.iter():
# 	output = np.empty( events.size, dtype=output_t )
# 	output['min'] = np.min (events['coordinates'].view( '3float64' ), axis=1 )
# 	output['max'] = np.max (events['coordinates'].view( '3float64' ), axis=1 )
# 	output_stream.write( output )