import Foundation
import AVFoundation
import React

@objc(AudioProcessorTurbo)
class AudioProcessorTurbo: NSObject, AudioProcessorSpec {
  
  @objc static func moduleName() -> String! { "AudioProcessorTurbo" }
  @objc static func requiresMainQueueSetup() -> Bool { false }

  @objc
  func slowDown(_ inputUri: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let inputPath = inputUri.replacingOccurrences(of: "file://", with: "")
    guard FileManager.default.fileExists(atPath: inputPath) else {
      reject("FILE_NOT_FOUND", "Input audio file not found", nil)
      return
    }

    let outputFileName = "processed_\(Int(Date().timeIntervalSince1970 * 1000)).wav"
    let outputPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(outputFileName)
    let outputUri = "file://\(outputPath)"

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try self.processAudioWithTimeStretch(inputPath: inputPath, outputPath: outputPath, rate: 0.75)
        
        guard FileManager.default.fileExists(atPath: outputPath) else {
          DispatchQueue.main.async { reject("PROCESSING_ERROR", "Output file was not created", nil) }
          return
        }
        
        DispatchQueue.main.async { resolve(outputUri) }
      } catch {
        DispatchQueue.main.async { reject("PROCESSING_ERROR", error.localizedDescription, error as NSError) }
      }
    }
  }

  private func processAudioWithTimeStretch(inputPath: String, outputPath: String, rate: Float) throws {
    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)
    
    // Remove existing output file
    if FileManager.default.fileExists(atPath: outputPath) {
      try FileManager.default.removeItem(at: outputURL)
    }
    
    let audioEngine = AVAudioEngine()
    let audioFile = try AVAudioFile(forReading: inputURL)
    let audioFormat = audioFile.processingFormat
    
    let playerNode = AVAudioPlayerNode()
    audioEngine.attach(playerNode)
    
    let timePitchNode = AVAudioUnitTimePitch()
    timePitchNode.rate = rate
    audioEngine.attach(timePitchNode)
    
    // Create mixer node for tapping
    let mixerNode = AVAudioMixerNode()
    audioEngine.attach(mixerNode)
    
    // Connect nodes: player -> timePitch -> mixer -> output
    audioEngine.connect(playerNode, to: timePitchNode, format: audioFormat)
    audioEngine.connect(timePitchNode, to: mixerNode, format: audioFormat)
    audioEngine.connect(mixerNode, to: audioEngine.outputNode, format: audioFormat)
    
    // Prepare output file
    let outputFile = try AVAudioFile(forWriting: outputURL, settings: audioFormat.settings)
    
    // Use a flag to track when we should stop writing
    var shouldStopWriting = false
    var isProcessingComplete = false
    
    // Install tap on the mixer node
    mixerNode.installTap(onBus: 0, bufferSize: 4096, format: audioFormat) { buffer, time in
      guard !shouldStopWriting else { return }
      
      do {
        try outputFile.write(from: buffer)
        
        // Check if we should stop writing after this buffer
        if isProcessingComplete {
          shouldStopWriting = true
        }
      } catch {
        print("Error writing to file: \(error)")
        shouldStopWriting = true
      }
    }
    
    // Use semaphore to wait for completion
    let completionSemaphore = DispatchSemaphore(value: 0)
    
    // Schedule the file with completion handler
    playerNode.scheduleFile(audioFile, at: nil) {
      // Mark processing as complete
      isProcessingComplete = true
      
      // Wait a moment for any remaining buffers to be processed
      DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
        completionSemaphore.signal()
      }
    }
    
    try audioEngine.start()
    playerNode.play()
    
    // Calculate maximum wait time
    let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
    let stretchedDuration = duration / Double(rate)
    let timeout = stretchedDuration + 3.0 // Add 3 second buffer
    
    // Wait for completion with timeout
    if completionSemaphore.wait(timeout: .now() + timeout) == .timedOut {
      print("Processing timed out")
      isProcessingComplete = true
    }
    
    // Cleanup
    playerNode.stop()
    audioEngine.stop()
    mixerNode.removeTap(onBus: 0)
  }
}