//
//  AdvancedEncoder.swift
//  SurdusEncoder
//
//  Created by apple on 2019/12/16.
//  Copyright © 2019 @WunschUnreif. All rights reserved.
//

import Foundation
import AVFoundation


class SEAdvancedEncoder {
    var sampleRate: Double = 96000.0
    
    /// Time duration for a single code element. Should be set by `transmitRateBPS`
    var codeElementTime: Double = 0.025
    
    /// Use Phase-Modulation. Should be set by `transmitRateBPS`
    var encodingInPhase = true
    
    // The current PCM buffer for coded data
    private var signalAudioPCMBuffers: [AVAudioPCMBuffer] = []
    // If the current byte/word is even-sequenced
    private var evenByte = true
    // The time for encoding a continous data
    private var globalTime = 0.0
    
    /// The total duration of the coded audio
    var duration: TimeInterval {
        return signalAudioPCMBuffers.reduce(0.0, { (lastResult, curr) in
            lastResult + Double((curr as AVAudioPCMBuffer).frameLength) / sampleRate
        })
    }
    
    /// Set or get the transmit rate in 'bps' and the current coding mode.
    var transmitRateBPS : (bps: Double, phaseMod: Bool) {
        get {
            return (encodingInPhase ? 1 / codeElementTime * 16 : 1 / codeElementTime * 8, encodingInPhase)
        }
        set {
            codeElementTime = newValue.phaseMod ? 1 / (newValue.bps / 16) : 1 / (newValue.bps / 8)
            encodingInPhase = newValue.phaseMod
        }
    }
    
    private let clockFreqs = [17400.0, 17500.0, 17600.0, 17700.0, 17800.0, 17900.0]
    private let dataFreqs = [18000.0, 18400.0, 18800.0, 19200.0]
    
    /// Clear the data it has encoded.
    func clearData() {
        signalAudioPCMBuffers = []
        evenByte = true
        globalTime = 0.0
        addPhaseSync()
    }
    
    /// Save the audio into the specified file URL
    func save(toFile file: URL) -> Bool {
        let audioFile = try? AVAudioFile(forWriting: file, settings: [AVSampleRateKey: NSNumber(floatLiteral: sampleRate)])
        do {
            try audioFile?.write(from: synthesize())
        } catch {
            return false
        }
        return true
    }
    
    /// Synthesize the buffers into one buffer
    private func synthesize() -> AVAudioPCMBuffer {
        let totalLength = signalAudioPCMBuffers.reduce(0, { $0 + $1.frameLength })
        
        let finalBuffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!, frameCapacity: totalLength)!
        
        finalBuffer.frameLength = totalLength
        
        var currIndex = 0
        for buffer in signalAudioPCMBuffers {
            for index in 0..<Int(buffer.frameLength) {
                finalBuffer.floatChannelData![0][currIndex] = buffer.floatChannelData![0][index]
                currIndex += 1
            }
        }
        
        return finalBuffer
    }
    
    private func clock() -> Double {
        if encodingInPhase {
            if evenByte {   // Even, Phase
                return sin(2 * .pi * clockFreqs[3] * globalTime)
            } else {        // Odd,  Phase
                return sin(2 * .pi * clockFreqs[2] * globalTime)
            }
        } else {
            if evenByte {   // Even, Freq
                return sin(2 * .pi * clockFreqs[1] * globalTime)
            } else {        // Odd,  Freq
                return sin(2 * .pi * clockFreqs[0] * globalTime)
            }
        }
    }
    
    private func data16(_ code: UInt16) -> Double {
        let c0 = (code & 0x000F) >> 0
        let c1 = (code & 0x00F0) >> 4
        let c2 = (code & 0x0F00) >> 8
        let c3 = (code & 0xF000) >> 12
        
        let f0 = Double(c0 / 4) * 100 + dataFreqs[0]
        let f1 = Double(c1 / 4) * 100 + dataFreqs[1]
        let f2 = Double(c2 / 4) * 100 + dataFreqs[2]
        let f3 = Double(c3 / 4) * 100 + dataFreqs[3]
        
        let p0 = Double(c0 % 4) * .pi / 2
        let p1 = Double(c1 % 4) * .pi / 2
        let p2 = Double(c2 % 4) * .pi / 2
        let p3 = Double(c3 % 4) * .pi / 2
        
        return sin(2 * .pi * f0 * globalTime + p0) +
                sin(2 * .pi * f1 * globalTime + p1) +
                sin(2 * .pi * f2 * globalTime + p2) +
                sin(2 * .pi * f3 * globalTime + p3)
    }
    
    private func data8(_ code: UInt8) -> Double {
        let c0 = (code & 0x03) >> 0
        let c1 = (code & 0x0C) >> 2
        let c2 = (code & 0x30) >> 4
        let c3 = (code & 0xC0) >> 6
        
        let f0 = Double(c0) * 100 + dataFreqs[0]
        let f1 = Double(c1) * 100 + dataFreqs[1]
        let f2 = Double(c2) * 100 + dataFreqs[2]
        let f3 = Double(c3) * 100 + dataFreqs[3]
        
        return sin(2 * .pi * f0 * globalTime) +
                sin(2 * .pi * f1 * globalTime) +
                sin(2 * .pi * f2 * globalTime) +
                sin(2 * .pi * f3 * globalTime)
    }
    
    private func sync() -> Double {
        var result = 0.0
        if evenByte {
            result += sin(2 * .pi * clockFreqs[5] * globalTime)
            for offset in stride(from: 0, to: 16, by: 2) {
                result += sin(2 * .pi * (18000 + Double(offset) * 100) * globalTime)
            }
            result /= 9.0
        } else {
            result += sin(2 * .pi * clockFreqs[4] * globalTime)
            for offset in stride(from: 1, to: 16, by: 2) {
                result += sin(2 * .pi * (18000 + Double(offset) * 100) * globalTime)
            }
            result /= 9.0
        }
        return result
    }
    
    private func addPhaseSync(ofFrameNum num: Int = 5) {
        // Half of the frequencies
        let buffer1 = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!,
            frameCapacity: UInt32(sampleRate * codeElementTime * Double(num))
        )!
        buffer1.frameLength = buffer1.frameCapacity

        for index in 0..<buffer1.frameCapacity {
            buffer1.floatChannelData![0][Int(index)] = Float(sync())
            globalTime += 1 / sampleRate
        }
       
        signalAudioPCMBuffers.append(buffer1)
        
        evenByte = !evenByte
        
        // Another half
        let buffer2 = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!,
            frameCapacity: UInt32(sampleRate * codeElementTime * Double(num))
        )!
        buffer2.frameLength = buffer2.frameCapacity

        for index in 0..<buffer2.frameCapacity {
            buffer2.floatChannelData![0][Int(index)] = Float(sync())
            globalTime += 1 / sampleRate
        }
        
        signalAudioPCMBuffers.append(buffer2)
        
        evenByte = !evenByte
    }
    
    private func add8Bit(data: UInt8) {
        let buffer = AVAudioPCMBuffer(
             pcmFormat: AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!,
             frameCapacity: UInt32(sampleRate * codeElementTime)
         )!
         buffer.frameLength = buffer.frameCapacity

         for index in 0..<buffer.frameCapacity {
             buffer.floatChannelData![0][Int(index)] = Float(data8(data) + clock()) / 5
             globalTime += 1 / sampleRate
         }
        
         signalAudioPCMBuffers.append(buffer)
         
         evenByte = !evenByte
    }
    
    private func add16Bit(data: UInt16) {
        let buffer = AVAudioPCMBuffer(
             pcmFormat: AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!,
             frameCapacity: UInt32(sampleRate * codeElementTime)
         )!
         buffer.frameLength = buffer.frameCapacity

         for index in 0..<buffer.frameCapacity {
             buffer.floatChannelData![0][Int(index)] = Float(data16(data) + clock()) / 5
             globalTime += 1 / sampleRate
         }
        
         signalAudioPCMBuffers.append(buffer)
         
         evenByte = !evenByte
    }
    
    private var byteCount = 0
    
    func addData(of16Bit word: UInt16) {
        byteCount += 2
        if encodingInPhase {
            add16Bit(data: word)
        } else {
            add8Bit(data: UInt8(word >> 8))
            add8Bit(data: UInt8(word & 0x00FF))
        }
        if byteCount >= 32 {
            addPhaseSync(ofFrameNum: 1)
        }
    }
}


