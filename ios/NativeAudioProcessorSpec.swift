import Foundation
import React

@objc(NativeAudioProcessorSpec)
protocol NativeAudioProcessorSpec: RCTBridgeModule, RCTTurboModule {
  func slowDown(_ inputUri: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock)
}
