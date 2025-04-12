local M = {}

M.api_endpoint = "https://youdomain.com" ---@type string
M.upload_header = { "Accept:application/json", "Content-Type:multipart/form-data" }
M.upload_body = { file = "$FILE", album_id = "1" }

---@param config_opts? table
function M.setup(config_opts)
	M.opts = vim.tbl_deep_extend("force", {}, M, config_opts or {})
end

return M
