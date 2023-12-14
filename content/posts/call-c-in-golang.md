+++
date = "2010-04-18T20:00:00+08:00"
title = "Golang里调用C"
category = "development"
tags = ["c", "golang"]
+++

Golang调用C分两个步骤：1 写一个C的wrapper，这个很简单；2 对wrapper做编译，这个步骤有点复杂，而且涉及众多中间文件。应该是有办法用自动化的工具简化这个过程的。

<!--more-->

先来展示一下C程序。为了将描述集中在如何调用上，C的程序很简单：

``` c
# file: prints.h
#ifndef PRINTS_HEAD
void prints(char* str);
#endif
```

``` c
# file: prints.c
#include "prints.h"
#include <stdio.h>

void prints(char* str)
{
  printf("%s\n", str);
}
```

之后是Golang对C的一个wrapper：

``` go
// file: prints.go
package prints

// NOTICE BELOW

//#include "prints.h"
// // some comment
import "C"

func Prints(s string) {
  p := C.CString(s);
  C.prints(p);
}
```

需要注意的是import "C"及其上面的几行注释。在编译过程中，go会根据import "C"之前的几行注释生成一个c程序，并将这个c程序里的符号导入到模块C里，最后由import "C"再导入到go程序里。如果需要在其他go程序里调用api，需要参照prints.go里的Prints函数（要导出的go模块需要首字母大写）写一个wrapper func。其中对c程序里符号的引用都需要通过C来引用，包括一些c的类型定义，比如传给c api的int需要通过C.int来定义，而字符串则是C.CString。

有了这几个文件，就可以编译一个可以在go里加载的库了。以下都是在x86 linux下操作过程，如果是其他环境，请替换相应的编译命令。

编译wrapper：

    cgo prints.go

生成文件：

- _cgo_defun.c：根据prints.go里标红的注释，生成用于在go里调用的c符号和函数
- _cgo_gotypes.go：_cgo_defun.c里的符号在go里对应的定义
- _cgo_.o
- prints.cgo1.go：根据prints.go生成的go wrapper func
- prints.cgo2.c：根据prints.go生成的c wrapper func

编译go wrapper相关的文件，生成_go_.8

    8g -o _go_.8 prints.cgo1.go _cgo_gotypes.go

编译c wrapper的通用部分，生成_cgo_defun.8

    8c -FVw -I"/home/lizh/go/src/pkg/runtime/" _cgo_defun.c

对上面两个编译好的wrapper打包，生成prints.a

    gopack grc prints.a _go_.8 _cgo_defun.8

将生成的prints.a放到go的包目录下

    cp prints.a $GOROOT/pkg/linux_386/

之后是对c部分的编译：

    gcc -m32 -fPIC -O2 -o prints.cgo2.o -c prints.cgo2.c
    gcc -m32 -fPIC -O2 -o prints.o -c prints.c
    gcc -m32 -o prints.so prints.o prints.cgo2.o -shared

根据prints.c和prints.cgo2.c生成prints.so，是一个可供go程序引入的动态库。通过objdump查看prints.so的符号，可以发现：

- prints：需要引入的c api符号
- _cgo_prints：由go生成的对c api的wrapper，具体可以查看prints.cgo2.c

将编译好的动态库放入go的包目录下

    cp prints.so /home/lizh/go/pkg/linux_386/

之后就可以在go里调用prints这个c函数了：

``` go
package main

import "prints"

func main() {
  s := "Hello world!";
  prints.Prints(s);
}
```

查看生成的调用程序，可以看到对$GOROOT/pkg/linux_386/libcgo.so和$GOROOT/pkg/linux_386/prints.so两个动态库的引用。发布时需要将这两个库放到发布环境里。
