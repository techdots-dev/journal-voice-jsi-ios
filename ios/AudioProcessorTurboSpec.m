#import <React/RCTBridgeModule.h>
#import <React/RCTTurboModule.h>

// Maps JS name "AudioProcessorTurbo" to Swift class AudioProcessorTurbo
@interface RCT_EXTERN_REMAP_MODULE(AudioProcessorTurbo, AudioProcessorTurbo, NSObject)

RCT_EXTERN_METHOD(slowDown:(NSString *)inputUri
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

@end
