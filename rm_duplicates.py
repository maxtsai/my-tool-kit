#!/usr/bin/env python
#-*- coding:utf-8 -*-

# Max @ 20130509

import sys
import os
import md5
#import hashlib

total = 0
remove = 0


def remove_duplicate(path):
	global total
	global remove
	hashes = {}
	for dirpath, dirnames, filenames in os.walk(path):
		for filename in filenames:
			full_path = os.path.join(dirpath, filename)
			filehash = md5.md5(file(full_path).read()).hexdigest()
			#print full_path + ' : ' + filehash
			duplicate = hashes.get(filehash, None)	
			if duplicate:
				print "Duplicate found: %s and %s" % (full_path, duplicate)
				os.remove(full_path)
				remove += 1
			else:
				hashes[filehash] = full_path
			total += 1
	#print hashes
	sys.stdout.write('\n')
	print 'total, remove, rest = ' + str(total) + ', ' + str(remove) + ', ' + str(total-remove)

if len(sys.argv) != 2:
	print "Usage: rm_duplicate folder"
	sys.exit(1)	
remove_duplicate(sys.argv[1])
