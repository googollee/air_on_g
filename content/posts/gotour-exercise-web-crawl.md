+++
date = "2012-02-04T20:00:00+08:00"
title = "关于gotour最后一题的一些想法"
category = "development"
tags = ["golang"]
+++

过年几天，把[A Tour of Go](http://tour.golang.org/)看了一遍，算是复习了一遍go语言。其中最后一题[Exercise: Web Crawler](http://tour.golang.org/#70)有些复杂，是串行程序转换到并行时常见的问题。这里记录一些当时思考的结果。

<!--more-->

## 原题

将下面的网页抓取程序，由串行改为并行。修改Crawl函数，并发抓取url指向的页面，并且保证对同一页面只做一次抓去。

``` go
package main

import (
	"os"
	"fmt"
)

type Fetcher interface {
	// Fetch returns the body of URL and
	// a slice of URLs found on that page.
	Fetch(url string) (body string, urls []string, err os.Error)
}

// Crawl uses fetcher to recursively crawl
// pages starting with url, to a maximum of depth.
func Crawl(url string, depth int, fetcher Fetcher) {
	// TODO: Fetch URLs in parallel.
	// TODO: Don't fetch the same URL twice.
	// This implementation doesn't do either:
	if depth <= 0 {
		return
	}
	body, urls, err := fetcher.Fetch(url)
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Printf("found: %s %q\n", url, body)
	for _, u := range urls {
		Crawl(u, depth-1, fetcher)
	}
	return
}

func main() {
	Crawl("http://golang.org/", 4, fetcher)
}


// fakeFetcher is Fetcher that returns canned results.
type fakeFetcher map[string]*fakeResult

type fakeResult struct {
	body string
	urls     []string
}

func (f *fakeFetcher) Fetch(url string) (string, []string, os.Error) {
	if res, ok := (*f)[url]; ok {
		return res.body, res.urls, nil
	}
	return "", nil, fmt.Errorf("not found: %s", url)
}

// fetcher is a populated fakeFetcher.
var fetcher = &fakeFetcher{
	"http://golang.org/": &fakeResult{
		"The Go Programming Language",
		[]string{
			"http://golang.org/pkg/",
			"http://golang.org/cmd/",
		},
	},
	"http://golang.org/pkg/": &fakeResult{
		"Packages",
		[]string{
			"http://golang.org/",
			"http://golang.org/cmd/",
			"http://golang.org/pkg/fmt/",
			"http://golang.org/pkg/os/",
		},
	},
	"http://golang.org/pkg/fmt/": &fakeResult{
		"Package fmt",
		[]string{
			"http://golang.org/",
			"http://golang.org/pkg/",
		},
	},
	"http://golang.org/pkg/os/": &fakeResult{
		"Package os",
		[]string{
			"http://golang.org/",
			"http://golang.org/pkg/",
		},
	},
}
```

程序有些长有些长，因为还包括一部分假数据。程序入口在`func main`里，提供`"http://golang.org/"`作为起始页面，抓取深度是4，使用fetcher作为抓取算法。

## 第一次并行化

最初的想法是让每个Crawl单独跑一个goroutine，当Crawl里抓到新的url时，就启动一个新的goroutine。这个改动很简单，只需要修改Crawl函数就行：

``` go
func Crawl(url string, depth int, fetcher Fetcher) {
	if depth <= 0 {
		return
	}
	body, urls, err := fetcher.Fetch(url)
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Printf("found: %s %q\n", url, body)
	for _, u := range urls {
		go Crawl(u, depth-1, fetcher)
	}
	return
}
```

但实际结果却是只打印最初的一条“http://golang.org/”就结束了。因为go的程序在终止时，并不等待其余goroutine的结束，Crawl内用`go Crawl(...)`的方式递归调用后，main并不等待新建的goroutine的结束，就结束了整个程序，因此其余的url还没有抓取，就结束了。

## 监视goroutine的启动和退出

因此，程序需要有办法监控总共启动了多少个goroutine，而且还要能知道，是否所有goroutine都已经运行完毕退出了。传统的并发程序，是通过thread id或者thread handler，配合类似join的api来完成的。但是go没有任何对goroutine的控制方法，要想知道goroutine的状态，只能在其内部，通过chan将状态发送给接收者。同时，为了方便对goroutine进行计数，最好将所有goroutine的启动放在一个函数内，这就需要Crawl将新抓到的url发到一个特殊的控制函数，这个控制函数在接收到新的url后，启动新的Crawl进行抓取。程序修改如下：

新建一个UrlData结构，用来传递新抓到的url，以及这个url对应的抓取深度depth：

``` go
type UrlData struct {
	url   string
	depth int
}
```

修改Crawl函数，加入两个chan，quit对应函数退出的信号，urldata对应抓取到新的url时的新数据传输通道。注意defer是如何间接明了的完成发送quit信号的功能的（对比C++的析构函数概念，defer要清晰明快的多，而且有closure的加持，能做的事情也比析构多）：

``` go
func Crawl(url string, depth int, fetcher Fetcher, urldata chan<- *UrlData, quit chan<- int) {
	defer func() { quit <- 1 }()

	if depth <= 0 {
		return
	}
	body, urls, err := fetcher.Fetch(url)
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Printf("found: %s %q\n", url, body)
	for _, u := range urls {
		urldata <- &UrlData{u, depth-1}
	}
	return
}
```

修改main函数，加入对goroutine的控制：

``` go
func main() {
	urldata := make(chan *UrlData)
	quit := make(chan int)

	go Crawl("http://golang.org/", 4, fetcher, urldata, quit)

	for i:=1; i>0; {
		select {
		case <-quit:
			i--
		case url := <-urldata:
			go Crawl(url.url, url.depth, fetcher, urldata, quit)
			i++
		}
	}
}
```

这样，整个程序在流程上就没有问题了。

## 加入cache，对同一网址只Crawl一遍

因为所有Crawl都是由main函数控制的，因此这个改动只在main里修改即可：

``` go
func main() {
	urldata := make(chan *UrlData)
	quit := make(chan int)
	url_cache := make(map[string]bool)

	url_cache["http://golang.org/"] = true
	go Crawl("http://golang.org/", 4, fetcher, urldata, quit)

	for i:=1; i>0; {
		select {
		case <-quit:
			i--
		case url := <-urldata:
			if url_cache[url.url] {
				break
			}
			url_cache[url.url] = true
			go Crawl(url.url, url.depth, fetcher, urldata, quit)
			i++
		}
	}
}
```

url_cache是一个key为string，value为bool的map，在有新的url传入时，先以url为key，检查其value是否为true。如果为true说明已经Crawl过，不再处理，如果为false，先将value设置为true，然后启动Crawl对这个url进行抓取。

## 重构，DRY

你注意到了么？main函数里有两个地方对url_cache进行操作并启动Crawl。一个是在for循环外面，设置启动url，另一个是在for循环里面，处理新的url。这两个地方所做的事情，本质上都是对一个新url的处理，但为什么要写两遍呢？现在就来试试能不能将其合并：

``` go
func main() {
	urldata := make(chan *UrlData)
	quit := make(chan int)
	url_cache := make(map[string]bool)

	go func() { urldata <- &UrlData{"http://golang.org/", 4} }()

Loop:
	for i := 0; ; {
		select {
		case <-quit:
			i--
			if i == 0 {
				break Loop
			}
		case url := <-urldata:
			if url_cache[url.url] {
				break
			}
			url_cache[url.url] = true
			go Crawl(url.url, url.depth, fetcher, urldata, quit)
			i++
		}
	}
}
```

利用已有的urldata chan，将初始url和depth作为参数传入，就可以去掉for外面的Crawl启动代码。不过，由于for的条件判断是前置判断，而go不支持do...while式的后置判断循环，所以for的终止条件只能移入for的内部，否则`for i:=0; i<0;`将不会进入循环。

## 抽象接口

对这道题来说，做完上面的部分，就已经完成了所有任务。不过从设计的角度，这个程序的输入和输出都混在一起（不会有真的只是打印就完事的抓取程序吧？）。能不能实现一个更好的接口呢？

先来设想一下使用的情况。一个简洁好用的接口应该是什么样子的呢？下面的样子是不是足够简洁呢？

``` go
func main() {
	for data := range CrawlWeb("http://golang.org/", fetcher) {
		if data.err == nil {
			fmt.Println("found:", data.url, data.body)
		} else {
			fmt.Println("not found:", data.url)
		}
	}
}
```

显然，为了实现并行，CrawlWeb应该返回一个chan，这个chan包含了抓取的相关信息：

``` go
type FetchData struct {
	err os.Error
	url string
	body string
}
```

对应修改Crawl的输出方式，使其不再直接Println结果，而是将结果打包，传入data chan作为输出：

``` go
func Crawl(url string, depth int, fetcher Fetcher, data chan<- *FetchData, new_url chan<- *UrlData, quit chan<- int) {
	defer func() { quit <- 1 }()

	if depth <= 0 {
		return
	}
	body, urls, err := fetcher.Fetch(url)
	data <- &FetchData{err, url, body}

	for _, u := range urls {
		new_url <- &UrlData{u, depth - 1}
	}
	return
}
```

由于在现在的main里，调用CrawlWeb后函数需要立刻返回，因此原先的for循环需要跑在一个单独的goroutine里，不能阻塞CrawlWeb的调用。为了清晰，将循环部分单独写成一个函数：

``` go
func CrawlLoop(url chan *UrlData, output chan<- *FetchData, fetcher Fetcher) {
	defer func() { close(output) }()

	url_cache := make(map[string]bool)
	quit := make(chan int)

	for i := 0; ; {
		select {
		case <-quit:
			i--
			if i == 0 {
				return
			}
		case data := <-url:
			if url_cache[data.url] {
				break
			}
			url_cache[data.url] = true
			go Crawl(data.url, data.depth, fetcher, output, url, quit)
			i++
		}
	}
}
```

CrawLoop在退出时会close(output)，来结束main里的range循环。

剩下的，就是如何用CrawlWeb来启动CrawlLoop，并将output chan作为返回值，返回给外面的range了：

``` go
func CrawlWeb(start_url string, depth int, fetcher Fetcher) <-chan *FetchData {
	output := make(chan *FetchData)
	url := make(chan *UrlData)

	go CrawlLoop(url, output, fetcher)

	url <- &UrlData{start_url, depth}

	return output
}
```

对于CrawlLoop这个函数，作为goroutine启动后，可以将url chan视为输入，output chan视为输出，当给url chan传入数据时，启动CrawlLoop的真正执行，结果会在执行过程中从output中逐项输出。由于并发的因素，和传统函数调用不同，输出不是等待函数结束后一次性输出，而是在函数的执行过程中，output随时会输出结果，当函数执行完毕后关闭output。

## 收工

最后，贴上修改后的所有代码。为了测试是否真正实现并行，我加入了一部分假数据。那么，如何测试是否真的实现了并发呢？有兴趣的可以自己动手实验一下。

``` go
package main

import (
	"os"
	"fmt"
)

type Fetcher interface {
	// Fetch returns the body of URL and
	// a slice of URLs found on that page.
	Fetch(url string) (body string, urls []string, err os.Error)
}

type UrlData struct {
	url   string
	depth int
}

type FetchData struct {
	err os.Error
	url string
	body string
}

// Crawl uses fetcher to recursively crawl
// pages starting with url, to a maximum of depth.
func Crawl(url string, depth int, fetcher Fetcher, data chan<- *FetchData, new_url chan<- *UrlData, quit chan<- int) {
	// TODO: Fetch URLs in parallel.
	// TODO: Don't fetch the same URL twice.
	// This implementation doesn't do either:
	defer func() { quit <- 1 }()

	if depth <= 0 {
		return
	}
	body, urls, err := fetcher.Fetch(url)
	data <- &FetchData{err, url, body}

	for _, u := range urls {
		new_url <- &UrlData{u, depth - 1}
	}
	return
}

func CrawlLoop(url chan *UrlData, output chan<- *FetchData, fetcher Fetcher) {
	defer func() { close(output) }()

	url_cache := make(map[string]bool)
	quit := make(chan int)

	for i := 0; ; {
		select {
		case <-quit:
			i--
			if i == 0 {
				return
			}
		case data := <-url:
			if url_cache[data.url] {
				break
			}
			url_cache[data.url] = true
			go Crawl(data.url, data.depth, fetcher, output, url, quit)
			i++
		}
	}
}

func CrawlWeb(start_url string, depth int, fetcher Fetcher) <-chan *FetchData {
	output := make(chan *FetchData)
	url := make(chan *UrlData)

	go CrawlLoop(url, output, fetcher)

	url <- &UrlData{start_url, depth}

	return output
}

func main() {
	for data := range CrawlWeb("http://golang.org/", 4, fetcher) {
		if data.err == nil {
			fmt.Println("found:", data.url, data.body)
		} else {
			fmt.Println("not found:", data.url)
		}
	}
}

// fakeFetcher is Fetcher that returns canned results.
type fakeFetcher map[string]*fakeResult

type fakeResult struct {
	body string
	urls []string
}

func (f *fakeFetcher) Fetch(url string) (string, []string, os.Error) {
	if res, ok := (*f)[url]; ok {
		return res.body, res.urls, nil
	}
	return "", nil, fmt.Errorf("not found: %s", url)
}

// fetcher is a populated fakeFetcher.
var fetcher = &fakeFetcher{
	"http://golang.org/": &fakeResult{
		"The Go Programming Language",
		[]string{
			"http://golang.org/pkg/",
			"http://golang.org/cmd/",
		},
	},
	"http://golang.org/pkg/": &fakeResult{
		"Packages",
		[]string{
			"http://golang.org/",
			"http://golang.org/cmd/",
			"http://golang.org/pkg/fmt/",
			"http://golang.org/pkg/os/",
		},
	},
	"http://golang.org/pkg/fmt/": &fakeResult{
		"Package fmt",
		[]string{
			"http://golang.org/",
			"http://golang.org/pkg/",
		},
	},
	"http://golang.org/pkg/os/": &fakeResult{
		"Package os",
		[]string{
			"http://golang.org/",
			"http://golang.org/pkg/",
		},
	},
	"http://golang.org/cmd/": &fakeResult{
		"Commands",
		[]string{
			"http://golang.org/cmd/6g",
			"http://golang.org/cmd/8g",
			"http://golang.org/cmd/",
			"http://golang.org/",
		},
	},
	"http://golang.org/cmd/6g": &fakeResult{
		"Command 6g",
		[]string{
			"http://golang.org/cmd/",
			"http://golang.org/",
		},
	},
}
```
