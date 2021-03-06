/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI23_0_0RCTBlobManager.h"

#import <ReactABI23_0_0/ABI23_0_0RCTConvert.h>
#import <ReactABI23_0_0/ABI23_0_0RCTWebSocketModule.h>

static NSString *const kBlobUriScheme = @"blob";

@interface _ABI23_0_0RCTBlobContentHandler : NSObject <ABI23_0_0RCTWebSocketContentHandler>

- (instancetype)initWithBlobManager:(ABI23_0_0RCTBlobManager *)blobManager;

@end


@implementation ABI23_0_0RCTBlobManager
{
  NSMutableDictionary<NSString *, NSData *> *_blobs;
  _ABI23_0_0RCTBlobContentHandler *_contentHandler;
  NSOperationQueue *_queue;
}

ABI23_0_0RCT_EXPORT_MODULE(BlobModule)

@synthesize bridge = _bridge;

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (NSDictionary<NSString *, id> *)constantsToExport
{
  return @{
    @"BLOB_URI_SCHEME": kBlobUriScheme,
    @"BLOB_URI_HOST": [NSNull null],
  };
}

- (dispatch_queue_t)methodQueue
{
  return [[_bridge webSocketModule] methodQueue];
}

- (NSString *)store:(NSData *)data
{
  NSString *blobId = [NSUUID UUID].UUIDString;
  [self store:data withId:blobId];
  return blobId;
}

- (void)store:(NSData *)data withId:(NSString *)blobId
{
  if (!_blobs) {
    _blobs = [NSMutableDictionary new];
  }

  _blobs[blobId] = data;
}

- (NSData *)resolve:(NSDictionary<NSString *, id> *)blob
{
  NSString *blobId = [ABI23_0_0RCTConvert NSString:blob[@"blobId"]];
  NSNumber *offset = [ABI23_0_0RCTConvert NSNumber:blob[@"offset"]];
  NSNumber *size = [ABI23_0_0RCTConvert NSNumber:blob[@"size"]];

  return [self resolve:blobId
                offset:offset ? [offset integerValue] : 0
                  size:size ? [size integerValue] : -1];
}

- (NSData *)resolve:(NSString *)blobId offset:(NSInteger)offset size:(NSInteger)size
{
  NSData *data = _blobs[blobId];
  if (!data) {
    return nil;
  }
  if (offset != 0 || (size != -1 && size != data.length)) {
    data = [data subdataWithRange:NSMakeRange(offset, size)];
  }
  return data;
}

ABI23_0_0RCT_EXPORT_METHOD(enableBlobSupport:(nonnull NSNumber *)socketID)
{
  if (!_contentHandler) {
    _contentHandler = [[_ABI23_0_0RCTBlobContentHandler alloc] initWithBlobManager:self];
  }
  [[_bridge webSocketModule] setContentHandler:_contentHandler forSocketID:socketID];
}

ABI23_0_0RCT_EXPORT_METHOD(disableBlobSupport:(nonnull NSNumber *)socketID)
{
  [[_bridge webSocketModule] setContentHandler:nil forSocketID:socketID];
}

ABI23_0_0RCT_EXPORT_METHOD(sendBlob:(NSDictionary *)blob socketID:(nonnull NSNumber *)socketID)
{
  [[_bridge webSocketModule] sendData:[self resolve:blob] forSocketID:socketID];
}

ABI23_0_0RCT_EXPORT_METHOD(createFromParts:(NSArray<NSDictionary<NSString *, id> *> *)parts withId:(NSString *)blobId)
{
  NSMutableData *data = [NSMutableData new];
  for (NSDictionary<NSString *, id> *part in parts) {
    NSData *partData = [self resolve:part];
    [data appendData:partData];
  }
  [self store:data withId:blobId];
}

ABI23_0_0RCT_EXPORT_METHOD(release:(NSString *)blobId)
{
  [_blobs removeObjectForKey:blobId];
}

#pragma mark - ABI23_0_0RCTURLRequestHandler methods

- (BOOL)canHandleRequest:(NSURLRequest *)request
{
  return [request.URL.scheme caseInsensitiveCompare:kBlobUriScheme] == NSOrderedSame;
}

- (id)sendRequest:(NSURLRequest *)request withDelegate:(id<ABI23_0_0RCTURLRequestDelegate>)delegate
{
  // Lazy setup
  if (!_queue) {
    _queue = [NSOperationQueue new];
    _queue.maxConcurrentOperationCount = 2;
  }

  __weak __block NSBlockOperation *weakOp;
  __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:request.URL
                                                        MIMEType:nil
                                           expectedContentLength:-1
                                                textEncodingName:nil];

    [delegate URLRequest:weakOp didReceiveResponse:response];

    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:request.URL resolvingAgainstBaseURL:NO];

    NSString *blobId = components.path;
    NSInteger offset = 0;
    NSInteger size = -1;

    if (components.queryItems) {
      for (NSURLQueryItem *queryItem in components.queryItems) {
        if ([queryItem.name isEqualToString:@"offset"]) {
          offset = [queryItem.value integerValue];
        }
        if ([queryItem.name isEqualToString:@"size"]) {
          size = [queryItem.value integerValue];
        }
      }
    }

    NSData *data;
    if (blobId) {
      data = [self resolve:blobId offset:offset size:size];
    }
    NSError *error;
    if (data) {
      [delegate URLRequest:weakOp didReceiveData:data];
    } else {
      error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil];
    }
    [delegate URLRequest:weakOp didCompleteWithError:error];
  }];

  weakOp = op;
  [_queue addOperation:op];
  return op;
}

- (void)cancelRequest:(NSOperation *)op
{
  [op cancel];
}

@end

@implementation _ABI23_0_0RCTBlobContentHandler {
  __weak ABI23_0_0RCTBlobManager *_blobManager;
}

- (instancetype)initWithBlobManager:(ABI23_0_0RCTBlobManager *)blobManager
{
  if (self = [super init]) {
    _blobManager = blobManager;
  }
  return self;
}

- (id)processMessage:(id)message forSocketID:(NSNumber *)socketID withType:(NSString *__autoreleasing _Nonnull *)type
{
  if (![message isKindOfClass:[NSData class]]) {
    *type = @"text";
    return message;
  }

  *type = @"blob";
  return @{
     @"blobId": [_blobManager store:message],
     @"offset": @0,
     @"size": @(((NSData *)message).length),
   };
}

@end
