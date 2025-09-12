import Foundation
import React

@objc(AudioProcessorSpec)
protocol AudioProcessorSpec: RCTBridgeModule {
  func slowDown(_ inputUri: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock)
}
