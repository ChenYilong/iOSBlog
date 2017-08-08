### 防 DNS 污染方案

## IM系列文章

IM系列文章分为下面这几篇：

 -  [《IM 即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）》](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md) 
 - [《技术实现细节》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/技术实现细节.md ) 
 - [《有一种 Block 叫 Callback，有一种 Callback 做 CompletionHandler》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/有一种%20Block%20叫%20Callback，有一种%20Callback%20做%20CompletionHandler.md ) 
 - [《防 DNS 污染方案》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/防%20DNS%20污染方案.md ) （本文）

本文是第四篇。

## 正文

DNS出问题的概率其实比大家感觉的要大，首先是DNS被劫持或者失效，2015年初业内比较知名的就有 Apple 内部 DNS 问题导致 App Store、iTunes Connect 账户无法登录；京东因为 CDN 域名付费问题导致服务停摆。

另一个常见问题就是 DNS 解析慢或者失败，例如国内中国运营商网络的 DNS 就很慢，一次 DNS 查询的耗时甚至都能赶上一次连接的耗时，尤其 2G 网络情况下，DNS 解析失败是很常见的。因此如果直接使用 DNS，对于首次网络服务请求耗时和整体服务成功率都有非常大的影响。

DNS 劫持、污染一般是针对递归 DNS 服务器的 DNS 劫持攻击，

 > DNS 系统中有两种服务角色：递归 DNS 和授权 DNS。本质上来说，授权 DNS 控制网站的解析；递归 DNS 只起缓存的作用。所以跟广大站长关系比较大的是授权 DNS，也就是在域名注册商处填写的 DNS 地址。而网民使用的则是递归 DNS。
见：https://support.dnspod.cn/Kb/showarticle/tsid/186/

现实中的问题：

 - DNS解析时间过长
 像 iOS 系统一般是24小时之后会过期，还有进入飞行模式再切回来，开关机，重置网络设置等也会导致DNS cache的清除。所以一般情况下用户在第二天打开你的app都会经历一次完整的DNS解析请求，网络情况差的时候会明显增加应用请求的总耗时。

 - DNS劫持，不可以被信任的运营商，不可以被信任的 DNS 解析服务。
 
 DNS 在设计之初是基于 UDP 的，显然这样的设计不能满足当今社会的准确性的需求，于是涌现了如 DNSPod 这样的基于 HTTP 的 DNS 解析服务。但是当时为什么这样设计，实际也很好理解，UDP 效率高，一来一回网络上传输的只有两个包，而 HTTP则需要三次握手三个包，再一拆包，就需要四个包。这是受限于当时整个社会的带宽水平较低，而现在没人会感激 UDP 所节省的流量，所有人都在诟病DNS污染问题。

图为360向大家们示范什么是 DNS 劫持:

![](http://ww3.sinaimg.cn/large/7853084cjw1f7yp6lxqikj20vp0iwgn3.jpg)

运营商 DNS 劫持问题中，中国移动最为严重，

某些地区的中国移动还有个简单粗爆的域名检查系统，包含 av 字样的域名一率返回错误的 IP，

LeanCloud 之前叫做 AVOSCLoud，域名是：https://cn.avoscloud.com，嗯，我们很受伤。
后来我们改名了，域名也切换到了 api.leancloud.cn ，我们用户的 DNS 问题已经大大的减少了。

鬼知道我们经历了什么。

虽然这个事件并不典型，但也足以说明，这个一个不可靠的服务，你无法掌控它的拦截规则。

而且黑产与各地运营商的一些“合作”也会导致 DNS 劫持。

原有的解决方法：简单粗暴投诉运营商。

#### 传统的解决方法：投诉

诊断方法步骤：

 * iOS 用户推荐 iNetTools
 * Android 用户推荐 LanDroid

 ping 响应时间，100（单位默认为 ms）以下都是可以接受的，高于 100 ms 会感到缓慢

 移动环境下，向中国移动打 10086 电话投诉，告之受影响的域名及 DNS 服务器的 IP，才能解决问题。
 如果是在无线网络情况下， DNS 异常，则请通过路由器的 DHCP 设置，将默认的 DNS 修改为正常的 DNS（推荐 114.114.114.114），并重启路由器即可。

投诉到中国移动后 48 小时问题仍未解决的话，依据中国相关法律法规规定，可以向工信部申诉，网址是 http://www.chinatcc.gov.cn:8080/cms/shensus/ ，这里最好是以邮件的方式申诉，将具体细节和截图写在邮件里发送给 accept@chinatcc.gov.cn，工信部的相关同学最早会在第 2 天回电话并催促中国移动。

申诉邮件的内容需要包括两个部分:
一是申诉者的姓名、身份证号码、通信地址、邮编、联系电话、申诉涉及到的电话号码、电子邮件、申诉日期 
二是被申诉企业名称、申诉内容（详情）、是否向企业申诉过（一定要先向企业投诉，无效后工信部才能受理，直接找工信部的不受理），最后要承诺「我承诺申诉信息真实有的」

这样显然不是长久之计，下面就介绍下如何用技术手段去解决：

#### IP 直连在IPv6 环境下的可行性

首先：**所有防 DNS 方案都是基于IP直连的方案**，那么就要首先介绍 IP 直连这个方案的可行性。

从2016年6月1日起，iOS 应用必须支持 IPv6，否则审核将被拒。IPv6 规则出来后，网上有一种言论称：IP 直连不可行。

其实是 IP 直连，在 IPv6 环境下也是可行的，下面做下说明：

IP或域名在到达服务器前，经历了两个步骤往往会被我们所忽略：

![](http://ww2.sinaimg.cn/large/801b780ajw1f88e1wjs95j20i70afdgw.jpg)

如果你拿一个 IPv4 的 IP 或域名进行请求，在 IPv6-Only 环境下，有两个机制可以保证最终能够到达 Server 地址。

第一个机制是绿色部分，指的是 iOS系统级别的 IPv4 兼容方案，只要你使用了 `NSURLSession` 或 `CFNetwork`， 那么 iOS 系统会将帮你把它转为 IPv6 地址。

 > NSURLSession and CFNetwork automatically synthesize IPv6 addresses from IPv4 literals locally on devices operating on DNS64/NAT64 networks.（如果当前网络是 IPv6 网络，那么会在iOS系统层面转换成 IPv6.）

 第二个机制是 DNS 服务的兼容方案，可以是运营商提供的服务，也可以是第三方 DNS 解析机构比如 DNSPod。如果 DNS 解析出来的域名是 IPv4 地址，也会转为 IPv6 兼容的地址。DNS64/NAT64 起到的作用就是将网关的出口地址进行转换，映射到 IPv4 地址上，保证路由能寻址到 IPv4 的地址。

综上所述，IPv6 政策的应对方案可以有下面几种：

 1. 使用高层API，比如 `NSURLSession` and `CFNetwork`。
 2. 升级服务器，让服务端支持 IPv6。在 APP 中替换 IPv4 的地址。
 3. 如果你的 APP 需要使用了更底层的 API 连接到仅支持 IPv4 的服务器，且不使用 DNS 域名解析，请在APP端使用 `getaddrinfo` 处理 IPv4 地址串( `getaddrinfo` 可通过传入一个IPv4或IPv6地址，得到一个 sockaddr 结构链表)。如果当前的网络接口不支持 IPv4，仅支持 IPv6，NAT64和DNS64，这样做可以得到一个合成的IPv6地址。

就目前国内的情况来看，据大部分的服务端器是不支持IPv6的，最后一种方法更加适用。这样一来，服务端完全不用做更改，在服务端看来，客户端是能够正常连接到 IPv4 的地址的。

参考：[《iOS支持IPv6 DNS64/NAT64网络》]( http://www.pchou.info/ios/2016/06/05/ios-supporting-ipv6.html ) 

#### 在 HTTPS 业务场景下的防 DNS 污染方案

防止 DNS 污染的方式有多种：

实现方式大致有两种：

方案一：HTTP 场景 IP 直连

通过IP直接访问网站，可以解决 DNS 劫持问题。如果是 HTTP 请求，使用 ip 地址直接访问接口，配合 header 中 Host 字段带上原来的域名信息即可；

方案二：客户端维护一个 IP 列表

 - 无效映射淘汰机制
 - 使用IP列表避免DNS解析失败或者劫持 (电信、移动、联通，域名异步地去获取)IP地址，请求成功就+1、失败就-1，然后得到优先级列表
 - 根据网络延迟选择服务端IP

参考： [《iOS网络请求优化之DNS映射》]( http://www.jianshu.com/p/ad038ea54310 )。

方案三：使用基于 HTTP 的 DNS 解析方案

对于服务器IP经常变的情况,可能需要使用第三方服务，比如DNSPod、httpDNS。

默认的 DNS 是基于 UDP，改用 HTTP 协议进行域名解析，代替现有基于 UDP 的 DNS 协议，域名解析请求直接发送到指定的第三方 DNS 解析服务器，从而绕过运营商的 Local DNS，能够避免 Local DNS 造成的域名劫持问题和调度不精准问题。

绕过运营商直接连可以信任的第三方服务。

![enter image description here](https://www.dnspod.cn/yantai/img/httpdnsjbyl.png)

那如果这些第三方解析商服务也挂掉了呢？这里有一个折中的方案，你可以两个服务都使用，其中一个作为失败重试的备选项，首选和备选的优先级可以调整。

参考：

  1. [《DNSPod接入指南》]( https://www.dnspod.cn/httpdns/guide ) 
  2. [《腾讯云DNSPod域名解析全面支持IPv6-only》]( http://www.qcloud.com/blog/?p=1234 ) 
  
#### 实现时的问题

发送 HTTPS 请求首先要进行 SSL/TLS 握手，握手过程大致如下：

 1. 客户端发起握手请求，携带随机数、支持算法列表等参数。
 2. 服务端收到请求，选择合适的算法，下发公钥证书和随机数。
 3. 客户端对服务端证书进行校验，并发送随机数信息，该信息使用公钥加密。
 4. 服务端通过私钥获取随机数信息。
 
 ![](http://ww4.sinaimg.cn/large/7853084cjw1f7zvcfp7qij20g40ergnj.jpg)

最后，双方根据以上交互的信息生成session ticket，用作该连接后续数据传输的加密密钥。
上述过程中，和我们的方案有关的是第3步，客户端需要验证服务端下发的证书，验证过程有以下两个要点：

客户端用本地保存的根证书解开证书链，确认服务端下发的证书是由可信任的机构颁发的。
客户端需要检查证书的domain域和扩展域，看是否包含本次请求的host。
如果上述两点都校验通过，就证明当前的服务端是可信任的，否则就是不可信任，应当中断当前连接。

当客户端使用基于HTTP的第三方解析服务解析域名时，请求URL中的host会被替换成解析出来的IP，所以在证书验证的第2步，会出现domain不匹配的情况，导致SSL/TLS握手不成功。

解决方案：

https 请求，需要 `Overriding TLS Chain Validation Correctly`;

如果使用第三方网络库：curl， 中有一个 `-resolve` 方法可以实现使用指定 ip 访问 https 网站,iOS 中集成 curl 库，参考 [curl文档](https://curl.haxx.se/libcurl/c/CURLOPT_RESOLVE.html) ；它也是支持 IPv6 环境的，只需要你在 build 时添加上 `--enable-ipv6` 即可。

如果使用AFN，则需要重写AFN里的一些方法，

具体步骤是：hook 住 SSL 握手方法，也就是上图中的第2步，对应于下面的方法：

 ```Objective-C
 /*
 * NSURLSession
 */
 - (void)connection:(NSURLConnection *)connectionwillSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge 
 ```


 ```Objective-C
/*
 * NSURLSession
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * __nullable credential))completionHandler

 ```

然后将IP直接替换成原来的域名，再执行证书验证。

具体参考：

 1. [《如何使用ip直接访问https网站?》]( https://segmentfault.com/a/1190000004359232?utm_source=Weibo ) 
 2. [《HTTPS业务场景解决方案》]( https://help.aliyun.com/document_detail/30143.html ) 
 3. [Supporting IPv6 DNS64/NAT64 Networks](https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/NetworkingOverview/UnderstandingandPreparingfortheIPv6Transition/UnderstandingandPreparingfortheIPv6Transition.html#//apple_ref/doc/uid/TP40010220-CH213-SW1) 

## IM系列文章

IM系列文章分为下面这几篇：

 -  [《IM 即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）》](https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/IM%20即时通讯技术在多应用场景下的技术实现，以及性能调优（iOS视角）.md) 
 - [《技术实现细节》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/技术实现细节.md ) 
 - [《有一种 Block 叫 Callback，有一种 Callback 做 CompletionHandler》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/有一种%20Block%20叫%20Callback，有一种%20Callback%20做%20CompletionHandler.md ) 
 - [《防 DNS 污染方案》]( https://github.com/ChenYilong/iOSBlog/blob/master/Tips/基于Websocket的IM即时通讯技术/防%20DNS%20污染方案.md ) （本文）

本文是第四篇。



----------

Posted by [微博@iOS程序犭袁](http://weibo.com/luohanchenyilong/)  
原创文章，版权声明：自由转载-非商用-非衍生-保持署名 | [Creative Commons BY-NC-ND 3.0](http://creativecommons.org/licenses/by-nc-nd/3.0/deed.zh)
<p align="center"><a href="http://weibo.com/u/1692391497?s=6uyXnP" target="_blank"><img border="0" src="http://service.t.sina.com.cn/widget/qmd/1692391497/b46c844b/1.png"/></a></a>

