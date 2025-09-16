//  RCTNativeAudioProcessor.m
//  TurboModuleExample

#import "RCTNativeAudioProcessor.h"

static NSString *const RCTNativeAudioProcessorKey = @"audio-processor";

@interface RCTNativeAudioProcessor()
@property (strong, nonatomic) NSUserDefaults *audioProcessor;
@end

@implementation RCTNativeAudioProcessor

- (id) init {
  if (self = [super init]) {
    _audioProcessor = [[NSUserDefaults alloc] initWithSuiteName:RCTNativeAudioProcessorKey];
  }
  return self;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeAudioProcessorSpecJSI>(params);
}

- (NSString * _Nullable)getItem:(NSString *)key {
  return [self.audioProcessor stringForKey:key];
}

+ (NSString *)moduleName
{
  return @"NativeAudioProcessor";
}

@end