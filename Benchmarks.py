#!/usr/bin/python3

from TSPSolver import *
from TSPClasses import *

import sys, getopt

################################################################
# 
# Run benchmarks for the traveling salesman problem
#
# Usage: python Benchmarks.py [--rounds=<int>] [--cities=<int>]
#
#  - rounds :: number of times to run a particular benchmark and
#    average out the results
#
#  - cities :: defaults to do all the numbers of cities; this
#   specifies a number to limit it to
#
################################################################

def main():
    try:
        opts, args = getopt.getopt(sys.argv, "h:rc", ["help", "rounds=", "cities="])
    except getopt.GetoptError as err:
        print(err)
        usage()
        sys.exit(2)

    rounds = 1
    cities = "all"
    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-r", "--rounds"):
            rounds = a
        elif o in ("-c", "--cities"):
            cities = a
        else:
            print(f"Undefined option {o}")
            sys.exit(2)


def usage():
    print("""
Usage: python Benchmarks.py [-r|--rounds=<int>] [-c|--cities=<int>]

 - rounds: number of times to run to average; default is 1
 - cities: number of cities in benchmark; defaults runing 10..50 in steps of 5
""")

if __name__ == "__main__":
    main()
