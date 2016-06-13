#!/usr/bin/lua
--[[
	Linux Only, lua 5.0+
	Max Tsai(haiching.tsai@gmail.com)
	2012/1/12
]]

dedicate_git_list = {}
git_list = {}
root_path = ""
max_path_length = 0


dir_level = 0

function scan_dir(path)
	dir = {}
	dirlist = os.tmpname()
	os.execute("ls -l " .. path .. " | awk '{split($1, a, \"r\"); if (a[1] == \"d\") {print $8}}' > " .. dirlist)
	f = assert(io.open(dirlist, "r"))
	for line in f:lines() do
		dir[#dir+1] = line
	end
	f:close()
	os.remove(dirlist)
	return dir
end

function travel_all_path (path)
	local root = path .. "/.git"

	-- directory not exist
	fp = io.open(path)
	if fp == nil then return 0 end
	io.close(fp)

	-- git exist
	fp = io.open(root)
	if fp ~= nil then
		dedicate_git_list[#dedicate_git_list+1] = path
		if max_path_length < string.len(path) then max_path_length = string.len(path) end
		io.close(fp)
		return 0
	end

	-- directory without git, scan sub-folder
	local sub_dir = scan_dir(path)
	for i=1,#sub_dir do
		if sub_dir[i] ~= nil then
			-- ignore out folder
			s = string.match (sub_dir[i], "out")
			if s ~= nil then
				table.remove(sub_dir, i)
			end
			sub_dir[i] = path.."/"..sub_dir[i]
			print(i.." : "..#sub_dir.." : "..sub_dir[i])
			travel_all_path(sub_dir[i])
		end
	end

end


function list_cur_branch(path)
	for i=1,#path do
		tmpfile = os.tmpname()
		cmd = "git --git-dir="..path[i].."/.git/ branch | awk '{split($1, a); if (a[1] == \"*\") {print $2 \" \" $3 \" \" $4}}' > "..tmpfile
		os.execute(cmd)
		f = assert(io.open(tmpfile, "r"))
		cur_branch = f:read()
		f:close()
		os.remove(tmpfile)
		print(path[i]..string.rep(" ", max_path_length-string.len(path[i])+3)..cur_branch)
	end
end




-- main --
if (#arg < 1) then print("Usage: "..arg[0].." repo_path")  return 0 end
if (#arg >= 1) then root_path = arg[1] end

travel_all_path(root_path)
list_cur_branch(dedicate_git_list)


