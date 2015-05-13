//
//  main.swift
//  BlendMicroMyoProtesis
//
//  Created by stant on 10/12/14.
//  Copyright (c) 2014 CCSAS. All rights reserved.
//

import Foundation
import CoreBluetooth


/**
 * The big delegate
 */

class CCBTCentralDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, MyoDelegate {
    
    var peripheral:CBPeripheral!
    var service:CBService!
    var characteristic:CBCharacteristic!
    var myo:Myo!
    
    override init() {
        super.init()
        self.myo = Myo(applicationIdentifier:"com.ccsas.blendmicromyoprotesis")
        self.myo.delegate = self
        self.myo.fuckLockPolicy()
        if self.myo.connectMyoWaiting(1000) {
            self.myo.startUpdate()
        } else {
            NSLog("Connection failed")
            abort()
        }
    }
    
    /**
     * CBCentralManagerDelegate methods
     */
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        if (central.state == CBCentralManagerState.PoweredOn) {
            central.scanForPeripheralsWithServices(nil, options: nil)
        }
    }
    
    func centralManager(central: CBCentralManager!, didFailToConnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        NSLog("Bluetooth connection failed:(")
        abort()
    }
    
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        NSLog("connection successful")
        peripheral.discoverServices(nil)
    }
    
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        self.peripheral = nil
        self.service = nil
        self.characteristic = nil
        central.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        if peripheral.identifier.UUIDString == "13FE7077-710C-46B2-8FF6-5282D972CFF9" {
            NSLog("found, connecting")
            NSLog("%@", advertisementData)
            central.connectPeripheral(peripheral, options: nil)
            central.stopScan()
            self.peripheral = peripheral
            self.peripheral.delegate = self
        }
    }
    
    /**
    * CBPeripheralDelegate methods
    */
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        if service != nil {
            return
        }
        for s in peripheral.services {
            var service = s as CBService
            var serviceUUIDString = service.UUID.UUIDString
            if serviceUUIDString == "713D0000-503E-4C75-BA94-3148F18D941E" {
                NSLog("Found service.")
                peripheral.discoverCharacteristics(nil, forService: service)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!)
    {
        for c in service.characteristics {
            var characteristic = c as CBCharacteristic
            if characteristic.properties == CBCharacteristicProperties.Write {
                NSLog("Write")
            } else if characteristic.properties == CBCharacteristicProperties.Read {
                NSLog("Read")
            } else if characteristic.properties == CBCharacteristicProperties.WriteWithoutResponse {
                NSLog("WriteWithoutResponse")
                self.characteristic = characteristic
            }
        }
    }
    
    /**
    * MyoDelegate methods
    */
    
    func myoOnLock(myo: Myo!, timestamp: UInt64) {
        NSLog("myo on lock")
    }
    
    func myoOnUnlock(myo: Myo!, timestamp: UInt64) {
        NSLog("myo on unlock")
    }
    
    func myoOnConnect(myo: Myo!, firmwareVersion firmware: String!, timestamp: UInt64) {
        NSLog("myo on connect")
    }
    
    func myoOnDisconnect(myo: Myo!, timestamp: UInt64) {
        NSLog("myo on disconnect")
    }
    
    func myoOnArmRecognized(myo: Myo!, arm: MyoArm, direction: MyoDirection, timestamp: UInt64) {
        NSLog("myo recognized")
    }
    
    func myo(myo: Myo!, onPose pose: MyoPose!, timestamp: UInt64) {
        if self.characteristic == nil {
            return
        }
        var poseName = myo.poseName(pose)
        NSLog("%@", poseName)
        if poseName == "Wave In" {
            self.send_msg("c")
        } else if poseName == "Wave Out"  {
            self.send_msg("a")
        } else if poseName == "Rest" {
            self.send_msg("b")
            self.send_msg("d")
        }
    }
    
    private func send_msg(sendString:NSString) {
        self.peripheral.writeValue(sendString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false), forCharacteristic: self.characteristic, type: CBCharacteristicWriteType.WithoutResponse)
    }
}

/**
 * NSRunLoop keep alive timer.
 */

class MainLoop: NSObject {
    
    var centralManager:CBCentralManager!
    var centralManagerDelegate: CCBTCentralDelegate!
    
    override init() {
    }
    
    func loop(timer:NSTimer) {
        if centralManager == nil {
            centralManagerDelegate = CCBTCentralDelegate()
            centralManager = CBCentralManager(delegate: centralManagerDelegate, queue: dispatch_get_main_queue())
        }
    }
    
}

/**
 * main function
 */

var mainLoop:MainLoop = MainLoop()

var mainTimer:NSTimer = NSTimer(timeInterval: 0.3, target: mainLoop, selector:Selector("loop:"), userInfo: nil, repeats: true)

var runLoop:NSRunLoop = NSRunLoop.currentRunLoop()
runLoop.addTimer(mainTimer, forMode: NSRunLoopCommonModes)
runLoop.run()
