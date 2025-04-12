local config = require("img-upload.config")
local M = {}

---@param config_opts? table
M.setup = function(config_opts)
	config.setup(config_opts)
end

return M
