# iOS SNI 场景下的防 DNS 污染方案调研

## 现状

/*one more thing*/

<!--- 

官网关于 iOS SNI 场景下的引导如下：

SNI（单IP多HTTPS证书）场景下，iOS上层网络库NSURLConnection/NSURLSession没有提供接口进行SNI字段的配置，因此需要Socket层级的底层网络库例如CFNetwork，来实现IP直连网络请求适配方案。而基于CFNetwork的解决方案需要开发者考虑数据的收发、重定向、解码、缓存等问题（CFNetwork是非常底层的网络实现），希望开发者合理评估该场景的使用风险。可参考：
-->

下面将目前面临的问题写一下：

## 基于 CFNetWork 有性能瓶颈

方案：

 1. 调研性能瓶颈的原因
 2. 换用其他提供了SNI字段配置接口的更底层网络库。

### 调研性能瓶颈的原因

#### 调研方法 

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

### 换用其他提供了SNI字段配置接口的更底层网络库

比如 curl，我在这里写了一个 Demo：[CYLCURLNetworking](https://github.com/ChenYilong/CYLCURLNetworking)，演示了下如何通过curl来进行类似NSURLSession。

## 参考链接：

 - [Apple - Communicating with HTTP Servers](https://developer.apple.com/library/content/documentation/Networking/Conceptual/CFNetwork/CFHTTPTasks/CFHTTPTasks.html?spm=5176.doc30143.2.3.5016q8) 
 - [Apple - HTTPS Server Trust Evaluation - Server Name Failures ](https://developer.apple.com/library/content/technotes/tn2232/_index.html?spm=5176.doc30143.2.4.5016q8#//apple_ref/doc/uid/DTS40012884-CH1-SECSERVERNAME) 
 - [Apple - HTTPS Server Trust Evaluation - Trusting One Specific Certificate ](https://developer.apple.com/library/content/technotes/tn2232/_index.html?spm=5176.doc30143.2.5.5016q8#//apple_ref/doc/uid/DTS40012884-CH1-SECCUSTOMCERT) 
