#import "AudioProcessor.h"
#import <AVFoundation/AVFoundation.h>
#import <React/RCTLog.h>

@implementation AudioProcessor

RCT_EXPORT_MODULE(AudioProcessor);

RCT_EXPORT_METHOD(slowDown:(NSString *)inputUri
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
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
                                           rate:0.75
                                          error:&error];

        if (!success || error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                reject(@"PROCESSING_ERROR", error.localizedDescription ?: @"Unknown error", error);
            });
            return;
        }

        // Resolve on main queue to ensure JS sees it
        dispatch_async(dispatch_get_main_queue(), ^{
            resolve(outputUri);
        });
    });
}

// CPU-based resample: works on simulator and device
- (BOOL)resampleAudioAtPath:(NSString *)inputPath
                 outputPath:(NSString *)outputPath
                      rate:(float)rate
                     error:(NSError **)error
{
    NSURL *inputURL = [NSURL fileURLWithPath:inputPath];
    AVAudioFile *inputFile = [[AVAudioFile alloc] initForReading:inputURL error:error];
    if (*error) return NO;

    AVAudioFormat *inputFormat = inputFile.processingFormat;
    double newSampleRate = inputFormat.sampleRate * rate;
    AVAudioFormat *outputFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:newSampleRate
                                                                                 channels:inputFormat.channelCount];

    AVAudioFile *outputFile = [[AVAudioFile alloc] initForWriting:[NSURL fileURLWithPath:outputPath]
                                                          settings:outputFormat.settings
                                                             error:error];
    if (*error) return NO;

    AVAudioConverter *converter = [[AVAudioConverter alloc] initFromFormat:inputFormat
                                                                  toFormat:outputFormat];

    AVAudioFrameCount bufferSize = 4096;
    AVAudioPCMBuffer *inputBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:inputFormat
                                                                 frameCapacity:bufferSize];

    while (YES) {
        NSError *readError = nil;
        BOOL didRead = [inputFile readIntoBuffer:inputBuffer error:&readError];
        if (readError) { *error = readError; return NO; }
        if (inputBuffer.frameLength == 0) break;

        AVAudioPCMBuffer *convertedBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:outputFormat
                                                                          frameCapacity:bufferSize];

        AVAudioConverterInputBlock inputBlock = ^AVAudioBuffer * _Nullable(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus *outStatus) {
            *outStatus = AVAudioConverterInputStatus_HaveData;
            return inputBuffer;
        };

        AVAudioConverterOutputStatus status = [converter convertToBuffer:convertedBuffer
                                                                    error:error
                                                       withInputFromBlock:inputBlock];
        if (*error || status == AVAudioConverterOutputStatus_Error) return NO;

        [outputFile writeFromBuffer:convertedBuffer error:error];
        if (*error) return NO;
    }

    return YES;
}

@end
