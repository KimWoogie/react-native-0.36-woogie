/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTImageCache.h"

#import <ImageIO/ImageIO.h>

#import <libkern/OSAtomic.h>

#import <objc/runtime.h>

#import "RCTConvert.h"
#import "RCTImageUtils.h"
#import "RCTNetworking.h"
#import "RCTUtils.h"

static const NSUInteger RCTMaxCachableDecodedImageSizeInBytes = 1048576; // 1MB

static NSString *RCTCacheKeyForImage(NSString *imageTag, CGSize size, CGFloat scale,
                                     RCTResizeMode resizeMode, NSString *responseDate)
{
    return [NSString stringWithFormat:@"%@|%g|%g|%g|%zd|%@",
            imageTag, size.width, size.height, scale, (long)resizeMode, responseDate];
}

@implementation RCTImageCache
{
  NSOperationQueue *_imageDecodeQueue;
  NSCache *_decodedImageCache;
}

- (instancetype)init
{
  _decodedImageCache = [NSCache new];
  _decodedImageCache.totalCostLimit = 5 * 1024 * 1024; // 5MB

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(clearCache)
                                               name:UIApplicationDidReceiveMemoryWarningNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(clearCache)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)clearCache
{
  [_decodedImageCache removeAllObjects];
}

- (void)addImageToCache:(UIImage *)image
                 forKey:(NSString *)cacheKey
{
  if (!image) {
    return;
  }
  CGFloat bytes = image.size.width * image.size.height * image.scale * image.scale * 4;
  if (bytes <= RCTMaxCachableDecodedImageSizeInBytes) {
    [self->_decodedImageCache setObject:image
                                 forKey:cacheKey
                                   cost:bytes];
  }
}

- (UIImage *)imageForUrl:(NSString *)url
                    size:(CGSize)size
                   scale:(CGFloat)scale
              resizeMode:(RCTResizeMode)resizeMode
            responseDate:(NSString *)responseDate
{
  NSString *cacheKey = RCTCacheKeyForImage(url, size, scale, resizeMode, responseDate);
  return [_decodedImageCache objectForKey:cacheKey];
}

- (void)addImageToCache:(UIImage *)image
                    URL:(NSString *)url
                   size:(CGSize)size
                  scale:(CGFloat)scale
             resizeMode:(RCTResizeMode)resizeMode
           responseDate:(NSString *)responseDate
{
  NSString *cacheKey = RCTCacheKeyForImage(url, size, scale, resizeMode, responseDate);
  return [self addImageToCache:image forKey:cacheKey];
}

@end
