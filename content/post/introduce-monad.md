+++
date = "2007-12-31T16:11:00+08:00"
title = "通过context/defer/promise介绍monad"
category = "development"
tags = ["monad", "type_system"]
+++

```go
func DeferUsage() {
  from, _ := os.Open('/proc/stat')
  defer from.Close()

  to, _ := ioutil.TempFile("", "defer")
  defer to.Close()
}
```

```go
func DeferUsage() {
  deferMonad := defer.Background()

  from, _ := os.Open('/proc/stat')
  deferMonad = defer(deferMonad, from.Close)

  to, _ := ioutil.TempFile("", "defer")
  deferMonad = defer(deferMonad, to.Close)
}
```

```go
func DeferUsage() {
  defer.Background().Call(func() {
    from, _ := os.Open('/proc/stat')
    return from.Close
  }).Call(func() {
    to, _ := ioutil.TempFile("", "defer")
    return to.Close
  }).Do()
}
```

```go
func ContextHandler() {
  timeout := 10*time.Second

  ctx := context.Background()
  ctx = context.WithValue(ctx, "user", "id-123")
  ctx1, cancel1 := context.WithTimeout(ctx, timeout)
  done := make(chan bool)
  go func() {
    fork1(ctx1)
    close(done)
  }()

  select {
  case <-done:
    // succeed
  case <-time.After(timeout):
    // timeout
  }
  cancel1()
}
```

```go
func ContextHandler() {
  timeout := 10*time.Second

  ctx := context.Background()

  ctx = context.WithValue(ctx, "user", "id-123")

  ctx1, cancel1 := context.WithTimeout(ctx, timeout)

  // ...
}
```

```js
function promise() {
  return readFile("~/data.js")
    .then(JSON.parse)
    .resolve();
}
```

```go
func Promise() {
  p := promise.Background()

  p = readFile("~/data.js")

  p = promise.Then(p, JSON.parse)

  return p.resolve()
}
```
