//  RCTNativeAudioProcessor.m
//  TurboModuleExample

#import "RCTNativeAudioProcessor.h"

#import <AVFoundation/AVFoundation.h>

static NSString *const RCTNativeAudioProcessorErrorDomain = @"NativeAudioProcessor";

@interface RCTNativeAudioProcessor ()
- (BOOL)resampleAudioAtPath:(NSString *)inputPath
                 outputPath:(NSString *)outputPath
                       rate:(float)rate
                      error:(NSError **)error;
@end

@implementation RCTNativeAudioProcessor

RCT_EXPORT_MODULE();

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:(const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeAudioProcessorSpecJSI>(params);
}

RCT_EXPORT_METHOD(slowDown:(NSString *)inputUri
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject)
{
  if (inputUri == nil || inputUri.length == 0) {
    reject(@"INVALID_URI", @"Input audio URI is required", nil);
    return;
  }

  NSString *inputPath = [inputUri stringByReplacingOccurrencesOfString:@"file://" withString:@""];
  if (![[NSFileManager defaultManager] fileExistsAtPath:inputPath]) {
    reject(@"FILE_NOT_FOUND", @"Input audio file not found", nil);
    return;
  }

  NSString *outputFileName = [NSString stringWithFormat:@"processed_%.0f.wav",
                                                        [[NSDate date] timeIntervalSince1970] * 1000];
  NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:outputFileName];
  NSString *outputUri = [NSString stringWithFormat:@"file://%@", outputPath];

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSError *error = nil;
    BOOL success = [self resampleAudioAtPath:inputPath
                                  outputPath:outputPath
                                        rate:0.75f
                                       error:&error];

    if (!success || error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        reject(@"PROCESSING_ERROR", error.localizedDescription ?: @"Unknown error", error);
      });
      return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      resolve(outputUri);
    });
  });
}

- (BOOL)resampleAudioAtPath:(NSString *)inputPath
                 outputPath:(NSString *)outputPath
                       rate:(float)rate
                      error:(NSError **)error
{
  NSURL *inputURL = [NSURL fileURLWithPath:inputPath];
  AVAudioFile *inputFile = [[AVAudioFile alloc] initForReading:inputURL error:error];
  if (error != NULL && *error) {
    return NO;
  }

  AVAudioFormat *inputFormat = inputFile.processingFormat;
  double newSampleRate = inputFormat.sampleRate * rate;
  AVAudioFormat *outputFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:newSampleRate
                                                                              channels:inputFormat.channelCount];

  AVAudioFile *outputFile = [[AVAudioFile alloc] initForWriting:[NSURL fileURLWithPath:outputPath]
                                                       settings:outputFormat.settings
                                                          error:error];
  if (error != NULL && *error) {
    return NO;
  }

  AVAudioConverter *converter = [[AVAudioConverter alloc] initFromFormat:inputFormat toFormat:outputFormat];
  if (converter == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:RCTNativeAudioProcessorErrorDomain
                                   code:-1
                               userInfo:@{NSLocalizedDescriptionKey : @"Unable to create audio converter"}];
    }
    return NO;
  }

  AVAudioFrameCount bufferSize = 4096;
  AVAudioPCMBuffer *inputBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:inputFormat
                                                                frameCapacity:bufferSize];

  while (YES) {
    NSError *readError = nil;
    BOOL didRead = [inputFile readIntoBuffer:inputBuffer error:&readError];
    if (readError) {
      if (error != NULL) {
        *error = readError;
      }
      return NO;
    }
    if (!didRead || inputBuffer.frameLength == 0) {
      break;
    }

    AVAudioPCMBuffer *convertedBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:outputFormat
                                                                        frameCapacity:bufferSize];

    AVAudioConverterInputBlock inputBlock = ^AVAudioBuffer * _Nullable(AVAudioPacketCount inNumberOfPackets,
                                                                       AVAudioConverterInputStatus *outStatus) {
      *outStatus = AVAudioConverterInputStatus_HaveData;
      return inputBuffer;
    };

    AVAudioConverterOutputStatus status = [converter convertToBuffer:convertedBuffer
                                                               error:error
                                                      withInputFromBlock:inputBlock];
    if (status == AVAudioConverterOutputStatus_Error || (error != NULL && *error)) {
      return NO;
    }

    [outputFile writeFromBuffer:convertedBuffer error:error];
    if (error != NULL && *error) {
      return NO;
    }
  }

  return YES;
}

// + (NSString *)moduleName
// {
//   return @"NativeAudioProcessor";
// }

@end
