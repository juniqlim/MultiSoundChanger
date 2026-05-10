//
//  MediaManager.swift
//  MultiSoundChanger
//
//  Created by Dmitry Medyuho on 15.11.2020.
//  Copyright © 2020 Dmitry Medyuho. All rights reserved.
//

import Cocoa
import Foundation
import MediaKeyTap

// MARK: - Protocols

protocol MediaManagerDelegate: class {
    func onMediaKeyTap(mediaKey: MediaKey)
}

protocol MediaManager: class {
    func listenMediaKeyTaps()
    func showOSD(volume: Float, chicletsCount: Int)
}

// MARK: - Implementation

final class MediaManagerImpl: MediaManager {
    private weak var delegate: MediaManagerDelegate?
    private var mediaKeyTap: MediaKeyTap?
    
    init(delegate: MediaManagerDelegate) {
        self.delegate = delegate
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    // MARK: Public
    
    func listenMediaKeyTaps() {
        observeMediaKeyOnAccessibiltiyApiChange()
        startMediaKeyTap()
    }
    
    func showOSD(volume: Float, chicletsCount: Int = 16) {
        NSLog("MSC: showOSD called, volume=\(volume)")
        guard let osdBundle = Bundle(path: "/System/Library/PrivateFrameworks/OSD.framework"),
              osdBundle.load(),
              let osdClass = NSClassFromString("OSDManager") as? NSObject.Type else {
            return
        }

        guard let manager = osdClass.perform(NSSelectorFromString("sharedManager"))?.takeUnretainedValue() as? NSObject else {
            return
        }

        let mouseloc: NSPoint = NSEvent.mouseLocation
        var displayForPoint: CGDirectDisplayID = 0
        var count: UInt32 = 0

        if CGGetDisplaysWithPoint(mouseloc, 1, &displayForPoint, &count) != .success {
            Logger.warning(Constants.InnerMessages.getDisplayError)
            displayForPoint = CGMainDisplayID()
        }

        let image: Int64 = (volume == 0) ? 4 : 3 // OSDGraphicSpeakerMuted / OSDGraphicSpeaker
        let volumeStep: Float = 100 / Float(chicletsCount)

        let sel = NSSelectorFromString("showImage:onDisplayID:priority:msecUntilFade:filledChiclets:totalChiclets:locked:")
        NSLog("MSC OSD: responds=\(manager.responds(to: sel)), volume=\(volume), filled=\(UInt32(volume / volumeStep)), total=\(UInt32(100.0 / volumeStep))")
        if manager.responds(to: sel) {
            let imp = manager.method(for: sel)
            typealias ShowImageFunc = @convention(c) (NSObject, Selector, Int64, UInt32, UInt32, UInt32, UInt32, UInt32, Bool) -> Void
            let f = unsafeBitCast(imp, to: ShowImageFunc.self)
            f(manager, sel, image, displayForPoint, 0x1F4, 1_000, UInt32(volume / volumeStep), UInt32(100.0 / volumeStep), false)
        }
    }
    
    // MARK: Private
    
    private func acquirePrivileges() {
        let trusted = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let privOptions = [trusted: true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(privOptions)
        
        if accessEnabled {
            Logger.warning(Constants.InnerMessages.accessEnabled)
        } else {
            Logger.warning(Constants.InnerMessages.accessDenied)
        }
    }
    
    private func startMediaKeyTap() {
        acquirePrivileges()
        
        let keys: [MediaKey] = [
            .volumeUp,
            .volumeDown,
            .mute
        ]
        
        mediaKeyTap?.stop()
        mediaKeyTap = MediaKeyTap(delegate: self, for: keys, observeBuiltIn: true)
        mediaKeyTap?.start()
    }
    
    private func observeMediaKeyOnAccessibiltiyApiChange() {
        let notificaion = NSNotification.Name(rawValue: Constants.Notifications.accessibility)
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(onAccessibilityNotification),
            name: notificaion,
            object: nil
        )
    }
    
    @objc
    private func onAccessibilityNotification(_ aNotification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.startMediaKeyTap()
        }
    }
}

// MARK: - MediaKeyTapDelegate

extension MediaManagerImpl: MediaKeyTapDelegate {
    func handle(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) {
        delegate?.onMediaKeyTap(mediaKey: mediaKey)
    }
}
