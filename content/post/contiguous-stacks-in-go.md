+++
date = "2014-03-28T21:21:24+08:00"
title = "Go中的连续栈"
category = "development"
tags = ["golang", "performance"]
+++

本文译自[Contiguous stacks in Go](http://agis.io/2014/03/25/contiguous-stacks-in-go.html)。介绍了Go 1.3版本在栈管理上的变化，以及由此带来的性能改进。

<!--more-->

Go里的连续栈

我用了一段时间Go，非常喜欢这种语言。1.3版本计划在2014年六月释出，这个版本会有不少关于性能的改进，其中一项性能改进是连续栈技术。让我们来看看连续栈到底是什么。

分段栈（segmented stacks）

The 1.2 runtime uses segmented stacks, also known as split stacks.
Go 1.2版本运行时使用分段栈，也被叫做切分栈（split stacks）。

分段栈是一种用来实现不连续且会连续增长的栈的方法。

Each stack starts with a single segment. When the stack needs to grow another segment is allocated and linked to the previous one, and so forth. Each stack is effectively a doubly linked list of one or more segments.
每个栈开始时只有一个单独的段。随着栈增长，就会分配新的段，并与上一个段相连，如此保证栈可以不断增长。每个栈都是一个或多个靠高效的双向互链的段组成的。

![分段栈](http://air.googol.im/images/segmented-stacks.png)

这种方法的优点是，栈可以一开始时很小，根据需要增长或者收缩。比如说，1.1版本的栈一开始是4kb，1.2版本的栈一开始是8kb。

当然，这种方法也会有问题。

考虑在栈接近满的时候，发生了一个函数调用。调用会强迫栈赠长，导致需要分配新的段。当这个函数返回时，这个新分配的段会被释放，栈也会再次收缩。

现在，假设这个调用发生的非常频繁。比如：

	func main() {
	    for {
	        big()
	    }
	}

	func big() {
	    var x [8180]byte
	    // 对x做些事情

	    return
	}

对`big()`的调用会申请新的段，这个新的段会在函数返回时释放。在循环里，这个申请释放的过程会反复发生。

这类情况里，恰巧在循环里遇到了栈的容量触及边界的情况，反复创建和销毁段时的开销会非常明显。在Go社区内部，这种情况被称作“切分热点”。Rust社区面对同样的问题，只不过将其称作“锻打栈”。

连续栈

在Go 1.3里会因为使用了连续栈实现而不再有“切分热点”问题。

现在，如果栈需要增长，不再申请新的段，而是按如下方式操作：

 - 创建一个新的，更大的栈
 - 将老栈的内容复制到新栈
 - 调整所有被复制的指针到新的地址
 - 销毁老栈

调整指针的操作会受到编译器的逃逸分析算法影响。这个算法保证只有指向栈上数据的指针会存储在同一个栈上（当然，也有一些例外）。如果某个指针有逃逸（比如，指针要返回给调用者，或者写入了一个全局变量），就意味着分配的数据需要保存在堆上。

这种方法当然也有一些挑战。1.2版本在运行时并不知道栈上一个指针大小的字，真的是个指针，还是别的同样大小的数据。也许是浮点数或者是更不常见的将一个整形数当作指针，真的指向某个数据。

由于缺少关于数据的理解，垃圾收集器只能保守考虑，将所有位于栈帧上的地址当作根。结果就导致了内存泄露的可能，尤其是在内存池更小的32位架构上。

如果是复制整个栈，就能避免这种问题，在调整指针时只考虑真正的指针。

工作就这么做完了，栈上活指针的信息现在嵌入了二进制程序里，并可以在运行时使用这些信息。这意味着1.3版本的垃圾收集器不仅可以精确收集栈数据，还可以调整栈上的指针。

1.3版本的初始栈大小很保守，设置为4kb，在1.4版本里可能会进一步缩小。对于收缩机制，在垃圾收集器执行时，栈使用了少于1/4的总空间时，会缩减一半的大小。

虽然连续栈会造成一些内存碎片的问题，但是使用json和html/template做性能测试的结果显示，连续栈的性能有很大改善。

![json benchmark](http://air.googol.im/images/json-benchmark.png)

![html benchmark](http://air.googol.im/images/html-benchmark.png)

来源：[contiguous stacks design document](https://docs.google.com/document/d/1wAaf1rYoM4S4gtnPh0zOlGzWtrZFQ5suE8qr2sD8uWQ/pub)

结论

Go 1.3将会是一个有重多性能改善和其他重要更新的大版本。我很期待。
