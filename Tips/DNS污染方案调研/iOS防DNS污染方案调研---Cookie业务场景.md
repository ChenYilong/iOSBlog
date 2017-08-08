<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [iOS 防 DNS 污染方案调研 --- Cookie 业务场景](#ios-%E9%98%B2-dns-%E6%B1%A1%E6%9F%93%E6%96%B9%E6%A1%88%E8%B0%83%E7%A0%94-----cookie-%E4%B8%9A%E5%8A%A1%E5%9C%BA%E6%99%AF)
  - [概述](#%E6%A6%82%E8%BF%B0)
  - [WKWebView 使用 NSURLProtocol 拦截请求无法获取 Cookie 信息](#wkwebview-%E4%BD%BF%E7%94%A8-nsurlprotocol-%E6%8B%A6%E6%88%AA%E8%AF%B7%E6%B1%82%E6%97%A0%E6%B3%95%E8%8E%B7%E5%8F%96-cookie-%E4%BF%A1%E6%81%AF)
    - [利用 iOS11 API WKHTTPCookieStore 解决 WKWebView 首次请求不携带 Cookie 的问题](#%E5%88%A9%E7%94%A8-ios11-api-wkhttpcookiestore-%E8%A7%A3%E5%86%B3-wkwebview-%E9%A6%96%E6%AC%A1%E8%AF%B7%E6%B1%82%E4%B8%8D%E6%90%BA%E5%B8%A6-cookie-%E7%9A%84%E9%97%AE%E9%A2%98)
  - [利用 iOS11 之前的 API 解决 WKWebView 首次请求不携带 Cookie 的问题](#%E5%88%A9%E7%94%A8-ios11-%E4%B9%8B%E5%89%8D%E7%9A%84-api-%E8%A7%A3%E5%86%B3-wkwebview-%E9%A6%96%E6%AC%A1%E8%AF%B7%E6%B1%82%E4%B8%8D%E6%90%BA%E5%B8%A6-cookie-%E7%9A%84%E9%97%AE%E9%A2%98)
  - [Cookie包含动态 IP 导致登陆失效问题](#cookie%E5%8C%85%E5%90%AB%E5%8A%A8%E6%80%81-ip-%E5%AF%BC%E8%87%B4%E7%99%BB%E9%99%86%E5%A4%B1%E6%95%88%E9%97%AE%E9%A2%98)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# iOS 防 DNS 污染方案调研 --- Cookie 业务场景

## 概述

本文将讨论下类似这样的问题：

  - WKWebView 对于 Cookie 的管理一直是它的短板，那么 iOS11 是否有改进，如果有，如果利用这样的改进？
 - 采用 IP 直连方案后，服务端返回的 Cookie 里的 Domain 字段也会使用 IP 。如果 IP 是动态的，就有可能导致一些问题：由于许多 H5 业务都依赖于 Cookie 作登录态校验，而 WKWebView 上请求不会自动携带 Cookie。


## WKWebView 使用 NSURLProtocol 拦截请求无法获取 Cookie 信息

iOS11推出了新的 API `WKHTTPCookieStore` 可以用来拦截 WKWebView 的 Cookie 信息

用法示例如下：

 ```Objective-C
   WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
   //get cookies
    [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
        NSLog(@"All cookies %@",cookies);
    }];

    //set cookie
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[NSHTTPCookieName] = @"userid";
    dict[NSHTTPCookieValue] = @"123";
    dict[NSHTTPCookieDomain] = @"xxxx.com";
    dict[NSHTTPCookiePath] = @"/";

    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:dict];
    [cookieStroe setCookie:cookie completionHandler:^{
        NSLog(@"set cookie");
    }];

    //delete cookie
    [cookieStroe deleteCookie:cookie completionHandler:^{
        NSLog(@"delete cookie");
    }];
 ```


### 利用 iOS11 API WKHTTPCookieStore 解决 WKWebView 首次请求不携带 Cookie 的问题


问题说明：由于许多 H5 业务都依赖于 Cookie 作登录态校验，而 WKWebView 上请求不会自动携带 Cookie。比如，如果你在Native层面做了登陆操作，获取了Cookie信息，也使用 NSHTTPCookieStorage 存到了本地，但是使用  WKWebView 打开对应网页时，网页依然处于未登陆状态。如果是登陆也在 WebView 里做的，就不会有这个问题。

iOS11 的 API 可以解决该问题，只要是存在 WKHTTPCookieStore 里的 cookie，WKWebView 每次请求都会携带，存在 NSHTTPCookieStorage 的cookie，并不会每次都携带。于是会发生首次 WKWebView 请求不携带 Cookie 的问题。

解决方法：

在执行 `-[WKWebView loadReques:]` 前将 `NSHTTPCookieStorage` 中的内容复制到 `WKHTTPCookieStore` 中。示例代码如下：

 ```Objective-C
        [self copyNSHTTPCookieStorageToWKHTTPCookieStoreWithCompletionHandler:^{
            NSURL *url = [NSURL URLWithString:@"https://www.v2ex.com"];
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            [_webView loadRequest:request];
        }];
 ```

 ```Objective-C
- (void)copyNSHTTPCookieStorageToWKHTTPCookieStoreWithCompletionHandler:(nullable void (^)())theCompletionHandler; {
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    if (cookies.count == 0) {
        !theCompletionHandler ?: theCompletionHandler();
        return;
    }
    for (NSHTTPCookie *cookie in cookies) {
        [cookieStroe setCookie:cookie completionHandler:^{
            if ([[cookies lastObject] isEqual:cookie]) {
                !theCompletionHandler ?: theCompletionHandler();
                return;
            }
        }];
    }
}
 ```

这个是 iOS11 的API，针对iOS11之前的系统，需要另外处理。

## 利用 iOS11 之前的 API 解决 WKWebView 首次请求不携带 Cookie 的问题

通过让所有 WKWebView 共享同一个 WKProcessPool 实例，可以实现多个 WKWebView 之间共享 Cookie（session Cookie and persistent Cookie）数据。不过 WKWebView WKProcessPool 实例在 app 杀进程重启后会被重置，导致 WKProcessPool 中的 Cookie、session Cookie 数据丢失，目前也无法实现 WKProcessPool 实例本地化保存。可以采取 cookie 放入 Header 的方法来做。

 ```Objective-C
 WKWebView * webView = [WKWebView new]; 
 NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://xxx.com/login"]]; 
 [request addValue:@"skey=skeyValue" forHTTPHeaderField:@"Cookie"]; 
 [webView loadRequest:request];
 ```

其中对于 `skey=skeyValue` 这个cookie值的获取，也可以统一通过domain获取，获取的方法，可以参照下面的工具类：

 ```Objective-C
HTTPDNSCookieManager.h

#ifndef HTTPDNSCookieManager_h
#define HTTPDNSCookieManager_h

// URL匹配Cookie规则
typedef BOOL (^HTTPDNSCookieFilter)(NSHTTPCookie *, NSURL *);

@interface HTTPDNSCookieManager : NSObject

+ (instancetype)sharedInstance;

/**
 指定URL匹配Cookie策略

 @param filter 匹配器
 */
- (void)setCookieFilter:(HTTPDNSCookieFilter)filter;

/**
 处理HTTP Reponse携带的Cookie并存储

 @param headerFields HTTP Header Fields
 @param URL 根据匹配策略获取查找URL关联的Cookie
 @return 返回添加到存储的Cookie
 */
- (NSArray<NSHTTPCookie *> *)handleHeaderFields:(NSDictionary *)headerFields forURL:(NSURL *)URL;

/**
 匹配本地Cookie存储，获取对应URL的request cookie字符串

 @param URL 根据匹配策略指定查找URL关联的Cookie
 @return 返回对应URL的request Cookie字符串
 */
- (NSString *)getRequestCookieHeaderForURL:(NSURL *)URL;

/**
 删除存储cookie

 @param URL 根据匹配策略查找URL关联的cookie
 @return 返回成功删除cookie数
 */
- (NSInteger)deleteCookieForURL:(NSURL *)URL;

@end

#endif /* HTTPDNSCookieManager_h */

HTTPDNSCookieManager.m
#import <Foundation/Foundation.h>
#import "HTTPDNSCookieManager.h"

@implementation HTTPDNSCookieManager
{
    HTTPDNSCookieFilter cookieFilter;
}

- (instancetype)init {
    if (self = [super init]) {
        /**
            此处设置的Cookie和URL匹配策略比较简单，检查URL.host是否包含Cookie的domain字段
            通过调用setCookieFilter接口设定Cookie匹配策略，
            比如可以设定Cookie的domain字段和URL.host的后缀匹配 | URL是否符合Cookie的path设定
            细节匹配规则可参考RFC 2965 3.3节
         */
        cookieFilter = ^BOOL(NSHTTPCookie *cookie, NSURL *URL) {
            if ([URL.host containsString:cookie.domain]) {
                return YES;
            }
            return NO;
        };
    }
    return self;
}

+ (instancetype)sharedInstance {
    static id singletonInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!singletonInstance) {
            singletonInstance = [[super allocWithZone:NULL] init];
        }
    });
    return singletonInstance;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (id)copyWithZone:(struct _NSZone *)zone {
    return self;
}

- (void)setCookieFilter:(HTTPDNSCookieFilter)filter {
    if (filter != nil) {
        cookieFilter = filter;
    }
}

- (NSArray<NSHTTPCookie *> *)handleHeaderFields:(NSDictionary *)headerFields forURL:(NSURL *)URL {
    NSArray *cookieArray = [NSHTTPCookie cookiesWithResponseHeaderFields:headerFields forURL:URL];
    if (cookieArray != nil) {
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in cookieArray) {
            if (cookieFilter(cookie, URL)) {
                NSLog(@"Add a cookie: %@", cookie);
                [cookieStorage setCookie:cookie];
            }
        }
    }
    return cookieArray;
}

- (NSString *)getRequestCookieHeaderForURL:(NSURL *)URL {
    NSArray *cookieArray = [self searchAppropriateCookies:URL];
    if (cookieArray != nil && cookieArray.count > 0) {
        NSDictionary *cookieDic = [NSHTTPCookie requestHeaderFieldsWithCookies:cookieArray];
        if ([cookieDic objectForKey:@"Cookie"]) {
            return cookieDic[@"Cookie"];
        }
    }
    return nil;
}

- (NSArray *)searchAppropriateCookies:(NSURL *)URL {
    NSMutableArray *cookieArray = [NSMutableArray array];
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        if (cookieFilter(cookie, URL)) {
            NSLog(@"Search an appropriate cookie: %@", cookie);
            [cookieArray addObject:cookie];
        }
    }
    return cookieArray;
}

- (NSInteger)deleteCookieForURL:(NSURL *)URL {
    int delCount = 0;
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        if (cookieFilter(cookie, URL)) {
            NSLog(@"Delete a cookie: %@", cookie);
            [cookieStorage deleteCookie:cookie];
            delCount++;
        }
    }
    return delCount;
}

@end
 ```

使用方法示例：

发送请求

 ```Objective-C
 WKWebView * webView = [WKWebView new]; 
 NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://xxx.com/login"]]; 
NSString *value = [[HTTPDNSCookieManager sharedInstance] getRequestCookieHeaderForURL:url];
[request setValue:value forHTTPHeaderField:@"Cookie"];
 [webView loadRequest:request];
 ```

接收处理请求：

 ```Objective-C
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            // 解析 HTTP Response Header，存储cookie
            [[HTTPDNSCookieManager sharedInstance] handleHeaderFields:[httpResponse allHeaderFields] forURL:url];
        }
    }];
    [task resume];
 ```


通过 `document.cookie` 设置 Cookie 解决后续页面(同域)Ajax、iframe 请求的 Cookie 问题；

 ```Objective-C
WKUserContentController* userContentController = [WKUserContentController new]; 
 WKUserScript * cookieScript = [[WKUserScript alloc] initWithSource: @"document.cookie = 'skey=skeyValue';" injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO]; 
 [userContentController addUserScript:cookieScript];
 ```

## Cookie包含动态 IP 导致登陆失效问题


关于COOKIE失效的问题，假如客户端登录 session 存在 COOKIE，此时这个域名配置了多个IP，使用域名访问会读对应域名的COOKIE，使用IP访问则去读对应IP的COOKIE，假如前后两次使用同一个域名配置的不同IP访问，会导致COOKIE的登录session失效，

如果APP里面的webview页面需要用到系统COOKIE存的登录session，之前APP所有本地网络请求使用域名访问，是可以共用COOKIE的登录session的，但现在本地网络请求使用httpdns后改用IP访问，导致还使用域名访问的webview读不到系统COOKIE存的登录session了（系统COOKIE对应IP了）。IP直连后，服务端返回Cookie包含动态 IP 导致登陆失效。

使用IP访问后，服务端返回的cookie也是IP。导致可能使用对应的域名访问，无法使用本地cookie，或者使用隶属于同一个域名的不同IP去访问，cookie也对不上，导致登陆失效，是吧。

我这边的思路是这样的，
 - 应该得干预cookie的存储，基于域名。
 - 根源上，api域名返回单IP

第二种思路将失去DNS调度特性，故不考虑。第一种思路更为可行。

当每次服务端返回cookie后，在存储前都进行下改造，使用域名替换下IP。
之后虽然每次网络请求都是使用IP访问，但是host我们都手动改为了域名，这样本地的cookie也是能对得上的。

代码演示：

在网络请求成功后，或者加载网页成功后，主动将本地的 domain 字段为 IP 的 Cookie 替换 IP 为 host 域名地址。

 ```Objective-C
- (void)updateWKHTTPCookieStoreDomainFromIP:(NSString *)IP toHost:(NSString *)host {
    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    [cookieStroe getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
        [[cookies copy] enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull cookie, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([cookie.domain isEqualToString:IP]) {
                NSMutableDictionary<NSHTTPCookiePropertyKey, id> *dict = [NSMutableDictionary dictionaryWithDictionary:cookie.properties];
                dict[NSHTTPCookieDomain] = host;
                NSHTTPCookie *newCookie = [NSHTTPCookie cookieWithProperties:[dict copy]];
                [cookieStroe setCookie:newCookie completionHandler:^{
                    [self logCookies];
                    //FIXME: `-[WKHTTPCookieStore deleteCookie:]` 在 iOS11-beta3 中依然有bug，不会执行。（后续正式版修复后，再更新该注视。）
                    [cookieStroe deleteCookie:cookie
                            completionHandler:^{
                                [self logCookies];
                            }];
                }];
            }
        }];
    }];
}
 ```


iOS11中也提供了对应的 API 供我们来处理替换 Cookie 的时机，那就是下面的API：

 ```Objective-C
@protocol WKHTTPCookieStoreObserver <NSObject>
@optional
- (void)cookiesDidChangeInCookieStore:(WKHTTPCookieStore *)cookieStore;
@end
 ```


 ```Objective-C
//WKHTTPCookieStore
/*! @abstract Adds a WKHTTPCookieStoreObserver object with the cookie store.
 @param observer The observer object to add.
 @discussion The observer is not retained by the receiver. It is your responsibility
 to unregister the observer before it becomes invalid.
 */
- (void)addObserver:(id<WKHTTPCookieStoreObserver>)observer;

/*! @abstract Removes a WKHTTPCookieStoreObserver object from the cookie store.
 @param observer The observer to remove.
 */
- (void)removeObserver:(id<WKHTTPCookieStoreObserver>)observer;
 ```

用法如下：

 ```Objective-C
@interface WebViewController ()<WKHTTPCookieStoreObserver>
- (void)viewDidLoad {
    [super viewDidLoad];
    [NSURLProtocol registerClass:[WebViewURLProtocol class]];
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    WKHTTPCookieStore *cookieStroe = self.webView.configuration.websiteDataStore.httpCookieStore;
    [cookieStroe addObserver:self];

    [self.view addSubview:self.webView];
    //... ...
}

#pragma mark -
#pragma mark - WKHTTPCookieStoreObserver Delegate Method

- (void)cookiesDidChangeInCookieStore:(WKHTTPCookieStore *)cookieStore {
    [self updateWKHTTPCookieStoreDomainFromIP:CYLIP toHost:CYLHOST];
}
 ```

`-updateWKHTTPCookieStoreDomainFromIP` 方法的实现，在上文已经给出。

//TODO:  这个思路正在完善中... ...

**相关的文章：**

  - [《WKWebView 那些坑》]( https://zhuanlan.zhihu.com/p/24990222 ) 
  - [《HTTPDNS域名解析场景下如何使用Cookie？》]( https://yq.aliyun.com/articles/64356 ) 

