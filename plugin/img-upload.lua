local upload = require("img-upload.upload")
vim.api.nvim_create_user_command("ImgUpload", function()
	upload.img_upload()
end, {})
