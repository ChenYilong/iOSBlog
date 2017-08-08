<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [iOS 防 DNS 污染方案调研--- WebView 业务场景](#ios-%E9%98%B2-dns-%E6%B1%A1%E6%9F%93%E6%96%B9%E6%A1%88%E8%B0%83%E7%A0%94----webview-%E4%B8%9A%E5%8A%A1%E5%9C%BA%E6%99%AF)
  - [概述](#%E6%A6%82%E8%BF%B0)
  - [面临的问题](#%E9%9D%A2%E4%B8%B4%E7%9A%84%E9%97%AE%E9%A2%98)
    - [WKWebView 无法使用 NSURLProtocol 拦截请求](#wkwebview-%E6%97%A0%E6%B3%95%E4%BD%BF%E7%94%A8-nsurlprotocol-%E6%8B%A6%E6%88%AA%E8%AF%B7%E6%B1%82)
    - [使用 NSURLProtocol 拦截 NSURLSession 请求丢失 body](#%E4%BD%BF%E7%94%A8-nsurlprotocol-%E6%8B%A6%E6%88%AA-nsurlsession-%E8%AF%B7%E6%B1%82%E4%B8%A2%E5%A4%B1-body)
  - [302重定向问题](#302%E9%87%8D%E5%AE%9A%E5%90%91%E9%97%AE%E9%A2%98)
  - [Cookie相关问题](#cookie%E7%9B%B8%E5%85%B3%E9%97%AE%E9%A2%98)
  - [参考链接](#%E5%8F%82%E8%80%83%E9%93%BE%E6%8E%A5)
  - [走过的弯路](#%E8%B5%B0%E8%BF%87%E7%9A%84%E5%BC%AF%E8%B7%AF)
  - [误以为 iOS11 新 API 可以原生拦截 WKWebView 的 HTTP/HTTPS 网络请求](#%E8%AF%AF%E4%BB%A5%E4%B8%BA-ios11-%E6%96%B0-api-%E5%8F%AF%E4%BB%A5%E5%8E%9F%E7%94%9F%E6%8B%A6%E6%88%AA-wkwebview-%E7%9A%84-httphttps-%E7%BD%91%E7%BB%9C%E8%AF%B7%E6%B1%82)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# iOS 防 DNS 污染方案调研--- WebView 业务场景

## 概述

为什么 WebView 需要特别适配SNI？


因为形如 http://1.1.1.1/a/b.com 在 WebView 中是无法正常访问的，也是需要修改HOST，所以需要使用 NSURLProtocol 来 hook 网络请求，而且 HTTPS+SNI 场景是非常场景的。

WebView的IP直连方案，基本的思路是接管网络请求，随之就会面临到一些重定向、cookie等问题。下面对这些问题做下记录、总结。

## 面临的问题

### WKWebView 无法使用 NSURLProtocol 拦截请求

 方案如下： 


  1.  换用 UIWebView 
  2. 使用私有API进行注册拦截

换用 UIWebView 方案不做赘述，说明下使用私有API进行注册拦截的方法：

 ```Objective-C
//注册自己的protocol
    [NSURLProtocol registerClass:[CustomProtocol class]];

    //创建WKWebview
    WKWebViewConfiguration * config = [[WKWebViewConfiguration alloc] init];
    WKWebView * wkWebView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height) configuration:config];
    [wkWebView loadRequest:webViewReq];
    [self.view addSubview:wkWebView];

    //注册scheme
    Class cls = NSClassFromString(@"WKBrowsingContextController");
    SEL sel = NSSelectorFromString(@"registerSchemeForCustomProtocol:");
    if ([cls respondsToSelector:sel]) {
        // 通过http和https的请求，同理可通过其他的Scheme 但是要满足ULR Loading System
        [cls performSelector:sel withObject:@"http"];
        [cls performSelector:sel withObject:@"https"];
    }

 ```
 注意避免执行太晚，如果在 `- (void)viewDidLoad` 中注册，可能会因为注册太晚，引发问题。建议在`+load`方法中执行。

然后同样会遇到 [《iOS SNI 场景下的防 DNS 污染方案调研》](https://github.com/ChenYilong/iOSBlog/issues/12) 里提到的各种 NSURLProtocol 相关的问题，可以参照里面的方法解决。

### 使用 NSURLProtocol 拦截 NSURLSession 请求丢失 body

 方案如下： 

  1. 换用 NSURLConnection 
  2. 将 body 放进 Header 中
  3. 使用 HTTPBodyStream 获取 body，并赋值到 body 中

 ```Objective-C
//处理POST请求相关POST  用HTTPBodyStream来处理BODY体
- (void)handlePostRequestBody {
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

 ```

使用 `-[WKWebView  loadRequest]` 同样会遇到该问题，按照同样的方法修改。



## 302重定向问题

上面提到的 Cookie 方案无法解决302请求的 Cookie 问题，比如，第一个请求是 http://www.a.com ，我们通过在 request header 里带上 Cookie 解决该请求的 Cookie 问题，接着页面302跳转到 http://www.b.com ，这个时候 http://www.b.com 这个请求就可能因为没有携带 cookie 而无法访问。当然，由于每一次页面跳转前都会调用回调函数：

 ```Objective-C
 - (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler;
 ```

可以在该回调函数里拦截302请求，copy request，在 request header 中带上 cookie 并重新 loadRequest。不过这种方法依然解决不了页面 iframe 跨域请求的 Cookie 问题，毕竟-[WKWebView loadRequest:]只适合加载 mainFrame 请求。


## Cookie相关问题

单独成篇： [《防 DNS 污染方案调研---iOS HTTPS(含SNI) 业务场景（四）-- Cookie 场景》]( https://github.com/ChenYilong/iOSBlog/issues/14 ) 


## 参考链接


**相关的库：**

  - [GitHub：WebViewProxy](https://github.com/marcuswestin/WebViewProxy) 
  - [GitHub：NSURLProtocol-WebKitSupport](https://github.com/Yeatse/NSURLProtocol-WebKitSupport) 
  - [GitHub：happy-dns-objc](https://github.com/qiniu/happy-dns-objc) 
  - [Chrome For iOS ](https://chromium.googlesource.com/chromium/src.git/+/master/ios/) 

**相关的文章：**

  - [《NSURLProtocol对WKWebView的处理》]( http://www.jianshu.com/p/8f5e1082f5e0 ) 
  - [《可能是最全的iOS端HttpDns集成方案》]( http://www.jianshu.com/p/cd4c1bf1fd5f ) 
  - [《WKWebView 那些坑》]( https://zhuanlan.zhihu.com/p/24990222 ) 


**可以参考的Demo：**

 - [支持SNI与WebView的 alicloud-ios-demo](https://github.com/Dave1991/alicloud-ios-demo) 
 - [HybirdWKWebVIew](https://github.com/LiuShuoyu/HybirdWKWebVIew/) 
 - [《WWDC ​2017-WKWebView 新功能》]( https://zhuanlan.zhihu.com/p/27914128 ) 

## 走过的弯路

## 误以为 iOS11 新 API 可以原生拦截 WKWebView 的 HTTP/HTTPS 网络请求
 
 参考：[Deal With WKWebView DNS pollution problem in iOS11](https://github.com/ChenYilong/iOS11AdaptationTips/issues/16) 

