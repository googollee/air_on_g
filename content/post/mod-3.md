+++
date = "2005-02-04T20:00:00+08:00"
title = "求3的余数"
category = "development"
tags = ["mod", "c", "interview"]
+++

北京华为的一道面试题。要求是只使用+-*和移位运算，且不能递减3求得余数。

<!--more-->

先在csdn上求，求得以下算法：

``` c
int i, m, n, p, q;
int yushu[]={1, 2};
m = n;
while(m>3)
{
 i=0;  q=0;
 while(m)
 {
  i&=0x1;
  q+=(m&0x1)*yushu[i++];
  m>>=1;
 }
 m=q;
}
```

没看懂，倒是提示我可以用查表的方法，变成求4的余数。自己探求程序如下：

``` c
int mo[]={0,1,2,0};
int i, m;
m = n;
i = 4;
while (i>3)
{
 i = 0;
 while(m>0)
 {
  i += m & 3;
  m >>= 2;
 }
 m = i;
}
```

貌似比网上高人给的算法效率更高，可惜没去证实。

晚上又想到更高效的算法：

``` c
int mo[]={0,1,2,0};
int m;
while(m>3)
{
 m = (m>>2) + (m&3);
}
```

想来不会有更高效的做法了，于是开始这种算法的数学证明，如下：

因为`4 mod 3=1`，所以`4^k mod 3 = 1^k mod 3`（此原理来源于小学数学奥校五年级分册= =|||），所以对任意数n，转化成4进制数后每位为n1 n2 n3 n4...nm，有

    (n1*4^(m-1)+n2*4^(m-2)+n3*4^(m-3)+n4*4^(m-4)+...+nm-1*4^1+nm*4^0) mod 3
    =n1*4^(m-1) mod 3+n2*4^(m-2) mod 3+n3*4^(m-3) mod 3+n4*4^(m-4) mod 3+...+nm-1*4^1 mod 3+nm*4^0 mod 3
    =n1*1^(m-1) mod 3+n2*1^(m-2) mod 3+n3*1^(m-3) mod 3+n4*1^(m-4) mod 3+...+nm-1*1^1 mod 3+nm*1^0 mod 3
    =(n1+n2+n3+n4+...+nm-1+nm) mod 3

因此对数n每次取二进制最后两位（四进制的最后一位），并加入除去二进制最后两位的余数（相当于右移2位），如此反复，直到只剩最后两位，此两位二进制数与原数n同余于3。

现在研究的是，求任意数的余数的高效算法是什么呢？
