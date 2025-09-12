#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_REMAP_MODULE(AudioProcessorTurbo, AudioProcessor, NSObject)
RCT_EXTERN_METHOD(slowDown:(NSString *)inputUri
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
@end
