<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [iOS 防 DNS 污染方案调研--- SNI 业务场景](#ios-%E9%98%B2-dns-%E6%B1%A1%E6%9F%93%E6%96%B9%E6%A1%88%E8%B0%83%E7%A0%94----sni-%E4%B8%9A%E5%8A%A1%E5%9C%BA%E6%99%AF)
  - [概述](#%E6%A6%82%E8%BF%B0)
  - [基于 CFNetWork 有性能瓶颈](#%E5%9F%BA%E4%BA%8E-cfnetwork-%E6%9C%89%E6%80%A7%E8%83%BD%E7%93%B6%E9%A2%88)
    - [调研性能瓶颈的原因](#%E8%B0%83%E7%A0%94%E6%80%A7%E8%83%BD%E7%93%B6%E9%A2%88%E7%9A%84%E5%8E%9F%E5%9B%A0)
      - [调研性能瓶颈的方法](#%E8%B0%83%E7%A0%94%E6%80%A7%E8%83%BD%E7%93%B6%E9%A2%88%E7%9A%84%E6%96%B9%E6%B3%95)
    - [能瓶颈原因](#%E8%83%BD%E7%93%B6%E9%A2%88%E5%8E%9F%E5%9B%A0)
      - [Body 放入 Header 导致请求超时](#body-%E6%94%BE%E5%85%A5-header-%E5%AF%BC%E8%87%B4%E8%AF%B7%E6%B1%82%E8%B6%85%E6%97%B6)
  - [换用其他提供了SNI字段配置接口的更底层网络库](#%E6%8D%A2%E7%94%A8%E5%85%B6%E4%BB%96%E6%8F%90%E4%BE%9B%E4%BA%86sni%E5%AD%97%E6%AE%B5%E9%85%8D%E7%BD%AE%E6%8E%A5%E5%8F%A3%E7%9A%84%E6%9B%B4%E5%BA%95%E5%B1%82%E7%BD%91%E7%BB%9C%E5%BA%93)
    - [iOS CURL 库](#ios-curl-%E5%BA%93)
  - [走过的弯路](#%E8%B5%B0%E8%BF%87%E7%9A%84%E5%BC%AF%E8%B7%AF)
  - [误以为 iOS11 新 API 可以直接拦截 DNS 解析过程](#%E8%AF%AF%E4%BB%A5%E4%B8%BA-ios11-%E6%96%B0-api-%E5%8F%AF%E4%BB%A5%E7%9B%B4%E6%8E%A5%E6%8B%A6%E6%88%AA-dns-%E8%A7%A3%E6%9E%90%E8%BF%87%E7%A8%8B)
  - [参考链接：](#%E5%8F%82%E8%80%83%E9%93%BE%E6%8E%A5)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# iOS 防 DNS 污染方案调研--- SNI 业务场景 

## 概述

SNI（单IP多HTTPS证书）场景下，iOS上层网络库 `NSURLConnection/NSURLSession` 没有提供接口进行 `SNI 字段` 配置，因此需要 Socket 层级的底层网络库例如 `CFNetwork`，来实现 `IP 直连网络请求`适配方案。而基于 CFNetwork 的解决方案需要开发者考虑数据的收发、重定向、解码、缓存等问题（CFNetwork是非常底层的网络实现）。

针对 SNI 场景的方案， Socket 层级的底层网络库，大致有两种：

 - 基于 CFNetWork ，hook 证书校验步骤。
 - 基于原生支持设置 SNI 字段的更底层的库，比如 libcurl。


下面将目前面临的一些挑战，以及应对策略介绍一下：

## 基于 CFNetWork 有性能瓶颈

方案：

 1. 调研性能瓶颈的原因
 2. 换用其他提供了SNI字段配置接口的更底层网络库。

### 调研性能瓶颈的原因

在使用 CFNetWork 实现了基本的SNI解决方案后，虽然问题解决了，但是遇到了性能瓶颈，对比 `NSURLConnection/NSURLSession` ，打开流到结束流时间明显更长。介绍下对比性能时的调研方法：

 /*one more thing*/

<!--- 

![enter image description here](https://ws1.sinaimg.cn/large/006tKfTcly1fhelbif790j30nk0dvaaw.jpg)

（横坐标是流的编号，纵轴是打开流到结束流，所耗费的时间，单位是毫秒。我们可以模拟下用户的测试方法 ）。

-->

#### 调研性能瓶颈的方法 


可以使用下面的方法，做一个简单的打点，将流开始和流结束记录下。

记录的数据如下：

key |   from | to | vule
-------|------|-------|------
请求的序列号 |  开始时间戳 | 结束时间戳 | 耗时


 ```Objective-C
#import <Foundation/Foundation.h>

@interface CYLRequestTimeMonitor : NSObject

+ (NSString *)requestBeginTimeKeyWithID:(NSUInteger)ID;
+ (NSString *)requestEndTimeKeyWithID:(NSUInteger)ID;
+ (NSString *)requestSpentTimeKeyWithID:(NSUInteger)ID;
+ (NSString *)getKey:(NSString *)key ID:(NSUInteger)ID;
+ (NSUInteger)timeFromKey:(NSString *)key;
+ (NSUInteger)frontRequetNumber;
+ (NSUInteger)changeToNextRequetNumber;
+ (void)setCurrentTimeForKey:(NSString *)key taskID:(NSUInteger)taskID time:(NSTimeInterval *)time;
+ (void)setTime:(NSUInteger)time key:(NSString *)key taskID:(NSUInteger)taskID;

+ (void)setBeginTimeForTaskID:(NSUInteger)taskID;
+ (void)setEndTimeForTaskID:(NSUInteger)taskID;
+ (void)setSpentTimeForKey:(NSString *)key endTime:(NSUInteger)endTime taskID:(NSUInteger)taskID;
    
@end
 ```


 ```Objective-C
#import "CYLRequestTimeMonitor.h"

@implementation CYLRequestTimeMonitor

static NSString *const CYLRequestFrontNumber = @"CYLRequestFrontNumber";
static NSString *const CYLRequestBeginTime = @"CYLRequestBeginTime";
static NSString *const CYLRequestEndTime = @"CYLRequestEndTime";
static NSString *const CYLRequestSpentTime = @"CYLRequestSpentTime";

+ (NSString *)requestBeginTimeKeyWithID:(NSUInteger)ID {
    return [self getKey:CYLRequestBeginTime ID:ID];
}

+ (NSString *)requestEndTimeKeyWithID:(NSUInteger)ID {
    return [self getKey:CYLRequestEndTime ID:ID];
}

+ (NSString *)requestSpentTimeKeyWithID:(NSUInteger)ID {
    return [self getKey:CYLRequestSpentTime ID:ID];
}

+ (NSString *)getKey:(NSString *)key ID:(NSUInteger)ID {
    NSString *timeKeyWithID = [NSString stringWithFormat:@"%@-%@", @(ID), key];
    return timeKeyWithID;
}

+ (NSUInteger)timeFromKey:(NSString *)key {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSUInteger time = [defaults integerForKey:key];
    return time ?: 0;
}

+ (NSUInteger)frontRequetNumber {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSUInteger frontNumber = [defaults integerForKey:CYLRequestFrontNumber];
    return frontNumber ?: 0;
}

+ (NSUInteger)changeToNextRequetNumber {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSUInteger nextNumber = ([self frontRequetNumber]+ 1);
    [defaults setInteger:nextNumber forKey:CYLRequestFrontNumber];
    [defaults synchronize];
    return nextNumber;
}

+ (void)setCurrentTimeForKey:(NSString *)key taskID:(NSUInteger)taskID time:(NSTimeInterval *)time {
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970]*1000;
    *time = currentTime;
    [self setTime:currentTime key:key taskID:taskID];
}

+ (void)setTime:(NSUInteger)time key:(NSString *)key taskID:(NSUInteger)taskID {
    NSString *keyWithID = [self getKey:key ID:taskID];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:time forKey:keyWithID];
    [defaults synchronize];
}

+ (void)setBeginTimeForTaskID:(NSUInteger)taskID {
    NSTimeInterval begin;
    [self setCurrentTimeForKey:CYLRequestBeginTime taskID:taskID time:&begin];
}

+ (void)setEndTimeForTaskID:(NSUInteger)taskID {
    NSTimeInterval endTime = 0;
    [self setCurrentTimeForKey:CYLRequestEndTime taskID:taskID time:&endTime];
    [self setSpentTimeForKey:CYLRequestSpentTime endTime:endTime taskID:taskID];
}

+ (void)setSpentTimeForKey:(NSString *)key endTime:(NSUInteger)endTime taskID:(NSUInteger)taskID {
    NSString *beginTimeString = [self requestBeginTimeKeyWithID:taskID];
    NSUInteger beginTime = [self timeFromKey:beginTimeString];
    NSUInteger spentTime = endTime - beginTime;
    [self setTime:spentTime key:CYLRequestSpentTime taskID:taskID];
}

@end

 ```

NSURLConnection 的打点位置如下：

 ```Objective-C
这里普通的做法就是继承NSURLProtocol 这个类写一个子类，然后在子类中实现NSURLConnectionDelegate 的那五个代理方法。 

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
//  这个方法里可以做计时的开始
 
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
//  这里可以得到返回包的总大小
 
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
//  这里将每次的data累加起来，可以做加载进度圆环之类的
 
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
//  这里作为结束的时间
 
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
//  错误的收集 
 ```
 
NSURLSession 类似。

然后在自定义CFNetwork的下面两个方法中打点：流开始和流结束，命名大致如：`-startLoading`、`-didReceiveRedirection`。

发送相同的网络请求，然后通过对比两个的时间来观察性能。

### 能瓶颈原因

#### Body 放入 Header 导致请求超时

使用 NSURLProtocol 拦截 NSURLSession 请求丢失 body，故有以下几种解决方法：


 方案如下： 

  1. 换用 NSURLConnection 
  2. 将 body 放进 Header 中
  3. 使用 HTTPBodyStream 获取 body，并赋值到 body 中

其中换用 NSURLConnection 这种方法，不用多少了，终究会被淘汰。不考虑。

其中body放header的方法，2M以下没问题，超过2M会导致请求延迟，超过 10M 就直接 Request timeout。而且无法解决 Body 为二进制数据的问题，因为Header里都是文本数据，

另一种方法是使用 HTTPBodyStream 获取 body，并赋值到 body 中，具体的代码如下，可以解决上面提到的问题：

 ```Objective-C
//
//  NSURLRequest+CYLNSURLProtocolExtension.h
//
//
//  Created by ElonChan on 28/07/2017.
//  Copyright © 2017 ChenYilong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURLRequest (CYLNSURLProtocolExtension)

- (NSMutableURLRequest *)cyl_getPostRequestIncludeBody;

@end


@interface NSMutableURLRequest (CYLNSURLProtocolExtension)

- (void)cyl_handlePostRequestBody;

@end


 //
//  NSURLRequest+CYLNSURLProtocolExtension.h
//
//
//  Created by ElonChan on 28/07/2017.
//  Copyright © 2017 ChenYilong. All rights reserved.
//

#import "NSURLRequest+CYLNSURLProtocolExtension.h"

@implementation NSURLRequest (CYLNSURLProtocolExtension)

- (NSMutableURLRequest *)cyl_getPostRequestIncludeBody {
    NSMutableURLRequest * req = [self mutableCopy];
    if ([self.HTTPMethod isEqualToString:@"POST"]) {
        if (!self.HTTPBody) {
            uint8_t d[1024] = {0};
            NSInputStream *stream = self.HTTPBodyStream;
            NSMutableData *data = [[NSMutableData alloc] init];
            [stream open];
            while ([stream hasBytesAvailable]) {
                NSInteger len = [stream read:d maxLength:1024];
                if (len > 0 && stream.streamError == nil) {
                    [data appendBytes:(void *)d length:len];
                }
            }
            req.HTTPBody = [data copy];
            [stream close];
        }
    }
    return req;
}

@end

@implementation NSMutableURLRequest (CYLNSURLProtocolExtension)

- (void)cyl_handlePostRequestBody {
    if ([self.HTTPMethod isEqualToString:@"POST"]) {
        if (!self.HTTPBody) {
            uint8_t d[1024] = {0};
            NSInputStream *stream = self.HTTPBodyStream;
            NSMutableData *data = [[NSMutableData alloc] init];
            [stream open];
            while ([stream hasBytesAvailable]) {
                NSInteger len = [stream read:d maxLength:1024];
                if (len > 0 && stream.streamError == nil) {
                    [data appendBytes:(void *)d length:len];
                }
            }
            self.HTTPBody = [data copy];
            [stream close];
        }
    }
}

@end

```

使用方法：

在用于拦截请求的 NSURLProtocol 的子类中实现方法 `-[NSURLProtocol startLoading]`，并处理 `request` 对象。


 ```Objective-C

/**
 * 开始加载，在该方法中，加载一个请求
 */
- (void)startLoading {
    NSMutableURLRequest *request = [self.request mutableCopy];
    [request cyl_handlePostRequestBody];
    // 表示该请求已经被处理，防止无限循环
    [NSURLProtocol setProperty:@(YES) forKey:CYL_NSURLPROTOCOL_REQUESTED_FLAG_KEY inRequest:request];
    curRequest = request;
    [self startRequest];
}
 ```

注意在拦截 `NSURLSession` 请求时，需要将用于拦截请求的 NSURLProtocol 的子类添加到 `NSURLSessionConfiguration` 中，用法如下：

 ```Objective-C
     NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
     NSArray *protocolArray = @[ [CYLURLProtocol class] ];
     configuration.protocolClasses = protocolArray;
     NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
```

## 换用其他提供了SNI字段配置接口的更底层网络库

如果使用第三方网络库：curl， 中有一个 `-resolve` 方法可以实现使用指定 ip 访问 https 网站,iOS 中集成 curl 库，参考 [curl文档](https://curl.haxx.se/libcurl/c/CURLOPT_RESOLVE.html) ；

另外有一点也可以注意下，它也是支持 IPv6 环境的，只需要你在 build 时添加上 `--enable-ipv6` 即可。

curl 支持指定 SNI 字段，设置 SNI 时我们需要构造的参数形如： `{HTTPS域名}:443:{IP地址}` 

假设你要访问. www.example.org ，若IP为 127.0.0.1 ，那么通过这个方式来调用来设置 SNI 即可：

  > curl --resolve 'www.example.org:443:127.0.0.1'

### iOS CURL 库

使用[libcurl](https://curl.haxx.se/libcurl/c/) 来解决，`curl` 中有一个 `-resolve` 方法可以实现使用指定ip访问https网站。

在iOS实现中，代码如下  
  
 ```Objective-C
    //{HTTPS域名}:443:{IP地址}
    NSString *curlHost = ...;
    _hosts_list = curl_slist_append(_hosts_list, curlHost.UTF8String);
    curl_easy_setopt(_curl, CURLOPT_RESOLVE, _hosts_list);
 ```

其中 `curlHost` 形如：

 `{HTTPS域名}:443:{IP地址}` 
 
 `_hosts_list` 是结构体类型`hosts_list`，可以设置多个IP与Host之间的映射关系。`curl_easy_setopt`方法中传入`CURLOPT_RESOLVE` 将该映射设置到 HTTPS 请求中。

这样就可以达到设置SNI的目的。

我在这里写了一个 Demo：[CYLCURLNetworking](https://github.com/ChenYilong/CYLCURLNetworking)，里面包含了编译好的支持 IPv6 的 libcurl 包，演示了下如何通过curl来进行类似NSURLSession。

## 走过的弯路

## 误以为 iOS11 新 API 可以直接拦截 DNS 解析过程

参考：[NEDNSProxyProvider:DNS based on HTTP supported in iOS11](https://github.com/ChenYilong/iOS11AdaptationTips/issues/12) 

## 参考链接：

 - [Apple - Communicating with HTTP Servers](https://developer.apple.com/library/content/documentation/Networking/Conceptual/CFNetwork/CFHTTPTasks/CFHTTPTasks.html?spm=5176.doc30143.2.3.5016q8) 
 - [Apple - HTTPS Server Trust Evaluation - Server Name Failures ](https://developer.apple.com/library/content/technotes/tn2232/_index.html?spm=5176.doc30143.2.4.5016q8#//apple_ref/doc/uid/DTS40012884-CH1-SECSERVERNAME) 
 - [Apple - HTTPS Server Trust Evaluation - Trusting One Specific Certificate ](https://developer.apple.com/library/content/technotes/tn2232/_index.html?spm=5176.doc30143.2.5.5016q8#//apple_ref/doc/uid/DTS40012884-CH1-SECCUSTOMCERT) 
 - [《HTTPDNS > 最佳实践 > HTTPS（含SNI）业务场景“IP直连”方案说明
HTTPS（含SNI）业务场景“IP直连”方案说明》]( https://help.aliyun.com/document_detail/30143.html?spm=5176.doc30141.6.591.A8B1d3 ) 
 -  [《在 curl 中使用指定 ip 来进行请求 https》]( https://blog.mozcp.com/curl-request-https-specify-ip/ ) 
 - [支持SNI与WebView的 alicloud-ios-demo](https://github.com/Dave1991/alicloud-ios-demo) 

