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
    public static let IdUUID          = CBUUID.init(string: "65025682-0FD8-5FB5-5148-3027069B3FD9")  //idキャラクタリスティック
    // サービスUUID
    public static let LedServiceUUID  = CBUUID.init(string: "A000")//var UUID1:CBUUID
    public static let WifiIdServiceUUID = CBUUID.init(string: "65020001-0FD8-5FB5-5148-3027069B3FD1")//Gateway Id Service
    public static let BleIdServiceUUID   = CBUUID.init(string: "65025680-0FD8-5FB5-5148-3027069B3FD9")//id Service
    public static let BatteryServiceUUID = CBUUID.init(string:"180F")
    public static let TxPowerServiceUUID = CBUUID.init(string:"1804")
    public static let EnvironmentalServiceUUID = CBUUID.init(string: "181A")
    //public static let nordicBlinkyServiceUUID  = CBUUID.init(string: "65025680-0FD8-5FB5-5148-3027069B3FD9")// ID service
    //MARK: - Properties
    //
    public private(set) var basePeripheral      : CBPeripheral //CoreBluetoothのペリフェラルクラス
    public private(set) var advertisedName      : String?   //アドバタイズデータに入っているname
    public private(set) var bleId              : String?    // BleIdキャラクタリスティック
    public private(set) var wifiId              : String?    // BleIdキャラクタリスティック
    public private(set) var RSSI                : NSNumber  //アドバタイズデータパケットの受信電力
    public private(set) var rssiCount = 0
    public private(set) var rssiSum = 0.0
    public private(set) var rssiSqr = 0.0
    public private(set) var advertisedServices  : [CBUUID]? //検索サービスUUID
    public var idUuid:UUID
    
    //MARK: - Callback handlers
    private var ledCallbackHandler : ((Bool) -> (Void))?

    //MARK: - Services and Characteristic properties
    //
    private             var bleIdService        : CBService?
    private             var wifiIdService       : CBService?
    private             var ledService          : CBService?
    private             var buttonCharacteristic: CBCharacteristic?
    private             var ledCharacteristic   : CBCharacteristic?
    private             var wifiIdCharacteristic   : CBCharacteristic?
    private             var bleIdCharacteristic   : CBCharacteristic?

    init(
        withPeripheral aPeripheral: CBPeripheral,
        advertisementData anAdvertisementDictionary: [String : Any],
        andRSSI anRSSI: NSNumber)
    {
        basePeripheral = aPeripheral
        RSSI = anRSSI
        rssiCount += 1
        rssiSum += anRSSI.doubleValue
        rssiSqr += anRSSI.doubleValue * anRSSI.doubleValue
        idUuid=aPeripheral.identifier
        
        super.init()
        
        (advertisedName, advertisedServices) = parseAdvertisementData(anAdvertisementDictionary)

        basePeripheral.delegate = self
        
    }
    
    public func setLEDCallback(aCallbackHandler: @escaping (Bool) -> (Void)){
        print("["+#function+"]")
        ledCallbackHandler = aCallbackHandler
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

    // 接続後のサービス検索
    public func discoverMmSensorServices() {
        print("["+#function+"]")
        basePeripheral.delegate = self
        basePeripheral.discoverServices([
                MmsensorPeripheral.WifiIdServiceUUID,
                MmsensorPeripheral.BleIdServiceUUID
            ])
    }
    
    // キャラクタリスティックの検索
    public func discoverCharacteristicsForBlinkyService(_ aService: CBService) {
        var CharacteristicsUUIDs:[CBUUID]!
        print("["+#function+"]")
        if aService.uuid == MmsensorPeripheral.WifiIdServiceUUID{
            CharacteristicsUUIDs = [
                MmsensorPeripheral.ledCharacteristicUUID,
                MmsensorPeripheral.WifiIdUUID,
                MmsensorPeripheral.BleIdUUID
            ]
        }else
        if aService.uuid == MmsensorPeripheral.BleIdServiceUUID{
            CharacteristicsUUIDs = [
                MmsensorPeripheral.ledCharacteristicUUID,
                MmsensorPeripheral.BleIdUUID
            ]
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
            ledCallbackHandler?(true)
        } else {
            ledCallbackHandler?(false)
        }
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
    private func parseAdvertisementData(_ anAdvertisementDictionary: [String : Any]) -> (String?, [CBUUID]?) {
        var advertisedName: String
        var advertisedServices: [CBUUID]

        if let name = anAdvertisementDictionary[CBAdvertisementDataLocalNameKey] as? String{
            advertisedName = name
        } else {
            advertisedName = "N/A"
        }
        if let services = anAdvertisementDictionary[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            advertisedServices = services
        } else {
            advertisedServices = [CBUUID]()
        }
        
        return (advertisedName, advertisedServices)
    }
    /*
    private func parseAdvertisementData(_ anAdvertisementDictionary: [String : Any]) -> (String?, [CBUUID]?) {
        //print("["+#function+"]")
        var advertisedName: String
        var tempName: String=""
        var advertisedServices: [CBUUID]

        if let name = anAdvertisementDictionary[CBAdvertisementDataLocalNameKey] as? String{
            tempName = name
        }else
        {
            tempName = "N/A"
        }
        if let name = anAdvertisementDictionary[CBAdvertisementDataIsConnectable] as? String{
            tempName += name
        }
        if let name = anAdvertisementDictionary[CBAdvertisementDataManufacturerDataKey] as? String{
            tempName += name
        }
        if let services = anAdvertisementDictionary[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            advertisedServices = services
            //print("[parseAdvertisementData]\(services.count)個のサービスを発見。\(services)")
        } else {
            advertisedServices = [CBUUID]()
        }
        //advertisedName += " count:"+String(anAdvertisementDictionary.count)
        //print("[parseAdvertisementData]anAdvertisementDictionary[]"+advertisedName)
        var str:String
        str=""
        //str="[parseAdvertisementData]"
        //str+="anAdvertisementDictionary.count:"+String(anAdvertisementDictionary.count)
        str+=":"+String(anAdvertisementDictionary.count)
        //str+=",type:"+String(describing: type(of:anAdvertisementDictionary) )
        for (key,value) in anAdvertisementDictionary{
            if key == CBAdvertisementDataIsConnectable{
                if value as! Bool{
                    str+=",conn:true"
                }else{
                    str+=",conn:false"
                }
            }else
            if key == CBAdvertisementDataServiceUUIDsKey{
                var temp:NSArray
                temp=value as! NSArray
                str+=",UUID.count:"+String(temp.count)
            }else
            if key == CBAdvertisementDataLocalNameKey{
            }else{
                str+=",key:"+String(key)
                str+=",value:"+String(describing: type(of: value) )
            }

        }
        tempName+=str
        advertisedName = tempName
        //print(str)
        return (advertisedName, advertisedServices)
    }
    */
    //MARK: - NSObject protocols
    // 比較のオーバライド
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
            if characteristic==ledCharacteristic{
                //didWriteValueToLED(values[0])
                if values[0]==0 {
                }else{
                }
            }else
            if characteristic==bleIdCharacteristic{
                let hexStr = values.map{
                    String(format: "%.2hhx",$0)
                }.joined()
                print("[\(index)][\(#function)]ID:\(hexStr)")
                bleId=hexStr
            }else
            if characteristic==wifiIdCharacteristic{
                let hexStr = values.map{
                    String(format: "%.2hhx",$0)
                }.joined()
                print("[\(index)][\(#function)]ID:\(hexStr)")
                wifiId=hexStr
            }else{
                //print("[\(#function)]service.UUID:\(characteristic.service.uuid)")
                //print("[\(#function)]characteristic.UUID:\(characteristic.uuid)")
                //print("[\(#function)]characteristic:\(characteristic)")
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
        var CharacteristicsUUIDs:[CBUUID]!
        print("[\(#function)]")
        if let services = peripheral.services {
            for aService in services {
                if aService.uuid == MmsensorPeripheral.BleIdServiceUUID {
                    print("Discovered BleId service!")
                    //Capture and discover all characteristics for the bleId service
                    bleIdService = aService
                    CharacteristicsUUIDs = [
                        MmsensorPeripheral.ledCharacteristicUUID,
                        MmsensorPeripheral.BleIdUUID
                    ]
                }else
                if aService.uuid == MmsensorPeripheral.WifiIdServiceUUID {
                    print("Discovered WifiId service!")
                    //Capture and discover all characteristics for the wifiId service
                    wifiIdService = aService
                    CharacteristicsUUIDs = [
                        MmsensorPeripheral.ledCharacteristicUUID,
                        MmsensorPeripheral.WifiIdUUID,
                        MmsensorPeripheral.BleIdUUID
                    ]
                }else
                if aService.uuid == MmsensorPeripheral.LedServiceUUID {
                    print("Discovered LED service!")
                    //Capture and discover all characteristics for the led service
                    ledService = aService
                    //discoverCharacteristicsForBlinkyService(ledService!)
                }else{
                    print("Discovered \(aService.uuid.uuidString)")
                }
                // サービスのキャラクタリスティックを検索する。
                basePeripheral.discoverCharacteristics( nil, for: aService)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("["+#function+"]Discovered characteristics forservice with UUID: \(service.uuid.uuidString)")
        print("["+#function+"]Discovered characteristics for blinky service")
        if let characteristics = service.characteristics {
            for aCharacteristic in characteristics {
                /*
                if aCharacteristic.uuid == MmsensorPeripheral.buttonCharacteristicUUID {
                    print("["+#function+"[Discovered Blinky button characteristic")
                    buttonCharacteristic = aCharacteristic
                    enableButtonNotifications(buttonCharacteristic!)
                } else 
                */
                if aCharacteristic.uuid == MmsensorPeripheral.ledCharacteristicUUID {
                    print("Discovered Blinky LED characteristic")
                    ledCharacteristic = aCharacteristic
                }else
                if aCharacteristic.uuid == MmsensorPeripheral.WifiIdServiceUUID {
                    print("Discovered WifiId characteristic")
                }else
                if aCharacteristic.uuid == MmsensorPeripheral.BleIdServiceUUID {
                    print("Discovered BleId characteristic")
                    wifiIdCharacteristic = aCharacteristic
                }else{
                    print("Discovered characteristic:\(aCharacteristic.uuid.uuidString)")
                    bleIdCharacteristic = aCharacteristic
                }
                print("device[\(index)]sevice:\(service.uuid.uuidString),\(characteristics.count)個のキャラクタリスティックを発見。")
     
                /*
                 * read属性のキャラクタリスティックの読み出しを実行する。
                 */
                let readFlag =  (UInt8(CBCharacteristicProperties.read.rawValue) & UInt8(aCharacteristic.properties.rawValue))
                if readFlag == CBCharacteristicProperties.read.rawValue {
                    peripheral.readValue(for: aCharacteristic)
                    print("device[\(peripheral.name)],uuid:\(aCharacteristic.uuid.uuidString),properties:\( aCharacteristic.properties.rawValue ),startRead")
                }else{
                    print("device[\(peripheral.name)],uuid:\(aCharacteristic.uuid.uuidString),properties:\( aCharacteristic.properties.rawValue )")
                }
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
