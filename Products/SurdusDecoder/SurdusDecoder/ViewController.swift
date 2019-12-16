//
//  ViewController.swift
//  SurdusDecoder
//
//  Created by apple on 2019/12/16.
//  Copyright © 2019 SJTU. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    var capturer = SDAudioCapturer(sampleRate: 96000)
    var analytics = SDAudioAnalytics(sampleRate: 96000)
    var audioDataBuffer: [Float] = []
    var audioWindowSize = 4096.0
    var advdec = SDAdvancedDecoder()
    var utf8Buffer: [UInt8] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        capturer.audioDataHandle = { (data: [Float], count: Int) in
            self.analytics.batchFeed([Float](data[0..<count]))
        }
        
        analytics.updateHandle = {
            self.advdec.update(anal: $0)
        }
        
        advdec.newFrameHandle = { (data, is16bit) in
            if data != 0 {
                self.utf8Buffer.append(UInt8((data & 0xFF00) >> 8))
                self.utf8Buffer.append(UInt8((data & 0x00FF) >> 0))
            }
            DispatchQueue.main.async {
                if let str = NSString(bytes: &self.utf8Buffer, length: self.utf8Buffer.count, encoding: String.Encoding.utf8.rawValue) {
                    self.textRecv.stringValue = str as String
                }
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func onClear(_ sender: NSButton) {
        textRecv.stringValue = ""
        utf8Buffer.removeAll()
    }
    
    @IBAction func onRun(_ sender: NSSwitch) {
        if sender.state == .on {
            capturer.start()
        } else {
            capturer.stop()
        }
    }
    
    
    @IBOutlet var textRecv: NSTextField!
    
    @IBOutlet weak var buttonClear: NSButton!
    
}

