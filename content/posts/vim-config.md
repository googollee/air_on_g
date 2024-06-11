+++
comments = true
date = "2017-05-01T08:38:56+02:00"
image = ""
share = true
tags = ["programming", "vim", "wsl"]
title = "在WSL上配置VIM"

+++

最近在Windows 10上折腾Windows Subsystem for Linux。为了减少折腾的复杂性和不一致性，决定在这个环境里用VIM。这里记录了这次配置VIM的经历。

<!--more-->

Linux Subsystem on Windows是Windows 10上的一个Linux模拟层，类似Wine。这个模拟层在底层模拟了Linux的系统调用，最早目的是在Windows RT上执行Android程序。后来随着Windows Mobile的衰落，这个项目就没用了。不过近几年微软实在好心，最终还是把这个项目废物利用，变成了Windows下兼容Linux的一套运行层环境。最早在Windows 10里叫Bash on Ubuntu on Windows，是和Ubuntu合作的一个项目。微软负责模拟层，Ubuntu负责基于模拟层搭建Ubuntu 14.04环境。在最新的Windows 10 Updates里，微软把这个模拟层改名叫Windows Subsystem for Linux，除了名字太长，至少没有前一个那么多的槽点了（其实还不如改名叫Line，和Wine凑一对）。自带的Ubuntu也升级到了16.04（都2017年了，不过至少是个LTS）。

不过我倒是不打算继续使用Ubuntu了。这货2年一更新，作为开发环境要配置一堆私有源才能工作。所以这次首先就想能不能换成一个Rolling的发行版。之后在社区发现[WSL Distribution Switcher](https://github.com/RoliSoft/WSL-Distribution-Switcher)这个项目，配合Docker可以安装几乎所有的发行版。于是就把这个模拟层的发行版换成了Debian testing。既足够稳定（一个包要在unstable里保证5天没bug才会切入testing），又能够及时滚动更新（上游package更新后就会立刻启动upstream->unstable->testing这个流程）。

这个环境依然有两个麻烦的地方，首先是模拟环境的文件系统和Windows 10的文件系统是分离的，可以把Windows 10的文件系统通过`/mnt/c`的方式挂载到模拟层里（先不吐槽所有文件挂载后0777的访问属性）。其次是Linux模拟环境下默认没有X，不能操作任何GUI，只能使用命令行交互（愿意的话可以通过SDL的方式装X，但我不愿意这么折腾）。第一次尝试的时候打算直接把工作目录通过软连接，进入`/mnt/c`下的工作目录。编辑文件在Windows 10里用Atom，编译执行在Linux环境。这样麻烦在于，我需要在Windows和Linux两个环境里同时配置一些运行环境，比如golang，lint等工具，才能在编辑的时候能够自动执行，也能在命令行下执行。这种在两个地方配置一套类似的东西，最后总会出现维护上的问题。

最后决定下狠心，放弃Atom，直接在命令行里使用VIM。

使用Switcher安装的Debian testing，默认的VIM不带任何脚本程序（Python，Ruby）支持，所以VIM插件会有限制（主要是YouCompleteMe这个插件）首先更新VIM：

```bash
$ sudo apt-get purge vim
$ sudo apt-get install vim-nox
```

由于这个包使用Python 3作为Python的默认支持，为了简化配置，将环境的Python也默认设置为Python 3（反正我不用Python）：

```bash
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1
sudo update-alternatives --config python
```

之后安装[Vundle.vim](https://github.com/VundleVim/Vundle.vim)作为插件管理：

```bash
$ mkdir -p ~/.vim/bundle
$ cd ~/.vim/bundle

# 以下两组命令2选1

# 1 直接使用Vindle.vim
$ git clone https://github.com/VundleVim/Vundle.vim

# 2 使用submodule管理Vindle.vim
$ git submodule add https://github.com/VundleVim/Vundle.vim
$ git submodule update --init Vundle.vim

$ cat > ~/.vimrc <<EOF
set nocompatible
filetype off

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'

call vundle#end()

filetype plugin indent on
EOF
```

最终安装并配置插件后的配置文件可以直接参考[.vimrc](https://github.com/googollee/my_sys/blob/master/vim/vimrc)。这个配置会利用`Ctrl-e`来循环打开NERDTree和TagBar，并可以按住`Ctrl`后，使用`hjkl`来切换不同的Window，使用`w`创建新的Tab，使用`nm`来切换不同的Tab（其实我更想使用`Ctrl-,.`来切换Tab，无奈似乎不能map）。使用`Ctrl-p`可以在当前目录下根据文件名快速定位文件。

修改好配制后，需要进入VIM执行`:PluginInstall`来安装所有的插件。插件安装好后，需要编译YouCompleteMe插件：

```bash
$ sudo apt-get install build-essential cmake
$ cd ~/.vim/bundle/YouCompleteMe
$ python ./install.py --clang-completer --gocode-completer --tern-completer
```

这个编译保证能对clang，golang和Javascript进行补全。

再次进入VIM，就可以正常使用了。

如果要更新插件，可以进入VIM执行`:PluginInstall`。
