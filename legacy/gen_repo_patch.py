#!/usr/bin/env python
'''
   Written by Max Tsai <haiching.tsai@gmail.com>, 2011/1/17

'''

import datetime
import time
import commands
import sys
import os


stat, source_dir = commands.getstatusoutput("pwd")
git_path_list = []

cur_time = datetime.datetime.now()
log_file = "log_" + cur_time.strftime('%Y%m%d-%H%M')

def show_env():
	os.system("clear")
	print "========================================================"
	print "source direction = " + source_dir
	print "patch direction = " + sys.argv[1]
	print "from tag = " + sys.argv[2]
	print "until tag = " + sys.argv[3]
	print "========================================================"

def travel_all_git_path(path):
	global git_path_list
	root = path + "/.git"

	if path.rfind("/out") != -1:
		return

	if os.path.exists(root):
		git_path_list.append(path)
		return
	if not os.path.isdir(path):
		return
	if not os.path.exists(path):
		return
	stat, cur_dir = commands.getstatusoutput("pwd")
	os.chdir(path)
	for name in os.listdir(path):
		if not name[0] == ".":
			git_path = os.path.join(path, name) + "/.git"
			if os.path.exists(git_path):
				git_path_list.append(os.path.join(path, name))
			else:
				travel_all_git_path(os.path.join(path, name))
	os.chdir(cur_dir)

def walk_func(patch_dir, direction, files):
	for i in files:
		if i.rfind(".patch") != -1:
			prefix = direction.split(patch_dir)[1][1:] #remove "/"
			prefix = prefix + "/"
			ifile = open(direction + "/" + i, "r")
			ofile = open(direction + "/" + i + ".tmp", "w")
			lines = ifile.readlines()
			ifile.close()
			patched_files = []
			for line in lines:
				if line.find("diff --git") != -1:
					line = line.split(" ")
					patched_files.append(line[2][2:])
			for line in lines:
				for j in patched_files:
					if line.find(j) != -1:
						lines[lines.index(line)] = lines[lines.index(line)].replace(j, prefix + j)
						break;
			ofile.writelines(lines)
			ofile.close()
			cmd = "mv " + direction + "/" + i + ".tmp " + direction + "/" + i
			os.system("mv " + direction + "/" + i + ".tmp " + direction + "/" + i)

def add_prefix_for_all_patch(patch_dir):
	print ""
	print "Modifying patches..."
	os.path.walk(patch_dir, walk_func, patch_dir)


def enumerate_git_path_by_branch(branch, root):
	global git_path_list
	git_path_list = []
	git_path_with_branch = []
	travel_all_git_path(root)
	stat, cur_dir = commands.getstatusoutput("pwd")
	for i in git_path_list:
		os.chdir(i)
		stat, ret = commands.getstatusoutput("git branch")
		if ret == "* " + branch:
			git_path_with_branch.append(i)
	os.chdir(cur_dir)
	return git_path_with_branch

def enumerate_current_branch_by_git_path(root):
	global git_path_list
	travel_all_git_path(root)
	git_branch_list = []
	stat, cur_dir = commands.getstatusoutput("pwd")
	for i in git_path_list:
		os.chdir(i)
		stat, branch = commands.getstatusoutput("git branch")
		branch = branch.split("\n")
		for j in branch:
			if j[0] == "*":
				j = j.split("* ")[1]
				git_branch_list.append([i, j])
	os.chdir(cur_dir)
	return git_branch_list

def list_current_branch(root):
	max_len = 0
	git_branch_list = enumerate_current_branch_by_git_path(root)
	for i in git_branch_list:
		if len(i[0]) > max_len:
			max_len = len(i[0])
	for i in git_branch_list:
		path = i[0].split(root)
		print "." + path[1] + " "*(abs(max_len-len(i[0])) + 1) + i[1]
	
'''
  create_patch_dir need git_path_list
'''
def create_patch_dir(patch_dir, root):
	global git_path_list
	if len(git_path_list) <= 0:
		print "no git path"
		return
	if os.path.exists(patch_dir):
		print patch_dir + " exists."
		return
	os.mkdir(patch_dir)
	path_to_create = []
	for i in git_path_list:
		sub = i.split(root)[1]
		folder = patch_dir + sub
		while not os.path.lexists(folder):
			path_to_create.insert(0, folder)
			head,tail = os.path.split(folder)
			if len(tail.strip()) == 0:
				folder = head
				head,tail = os.path.split(folder)
			folder = head
		for j in path_to_create:
			if not os.path.lexists(j):
				os.mkdir(j)

def num_by_tag(root, git_tag):
	global git_path_list
	travel_all_git_path(root)
	for i in git_path_list:
		os.chdir(i)
		cmd = "git rev-list --no-merges " + git_tag
		stat, commits = commands.getstatusoutput(cmd)
		if commits.find("fatal") != -1:
			print "Unable to generate format patch: " + i
		else:
			commits = commits.split("\n")
			print i + " "*abs(80-len(i)) + str(len(commits))

def gen_path_between_tags(patch_dir, root, old_tag, new_tag):
	global git_patch_list
	travel_all_git_path(root)
	need_remove_git_path = []
	path_max_len = 0

	if os.path.exists(patch_dir):
		ret = raw_input(patch_dir + " exists. delete[y/N]? ")
		if ret == "y" or ret == "Y":
			os.system("rm -r " + patch_dir)
		else:
			return -1

	print "Search new patches..."

	for i in git_path_list:
		os.chdir(i)
		cmd = "git rev-list --no-merges " + old_tag
		stat, old_commits = commands.getstatusoutput(cmd)
		if old_commits.find("fatal") != -1:
			print i
			print "\t" + old_commits
			#return -1
			need_remove_git_path.append(i)
			continue
		cmd = "git rev-list --no-merges " + new_tag
		stat, new_commits = commands.getstatusoutput(cmd)
		if new_commits.find("fatal") != -1:
			print i
			print "\t"+ new_commits
			#return -1
			need_remove_git_path.append(i)
			continue
		old_commits = old_commits.split("\n")
		new_commits = new_commits.split("\n")
		if len(old_commits) > len(new_commits):
			print new_tag + " is older than " + old_tag
			return -1
		if len(old_commits) == len(new_commits):
			need_remove_git_path.append(i)
		if len(i) > path_max_len:
			path_max_len = len(i)

	for i in need_remove_git_path:
		git_path_list.remove(i)

	create_patch_dir(patch_dir, root)
	os.system("echo '' >" + sys.argv[1] + "/" + log_file)

	print ""
	print "Generating patches..."

	for i in git_path_list:
		os.chdir(i)
		cmd = "git rev-list --no-merges " + old_tag
		stat, old_commits = commands.getstatusoutput(cmd)
		cmd = "git rev-list --no-merges " + new_tag
		stat, new_commits = commands.getstatusoutput(cmd)
		old_commits = old_commits.split("\n")
		new_commits = new_commits.split("\n")
		patch_num = len(new_commits) - len(old_commits)
		output_dir = patch_dir + i.split(root)[1]

		### unknown reason. some commits lost by "git format-patch -<n>"
		#cmd = "git format-patch " + new_commits[0] + " -" + str(patch_num) + " -o " + output_dir

		cmd = "git format-patch " + old_commits[0] + " -o " + output_dir
		stat, ret = commands.getstatusoutput(cmd)
		if len(output_dir) > path_max_len:
			path_max_len = len(output_dir)
		msg = i + " "*abs(path_max_len-len(i)+1) + str(patch_num)
		print "\t" + msg
		os.system("echo " + msg + " >>" + sys.argv[1] + "/" + log_file)


if len(sys.argv) == 1:
	print "Listing current branch..."
	list_current_branch(source_dir)
	exit()

if len(sys.argv) < 4:
	print sys.argv[0] + " path_2gen_patches old_tag new_tag"
	exit()

show_env()
if -1 != gen_path_between_tags(sys.argv[1], source_dir, sys.argv[2], sys.argv[3]):
	#add_prefix_for_all_patch(sys.argv[1])
	print "Done."

