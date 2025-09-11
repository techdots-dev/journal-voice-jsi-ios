import Foundation
import AVFoundation
import React

@objc(NativeAudioProcessor)
class NativeAudioProcessor: NSObject, NativeAudioProcessorSpec {
  @objc static func requiresMainQueueSetup() -> Bool { false }

  func slowDown(_ inputUri: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let inputPath = inputUri.replacingOccurrences(of: "file://", with: "")
    guard FileManager.default.fileExists(atPath: inputPath) else {
      reject("FILE_NOT_FOUND", "Input audio file not found", nil)
      return
    }

    let outputFileName = String(format: "processed_%.0f.wav", Date().timeIntervalSince1970 * 1000)
    let outputPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(outputFileName)
    let outputUri = "file://\(outputPath)"

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try self.resample(inputPath: inputPath, outputPath: outputPath, rate: 0.75)
        DispatchQueue.main.async {
          resolve(outputUri)
        }
      } catch {
        DispatchQueue.main.async {
          reject("PROCESSING_ERROR", error.localizedDescription, error as NSError)
        }
      }
    }
  }

  private func resample(inputPath: String, outputPath: String, rate: Float) throws {
    let inputURL = URL(fileURLWithPath: inputPath)
    let inputFile = try AVAudioFile(forReading: inputURL)
    let inputFormat = inputFile.processingFormat
    let newSampleRate = inputFormat.sampleRate * Double(rate)
    guard let outputFormat = AVAudioFormat(standardFormatWithSampleRate: newSampleRate, channels: inputFormat.channelCount) else {
      throw NSError(domain: "NativeAudioProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create output format"])
    }
    let outputURL = URL(fileURLWithPath: outputPath)
    let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputFormat.settings)
    guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
      throw NSError(domain: "NativeAudioProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create converter"])
    }
    let bufferSize: AVAudioFrameCount = 4096
    guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: bufferSize) else {
      throw NSError(domain: "NativeAudioProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create input buffer"])
    }
    while true {
      try inputFile.read(into: inputBuffer)
      if inputBuffer.frameLength == 0 { break }
      guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: bufferSize) else {
        throw NSError(domain: "NativeAudioProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create converted buffer"])
      }
      let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
        outStatus.pointee = .haveData
        return inputBuffer
      }
      try converter.convert(to: convertedBuffer, withInputFrom: inputBlock)
      try outputFile.write(from: convertedBuffer)
    }
  }
}
