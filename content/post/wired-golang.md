+++
date = "2013-04-03T20:00:00+08:00"
title = "Go语言奇怪的特性"
category = "development"
tags = ["golang"]
+++

记录了一些使用Go时遇到的违反直觉的特性。

<!--more-->

## recover是个特殊的函数

能猜到下面的程序会不会崩溃么？

``` go
package main

func main() {
	defer recover()
	panic(1)
}
```

程序依旧会崩溃。

原因是recover虽然看起来是个函数，但其实是编译器有特殊处理，可以当做一个关键字看待。

正确的写法是把recover放到一个函数里：

``` go
package main

func main() {
	defer func() { recover() }()
	panic(1)
}
```

## slice的引用特性

依旧是先给出程序，猜输出：

``` go
package main

import (
	"fmt"
)

func main() {
	array := make([]int, 0, 3)
	array = append(array, 1)
	a := array
	b := array
	a = append(a, 2)
	b = append(b, 3)
	fmt.Println(a)
}
```

答案揭晓，输出是`[1 3]`。

就我的理解，slice是一个{指向内存的指针，当前已有元素的长度，内存最大长度}的结构体，其中只有_指向内存的指针_一项是真正具有引用语义的域，另外两项都是每个slice自身的值。因此，对slice做赋值时，会出现两个slice指向同一块内存，但是又分别具有各自的元素长度和最大长度。程序里把array赋值给a和b，所以a和b会同时指向array的内存，并各自保存一份当前元素长度1和最大长度3。之后对a的追加操作，由于没有超出a的最大长度，因此只是把新值2追加到a指向的内存，并把a的“当前已有元素的长度”增加1。之后对b进行追加操作时，因为a和b各自拥有各自的“当前已有元素的长度”，因此b的这个值依旧是1，追加操作依旧写在b所指向内存的偏移为1的位置，也就复写了之前对a追加时写入的2。

为了让slice具有引用语义，同时不增加array的实现负担，又不增加运行时的开销，似乎也只能忍受这个奇怪的语法了。
