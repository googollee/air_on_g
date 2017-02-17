+++
date = "2004-10-18T20:00:00+08:00"
title = "内核printf源代码分析"
category = "development"
tags = ["c", "printf"]
+++

对VC里printf的实现的分析。

<!--more-->

在stdio.c里找到了printf的实现代码.首先看看对printf的定义:

``` c
int printf (const char *cntrl_string, ...)
```

第一个参数cntrl_string是控制字符串,也就是平常我们写入%d,%f的地方.紧接着后面是一个变长参数.

看看函数头部的定义:

``` c
  int pos = 0, cnt_printed_chars = 0, i;
  unsigned char* chptr;
  va_list ap;
```

马上晕!除了ap我们可以马上判断出来是用来读取变长参数的,i用于循环变量.其他变量都不知道是怎么回事.不要着急,我们边看代码边分析.代码的第一行必然是

``` c
va_start (ap, cntrl_string);
```

用来初始化变长参数.

接下来是一个while循环

``` c
while (cntrl_string[pos]) {
...
}
```

结束条件是cntrl_string[pos]为NULL,显然这个循环是用来遍历整个控制字符串的.自然pos就是当前遍历到的位置了.进入循环首先闯入视线的是

``` c
if (cntrl_string[pos] == '%') {
     pos++;
     ...
}
```

开门见山,上来就当前字符是否办断是否%.一猜就知道如果成立pos++马上取出下一个字符在d,f,l等等之间进行判断.往下一看,果真不出所料:

``` c
switch (cntrl_string[pos]) {
    case 'c':
...
    case 's':
...
    case 'i':
...
    case 'd':
...
    case 'u':
...
```

用上switch-case了. 快速浏览一下下面的代码.

首先看看case 'c'的部分

``` c
case 'c':
 putchar (va_arg (ap, unsigned char));
 cnt_printed_chars++;
 break;
```

%c表示仅仅输出一个字符.因此先通过va_arg进行参数的类型转换,之后用putchar[1]输出到屏幕上去.之后是cnt_printed_chars++,通过这句我们就可以判断出cnt_printed_chars使用来表示,已经被printf输出的字符个数的.

再来看看 case 's':

``` c
case 's':
 chptr = va_arg (ap, unsigned char*);
 i = 0;
 while (chptr [i]) {
   cnt_printed_chars++;
   putchar (chptr [i++]);
 }
 break;
```

和case 'c',同出一辙.cnt_printed_chars++放在了循环内,也证明了刚才提到的他的作用.另外我们也看到了cnptr是用来在处理字符串时的位置指针.到此为止,我们清楚的所有变量的用途,前途变得更加光明了.

接下来:

``` c
// PartI
      case 'i':
      case 'd':
 cnt_printed_chars += printInt (va_arg (ap, int));
 break;
      case 'u':
 cnt_printed_chars += printUnsignedInt (va_arg (ap, unsigned int));
 break;
      case 'x':
 cnt_printed_chars += printHexa (va_arg (ap, unsigned int), 'x');
 break;
      case 'X':
 cnt_printed_chars += printHexa (va_arg (ap, unsigned int), 'X');
 break;
      case 'o':
 cnt_printed_chars += printOctal (va_arg (ap, unsigned int));
 break;
// Part II
 case 'p':
 putchar ('0');
 putchar ('x');
 cnt_printed_chars += 2; /* of '0x' */
 cnt_printed_chars += printHexa (va_arg (ap, unsigned int), 'x');
 break;
      case '#':
 pos++;
 switch (cntrl_string[pos]) {
 case 'x':
   putchar ('0');
   putchar ('x');
   cnt_printed_chars += 2; /* of '0x' */
   cnt_printed_chars += printHexa (va_arg (ap, unsigned int), 'x');
   break;
 case 'X':
   putchar ('0');
   putchar ('X');
   cnt_printed_chars += 2; /* of '0X' */
   cnt_printed_chars += printHexa (va_arg (ap, unsigned int), 'X');
   break;
 case 'o':
   putchar ('0');
   cnt_printed_chars++;
   cnt_printed_chars += printOctal (va_arg (ap, unsigned int));
   break;
```

注意观察一下,PartII的代码其实就是比PartI的代码多一个样式.在16进制数或八进制前加入0x或是o,等等.因此这里就只分析一下PartI咯.

其实仔细看看PartI的个条case,也就是把参数分发到了更具体的函数用于显示,然后以返回值的形式返回输出个数.对于这些函数就不具体分析了.我们先来看看一些善后处理:

先看case的default处理.

``` c
default:
 putchar ((unsigned char) cntrl_string[pos]);
 cnt_printed_chars++;
```

就是直接输出cntrl_string里%号后面的未知字符.应该是一种容错设计处理.

再看看if (cntrl_string[pos] == '%')的else部分

``` c
else {
      putchar ((unsigned char) cntrl_string[pos]);
      cnt_printed_chars++;
      pos++;
 }
```

如果不是%开头的,那么直接输出这个字符.

最后函数返回前

``` c
  va_end (ap);
  return cnt_printed_chars;
```

va_end处理变长参数的善后工作.并返回输出的字符个数.

在最后我们有必要谈谈putChar函数以及基本输出的基础函数printChar,先来看看putChar

``` c
int putchar (int c) {
  switch ((unsigned char) c) {
  case '\n' :
    newLine ();
    break;
  case '\r' :
    carriageReturn ();
    break;
  case '\f' :
    clearScreen ();
    break;
  case '\t' :
    printChar (32); printChar (32); /* 32 = space */
    printChar (32); printChar (32);
    printChar (32); printChar (32);
    printChar (32); printChar (32);
    break;
  case '\b':
    backspace ();
    break;
  case '\a':
    beep ();
    break;
  default :
    printChar ((unsigned char) c);
  }
  return c;
}
```

通览一下,也是switch-case为主体的.主要是用来应对一些特殊字符,如\n,\r,....这里需要提一下,关于\t的理解.有些人认为\t就是8个space,有些人则认为,屏幕分为10大列(每个大列8个小列总共80列).一个\t就跳到下一个大列输出.也就是说不管你现在实在屏幕的第1,2,3,4,5,6,7位置输出字符,只要一个\t都在第8个位置开始输出. VS.NET中就是用的这种理解.因此如果按照这个理解的话,\t的实现可以这样

``` c
int currentX = ((currentX % 10) + 1) * 8;
```

然后在currentX位置输出.

接下来看printChar也就是输出部分最低层的操作咯

``` c
void printChar (const byte ch) {
  *(word *)(VIDEO + y * 160 + x * 2) = ch | (fill_color << 8);
  x++;
  if (x >= WIDTH)
    newLine ();
  setVideoCursor (y, x);
}
```

这里VIDEO表示显存地址也就是0xB8000.通过`y * 160 + x`屏幕`(x,y)`坐标在显存中的位置.这里需要知道,一个字符显示需要两个字节,一个是ASCII码,第二个是字符属性代码也就是颜色代码.因此才必须`y * 80 * 2 + x = y * 160 + x`.那么`ch | (fill_color << 8)`也自然就是写入字符及属性代码用的了.每写一个字符光标位置加1,如果大于屏幕宽度WIDTH就换行.最后通过setVideoCursor设置新的光标位置.完成了整个printChar过程.

到此,把printf从上到下说了一遍.不知道各位大家感觉如何,如果说得不清楚还大家多提意见.有说得不对的地方请大家多多指教.
