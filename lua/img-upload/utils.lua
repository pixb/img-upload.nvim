local M = {}
function M.generate_uuid()
	local random = math.random
	return string.format(
		"%04x%04x-%04x-%04x-%04x-%04x%04x%04x",
		random(0, 0xffff),
		random(0, 0xffff),
		random(0, 0xffff),
		random(0, 0x0fff) + 0x4000,
		random(0, 0x3fff) + 0x8000,
		random(0, 0xffff),
		random(0, 0xffff),
		random(0, 0xffff)
	)
end

function M.get_content_type(url)
	local command = string.format("curl -I %s | grep 'Content-Type'", url)
	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()

	local content_type = result:match("Content%-Type: (%w+/%w+)%s*")
	return content_type or "jpg"
end

function M.get_temp_dir()
	local os_name = package.config:sub(1, 1) == "\\" and "Windows" or "Unix"

	if os_name == "Windows" then
		local temp_env = os.getenv("TEMP") or os.getenv("TMP")
		return temp_env or "C:\\Windows\\Temp"
	else
		return os.getenv("TMPDIR") or "/tmp"
	end
end

function M.download_img(url)
	local temp_dir = M.get_temp_dir()
	local content_type = M.get_content_type(url)
	local file_extension = content_type:match("%w+$") or "jpg"
	local file_name = M.generate_uuid() .. "." .. file_extension
	local full_path = temp_dir .. "/" .. file_name

	local command = string.format("curl --compressed -o %s %s", full_path, url)
	local res = os.execute(command)

	if res then
		return full_path
	else
		return nil
	end
end

function M.is_http_or_https_link(url)
	vim.print("M.is_http_or_https_link:", url)
	local pattern = "^https?://.*"

	if string.match(url, pattern) then
		vim.print("M.is_http_or_https_link:", true)
		return true
	else
		vim.print("M.is_http_or_https_link:", false)
		return false
	end
end

function M.trim(s)
	s = s:match("^%s*(.*)")
	s = s:match("(.-)%s*$")
	return s
end

return M
