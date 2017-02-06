//
//  GCCWrapper.swift
//  GCCWrapper
//
//  Created by kofktu on 2017. 2. 3..
//  Copyright © 2017년 Kofktu. All rights reserved.
//

import UIKit
import GoogleCast
import KofktuSDK

public enum GCCastState {
    case unavailable
    case connecting
    case connected
    case available
}

public extension Notification.Name {
    static let gccDidConnect = Notification.Name(rawValue: "gccDidConnect")
    static let gccDidDisconnect = Notification.Name(rawValue: "gccDidDisconnect")
}

open class GCCWrapper: NSObject {
    public static let `default` = GCCWrapper()
    public var isConnected: Bool {
        return deviceManager?.applicationConnectionState == .connected
    }
    public var isPlayingMedia: Bool {
        guard let _ = mediaControlChannel?.mediaStatus, deviceManager?.connectionState == .connected else { return false }
        switch playerState {
        case .buffering,
             .playing,
             .paused:
            return true
        default:
            return false
        }
    }
    public var isPaused: Bool {
        guard let _ = mediaControlChannel?.mediaStatus, deviceManager?.connectionState == .connected else { return false }
        return playerState == .paused
    }

    public var dicoveredDevices: [GCKDevice]? {
        return deviceScanner?.devices as? [GCKDevice]
    }
    
    public fileprivate(set) var isReconnecting = false
    public fileprivate(set) var playerState: GCKMediaPlayerState = .unknown
    public fileprivate(set) var state: GCCastState = .unavailable
    
    public fileprivate(set) var streamPosition: TimeInterval = 0.0
    public fileprivate(set) var mediaInformation: GCKMediaInformation?
    public fileprivate(set) var selectedTrackByIdentifier: [Int: Any]?
    
    fileprivate var appId: String!
    fileprivate var clientPackageName: String!
    
    fileprivate var deviceManager: GCKDeviceManager?
    fileprivate var deviceScanner: GCKDeviceScanner?
    fileprivate var mediaControlChannel: GCKMediaControlChannel?
    fileprivate var applicationMeta: GCKApplicationMetadata?
    fileprivate weak var selectedDevice: GCKDevice?
    
    fileprivate var updateTimer: Timer?
    fileprivate var updateInterval: TimeInterval = 1.0
    fileprivate var onUpdateHandler: ((TimeInterval) -> Void)?
    
    fileprivate var lastDeviceId: String?
    fileprivate var lastSessionId: String?
    
    public func setup(appId: String? = nil, clientPackageName: String? = nil) {
        self.appId = appId ?? kGCKMediaDefaultReceiverApplicationID
        self.clientPackageName = clientPackageName ?? Bundle.main.bundleIdentifier!
        let options = GCKCastOptions(receiverApplicationID: self.appId)
        GCKCastContext.setSharedInstanceWith(options)
        
        let filterCriteria = GCKFilterCriteria(forAvailableApplicationWithID: self.appId)
        
        deviceScanner = GCKDeviceScanner(filterCriteria: filterCriteria)
        deviceScanner?.passiveScan = true
    }
    
    public func startScan() {
        if deviceScanner?.scanning ?? false { return }
        
        deviceScanner?.add(self)
        deviceScanner?.startScan()
    }
    
    public func stopScan() {
        guard deviceScanner?.scanning ?? false else { return }
        
        deviceScanner?.stopScan()
        deviceScanner?.remove(self)
    }
    
    public func connect(device: GCKDevice) {
        selectedDevice = device
        
        deviceManager = GCKDeviceManager(device: device, clientPackageName: clientPackageName)
        deviceManager?.delegate = self
        deviceManager?.connect()
    }
    
    public func disconnect() {
        // We're not going to stop the applicaton in case we're not the last client.
        deviceManager?.leaveApplication()
        // If you want to force application to stop, uncomment below.
        deviceManager?.disconnect()
    }
    
    public func loadMedia(_ media: GCCMedia?, autoPlay: Bool = true, playPosition: TimeInterval = 0.0) {
        guard let mediaInfo = media?.mediaInformation else { return }
        guard let deviceManager = deviceManager, deviceManager.connectionState == .connected else {
            Log?.d("deviceManager.connectionState : \(self.deviceManager?.connectionState.rawValue)")
            return
        }
        
        selectedTrackByIdentifier = nil
        mediaControlChannel?.loadMedia(mediaInfo, autoplay: autoPlay, playPosition: playPosition)
    }
    
    open func addPositionObserver(for interval: TimeInterval, progress: ((TimeInterval) -> Void)?) {
        updateTimer?.invalidate()
        updateTimer = nil
        
        updateInterval = interval
        onUpdateHandler = progress
        
        updateTimer = Timer(timeInterval: interval, target: self, selector: #selector(onUpdate), userInfo: nil, repeats: true)
        RunLoop.current.add(updateTimer!, forMode: .commonModes)
    }
    
    open func removePositionObserver() {
        updateTimer?.invalidate()
        updateTimer = nil
        onUpdateHandler = nil
    }
    
    open func updateStatsFromDevice() {
        guard let mediaControlChannel = mediaControlChannel, isConnected, let mediaStatus = mediaControlChannel.mediaStatus else { return }
        
        streamPosition = mediaControlChannel.approximateStreamPosition()
        playerState = mediaStatus.playerState
        mediaInformation = mediaStatus.mediaInformation
        
        if let _ = selectedTrackByIdentifier {
        } else {
            zeroSelectedTracks()
        }
    }
    
    // MARK: - Private
    fileprivate func updateCastState() {
        if deviceScanner?.devices.isEmpty ?? false {
            state = .unavailable
        } else {
            guard let applicationConnectionState = deviceManager?.applicationConnectionState else {
                state = .unavailable
                return
            }
            
            switch applicationConnectionState {
            case .connecting:
                state = .connecting
            case .connected:
                state = .connected
            default:
                state = .available
            }
        }
    }
    
    fileprivate func deviceDisconnectedForgetDevice(clear: Bool = true) {
        mediaControlChannel = nil
        selectedDevice = nil
        
        if clear {
            lastDeviceId = nil
            lastSessionId = nil
        }
    }
    
    fileprivate func isRecoverable(error: Error?) -> Bool {
        guard let error = error as? NSError else { return false }
        
        return error.code == GCKErrorCode.networkError.rawValue ||
               error.code == GCKErrorCode.timeout.rawValue ||
               error.code == GCKErrorCode.appDidEnterBackground.rawValue
    }
    
    private func zeroSelectedTracks() {
        guard let tracks = mediaInformation?.mediaTracks else { return }
        
        selectedTrackByIdentifier = [Int: Any]()
        
        for track in tracks {
            selectedTrackByIdentifier?[track.identifier] = false
        }
    }
    
    // MARK: - Action
    internal func onUpdate() {
        updateStatsFromDevice()
        onUpdateHandler?(streamPosition)
    }
}

extension GCCWrapper {
    func play() {
        mediaControlChannel?.play()
    }
    
    func pause() {
        mediaControlChannel?.pause()
    }
    
    func stop() {
        mediaControlChannel?.stop()
    }
    
    func seekTo(position: TimeInterval) {
        mediaControlChannel?.seek(toTimeInterval: max(0.0, position))
    }
}

extension GCCWrapper: GCKDeviceScannerListener {
    public func deviceDidComeOnline(_ device: GCKDevice) {
        Log?.d("device.online : \(device.friendlyName)")
        
        if let lastDeviceId = lastDeviceId, lastDeviceId == device.deviceID {
            isReconnecting = true
        }
        
        connect(device: device)
    }
    
    public func deviceDidGoOffline(_ device: GCKDevice) {
        Log?.d("device.offline : \(device.friendlyName)")
        updateCastState()
    }
}

extension GCCWrapper: GCKDeviceManagerDelegate {
    public func deviceManagerDidConnect(_ deviceManager: GCKDeviceManager) {
        Log?.d("deviceManager.didConnect")
        if let lastSessionId = lastSessionId, isReconnecting {
            deviceManager.joinApplication(appId, sessionID: lastSessionId)
        } else {
            deviceManager.launchApplication(appId)
        }
        
        updateCastState()
    }
    
    public func deviceManager(_ deviceManager: GCKDeviceManager, didConnectToCastApplication applicationMetadata: GCKApplicationMetadata, sessionID: String, launchedApplication: Bool) {
        isReconnecting = false
        
        mediaControlChannel = GCKMediaControlChannel()
        mediaControlChannel?.delegate = self
        deviceManager.add(mediaControlChannel!)
        mediaControlChannel?.requestStatus()
        
        applicationMeta = applicationMetadata
        updateCastState()
        
        if let selectedDevice = selectedDevice {
            lastSessionId = sessionID
            lastDeviceId = selectedDevice.deviceID
        }
    }
    
    public func deviceManager(_ deviceManager: GCKDeviceManager, didDisconnectWithError error: Error?) {
        Log?.e(error as? NSError)
        
        deviceDisconnectedForgetDevice(clear: !isRecoverable(error: error))
        updateCastState()
    }
    
    public func deviceManager(_ deviceManager: GCKDeviceManager, didDisconnectFromApplicationWithError error: Error?) {
        Log?.e(error as? NSError)
        
        deviceDisconnectedForgetDevice(clear: !isRecoverable(error: error))
        updateCastState()
    }
    
    public func deviceManager(_ deviceManager: GCKDeviceManager, didFailToConnectWithError error: Error) {
        Log?.d("deviceManager.didFailToConnect : \(error)")
        
        deviceDisconnectedForgetDevice()
        updateCastState()
    }
    
    public func deviceManager(_ deviceManager: GCKDeviceManager, didFailToConnectToApplicationWithError error: Error) {
        Log?.d("deviceManager.didFailToConnectToApplication : \(error)")
        
        if isReconnecting && (error as NSError).code == GCKErrorCode.applicationNotRunning.rawValue {
            // Expected error when unable to reconnect to previous session after another
            // application has been running
            isReconnecting = false
            deviceDisconnectedForgetDevice()
        }
        
        updateCastState()
    }
    
    public func deviceManager(_ deviceManager: GCKDeviceManager, volumeDidChangeToLevel volumeLevel: Float, isMuted: Bool) {
        Log?.d("volume : \(volumeLevel), isMuted : \(isMuted)")
    }
    
    public func deviceManager(_ deviceManager: GCKDeviceManager, didSuspendConnectionWith reason: GCKConnectionSuspendReason) {
        if reason == .appBackgrounded {
            Log?.d("connection suspended : app background")
        } else {
            Log?.d("connection suspended : network disconnected. reconnect")
        }
    }
    
    public func deviceManagerDidResumeConnection(_ deviceManager: GCKDeviceManager, rejoinedApplication: Bool) {
        Log?.d("deviceManager.connectionResume : \(rejoinedApplication ? "YES" : "NO")")
        updateCastState()
    }
}

extension GCCWrapper: GCKMediaControlChannelDelegate {
    public func mediaControlChannel(_ mediaControlChannel: GCKMediaControlChannel, didCompleteLoadWithSessionID sessionID: Int) {
        Log?.d("didCompleteLoadWithSessionID : \(sessionID)")
        self.mediaControlChannel = mediaControlChannel
    }
    
    public func mediaControlChannelDidUpdateStatus(_ mediaControlChannel: GCKMediaControlChannel) {
        Log?.d("mediaControlChannelDidUpdateStatus")
        self.mediaControlChannel = mediaControlChannel
        updateStatsFromDevice()
    }
    
    public func mediaControlChannelDidUpdateMetadata(_ mediaControlChannel: GCKMediaControlChannel) {
        Log?.d("mediaControlChannelDidUpdateMetadata")
        self.mediaControlChannel = mediaControlChannel
        updateStatsFromDevice()
    }
}

extension GCCWrapper: GCKLoggerDelegate {
    public func logMessage(_ message: String, fromFunction function: String) {
        Log?.d("[\(function)] : \(message)")
    }
}
