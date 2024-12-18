+++
date = "2011-12-22T20:00:00+08:00"
title = "到底应该怎么存密码"
category = "development"
tags = ["security"]
+++

最近各大网站频频爆出密码泄露的事情，搞得用户“改密码改到手软”。先姑且不说一些政治上的因素导致网站必须保存明文的情况，到底应该如何保存密码，才能保证即便数据库内容被盗，用户的密码本身也是安全的呢？

说到这个问题，先要明确一些原则的问题，然后才能讨论具体的解决方法。

<!--more-->

## 密码安全原则

1. 非用户本人，不能拿到网站保存的用户密码（不管是明文形式的还是密文形式的）。

2. 如果拿到网站保存的用户密码，不能直接或者间接推算出用户密码原文（这一条排除保存明文以及任何可还原的加密方法）

3. 对密文的暴力破解有一定难度。（暴力破解一般指用字典枚举可能的密码，如果与密文正确匹配，即为破解成功）

4. 不同用户，即便密码内容一样，保存的密文也应该不一样。（防止非正常手段拿到密文后，根据概率来猜测密码）

5. 即便在有人知道网站的加密算法，甚至是加密程序的源代码的情况下，依旧无法通过密文直接得到原文，且对暴力破解密文有一定难度。

这5条原则的强度是逐条递增的。网上的网站教学一般能实现到第4条，第5条是我在翻Rails源码的时候发现的。而这次泄漏密码的那些网站，大概只实现了第1条原则吧。

## 密码存储算法

第1条原则其实是由网站的认证体系保证的，与存储无关。这条十分重要，而且也有大家都不注意的地方，比如实现“记住登录用户”时，cookie对用户身份和验证方法的保存。时刻牢记cookie也是可以随意访问和泄漏的。再有就是密码的传输过程，如果被监听，是否会泄漏明文。以及中间人攻击和钓鱼这些方法，都会导致非用户本人拿到用户密码明文。但是这个和密码的存储关系不大，在此略过。

为了实现第2条，在存储密码时绝对不能保存明文，也绝不能保存任何对称加密或者非对称加密算法算出的密文。因为不管对称加密还是非对称加密，密文和明文都是一一对应，在数据库整体泄漏，被人拿到大量用户密码的时候，这种一一对应有可能通过概率等手段破译。比如可以根据这次泄漏的密码，选取使用人数最多的密码作为明文，假设其经过加密后与泄漏数据库里密文最高的密文对应的明文一致，就可以慢慢尝试各种加密算法，来找出真正的算法，完成破译。

应该使用的加密方法，是称作摘要算法的一套算法。这类算法并不保留所有的原文信息，而是类似原文的特征值。通过原文可以算出唯一特征值，但是通过特征值无法得到唯一的原文。目前广泛采用的摘要算法有MD5和SHA1。存储密码一般使用MD5。后文还将介绍blowfish算法的password-hash算法（以下简称blowfish算法），用作密码存储时有更好的效果。

使用摘要算法加密密码明文，验证的时候，将用户输入的密码再用摘要算法处理一次，将处理后的密文与保存后的密文相比较，如果一致就认为密码有效。由于摘要算法无法保证一对一的加密，因此确实可能出现两个密码明文对应同一个密文的情况。但由于算法本身的强度，保证这两个明文一定相差“非常大”，从一个明文开始，按顺序暴力穷举，在一定时间内是无法碰上的。由于这种强度需要算法保证，所以一定要使用经过验证的摘要算法。上文提到的MD5，SHA1和blowfish，都是经过实际生产环境验证的算法，在现阶段可以安全使用。（随着计算机速度的提高，这些算法终有失效，也就是碰撞破译速度足够快的一天，不过到时就会有新的算法出现了。）

对于第3条，由于有些简单密码有很多人用（别笑，历史上泄漏密码很多次了，但这类简单密码依旧有大量的使用者），破译者就可以预先算出这些密码的MD5值或者SHA1值。之后只要看到这些值，就可以用简单密码通过验证。这就为暴力破解提出了新的要求。

为了防止这种常见密码形成常见密文，可以对密码进行n次加密，也就是在求得一次密文后，对密文再进行一次摘要算法。这样保存的密文就不会形成常见密文。

但是n次加密，对于同样的密码明文，生成的密文依旧是相同的。为了保证同样的明文生成的密文不同，也就是第4条原则，在每次加密密码时，生成一段随机字符串，称作“盐”，把这个随机“盐”拼接到密码明文上，再将拼接后的字符作为整体进行加密。保存的时候不仅要保存加密后的密文，也要保存“盐”。这个过程也可以称作“加点盐”（注意不是“加碘盐”）。

“加盐”的过程，不仅能防止不同用户同样的密码明文生成同样的密文，也可以防止形成“常见密文”，同时满足第3条和第4条原则，因此只采用“加盐”，不采用n次加密也是可行的。rails3的默认密码策略就采用“加盐”后的一次blowfish加密。而wordpress的密码，在“加盐”后，依旧进行了8重MD5加密。

第5条是一条隐藏的更深的原则。如果有人拿到了密码密文和程序的加密算法，理论上，只要有足够的时间，可以通过列举所有可能的密码明文，来找出密文对应的密码。但是毕竟加密算法是需要时间的，如果这个算法足够的“慢”，而且最好随着电脑速度的提升，算法的速度提升不明显（如果电脑速度提升随时间是线性O(n)关系，算法的效率只要达到O(nlogn)或者O(n^2)，就能实现这种不明显的提升），那么就能大大延长列举破解的时间，也就具有更强的安全性。blowfish就是这么一个算法。对比MD5和SHA1，blowfish的加密速度足够慢，但又没有慢到单次无法忍受的地步。MD5，SHA1和blowfish对同一字符串执行1000次加密的速度对比如下：

``` ruby
require 'benchmark'

def get_rand_str(size = 10)
  chars = 'abcdefghjiklmnopqrstuvwxyzABCDEFGHJIJKLMNOPQRSTUVWXYZ1234567890!@#%^&*()'
  ret = ''
  size.times do
    ret << chars[rand(chars.size - 1)]
  end
  ret
end

Benchmark.bm(5) do |x|
  str = 'some string need be crypted.'
  loop_count = 1000

  x.report('md5') do
    require 'digest/md5'
    loop_count.times do
      salt = get_rand_str
      "$#{salt}$#{Digest::MD5.hexdigest(str + salt)}"
    end
  end

  x.report('sha1') do
    require 'digest/sha1'
    loop_count.times do
      salt = get_rand_str
      "$#{salt}$#{Digest::SHA1.hexdigest(str + salt)}"
    end
  end

  x.report('blowfish') do
    require 'bcrypt'
    loop_count.times do
      BCrypt::Password.create(str)
    end
  end
end
```

               user     system      total        real
    md5    0.010000   0.010000   0.020000 (  0.026685)
    sha1   0.010000   0.000000   0.010000 (  0.012632)
    blowfish  85.100000   0.180000  85.280000 ( 87.112666)

可见blowfish与MD5和SHA1比起来确实相当慢。正因如此，blowfish被OpenBSD采用作为其密码加密算法，而Rails3的has_secure_password也是用的blowfish。

## 密码存储算法的实现

算法的实现与语言本身紧密相关。不过，如果语言提供了blowfish的算法库，直接使用这个库是最好的方法。Ruby的实现如下：

``` ruby
require 'bcrypt'

password_digest = BCrypt::Password.create(password) # 根据明文password生成密文password_digest

BCrypte::Password.new(password_digest) == password  # 根据密文password_digest验证明文password是否有效
```

如果使用Rails3，可以在Model上直接加入has_secure_password，即可支持blowfish算法实现的密码存储。Model需要提供名为password_digest的字符串域。

对于php，可以直接使用wordpress实现的密码类[class-phpass.php](http://core.trac.wordpress.org/browser/trunk/wp-includes/class-phpass.php)：

``` php
$hasher = new PasswordHash(8, TRUE);

$password_digest = $hasher->HashPassword($password);  // 根据明文$password生成密文$password_digest

$hasher->CheckPassowrd($password, $password_digest);  // 根据密文$password_digest验证明文$password是否有效
```
