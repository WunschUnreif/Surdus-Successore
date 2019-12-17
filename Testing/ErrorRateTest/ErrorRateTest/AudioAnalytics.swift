//
//  AudioAnalytics.swift
//  SurdusDecoder
//
//  Created by apple on 2019/12/16.
//  Copyright © 2019 SJTU. All rights reserved.
//

import Foundation
import Accelerate

class SDAudioAnalytics {
    var anal = Analytics()
    
    var updateHandle : ((Analytics)->Void)? = nil
    
    init(sampleRate: Float) {
        AnalticsInit(&anal, sampleRate)
    }
    
    func feed(_ sample: Float) {
        AnalticsPush(&anal, sample)
        if anal.updated == 1 {
            updateHandle?(anal)
            anal.updated = 0
        }
    }
    
    func batchFeed(_ samples: [Float]) {
        for x in samples {
            feed(x)
        }
    }
    
}

