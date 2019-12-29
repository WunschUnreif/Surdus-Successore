//
//  AdvancedDecoder.swift
//  SurdusDecoder
//
//  Created by apple on 2019/12/16.
//  Copyright © 2019 @WunschUnreif. All rights reserved.
//

import Foundation

// After down-sampling, this module works at about 600 Hz.
// The working frequency can be changed in `filter.c`
class SDAdvancedDecoder {
    
    enum CodeType {
        case noSignal           //
        case oddByteFreqOnly    //    17400
        case evenByteFreqOnly   //    17500
        case oddBytePhase       //    17600
        case evenBytePhase      //    17700
        case oddPhaseSync       //    17800
        case evenPhaseSync      //    17900
    }
    
    struct SpectrumSenario {
        var type : CodeType = .noSignal
        var powerBuffer: [Float] = []   // Only the data frequencies
        var phaseBuffer: [Float] = []   // Only the data frequencies
    }
    
    /// The current estimation of initial phase error for each data frequency
    private var initialPhaseEstimation = [Float](repeating: 0, count: 16)
    
    /// The current estimation of data
    private var currentDataEstimations: [(type: CodeType, data: UInt16, is16Bit: Bool)] = []
    
    /// A sliding window for spectrum senarios
    private var senarioWindow = [SpectrumSenario](repeating: SpectrumSenario(), count: 15)
    
    /// The handle which is called when a new word is resolved
    /// parameters: [word:UInt16, is16Bit:Bool]
    ///             [received data, is 16 bit (true) or 8 bit (false) frame]
    var newFrameHandle: ((UInt16, Bool) -> Void)? = nil
    
    /// convert phase angle to [-pi, pi]
    private func phaseNormalize(p: Float) -> Float {
        var phase = p
        while phase > .pi {
            phase -= 2 * .pi
        }
        while phase < -.pi {
            phase += 2 * .pi
        }
        return phase
    }
    
    /// Normalize a vector of length 3
    private func vecNorm3(x: [Float]) -> [Float] {
        let norm = sqrt(x[0] * x[0] + x[1] * x[1] + x[2] * x[2])
        return x.map { $0 / norm }
    }
    
    /// Calculate dot product of vectors of length 3
    private func dot3(x: [Float], y: [Float]) -> Float {
        let normX = vecNorm3(x: x)
        let normY = vecNorm3(x: y)
        return normX[0] * normY[0] + normX[1] * normY[1] + normX[2] * normY[2]
    }
    
    /// Estimate the current spectrum senario
    private func senario(anal: Analytics) -> SpectrumSenario {
        let background = anal.powers[0]
        
        let clocks = (1..<7).map{ anal.powers[$0] }
        
        var senarioEstimation = SpectrumSenario()
        senarioEstimation.powerBuffer = (7..<23).map { anal.powers[$0] }
        senarioEstimation.phaseBuffer = (7..<23).map { self.phaseNormalize(p: anal.phases[$0]) }
        
        if clocks.max()! - background < 40 {
            senarioEstimation.type = .noSignal
            return senarioEstimation
        }
        
        let maxInd = maxIndex(of: clocks)
        
        switch maxInd {
        case 0:
            senarioEstimation.type = .oddByteFreqOnly
        case 1:
            senarioEstimation.type = .evenByteFreqOnly
        case 2:
            senarioEstimation.type = .oddBytePhase
        case 3:
            senarioEstimation.type = .evenBytePhase
        case 4:
            senarioEstimation.type = .oddPhaseSync
        case 5:
            senarioEstimation.type = .evenPhaseSync
        default:
            senarioEstimation.type = .noSignal
        }
        
        return senarioEstimation
    }
    
    /// Get the most common type in current window
    private func commonType() -> CodeType {
        var maxCount = 0
        var common: CodeType = .noSignal
        
        let labels: [CodeType] = [
            .noSignal, .oddByteFreqOnly, .evenByteFreqOnly,
            .oddPhaseSync, .oddBytePhase, .evenPhaseSync, .evenBytePhase
        ]
        
        for label in labels {
            let cnt = senarioWindow.filter({ $0.type == label }).count
            if cnt > maxCount {
                maxCount = cnt
                common = label
            }
        }
        
        return common
    }
    
    /// Get the index of the maximum element
    private func maxIndex(of arr: [Float]) -> UInt8 {
        var max = arr.min()!
        var ind = 0
        
        for index in 0..<arr.count {
            if arr[index] > max {
                ind = index
                max = arr[index]
            }
        }
        
        return UInt8(ind)
    }
    
    private func commonFrame() {
        var currCommon: UInt16 = 0
        var maxCount = 0
        
        if currentDataEstimations.count == 0 {
            return
        }
        
        for frame in currentDataEstimations {
            let count = currentDataEstimations.filter({ $0.data == frame.data }).count
            if count > maxCount {
                maxCount = count
                currCommon = frame.data
            }
        }
        
        if maxCount != 0 {
            newFrameHandle?(currCommon, currentDataEstimations[0].is16Bit)
        }
        
        currentDataEstimations.removeAll()
    }
    
    /// Estimate one senario using only frequency
    private func codeEstimateFreqOnly(anal: SpectrumSenario) -> UInt8 {
        let dataIndices:[Int] = [
            0, 4, 8, 12
        ]
        let codeIndices = dataIndices.map {
            return [$0, $0 + 1, $0 + 2, $0 + 3]
        }
        
        let code0 = maxIndex(of: codeIndices[0].map { anal.powerBuffer[$0] })
        let code1 = maxIndex(of: codeIndices[1].map { anal.powerBuffer[$0] })
        let code2 = maxIndex(of: codeIndices[2].map { anal.powerBuffer[$0] })
        let code3 = maxIndex(of: codeIndices[3].map { anal.powerBuffer[$0] })
        
        return UInt8(code0 | (code1 << 2) | (code2 << 4) | (code3 << 6))
    }
    
    /// Resolve a data word which uses only frequency coding
    private func resolveDataFreqOnly(window: [SpectrumSenario]) {
        var dataEstimation: (type: CodeType, data: UInt16, is16Bit: Bool) = (window[0].type, 0, false)
        
        let estimates = window.map { codeEstimateFreqOnly(anal: $0) }
        var maxCount = 0
        for byte in estimates {
            let cnt = estimates.filter {$0 == byte }.count
            if cnt > maxCount {
                maxCount = cnt
                dataEstimation.data = UInt16(byte)
            }
        }
        
        if currentDataEstimations.count != 0 && dataEstimation.type != currentDataEstimations[0].type {
            commonFrame()
        }
        currentDataEstimations.append(dataEstimation)
    }
    
    /// Using frequency index and phase to synthesize a code of 4 bits
    private func synthesizeFreqPhase(freqIndex: UInt8, phase: Float) -> UInt16 {
        if phase > -.pi / 4 && phase <= .pi / 4 {           // 0 deg : -45 ~ 45
            return UInt16(freqIndex) * 4 + 0
        }
        if phase > .pi / 4 && phase <= 3 * .pi / 4 {        // 90 deg: 45 ~ 135
            return UInt16(freqIndex) * 4 + 3
        }
        if phase > 3 * .pi / 4 || phase <= -3 * .pi / 4 {   // 180 deg: > 135 || < -135
            return UInt16(freqIndex) * 4 + 2
        }
        return UInt16(freqIndex) * 4 + 1                    // 270 deg
    }
    
    /// Estimate one senario using frequency and phase
    private func codeEstimateFreqPhase(anal: SpectrumSenario) -> UInt16 {
        let dataIndices:[Int] = [
            0, 4, 8, 12
        ]
        let codeIndices = dataIndices.map {
            return [$0, $0 + 1, $0 + 2, $0 + 3]
        }
        
        // Frequency modulated part
        let f0 = maxIndex(of: codeIndices[0].map { anal.powerBuffer[$0] })
        let f1 = maxIndex(of: codeIndices[1].map { anal.powerBuffer[$0] })
        let f2 = maxIndex(of: codeIndices[2].map { anal.powerBuffer[$0] })
        let f3 = maxIndex(of: codeIndices[3].map { anal.powerBuffer[$0] })
        
        // Phase modulated part
        let p0 = phaseNormalize(p: anal.phaseBuffer[Int(0 * 4 + f0)] - initialPhaseEstimation[Int(0 * 4 + f0)])
        let p1 = phaseNormalize(p: anal.phaseBuffer[Int(1 * 4 + f1)] - initialPhaseEstimation[Int(1 * 4 + f1)])
        let p2 = phaseNormalize(p: anal.phaseBuffer[Int(2 * 4 + f2)] - initialPhaseEstimation[Int(2 * 4 + f2)])
        let p3 = phaseNormalize(p: anal.phaseBuffer[Int(3 * 4 + f3)] - initialPhaseEstimation[Int(3 * 4 + f3)])
                        
        // Resolving
        let code0 = synthesizeFreqPhase(freqIndex: f0, phase: p0)
        let code1 = synthesizeFreqPhase(freqIndex: f1, phase: p1)
        let code2 = synthesizeFreqPhase(freqIndex: f2, phase: p2)
        let code3 = synthesizeFreqPhase(freqIndex: f3, phase: p3)
        
        print("\(code0) \(code1) \(code2) \(code3)")
        
        return UInt16(code0 | (code1 << 4) | (code2 << 8) | (code3 << 12))
    }
    
    /// Resolve a data word which uses frequency and phase coding
    private func resolveDataFreqPhase(window: [SpectrumSenario]) {
        var dataEstimation: (type: CodeType, data: UInt16, is16Bit: Bool) = (window[0].type, 0, true)
        
        let estimates = window.map { codeEstimateFreqPhase(anal: $0) }
        var maxCount = 0
        for byte in estimates {
            let cnt = estimates.filter {$0 == byte }.count
            if cnt > maxCount {
                maxCount = cnt
                dataEstimation.data = UInt16(byte)
            }
        }
        
        if currentDataEstimations.count != 0 && dataEstimation.type != currentDataEstimations[0].type {
            commonFrame()
        }
        currentDataEstimations.append(dataEstimation)
    }
    
    private var syncBufferI: [Float] = [Float](repeating: 0, count: 16)
    private var syncBufferQ: [Float] = [Float](repeating: 0, count: 16)
    private var syncBufferCount = 0
    private var isSyncingOdd = false, isSyncingEven = false
    
    /// Syncronize the initial phases
    private func phaseSync(window: [SpectrumSenario]) {
        var avgCos = [Float](repeating: 0, count: 16)
        var avgSin = [Float](repeating: 0, count: 16)
        for i in 0..<16 {
            for senario in window {
                avgCos[i] += cosf(senario.phaseBuffer[i])
                avgSin[i] += sinf(senario.phaseBuffer[i])
            }
            avgCos[i] /= Float(window.count)
            avgSin[i] /= Float(window.count)
        }
        
        if (window[0].type == .oddPhaseSync  && isSyncingOdd  == false) ||
           (window[0].type == .evenPhaseSync && isSyncingEven == false) {
            
            syncBufferI = [Float](repeating: 0, count: 16)
            syncBufferQ = [Float](repeating: 0, count: 16)
            syncBufferCount = 0
            
            isSyncingOdd = window[0].type == .oddPhaseSync
            isSyncingEven = window[0].type == .evenPhaseSync
        }
        
        if window[0].type == .oddPhaseSync {
            for i in stride(from: 1, to: 16, by: 2) {
                syncBufferI[i] += avgCos[i]
                syncBufferQ[i] += avgSin[i]
                syncBufferCount += 1
                initialPhaseEstimation[i] = atan2f(syncBufferQ[i] / Float(syncBufferCount), syncBufferI[i] / Float(syncBufferCount))
            }
        } else {
            for i in stride(from: 0, to: 16, by: 2) {
                syncBufferI[i] += avgCos[i]
                syncBufferQ[i] += avgSin[i]
                syncBufferCount += 1
                initialPhaseEstimation[i] = atan2f(syncBufferQ[i] / Float(syncBufferCount), syncBufferI[i] / Float(syncBufferCount))
            }
        }
    }
    
    
    /// Update the decoder with a new Analytics data
    func update(anal: Analytics) {
        // Update the silding window
        let currSenario = senario(anal: anal)
        senarioWindow.remove(at: 0)
        senarioWindow.append(currSenario)
        
        let common = commonType()
        let commonWindow = senarioWindow.filter({ $0.type == common })
        
        // Ignore heavy noised window
        if commonWindow.count < 9 {
            return
        }
                
        // Respond to common label
        switch common {
        case .noSignal:
            commonFrame()
        case .oddByteFreqOnly, .evenByteFreqOnly:
            resolveDataFreqOnly(window: commonWindow)
        case .oddBytePhase, .evenBytePhase:
            resolveDataFreqPhase(window: commonWindow)
        case .oddPhaseSync, .evenPhaseSync:
            commonFrame()
            phaseSync(window: commonWindow)
        }
        
        isSyncingOdd = common == .oddPhaseSync
        isSyncingEven = common == .evenPhaseSync
    }
    
}
