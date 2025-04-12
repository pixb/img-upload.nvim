# img-upload.nvim

This is a plugin for the Neovim editor that allows you to edit markdown files and upload local images to a server.

![neovim](https://piwigo.pixtang.com/upload/2025/04/12/20250412155859-573d8556.png)

## 🤖 use `lazy.vim` config

```lua
return {
    "pixb/img-upload.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>pu", "<cmd>ImgUpload<cr>", desc = "image upload" },
    },
    opts = {
      api_endpoint = "https://youdomain.com/upload",
      upload_body = { file = "$FILE", album_id = "1" },
      upload_header = { "Accept:application/json", "Content-Type:multipart/form-data" },
    },
}
```

# 📲 Ref

Referenced and learned from the following projects, Thanks!!💕.

- [img-clip.nvim](https://github.com/hakonharnes/img-clip.nvim)
