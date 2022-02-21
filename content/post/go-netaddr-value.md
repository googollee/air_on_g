---
title: "Go 1.18新库netaddr里的intern.Value"
date: 2022-02-20T17:37:40+01:00
categories:
 - 开发
tags:
 - go
 - unsafe
featured_image: /images/go-netaddr-value.jpg
author: "Googol Lee"
---

Go 1.18引入了新库`netaddr`来表示IP地址及相关操作。其作者Brad Fitzpatrick专门写了篇[blog](https://tailscale.com/blog/netaddr-new-ip-type-for-go/)说明这个库的设计原则和最终实现。

这个实现最主要的特性依赖[intern.Value](https://pkg.go.dev/go4.org/intern)这个库。这里记录一下我对这个库的一些研究和看法

<!--more-->

`netaddr`的设计原则是希望一个类型可以同时支持IPv4，无区域IPv6以及有区域IPv6，同时希望这个类型是一个值类型，可以使用`==`进行正确的比较，且内存占用尽量小。这个要求确实很难。具体的设计过程可以去参考库作者的blog。

最终的实现结果：

```go
type IP struct {
    addr uint128
    z    *intern.Value // zone and family
}
```

其中`addr`用来保存实际的IP地址（如果是IPv4，则只使用低32位），`z`即作为一个标志位，用来区分IPv4，无区域IPv6及有区域IPv6，同时也用来记录区域信息。由于区域信息可以是任意字符串，正确的实现要求`intern.Value`在具有相同内容的字符串时，指向相同的地址。

这里的`z`没有使用字符串，我猜是为了尽量压缩IP结构的大小。Go一个字符串会固定占用16byte（内部一个指向[]byte的指针，一个int表是字符串长度），比指针8byte要大一倍。不过使用字符串会让实现更容易理解：

```go
type IP struct {
    addr uint128
    z    string // "4" for IPv4, "6" for IPv6 without zone, "6eth0" for IPv6 with zone 'eth0'.
}
```

除了比原来的结构多了8byte，也做到了其余的目标。

下面看看`intern.Value`是如何在节省8byte情况下，实现同样的功能。根据功能`在具有相同内容的字符串时，指向相同的地址`，一个非常直白的实现是这样的：

```go
var values = map[string]*string

func Get(s string) *string {
  if _, ok := values[s]; !ok {
    values[s] = &s
  }
  return values[s]
}
```

不考虑并发，这个实现最大的问题是内存泄漏。所有Get返回的指针，都会被values持久引用。要解决内存泄漏问题，需要请出unsafe库。这就很接近`intern.Value`的实现：

```go
var valMap  = map[key]uintptr{}

type Value struct {
  s           string
	resurrected bool
}

func Get(s string) *Value {
  var v *Value

  if addr, ok := valMap[k]; ok {
    v = (*Value)((unsafe.Pointer)(addr))
    v.resurrected = true
  }
  if v != nil {
    return v
  }

  v = &Value{
    s: s,
    resurrected: true,
  }

  // SetFinalizer before uintptr conversion (theoretical concern;
  // see https://github.com/go4org/intern/issues/13)
  runtime.SetFinalizer(v, finalize)
  valMap[k] = uintptr(unsafe.Pointer(v))

  return v
}

func finalize(v *Value) {
  if v.resurrected {
    // 程序在这次GC时引用过v
    // 下轮GC再检查
    v.resurrected = false
    runtime.SetFinalizer(v, finalize)
    return
  }
  delete(valMap, v.s)
}
```

`valMap`并没有引用`Value`，只是用`unsafe.Pointer`的方式记录下了`Value`的地址。当外部所有对`Value`的引用失效后，GC过程会触发`finalize`做检查。如果两轮`finalize`后`Value`还没有被引用过，则从`valMap`里删除对应的记录地址。`Value`会在再下一次的GC过程中（因为这次没有挂接`finalize`）被删除。

如果再加上保护并发的锁，就和`intern.Value`的实现差不多了。`intern.Value`还考虑了非字符串值的情况。

这里如此麻烦的原因，在于`==`只能做一层实例值比较，也不能自定义。考虑到自定义`==`带来的问题，这种unsafe的交换大概还能承受。

一个漏洞，如果有外部程序也通过`unsafe.Pointer`记录了某个`Value`的地址，那么有可能过一段时间后，具有同样内容的`Value`地址会变化。

说实话，我不太喜欢`intern.Value`的实现。可能底层库真的很缺这8byte的大小吧。
