#!/usr/bin/env python


import os
import sys
import shutil
import commands
import time
import datetime

dst_root = ''
total = 0

def get_cfiletime(filename):
	return datetime.datetime.fromtimestamp(os.path.getctime(filename)).strftime("%Y-%m-%d")

def move_jpeg(filename):
	global dst_root
	global total

	cmd = "exif -t 0x9003 " + filename
	stat, log = commands.getstatusoutput(cmd)
	if log.find('EXIF tags in') != -1:
		log_list = log.split('\n')
		log_list = log_list[5].split(' ');
		if len(log_list) == 0:
			exif_date = get_cfiletime(filename)
		else:
			exif_date = log_list[3].replace(':', '-')
	else:
		exif_date = get_cfiletime(filename)
	dst_path = dst_root + '/' + exif_date
	if not os.path.exists(dst_path):
		os.mkdir(dst_path)
	head, tail = os.path.split(filename)
	if not os.path.exists(dst_path + '/' + tail):
		total += 1
		shutil.move(filename, dst_path)
	else:
		for i in range(5):
			if not os.path.exists(dst_path + '/' + str(i) + '_' + tail):
				shutil.move(filename, dst_path + '/' + str(i) + '_' + tail)
				total += 1
				break
def move_other_type(filename):
	global dst_root
	global total
	_date = get_cfiletime(filename)
	dst_path = dst_root + '/' + _date

	if not os.path.exists(dst_path):
		os.mkdir(dst_path)
	head, tail = os.path.split(filename)
	if not os.path.exists(dst_path + '/' + tail):
		total += 1
		shutil.move(filename, dst_path)
	else:
		for i in range(5):
			if not os.path.exists(dst_path + '/' + str(i) + '_' + tail):
				shutil.move(filename, dst_path + '/' + str(i) + '_' + tail)
				total += 1
				break

def walk_func(cur_dir, direction, files):
	for i in files:
		filename, fileExtension = os.path.splitext(direction + "/" + i)
		if fileExtension == '.JPG' or fileExtension == '.jpg' or fileExtension == '.JPEG' or fileExtension == '.jpeg':
			sys.stdout.write("x")
			sys.stdout.flush()
			move_jpeg(direction + '/' + i)
		if fileExtension == '.mov' or fileExtension == '.MOV':
			sys.stdout.write("x")
			sys.stdout.flush()
			move_other_type(direction + '/' + i)
		if fileExtension == '.avi' or fileExtension == '.AVI':
			sys.stdout.write("x")
			sys.stdout.flush()
			move_other_type(direction + '/' + i)

if len(sys.argv) != 2:
	print 'Usage: collect target_folder'
	sys.exit(1)
dst_root = sys.argv[1]

if len(dst_root) == 0:
	dst_root = './'
if not os.path.exists(dst_root):
	print dst_root + " doesn't exist!"
	exit(1)

os.path.walk("./", walk_func, "./")
sys.stdout.write('\n')
print 'total = ' + str(total)
