---
title: "组织Neovim配置的方法"
date: 2021-11-09T22:54:04+01:00
description: 如何使用Lua组织Neovim的配置
categories:
 - 开发
tags:
 - neovim
 - lua
 - editor
featured_image: /images/neovim-configuration.jpg
author: "Googol Lee"
---

最近NeoVim放出了0.5.1版本，默认支持Lsp以及Lua脚本运行时。Lsp是我现在非常常用的功能。Vim只依靠插件支持Lsp，很多特性用起来并不顺畅。所以我放弃了Vim，转而使用NeoVim作为主力编辑器。

NeoVim另一个特点是使用Lua做配置，而不是VimScript。Lua语法层面比VimScript要更像一个正常的语言，也很灵活。我花了大概两天时间，把VimScript的配置彻底改成了Lua。这里记录一下我是如何使用Lua组织NeoVim的插件和配置的。

插件管理使用[Packer](https://github.com/wbthomason/packer.nvim)。这是一个Lua编写，利用了NeoVim内置模块功能的插件。主配置文件`~/.config/nvim/init.lua`很简单，就是Packer的内容。其余插件都通过`require()`，从别的文件中引用。

```lua
local fn = vim.fn
local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end

require('packer').startup(function(p)
  require('editor')(p)
  require('telescope')(p)
  require('git')(p)
  require('treesitter')(p)
  require('lsp').init(p)
  require('nvim-compe')(p)

  require('lang/go')(p)
  require('lang/markdown')(p)
  require('lang/cider')(p)

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require('packer').sync()
  end
end)
```

其中`require('telescope')(p)`相对简单。文件位置在`~/.config/nvim/lua/telescope.lua`。NeoVim所有用于`require()`的文件都要放在`~/.config/nvim/lua`目录下，并且以此目录为准，使用相对路径做引用。引用时不包括扩展名`.lua`。


```lua
return function(packer)
  packer {
    'nvim-telescope/telescope.nvim',
    requires = {'nvim-lua/popup.nvim', 'nvim-lua/plenary.nvim'},
    config = function()
      vim.g.NERDSpaceDelims = 1

      local util = require('util')
      util.noremap('n', '<C-p>', ':Telescope find_files<CR>')
      util.noremap('n', '<leader>fg', ':Telescope live_grep<CR>')
      util.noremap('n', '<leader>fb', ':Telescope buffers<CR>')
      util.noremap('n', '<leader>fh', ':Telescope help_tags<CR>')
    end,
  }
end
```

每个文件都会返回一个函数，这个函数会传入一个用于配置的参数`packer`。在[Packer官方推荐的配置](https://github.com/wbthomason/packer.nvim#bootstrapping)里，这个参数更常被命名为`use`。不过拆分到子文件后，再使用`use`会比较奇怪，所以这里改为`packer`。

调用`pack`可以传入一个table。其中第一项必须是插件的名字。这里是`nvim-telescope/telescope.nvim`。`requires`字段表示载入该插件时还需要依赖哪些插件。`config`表示载入该插件后，需要执行哪些配置。这个table还支持其他的字段，具体可以参考[Packer官方文档`packer.use()`](https://github.com/wbthomason/packer.nvim/blob/master/doc/packer.txt#L534)。

比较特别的一个文件是`~/.config/nvim/lua/lsp.lua`。因为Lsp还需要对外提供一些其他函数，所以这个文件没有直接返回函数，而是返回了一组函数：

```lua
local M = {}

function M.init(packer)
  packer {
    'neovim/nvim-lspconfig',
    config = function()
      -- blablabla
    end,
  }
  packer "ray-x/lsp_signature.nvim"
end

function M.on_attach(client, bufnr)
  -- blablabla
nd

return M
```

一个函数是`init`，用来在Packer的`startup()`方法里初始化插件。这个函数调用了两次`packer`，注册了两个插件。另一个函数`on_attach`用于启用Lsp的配置。因为不是所有的文件都有Lsp的支持，比如日志文件就不需要任何Lsp的功能，使用`on_attach`可以保证只在打开有Lsp支持的文件时，才执行对应的Lsp配置。

我不打算介绍所有的插件，这里只介绍几个配置比较简单的插件，来展示组织方式。完整的配置文件可以看[my_sys](https://github.com/googollee/my_sys/tree/master/nvim/)。

