//
//  main.swift
//  ErrorRateTest
//
//  Created by apple on 2019/12/16.
//  Copyright © 2019 SJTU. All rights reserved.
//

import Foundation
import AVFoundation

print("Hello, World!")

let testTarget: [UInt16] = [0x5a5a, 0xa5a5, 0x1234, 0xcdef]

var received = 0
var error = 0

func countBit(data:UInt16) -> Int {
    var result = 0
    var temp = data
    for _ in 0..<16 {
        result += temp % 2 == 1 ? 1 : 0
        temp = temp >> 1
    }
    return result
}

let encoder = SEAdvancedEncoder()

encoder.clearData()

// You can change this to test under different conditions.
encoder.transmitRateBPS = (1600, true)

var k = 0
for _ in 0..<60 {
    encoder.addData(of16Bit: testTarget[k])
    k = (k + 1) % 4
}

let _ = encoder.save(toFile: URL(fileURLWithPath:
    "./ert_\(encoder.transmitRateBPS.phaseMod ? "p" : "f")_\(Int(encoder.transmitRateBPS.bps))bps.wav"))

print("Enter 'stop' to stop or other thing to start test")
let str = readLine()
if(str == "stop") {
    exit(0)
}

let capturer = SDAudioCapturer(sampleRate: 96000)

let analytics = SDAudioAnalytics(sampleRate: 96000)

let decoder = SDAdvancedDecoder()

capturer.audioDataHandle = { (data, count) in
    analytics.batchFeed([Float](data[0..<count]))
}

analytics.updateHandle = { anal in
    decoder.update(anal: anal)
}

var cnter = 0
var low8: UInt8 = 0
decoder.newFrameHandle = { (data, is16bit) in
    if received >= 960 {
        return
    }
    if is16bit {
        error += countBit(data: data ^ testTarget[Int(cnter) / 2])
        received += 16
        cnter += 2
    } else {
        received += 8
        if cnter % 2 == 0 {
            low8 = UInt8(data)
        } else {
            error += countBit(data: ((data << 8) | (UInt16(low8))) ^ testTarget[Int(cnter) / 2])
        }
        cnter += 1
    }
    if cnter > 7 {
        cnter = 0
    }
}

capturer.start()

let starttime = Date()
while(received < 900) {
    sleep(1)
    if(Date().timeIntervalSince(starttime) > 10) {
        break;
    }
}
sleep(1)

print("Received Bit: \(received), Error Bit: \(error), Rate: \(Double(error) / Double(received) * 100.0)%")
