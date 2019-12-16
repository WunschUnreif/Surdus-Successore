//
//  AudioCapturer.swift
//  AudioServer
//
//  Created by apple on 2019/12/16.
//  Copyright © 2019 SJTU. All rights reserved.
//

import Foundation
import AVFoundation

class SDAudioCapturer : NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    let capSession = AVCaptureSession()
    
    let dispatchQueue = DispatchQueue(label: "com.wunschunreif.ASAudioCapturer", qos: .userInteractive)
    
    var audioDataHandle : (([Float], Int) -> Void)? = nil
    
    var sampleRate = 96400.0
    
    
    init(sampleRate: Double = 96000.0) {
        super.init()
        
        self.sampleRate = sampleRate
        
        configureCaptureSession()
    }
    
    func configureCaptureSession() {
        capSession.beginConfiguration()

        // Configure the input device
        let audioDev = AVCaptureDevice.default(for: .audio)!
        let audioInput = try! AVCaptureDeviceInput(device: audioDev)

        if(capSession.canAddInput(audioInput)) {
            capSession.addInput(audioInput)
        }
        
        // Configure the output
        let dataOutput = AVCaptureAudioDataOutput()
        dataOutput.audioSettings = [
            AVSampleRateKey : NSNumber(floatLiteral: sampleRate),   // Sample rate
            AVNumberOfChannelsKey : NSNumber(integerLiteral: 1),    // Channle number
            AVFormatIDKey : kAudioFormatLinearPCM,                  // Output format

            AVLinearPCMBitDepthKey : NSNumber(integerLiteral: 32),  // Bit depth
            AVLinearPCMIsBigEndianKey : false,                      // Endian
            AVLinearPCMIsFloatKey : true,                           // Float data
            AVLinearPCMIsNonInterleaved : false,                    // Useless when only 1 channel
        ]
        dataOutput.setSampleBufferDelegate(self, queue: dispatchQueue)

        if(capSession.canAddOutput(dataOutput)) {
            capSession.addOutput(dataOutput)
        }
        
        capSession.commitConfiguration()
    }
    
    // Delegate function, called when an audio buffer is generated
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Copy the raw PCM data
        var dataBuffer = [Float](repeating: 0, count: 8192)
        CMBlockBufferCopyDataBytes(sampleBuffer.dataBuffer!, atOffset: sampleBuffer.dataBuffer!.startIndex, dataLength: sampleBuffer.dataBuffer!.dataLength, destination: UnsafeMutableRawPointer(&dataBuffer))
        
        // Call the data handle function
        dispatchQueue.async {
            self.audioDataHandle?(dataBuffer, sampleBuffer.numSamples)
        }
    }
    
    func start() {
        capSession.startRunning()
    }
    
    func stop() {
        capSession.stopRunning()
    }
}
