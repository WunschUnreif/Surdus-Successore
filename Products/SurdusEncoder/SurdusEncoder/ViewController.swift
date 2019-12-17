//
//  ViewController.swift
//  SurdusEncoder
//
//  Created by apple on 2019/12/16.
//  Copyright © 2019 SJTU. All rights reserved.
//

import Cocoa
import AVFoundation

class ViewController: NSViewController, NSOpenSavePanelDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        initSavePanel()
        
        advenc.transmitRateBPS = (640, true)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func initSavePanel() {
        savePanel.delegate = self
        savePanel.allowedFileTypes = ["wav"]
        savePanel.isExtensionHidden = false
    }
    
    func encodeMessage() {
        let message = textMessage.stringValue
        
        advenc.clearData()
        
        var currWord: UInt16 = 0
        
        for i in stride(from: 0, to: message.lengthOfBytes(using: .utf8), by: 2) {
            if i == message.lengthOfBytes(using: .utf8) - 1 {
                currWord = UInt16(message.utf8[message.utf8.index(message.utf8.startIndex, offsetBy: i)]) << 8
            } else {
                currWord = UInt16(message.utf8[message.utf8.index(message.utf8.startIndex, offsetBy: i)]) << 8
                currWord += UInt16(message.utf8[message.utf8.index(message.utf8.startIndex, offsetBy: i+1)])
            }
            advenc.addData(of16Bit: currWord)
        }
    }
    
    func updateRate(_ rate: Double, usePhase: Bool) {
        if usePhase {
            slideRate.maxValue = 1200
        } else {
            slideRate.maxValue = 600
        }
        
        let realRate = min(slideRate.maxValue, rate)
        
        slideRate.doubleValue = realRate
        textRate.doubleValue = realRate
        
        advenc.transmitRateBPS = (rate, usePhase)
    }
        
    var advenc = SEAdvancedEncoder()
    
    var savePanel: NSSavePanel = NSSavePanel()
    
    var player: AVAudioPlayer = AVAudioPlayer()
    
    @IBAction func onSave(_ sender: NSButton) {
        encodeMessage()
        savePanel.beginSheetModal(for: view.window!, completionHandler: {response in
            if response == .OK {
                let _ = self.advenc.save(toFile: self.savePanel.url!)
            }
        })
    }
    
    @IBAction func onPlay(_ sender: NSButton) {
        encodeMessage()
        let _ = advenc.save(toFile: URL(fileURLWithPath: "./temp.wav"))
        player = try! AVAudioPlayer(contentsOf: URL(fileURLWithPath: "./temp.wav"))
        player.prepareToPlay()
        player.play()
    }
    
    @IBAction func onPhaseModChanged(_ sender: NSSwitch) {
        updateRate(textRate.doubleValue, usePhase: sender.state == .on)
    }
    
    @IBAction func onSlideRateChanged(_ sender: NSSlider) {
        updateRate(sender.doubleValue, usePhase: switchPhase.state == .on)
    }
    @IBAction func onTextRateChanged(_ sender: NSTextField) {
        updateRate(sender.doubleValue, usePhase: switchPhase.state == .on)
    }
    
    @IBOutlet weak var textMessage: NSTextField!
    @IBOutlet weak var switchPhase: NSSwitch!
    @IBOutlet weak var slideRate: NSSlider!
    @IBOutlet weak var textRate: NSTextField!
}



