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

let testTarget: [UInt16] = [0x5555, 0x5a5a, 0x1212, 0xcdcd]

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
decoder.newFrameHandle = { (data, is16bit) in
    if received >= 1600 {
        return
    }
    if is16bit {
        error += countBit(data: data ^ testTarget[Int(cnter) / 2])
        received += 16
        cnter += 2
    } else {
        error += countBit(data: data ^ (testTarget[Int(cnter) / 2] & 0xFF))
        received += 8
        cnter += 1
        
    }
    if cnter > 7 {
        cnter = 0
    }
}
capturer.start()

let encoder = SEAdvancedEncoder()
encoder.clearData()

// You can change this to test under different conditions.
encoder.transmitRateBPS = (1200, true)

var k = 0
for _ in 0..<100 {
    encoder.addData(of16Bit: testTarget[k])
    k = (k + 1) % 4
}

sleep(1)

let _ = encoder.save(toFile: URL(fileURLWithPath: "./temp.wav"))
let player = try! AVAudioPlayer(contentsOf: URL(fileURLWithPath: "./temp.wav"))
player.prepareToPlay()


    player.play()


while player.isPlaying {}
sleep(1)

print("Received Bit: \(received), Error Bit: \(error), Rate: \(Double(error) / Double(received) * 100.0)%")
