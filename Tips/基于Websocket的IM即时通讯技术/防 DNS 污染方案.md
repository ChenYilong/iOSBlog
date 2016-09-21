### 防 DNS 污染方案

DNS出问题的概率其实比大家感觉的要大，首先是DNS被劫持或者失效，2015年初业内比较知名的就有Apple内部DNS问题导致App Store、iTunes Connect账户无法登录；京东因为CDN域名付费问题导致服务停摆。携程在去年11月也遇到过DNS问题，主域名被国外服务商误列入黑名单，导致主站和H5等所有站点无法访问，但是App客户端的Native服务都正常，原因后面介绍。

另一个常见问题就是DNS解析慢或者失败，例如国内中国运营商网络的DNS就很慢，一次DNS查询的耗时甚至都能赶上一次连接的耗时，尤其2G网络情况下，DNS解析失败是很常见的。因此如果直接使用DNS，对于首次网络服务请求耗时和整体服务成功率都有非常大的影响。

DNS 劫持、污染一般是针对递归 DNS 服务器的 DNS 劫持攻击，

 > DNS 系统中有两种服务角色：递归 DNS 和授权 DNS。本质上来说，授权 DNS 控制网站的解析；递归 DNS 只起缓存的作用。所以跟广大站长关系比较大的是授权 DNS，也就是在域名注册商处填写的 DNS 地址。而网民使用的则是递归 DNS。
见：https://support.dnspod.cn/Kb/showarticle/tsid/186/

现实中的问题：

 - DNS解析时间过长
 像iOS系统一般是24小时之后会过期，还有进入飞行模式再切回来，开关机，重置网络设置等也会导致DNS cache的清除。所以一般情况下用户在第二天打开你的app都会经历一次完整的DNS解析请求，网络情况差的时候会明显增加应用请求的总耗时。

 - DNS劫持，不可以被信任的运营商，不可以被信任的 DNS 解析服务。
 
 DNS 在设计之初是基于 UDP 的，显然这样的设计不能满足当今社会的准确性的需求，于是涌现了如 DNSPod 这样的基于 HTTP 的 DNS 解析服务。但是当时为什么这样设计，实际也很好理解，UDP 效率高，一来一回网络上传输的只有两个包，而 HTTP则需要三次握手三个包，再一拆包，就需要四个包。这是受限于当时整个社会的带宽水平较低，而现在没人会感激 UDP 所节省的流量，所有人都在诟病DNS污染问题。

图为360向大家们示范什么是 DNS 劫持:

![](http://ww3.sinaimg.cn/large/7853084cjw1f7yp6lxqikj20vp0iwgn3.jpg)

运营商 DNS 劫持问题中，中国移动最为严重，

某些地区的中国移动还有个简单粗爆的域名检查系统，包含 av 字样的域名一率返回错误的 IP，

LeanCloud之前叫做AVOSCLoud，域名是：https://cn.avoscloud.com，嗯，我们很受伤。
后来我们改名了，域名也切换到了 api.leancloud.cn，我们用户的 DNS 问题已经大大的减少了。

鬼知道我们经历了什么。

原有的解决方法：简单粗暴投诉运营商。

#### 传统的解决方法：投诉

诊断方法步骤：

 * iOS 用户推荐 iNetTools
 * Android 用户推荐 LanDroid

 ping 响应时间，100（单位默认为 ms）以下都是可以接受的，高于 100 ms 会感到缓慢

 移动环境下，向中国移动打 10086 电话投诉，告之受影响的域名及 DNS 服务器的 IP，才能解决问题。
 如果是在无线网络情况下， DNS 异常，则请通过路由器的 DHCP 设置，将默认的 DNS 修改为正常的 DNS（推荐 114.114.114.114），并重启路由器即可。

投诉到中国移动后 48 小时问题仍未解决的话，依据中国相关法律法规规定，可以向工信部申诉，网址是 http://www.chinatcc.gov.cn:8080/cms/shensus/，这里最好是以邮件的方式申诉，将具体细节和截图写在邮件里发送给 accept@chinatcc.gov.cn，工信部的相关同学最早会在第 2 天回电话并催促中国移动。

申诉邮件的内容需要包括两个部分:
一是申诉者的姓名、身份证号码、通信地址、邮编、联系电话、申诉涉及到的电话号码、电子邮件、申诉日期 
二是被申诉企业名称、申诉内容（详情）、是否向企业申诉过（一定要先向企业投诉，无效后工信部才能受理，直接找工信部的不受理），最后要承诺「我承诺申诉信息真实有的」

#### 在 HTTPS 业务场景下的防 DNS 污染方案

防止 DNS 污染的方式有多种：

实现方式大致有两种：

方案一：HTTP 场景 IP 直连

通过IP直接访问网站，可以解决 DNS 劫持问题。如果是 HTTP 请求，使用 ip 地址直接访问接口，配合 header 中 Host 字段带上原来的域名信息即可；

从2016年6月1日起，iOS应用必须支持IPv6，否则审核将被拒。IPv6规则出来后，IP 直连，需要确保直连的是IPv6的地址，

两种方式：

 1. 升级服务器，让服务端支持 IPv6。在 APP 中替换IPv4的地址。
 2. 使用系统API合成IPv6地址，
  如果你的app需要连接到仅支持IPv4的服务器，且不使用DNS域名解析，请在APP端使用getaddrinfo处理IPv4地址串(getaddrinfo可通过传入一个IPv4或IPv6地址，得到一个sockaddr结构链表)。如果当前的网络接口不支持IPv4，仅支持IPv6,NAT64和DNS64，这样做可以得到一个合成的IPv6地址。
 
参考：[《iOS支持IPv6 DNS64/NAT64网络》]( http://www.pchou.info/ios/2016/06/05/ios-supporting-ipv6.html ) 

方案二：服务器动态部署，客户端维护一个 IP 列表

 - 无效映射淘汰机制
 - ✅使用IP列表避免DNS解析失败或者劫持 (电信、移动、联通，域名异步地去获取)IP地址，请求成功就+1、失败就-1，然后得到优先级列表
 - 根据网络延迟选择服务端IP

参考： [《iOS网络请求优化之DNS映射》]( http://www.jianshu.com/p/ad038ea54310 )。

方案三：使用基于 HTTP 的 DNS 解析方案

对于服务器IP经常变的情况,可能需要使用第三方服务，比如DNSPod、httpDNS。

默认的 DNS 是基于 UDP，改用 HTTP 协议进行域名解析，代替现有基于 UDP 的 DNS 协议，域名解析请求直接发送到指定的第三方 DNS 解析服务器，从而绕过运营商的 Local DNS，能够避免 Local DNS 造成的域名劫持问题和调度不精准问题。

绕过运营商直接连可以信任的第三方服务。

![enter image description here](https://www.dnspod.cn/yantai/img/httpdnsjbyl.png)

图中首选和备选的优先级可以调整。

参考：
  1. [《DNSPod接入指南》]( https://www.dnspod.cn/httpdns/guide ) 
  2. [《腾讯云DNSPod域名解析全面支持IPv6-only》]( http://www.qcloud.com/blog/?p=1234 ) 
  
#### 实现时的问题

发送HTTPS请求首先要进行SSL/TLS握手，握手过程大致如下：

 1. 客户端发起握手请求，携带随机数、支持算法列表等参数。
 2. 服务端收到请求，选择合适的算法，下发公钥证书和随机数。
 3. 客户端对服务端证书进行校验，并发送随机数信息，该信息使用公钥加密。
 4. 服务端通过私钥获取随机数信息。
 
![](http://ww4.sinaimg.cn/large/7853084cjw1f7zvcfp7qij20g40ergnj.jpg)

最后，双方根据以上交互的信息生成session ticket，用作该连接后续数据传输的加密密钥。
上述过程中，和HTTPDNS有关的是第3步，客户端需要验证服务端下发的证书，验证过程有以下两个要点：

客户端用本地保存的根证书解开证书链，确认服务端下发的证书是由可信任的机构颁发的。
客户端需要检查证书的domain域和扩展域，看是否包含本次请求的host。
如果上述两点都校验通过，就证明当前的服务端是可信任的，否则就是不可信任，应当中断当前连接。

当客户端使用基于HTTP的第三方解析服务解析域名时，请求URL中的host会被替换成解析出来的IP，所以在证书验证的第2步，会出现domain不匹配的情况，导致SSL/TLS握手不成功。

解决方案：

https 请求，需要 `Overriding TLS Chain Validation Correctly`;

如果使用第三方网络库：curl， 中有一个 `-resolve` 方法可以实现使用指定 ip 访问 https 网站,iOS 中集成 curl 库，参考 [curl文档](https://curl.haxx.se/libcurl/c/CURLOPT_RESOLVE.html) ；

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

 [《如何使用ip直接访问https网站?》]( https://segmentfault.com/a/1190000004359232?utm_source=Weibo ) 
 
 [《HTTPS业务场景解决方案》]( https://help.aliyun.com/document_detail/30143.html ) 

---------

问题一：DNS ip直连 https，可行性，会不会受审核时的 ipv6 的影响。
可以为某个 HTTPS 请求指定 IP，不过需要为这个域名设置 ATS 白名单。IP 连 IPv6 only 是可以的。只要不调用一些 IPv4-only 的 API 即可。

 > 从IOS9何OSX10.11开始，NSURLSession和CFNetwork会在本地自动将IPv4的地址合成IPv6地址，便于与DNS64/NAT64通信。不过，你依旧不该使用IP地址串。

参考： [《IOS支持IPv6 DNS64/NAT64网络》]( http://www.pchou.info/ios/2016/06/05/ios-supporting-ipv6.html ) 
问题二：SDK中是否 使用了 DNSPod 服务？具体是怎样工作的。
SDK 之前的版本使用 curl 作为网络库，使用了 DNSPod 解析服务。工作原理是当某个请求出现异常时，使用 DNSPod 的 119.29.29.29 服务解析域名，得到 IP。然后使用 curl pre-populate DNS 缓存。具体可以参考 https://curl.haxx.se/libcurl/c/CURLOPT_RESOLVE.html 这里的描述。

操作系统会负责把 IPv4 地址翻译成 IPv6。