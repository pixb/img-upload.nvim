local config = require("img-upload.config")
local utils = require("img-upload.utils")
local M = {}

-- Helper function to print messages to the upload buffer
local function upload_print(message)
	vim.api.nvim_buf_set_lines(upload_buf, -1, -1, false, { message })
end

local function upload_img(image_path)
	local command = string.format(
		'curl --location "%s" --form "file=@%s" --form "album_id=1"',
		config.opts.api_endpoint,
		image_path
	)
	vim.print("upload.lua upload_img(), command=" .. command)
	local cmd = "sh -c " .. vim.fn.shellescape(command)
	vim.print("upload.lua upload_img(), cmd=" .. cmd)
	local result = vim.fn.system(cmd)
	vim.print("upload.lua upload_img(), result=" .. result)
	return result
end

-- 异步上传图片
local function upload_img_async(image_path, callback)
	-- 拼接上传命令
	local header_str = ""
	for _, value in ipairs(config.opts.upload_header) do
		header_str = header_str .. " -H " .. string.format('"%s"', value)
	end

	local body_form = ""
	for key, value in pairs(config.opts.upload_body) do
		print(key, value)
		if value == "$FILE" then
			body_form = body_form .. " --form " .. string.format('"%s=@%s"', key, image_path)
		else
			body_form = body_form .. " --form " .. string.format('"%s=%s"', key, value)
		end
	end
	local command = string.format('curl --location "%s" %s %s', config.opts.api_endpoint, header_str, body_form)

	upload_print("upload.lua upload_img_async(), command=" .. command)

	-- 使用 vim.loop.spawn 异步执行命令
	local cmd = "sh"
	local args = { "-c", command }
	local handle
	local stdout = vim.loop.new_pipe(false)
	local stderr = vim.loop.new_pipe(false)

	handle = vim.loop.spawn(cmd, {
		args = args,
		stdio = { nil, stdout, stderr },
	}, function(code, signal)
		stdout:close()
		stderr:close()
		handle:close()
	end)

	stdout:read_start(function(err, data)
		if data then
			vim.schedule(function()
				callback(data)
			end)
		end
	end)

	stderr:read_start(function(err, data)
		if data then
			vim.schedule(function()
				callback(data)
			end)
		end
	end)
end

upload_buf = nil

local function get_or_create_upload_buf()
	-- 检查是否已经存在名为 "Upload Info" 的缓冲区
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(buf):match("Upload Info") then
			upload_buf = buf
			return buf
		end
	end
	-- 如果缓冲区不存在，则创建一个新的缓冲区
	upload_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(upload_buf, "Upload Info")
	vim.api.nvim_buf_set_option(upload_buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(upload_buf, "filetype", "markdown")
	return upload_buf
end

local function create_split_window()
	-- 获取或创建缓冲区
	local buf = get_or_create_upload_buf()

	-- 检查是否已经存在一个使用该缓冲区的垂直分割窗口
	local current_win = vim.api.nvim_get_current_win()
	local found_win = false
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == buf then
			vim.api.nvim_set_current_win(win)
			found_win = true
			break
		end
	end
	-- 如果未找到使用该缓冲区的窗口，则创建新的垂直分割窗口并设置缓冲区
	if not found_win then
		vim.cmd("vsplit")
		vim.api.nvim_win_set_buf(0, buf)
		vim.api.nvim_win_set_width(0, 70)
		vim.api.nvim_win_set_option(0, "wrap", true)
	end
	vim.cmd("wincmd p")
end

M.img_upload = function()
	create_split_window()
	upload_print("----")
	upload_print("# img-upload, start====")
	-- get cursor line content
	local line = vim.api.nvim_get_current_line()
	upload_print(string.format("img-upload, current line=`%s`", line))
	-- get markdown image path, e.g. ![img](/path/to/img.png),get file path /path/to/img.png
	local img_path = line:match("!%[.*%]%((.*)%)")
	local img_name = line:match("!%[(.-)%]")
	if utils.is_http_or_https_link(utils.trim(img_path)) then
		img_path = utils.download_img(img_path)
		-- img_name = img_path:match(".*(.-)")
	end
	if img_path == nil then
		vim.notify("img-upload, no image found in current line, skip upload.")
		upload_print("upload.lua img_upload(), no image found in current line, skip upload.")
		return
	end
	upload_print("img-upload, img_path=" .. img_path)
	upload_print("img-upload, img_name=" .. img_name)

	-- if img_path is not nil, and file exists, upload to server
	if img_path and vim.fn.filereadable(img_path) == 1 then
		upload_print("img-upload, file exists, start upload...")
		-- upload_img(img_path)
		upload_img_async(img_path, function(result)
			upload_print(vim.inspect(result))
			local decode_ok, decode_result = pcall(vim.json.decode, tostring(result))
			if decode_ok then
				-- insert uploaded image url to markdown
				local url = decode_result.result.element_url
				local new_line = line:gsub("!%[.*%]%(.*%)", "![" .. img_name .. "](" .. url .. ")")
				vim.api.nvim_set_current_line(new_line)
				upload_print(string.format("img-upload, upload success, new_line=`%s`, url=`%s`", new_line, url))
			else
				local lines = {}
				for line in result:gmatch("[^%z]+") do
					-- 取出换行符
					line = line:gsub("\n", "")
					table.insert(lines, line)
					vim.print("line = " .. line)
				end
				local upload_progress = {}
				for i, line in ipairs(lines) do
					-- 去除行首尾的空格
					line = line:gsub("^%s+", ""):gsub("%s+$", "")
					upload_print(line)
					-- 分割数据为多个部分
					local parts = {}
					for part in line:gmatch("%S+") do
						table.insert(parts, part)
					end
					-- 解析为一个表，假设每一列代表不同的信息，如百分比完成、上传速度等
					-- 这里仅作为示例，实际应根据具体需求调整
					table.insert(upload_progress, {
						percent = tonumber(parts[1]),
						totalSize = parts[2],
						downloaded = parts[3],
						uploadSpeed = parts[8],
						downloadSpeed = parts[7],
						elapsedTime = parts[9],
						remainingTime = parts[10],
						overallSpeed = parts[11],
					})
				end
				-- upload_print输出进度信息, upload_print只接受单行信息
				-- for i, progress in ipairs(upload_progress) do
				-- 	upload_print(string.format("%s\t\t%s\t\t%s", progress.percent, progress.totalSize, progress.uploadSpeed))
				-- end
			end
		end)
		upload_print("img-upload, upload end.")
		upload_print("----")
	else
		upload_print("upload.lua img_upload(), file not exists, skip upload.")
		upload_print("----")
	end
end

return M
