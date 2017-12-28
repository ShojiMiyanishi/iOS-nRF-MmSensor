//
//  BlinkyPeripheral.swift
//  nRFBlinky
//
//  Created by Mostafa Berg on 28/11/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//

import UIKit
import CoreBluetooth

class MmsensorPeripheral:
 NSObject,
 CBPeripheralDelegate   // peripheralからのコールバック
{
    // スキャン開始は　
    // ScannerTableViewController.swftの
    // centralManagerDidUpdateState
    // override func viewDidAppear(_ animated: Bool)
    // で開始されている。
    // キャラクタリスティックUUID
    public static let ledCharacteristicUUID = CBUUID.init(string: "A001")                                       //LEDキャラクタリスティック
    public static let TxPowerUUID     = CBUUID.init(string: "2A07")
    public static let TxIntervalUUID  = CBUUID.init(string: "65025681-0FD8-5FB5-5148-3027069B3FD9") 
    public static let TxUUID          = CBUUID.init(string: "65020002-0FD8-5FB5-5148-3027069B3FD1")  //キャラクタリスティック
    public static let RxUUID          = CBUUID.init(string: "65020003-0FD8-5FB5-5148-3027069B3FD1")  //キャラクタリスティック
    public static let BleIdUUID        = CBUUID.init(string: "65020004-0FD8-5FB5-5148-3027069B3FD1")  //BleIdキャラクタリスティック
    public static let IntervalUUID    = CBUUID.init(string: "65020005-0FD8-5FB5-5148-3027069B3FD1")  //キャラクタリスティック
    public static let WifiIdUUID      = CBUUID.init(string: "65020006-0FD8-5FB5-5148-3027069B3FD1")  //WifiIdキャラクタリスティック
    // サービスUUID
    public static let LedServiceUUID  = CBUUID.init(string: "A000")//var UUID1:CBUUID
    public static let WifiIdServiceUUID = CBUUID.init(string: "65020001-0FD8-5FB5-5148-3027069B3FD1")//Gateway Id Service
    
    public static let BatteryServiceUUID = CBUUID.init(string:"180F")
    public static let TxPowerServiceUUID = CBUUID.init(string:"1804")
    public static let EnvironmentalServiceUUID = CBUUID.init(string: "181A")
    //public static let nordicBlinkyServiceUUID  = CBUUID.init(string: "65025680-0FD8-5FB5-5148-3027069B3FD9")// ID service
    //MARK: - Properties
    //
    public private(set) var basePeripheral      : CBPeripheral //CoreBluetoothのペリフェラルクラス
    public private(set) var advertisedName      : String?   //アドバタイズデータに入っているname
    public var bleId              : String!    // BleIdキャラクタリスティック
    public var wifiId              : String!    // BleIdキャラクタリスティック
    public private(set) var RSSI                : NSNumber  //アドバタイズデータパケットの受信電力
    public private(set) var rssiCount = 0
    public private(set) var rssiSum = 0.0
    public private(set) var rssiSqr = 0.0
    public private(set) var advertisedServices  : [CBUUID]? //検索サービスUUID

    var ledIsOn:Bool!
    var celIndex:Int!

    //MARK: - Callback handlers
    private var ledCallbackHandler : ((Bool) -> (Void))?
    private var bleCallbackHandler : ((String) -> (Void))?
    private var wifiCallbackHandler : ((String) -> (Void))?

    //MARK: - Services and Characteristic properties
    //
    public private(set) var bleIdService        : CBService?
    private             var wifiIdService       : CBService?
    private             var ledService          : CBService?
    private             var buttonCharacteristic: CBCharacteristic?
    private             var ledCharacteristic   : CBCharacteristic?
    private             var wifiIdCharacteristic   : CBCharacteristic?
    private             var bleIdCharacteristic   : CBCharacteristic?

    func setBleIdService(_ service:CBService){    bleIdService = service    }
    func setWifiIdService(_ service:CBService){   wifiIdService = service    }
    func setCharacteristic( target:CBUUID , value:CBCharacteristic){
        if target == MmsensorPeripheral.BleIdUUID{
            bleIdCharacteristic = value
        }else
        if target == MmsensorPeripheral.WifiIdUUID{
            wifiIdCharacteristic = value
        }
    }
    enum Job{
        case none
        case readAll
        case readLed
        case readId
        case searchSSID
    }
    
    var job=Job.none
    
    init(
        withPeripheral aPeripheral: CBPeripheral,
        advertisementData anAdvertisementDictionary: [String : Any],// 引数ラベル:advertisementData 仮引数：anAdvertisementDictionary
        andRSSI anRSSI: NSNumber)
    {
        basePeripheral = aPeripheral
        RSSI = anRSSI
        rssiCount += 1
        rssiSum += anRSSI.doubleValue
        rssiSqr += anRSSI.doubleValue * anRSSI.doubleValue
        
        super.init()
        
        (advertisedName, advertisedServices) = parseAdvertisementData(anAdvertisementDictionary)

        //print("[MmsensorPeripheral.init]",(advertisedName, advertisedServices))
        basePeripheral.delegate = self
        
    }
    
    public func setLEDCallback(aCallbackHandler: @escaping (Bool) -> (Void)){
        print("["+#function+"]")
        ledCallbackHandler = aCallbackHandler
    }
    public func setBleIdCallback(aCallbackHandler: @escaping (String) -> (Void)){
        print("["+#function+"]")
        bleCallbackHandler = aCallbackHandler
    }
    public func setWifiIdCallback(aCallbackHandler: @escaping (String) -> (Void)){
        print("["+#function+"]")
        wifiCallbackHandler = aCallbackHandler
    }

/*
    public func removeButtonCallback() {
        print("["+#function+"]")
        buttonPressHandler = nil
    }
*/    
    public func removeLEDCallback() {
        print("["+#function+"]")
        ledCallbackHandler = nil
    }

    // 接続後のサービス検索開始
    public func discoverMmSensorServices() {
        //print("["+#function+"]")
        basePeripheral.delegate = self
        
        //basePeripheral.discoverServices( nil )
        //return 
        
        var ServiceUUIDs:[CBUUID]=[CBUUID]()
        if nil == wifiIdService {
            //print("Discover WifiId service!")
            ServiceUUIDs.append(MmsensorPeripheral.WifiIdUUID)
            ServiceUUIDs.append(MmsensorPeripheral.BleIdUUID)
        }else{
            if nil == bleId {
                if let readCharacteristic = bleIdCharacteristic{
                    basePeripheral.readValue(for: readCharacteristic)
                }
            }
            if nil == wifiId {
                if let readCharacteristic = wifiIdCharacteristic{
                    basePeripheral.readValue(for: readCharacteristic)
                }
            }
        }
        if nil == ledService {
            //print("Discover LED service!")
            ServiceUUIDs.append( MmsensorPeripheral.ledCharacteristicUUID )
        }else{
            if nil == ledIsOn {
                if let readCharacteristic = ledCharacteristic{
                    basePeripheral.readValue(for: readCharacteristic)
                }
            }else{
                ledCallbackHandler!(ledIsOn)
            }
        }
        // サービスを検索する。
        if !ServiceUUIDs.isEmpty{
            print("Discover services!:\(ServiceUUIDs)")
            //basePeripheral.discoverServices(ServiceUUIDs)
            basePeripheral.discoverServices( nil )
        }
    }
    public func discoverMmSensorServicesByJob(mode:Job) {
        print("["+#function+"]")
        job = mode
        basePeripheral.delegate = self
        if mode == .readAll{
            basePeripheral.discoverServices(nil)
        }else{
            basePeripheral.discoverServices([
                MmsensorPeripheral.WifiIdServiceUUID
            ])
        }
    }
    // キャラクタリスティックの検索開始
    public func discoverCharacteristicsByJob(_ aService: CBService) {
        var CharacteristicsUUIDs:[CBUUID]!
        print("["+#function+"]\(job)")
        //
        //  Jobによって検索するUUIDを設定する
        //
        switch job{
        case .readId:
            if aService.uuid == MmsensorPeripheral.WifiIdServiceUUID{
                print("Search:\(aService.uuid.uuidString)->WifiId & BleId")
                CharacteristicsUUIDs = [
                    MmsensorPeripheral.ledCharacteristicUUID,
                    MmsensorPeripheral.WifiIdUUID,
                    MmsensorPeripheral.BleIdUUID
                ]
            }
            
        default:
            print("SERVICE:\(aService.uuid.uuidString)->do nothing")
        }
        // サービスのキャラクタリスティックを検索する。
        if let searchUuid = CharacteristicsUUIDs{
            basePeripheral.discoverCharacteristics( searchUuid, for: aService)
        }
    }
    /*
    public func enableButtonNotifications(_ buttonCharacteristic: CBCharacteristic) {
        print("["+#function+"]Enabling notifications for button characteristic")
        //basePeripheral.setNotifyValue(true, for: buttonCharacteristic)
    }
    */
    public func readLEDValue() {
        print("["+#function+"]")
        if let ledCharacteristic = ledCharacteristic {
            basePeripheral.readValue(for: ledCharacteristic)
        }
    }
    
    public func readButtonValue() {
        print("["+#function+"]")
        if let buttonCharacteristic = buttonCharacteristic {
            basePeripheral.readValue(for: buttonCharacteristic)
        }
    }

    public func didWriteValueToLED(_ aValue: Data) {
        print("["+#function+"]")
        print("LED value written \(aValue[0])")
        if aValue[0] == 1 {
            ledIsOn = true
        } else {
            ledIsOn = false
        }
        ledCallbackHandler?(ledIsOn)
    }
    
/*
    public func didReceiveButtonNotificationWithValue(_ aValue: Data) {
        print("["+#function+"]")
        print("Button value changed to: \(aValue[0])")
        if aValue[0] == 1 {
            buttonPressHandler?(true)
        } else {
            buttonPressHandler?(false)
        }
    }
*/    
    public func turnOnLED() {
        print("["+#function+"]")
        writeLEDCharcateristicValue(Data([0x1]))
    }
    
    public func turnOffLED() {
        print("["+#function+"]")
        writeLEDCharcateristicValue(Data([0x0]))
    }
    
    private func writeLEDCharcateristicValue(_ aValue: Data) {
        print("["+#function+"]")
        guard let ledCharacteristic = ledCharacteristic else {
            print("LED characteristic is not present, nothing to be done")
            return
        }
        basePeripheral.writeValue(aValue, for: ledCharacteristic, type: .withResponse)
    }

    // アドバタイズデータの解析(パース)
    // 引数：anAdvertisementDictionaryは、key: Srting型、value:Anyの辞書
    // 戻り値：
    private func parseAdvertisementData(_ anAdvertisementDictionary: [String : Any]) -> (String?, [CBUUID]?) {
        var advertisedServices: [CBUUID]
        var key: String
        if let name = anAdvertisementDictionary[CBAdvertisementDataLocalNameKey] as? String{
            key = name
        } else {
            key = "N/A"
        }
        if let services = anAdvertisementDictionary[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            advertisedServices = services
        } else {
            advertisedServices = [CBUUID]()
        }
        
        return (key, advertisedServices)
    }

    //MARK: - NSObject protocols
    // 比較のオーバライド
    // identifierを使用して比較
    override func isEqual(_ object: Any?) -> Bool {
        if object is MmsensorPeripheral {
            let peripheralObject = object as! MmsensorPeripheral
            return peripheralObject.basePeripheral.identifier == basePeripheral.identifier
        } else if object is CBPeripheral {
            let peripheralObject = object as! CBPeripheral
            return peripheralObject.identifier == basePeripheral.identifier
        } else {
            return false
        }
    }
    
    //MARK: - CBPeripheralDelegate
    /*
     * キャラクタリスティックのReadWriteによるコールバック
     *
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("[\(#function)]\(characteristic.uuid)")
        /*
        if characteristic == buttonCharacteristic {
            if let aValue = characteristic.value {
                didReceiveButtonNotificationWithValue(aValue)
            }
        } else
        */ 
        if let count = characteristic.value?.count{
            var values0 = [UInt8](repeating:0, count: count)
            var values = [UInt8](repeating:0, count: count)
        
            characteristic.value?.copyBytes(to: &values0,count:values.count)
            var index:Int=1
            for i in values0{
                values[count-index]=i
                index += 1
            }
            if characteristic.uuid.uuidString==ledCharacteristic?.uuid.uuidString{
                if values[0]==0 {
                    ledIsOn = false
                }else{
                    ledIsOn = true
                }
                print("led:\(ledIsOn),values:\(values)")
                ledCallbackHandler?(ledIsOn)
            }else
            if characteristic.uuid==bleIdCharacteristic?.uuid{
                let hexStr = values.map{
                    String(format: "%.2hhx",$0)
                }.joined()
                self.bleId=hexStr
                print("[\(index)][\(#function)]ID:\(hexStr),bleId:\(String(describing: self.bleId))")
                bleCallbackHandler?(hexStr)
            }else
            if characteristic.uuid==wifiIdCharacteristic?.uuid{
                let hexStr = values.map{
                    String(format: "%.2hhx",$0)
                }.joined()
                self.wifiId=hexStr
                print("[\(index)][\(#function)]ID:\(hexStr),wifiId:\(wifiId)")
                wifiCallbackHandler?(hexStr)
            }else{
                //print("[\(#function)]bleIdCharacteristic:\(bleIdCharacteristic.uuid.uuidString)")
                print("[\(#function)]characteristic.UUID:\(characteristic.uuid)")
                print("[\(#function)]characteristic:\(characteristic)")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == buttonCharacteristic?.uuid {
            print("Notification state is now \(characteristic.isNotifying) for Button characteristic")
            readButtonValue()
            readLEDValue()
        } else {
            print("Notification state is now \(characteristic.isNotifying) for an unknown characteristic with UUID: \(characteristic.uuid.uuidString)")
        }
    }

    /*
     * サービススキャンでサービスを発見した時のコールバック
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("[\(#function)]")
        if let services = peripheral.services {
            for service in services {
                var CharacteristicsUUIDs:[CBUUID]!
                if service.uuid == MmsensorPeripheral.WifiIdServiceUUID {
                    wifiIdService = service
                    print("Discovered WifiId service!")
                    CharacteristicsUUIDs = [
                        MmsensorPeripheral.WifiIdUUID,
                        MmsensorPeripheral.BleIdUUID
                    ]
                }else
                if service.uuid == MmsensorPeripheral.LedServiceUUID {
                    print("Discovered LED service!")
                    ledService = service
                    CharacteristicsUUIDs = [
                        MmsensorPeripheral.ledCharacteristicUUID
                    ]
                }else{
                    print("Discovered \(service.uuid.uuidString)")
                }
                // サービスのキャラクタリスティックを検索する。
                if let searchUuid = CharacteristicsUUIDs{
                    peripheral.discoverCharacteristics( searchUuid, for: service)
                }
            }
        }
    }
    /*
     * キャラクタリスティック発見時のコールバック
     *
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                /*
                if aCharacteristic.uuid == MmsensorPeripheral.buttonCharacteristicUUID {
                    print("["+#function+"[Discovered Blinky button characteristic")
                    buttonCharacteristic = aCharacteristic
                    enableButtonNotifications(buttonCharacteristic!)
                } else 
                */
                if characteristic.uuid == MmsensorPeripheral.ledCharacteristicUUID {
                    ledCharacteristic = characteristic
                    if let readCharacteristic = ledCharacteristic{
                        peripheral.readValue(for: readCharacteristic)
                    }
                }else
                if characteristic.uuid == MmsensorPeripheral.WifiIdUUID {
                    wifiIdCharacteristic = characteristic
                    if let readCharacteristic = wifiIdCharacteristic{
                        peripheral.readValue(for: readCharacteristic)
                    }
                }else
                if characteristic.uuid == MmsensorPeripheral.BleIdUUID {
                    bleIdCharacteristic = characteristic
                    if let readCharacteristic = bleIdCharacteristic{
                        peripheral.readValue(for: readCharacteristic)
                    }
                }else{
                    //print("Discovered characteristic:\(aCharacteristic.uuid.uuidString)")
                }
                //print("device[\(index)]sevice:\(service.uuid.uuidString),\(characteristics.count)個のキャラクタリスティックを発見。")
     
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("["+#function+"]")
        if characteristic == ledCharacteristic {
            peripheral.readValue(for: ledCharacteristic!)
        }
    }
}
