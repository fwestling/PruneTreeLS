import math
import numpy
import sys
from external import geodesic
import argparse
import signal

"""
#####################################################################################

This file contains code to generate points placed pseudo uniformly on a sphere surface. 
It also contains a method to find the closest discretised point, given
an arbitrary set of angles. 
#####################################################################################
"""


"""
Generates pseudo uniformly spaced samples of a sphere's surface.
The algorithm used builds a geodesic sphere.
"""
def generateSamplesCartesian(N, radius=1,polyhedron='i',class_pattern=[1,0,1],equal_length=False,flat_faced=False):
    
    return geodesic.pythonInterface(N,radius,polyhedron,class_pattern,equal_length,flat_faced)

def generateSamplesCartesian_upper(N, radius=1,polyhedron='i',class_pattern=[1,0,1],equal_length=False,flat_faced=False):
    samples = generateSamplesCartesian(N,radius,polyhedron,class_pattern,equal_length,flat_faced)
    upper_samples=[]
    for sample in samples:
        if(sample[2] > 0):
            upper_samples.append(sample)
    return upper_samples


def toCsv(python_list):
    csv = []
    for item in python_list:
        csv.append(','.join(map(str,item)))

    return '\n'.join(csv)

"""
Same as above, but returns angles (theta elevation, phi azimuth) instead of cartesian
"""
def generateSamplesSpherical(N, polyhedron='i',class_pattern=[1,0,1],equal_length=False,flat_faced=False):
    return cartesianToSpherical(generateSamplesCartesian(N,1,polyhedron,class_pattern,equal_length,flat_faced),1)


def generateSamplesSpherical_upper(N, polyhedron='i',class_pattern=[1,0,1],equal_length=False,flat_faced=False):
    return cartesianToSpherical(generateSamplesCartesian_upper(N,1,polyhedron,class_pattern,equal_length,flat_faced),1)

    samples = cartesianToSpherical(generateSamplesCartesian(N,1,polyhedron,class_pattern,equal_length,flat_faced),1)
    upper_samples=[]
    for sample in samples:
        if(sample[0] > 0):
            upper_samples.append(sample)
    return upper_samples



def closestPointOnDescretisedSphere(sphere_angles,point):
    assert(len(point) == 2)

    min_distance = sys.float_info.max
    for angle_pair in sphere_angles:
        distance = angularDistanceSphere(angle_pair,point)
        if(distance < min_distance):
            min_distance = distance
            closest_point = angle_pair

    return closest_point

def closestIndexOnDescretisedSphere(sphere_angles,point):
    assert(len(point) == 2)

    min_distance = sys.float_info.max
    for index in range(0,len(sphere_angles)):
        distance = angularDistanceSphere(sphere_angles[index],point)
        if(distance < min_distance):
            min_distance = distance
            closest_index = index

    error_deg = angularDistanceSphere(sphere_angles[closest_index],point)

    return closest_index,error_deg

def angularDistanceSphere(angles1,angles2):
    assert(len(angles1) == 2 and len(angles2) == 2)
    epsilon = 0.0000000001

    theta1 = angles1[0]  
    phi1 = angles1[1]
    theta2 = angles2[0]
    phi2 = angles2[1]

    val = math.sin(theta1)*math.sin(theta2) + math.cos(theta1)*math.cos(theta2)*math.cos(phi1 - phi2)
    
    # Quick way to deal with float rounding errors
    if (val > 1.0 and val < 1.0 + epsilon):
        val = 1

    return math.degrees(math.acos(val))


def cartesianToSpherical(cartesian_points,radius=1):
    spherical_angles = []
    for point in cartesian_points:
        theta = math.pi/2 - math.acos(point[2]/radius)
        if(point[0] == 0):
            phi=math.pi/2*numpy.sign(point[1])
        else:
            phi = math.atan2(point[1],point[0])

        # Make sure angles are always positive (boost whines otherwise...)
        if(phi < 0):
            phi += 2*math.pi

        spherical_angles.append([theta,phi])

    return spherical_angles


def get_size(num_div,start_form):
    if start_form=='i':
        factor=10
    elif start_form=='o':
        factor=4
    elif start_form=='t':
        factor=2
    else:
        return

    return factor*num_div*num_div+2

def generate_csv(args):
    N = args.repeats[0]
    radius=float(args.radius)
    polyhedron=args.poly_start
    flat_faced=args.flat_faced

    if(args.output_spherical):
        return toCsv(generateSamplesAngles(N,polyhedron,[1,0,1],False,flat_faced))
    else:
        return toCsv(generateSamplesCartesian(N, radius,polyhedron,[1,0,1],False,flat_faced))



# ------------------------------------------------------------
# Field handling


def output_format( args ):
    if(args.output_spherical):
        return 'd,d'
    else:
        return 'd,d,d'

def output_fields( args ):   
    if(args.output_spherical):
        return 'elevation,azimuth'
    else:
        return 'x,y,z'

def parse_args():
    description="""
Generates a geodesic sphere and returns the indices
"""

    epilog="""
Required input field is:

    repeats

    Generates a geodesic sphere by divising the surfaces of a polyhedron into repeats^2 triangular tiles.
    Outputs csv list containing coordinates of the vertices.

examples:
    # Output vertices of unit sphere in cartesian (x,y,z) coordinates:
    {script_name} 10

    # Output vertices in spherical (elevation and azimuth in radians) coordinates:
    {script_name} 10 --output-spherical

    # Output the number of vertices in the geodesic sphere without generating it:
    {script_name} 10 --output-size
""".format( script_name=sys.argv[0].split('/')[-1] )

    fmt=lambda prog: argparse.RawDescriptionHelpFormatter( prog, max_help_position=50 )

    parser = argparse.ArgumentParser( description=description,
                                      epilog=epilog,
                                      formatter_class=fmt )

    parser.add_argument( "--output-spherical", action="store_true",
                         help='''output is spherical angles ([elevation, azimuth] in radians) instead of cartesian''' )

    parser.add_argument( "--radius", metavar="<float>", default=1,
                         help='''radius of geodesic sphere:
                         only used when output is cartesian, defualt=1''' )

    parser.add_argument( "--poly-start", metavar="<type>", default='i', choices=['i', 'o', 't'],
                         help='''which polyhedron to start from:
                         i: icosahedron (default)
                         o: octahedron
                         t: tetrahedron''' )

    parser.add_argument ("--output-fields", action="store_true",
                         help="list of the output fields for a given input")

    parser.add_argument ("--output-format", action="store_true",
                         help="list of the output types for a given input")

    parser.add_argument ("--output-size", action="store_true",
                         help="the number of points (vertices) of the geodesic sphere without generating it")

    parser.add_argument ("--flat-faced", action="store_true",
                     help="don't project the vertices to the sphere")

    parser.add_argument('repeats', metavar='repeats', type=int, nargs=1,
                    help='number of times to divide icosahedron surfaces')


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

    if args.output_size:
        print get_size( args.repeats[0], args.poly_start )
        sys.exit( 0 )


    print generate_csv(args)

if __name__ == '__main__':
    main()




