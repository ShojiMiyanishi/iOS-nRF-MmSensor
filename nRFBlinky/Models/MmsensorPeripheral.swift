//
//  BlinkyPeripheral.swift
//  nRFBlinky
//
//  Created by Mostafa Berg on 28/11/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//

import UIKit
import CoreBluetooth
import Foundation

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
    public static let BleIdServiceUUID  = CBUUID.init(string: "65025680-0FD8-5FB5-5148-3027069B3FD9")// ID service
    //MARK: - Properties
    //
    public private(set) var basePeripheral      : CBPeripheral //CoreBluetoothのペリフェラルクラス
    public private(set) var identifier          : UUID
    public var mmSensor : MmSensor
    //public private(set) var advertisedName      : String?   //アドバタイズデータに入っているname
    //public var bleId              : String!    // BleIdキャラクタリスティック
    //public var wifiId              : String!    // BleIdキャラクタリスティック
    public var ssid               : String!     // Wifi アクセスポイントSSID

    public private(set) var rssi     = 0.0  //アドバタイズデータパケットの受信電力
    public private(set) var rssiCount = 0.0
    public private(set) var rssiSum = 0.0
    public private(set) var rssiSqr = 0.0
    public private(set) var advertisedServices  : [CBUUID]? //検索サービスUUID

    var ledIsOn:Bool!
    var celIndex:Int!

    //MARK: - Callback handlers
    private var ledCallbackHandler : ((Bool) -> (Void))?
    private var bleCallbackHandler : ((String) -> (Void))?
    private var wifiCallbackHandler : ((String) -> (Void))?
    private var ssidCallbackHandler : ((String) -> (Void))?
    private var rxCallbackHandler : ((String) -> (Void))?

    public private(set) var bleIdService        : CBService?
    public private(set) var wifiIdService       : CBService?
    public private(set) var ledService          : CBService?
    public private(set) var buttonCharacteristic: CBCharacteristic?
    public private(set) var ledCharacteristic   : CBCharacteristic?
    public private(set) var wifiIdCharacteristic: CBCharacteristic?
    public private(set) var bleIdCharacteristic : CBCharacteristic?
    public private(set) var txCharacteristic    : CBCharacteristic?
    public private(set) var rxCharacteristic    : CBCharacteristic?

    enum Job{
        case none
        case readAll
        case readLed
        case readId
        case searchSSID
    }
    
    var job=Job.none
    
    init(
        withMmSensor aMmSensor: MmSensor,
        withPeripheral aPeripheral: CBPeripheral,
        advertisementData anAdvertisementDictionary: [String : Any],// 引数ラベル:advertisementData 仮引数：anAdvertisementDictionary
        andRSSI anRSSI: NSNumber)
    {
        basePeripheral = aPeripheral
        mmSensor = aMmSensor
        identifier=aPeripheral.identifier
        rssi = anRSSI.doubleValue
        rssiCount += 1
        rssiSum += rssi
        rssiSqr += rssi * rssi
        
        super.init()
        
        (mmSensor.advertisedName, advertisedServices) = parseAdvertisementData(anAdvertisementDictionary)

        //print("[MmsensorPeripheral.init]",(advertisedName, advertisedServices))
        basePeripheral.delegate = self
        
    }

    func setService( target:CBService){
        if target.uuid == MmsensorPeripheral.WifiIdServiceUUID{
            wifiIdService = target
        }else
        if target.uuid == MmsensorPeripheral.LedServiceUUID{
            ledService = target
        }else
        if target.uuid == MmsensorPeripheral.BleIdServiceUUID{
            bleIdService = target
        }
    }
    func setCharacteristic( target:CBCharacteristic){
        if target.uuid == MmsensorPeripheral.BleIdUUID{
            bleIdCharacteristic = target
        }else
        if target.uuid == MmsensorPeripheral.WifiIdUUID{
            wifiIdCharacteristic = target
        }else
        if target.uuid == MmsensorPeripheral.TxUUID{
            txCharacteristic = target
        }else
        if target.uuid == MmsensorPeripheral.RxUUID{
            rxCharacteristic = target
        }else
        if target.uuid == MmsensorPeripheral.ledCharacteristicUUID{
            ledCharacteristic = target
        }
    }
    public func updateRssi(_ _rssi:NSNumber){
        let val = _rssi.doubleValue
        rssiSum += val
        rssiCount += 1
        rssiSqr += val*val
        rssi = round(rssiSum/rssiCount*10.0)/10.0
    }
    public func resetRssi(){
        rssiCount = 0
        rssiSqr = 0.0
        rssiSum = 0.0
    }
    public func setRxCallback(aCallbackHandler: @escaping (String) -> (Void)){
        print("["+#function+"]")
        rxCallbackHandler = aCallbackHandler
    }
    public func setSsidCallback(aCallbackHandler: @escaping (String) -> (Void)){
        print("["+#function+"]")
        ssidCallbackHandler = aCallbackHandler
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


    public func removeCallback() {
        print("["+#function+"]")
        ledCallbackHandler = nil
        ssidCallbackHandler = nil
        bleCallbackHandler = nil
        wifiCallbackHandler = nil
        rxCallbackHandler = nil
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
            if nil == mmSensor.bleId {
                if let readCharacteristic = bleIdCharacteristic{
                    basePeripheral.readValue(for: readCharacteristic)
                }
            }
            if nil == mmSensor.wifiId {
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
    public func enableRxNotifications(_ rxCharacteristic: CBCharacteristic) {
        print("["+#function+"]Enabling notifications for rx characteristic")
        basePeripheral.setNotifyValue(true, for: rxCharacteristic)
    }

    public func readLEDValue() {
        print("["+#function+"]")
        if let ledCharacteristic = ledCharacteristic {
            basePeripheral.readValue(for: ledCharacteristic)
        }
    }
    public func readRxValue() {
        print("["+#function+"]")
        if let aCharacteristic = rxCharacteristic {
            basePeripheral.readValue(for: aCharacteristic)
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
    
    public func didReceiveRxNotificationWithValue(_ value: Data) {
        print("["+#function+"]")
        //let str = NSString(data:value , encoding: NSASCIIStringEncoding)
        print("RX: \(value.count),\(value)")
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
        //writeLEDCharcateristicValue(Data([0x01]))
    }
    
    public func turnOffLED() {
        print("["+#function+"]")
        //writeLEDCharcateristicValue(Data([0x00]))
    }
    
    private func writeLEDCharcateristicValue(_ aValue: Data) {
        print("["+#function+"]")
        guard let ledCharacteristic = ledCharacteristic else {
            print("LED characteristic is not present, nothing to be done")
            return
        }
        basePeripheral.writeValue(aValue, for: ledCharacteristic, type: .withResponse)
        /*
        do{
            try basePeripheral.writeValue(aValue, for: ledCharacteristic, type: .withResponse)
        }catch {
            print(error)
        }
        */
    }

    public func getSsid() {
        print("SSIDの取得["+#function+"]")
        let command:String = "s\n"
        writeTxCharcateristicValue(command)
    }
    public func getList() {
        print("PingerListの取得["+#function+"]")
        let command:String = "l\n"
        writeTxCharcateristicValue(command)
    }
    public func smartConfig(){
        print("スマート設定["+#function+"]")
        let command:String = "z\n"
        writeTxCharcateristicValue(command)
    }
    private func writeTxCharcateristicValue(_ str: String) {
        guard let txCharacteristic = txCharacteristic else {
            print("TX characteristic is not present, nothing to be done")
            return
        }
        let value = Data.init(bytes:str,count:str.count)
        print("["+#function+"]",str,value)
        basePeripheral.writeValue(value, for: txCharacteristic, type: .withResponse)
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
        print("[peripheral(didUpdateValueFor)]\(characteristic.uuid)")

        if let count = characteristic.value?.count{
            var values0 = [UInt8](repeating:0, count: count)
            var values = [UInt8](repeating:0, count: count)
        
            characteristic.value?.copyBytes(to: &values0,count:values.count)
            var index:Int=1
            for i in values0{
                values[count-index]=i
                index += 1
            }
            if characteristic.uuid.uuidString == ledCharacteristic?.uuid.uuidString{
                if values[0]==0 {
                    ledIsOn = false
                }else{
                    ledIsOn = true
                }
                print("ledキャラクタリスティックの値:\(ledIsOn),values:\(values)")
                ledCallbackHandler?(ledIsOn)
            }else
            if characteristic.uuid == bleIdCharacteristic?.uuid{
                let hexStr = values.map{
                    String(format: "%.2hhx",$0)
                }.joined()
                self.mmSensor.bleId=hexStr
                print("BLEIDキャラクタリスティックの値:\(hexStr),BleId:\(String(describing: self.mmSensor.bleId))")
                bleCallbackHandler?(hexStr)
            }else
            if characteristic.uuid == wifiIdCharacteristic?.uuid{
                let hexStr = values.map{
                    String(format: "%.2hhx",$0)
                }.joined()
                self.mmSensor.wifiId=hexStr
                print("[WifiIDキャラクタリスティックの値:\(hexStr),WifiId:\(self.mmSensor.wifiId)")
                wifiCallbackHandler?(hexStr)
            }else
            if characteristic.uuid == rxCharacteristic?.uuid{
                let str = values0.map{ String(format:"%c",$0)}.joined() 
                print("rxキャラクタリスティックの値:",count,str,values0)
                var idx = str.startIndex
                rxCallbackHandler?(str)
                while idx < str.endIndex{
                    if str[idx]=="s" && str[str.index(after:idx)]==":"{
                        let ssid = str.components(separatedBy: ":")
                        if ssid.count>=2 {
                            ssidCallbackHandler?(ssid[1])
                        }
                    }
                    idx = str.index(after: idx)
                }
                
            }else
            if characteristic.uuid == txCharacteristic?.uuid{
                let str = values0.map{ String(format:"%c",$0)}.joined() 
                print("txキャラクタリスティックの値:",count,str,values0)
            }else{
                //print("[\(#function)]bleIdCharacteristic:\(bleIdCharacteristic.uuid.uuidString)")
                print("未対応キャラクタリスティック.UUID:\(characteristic.uuid)")
                print("未対応キャラクタリスティックの値:\(characteristic)")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("notificatioのコールバック",characteristic.value ?? "")
        if characteristic.uuid == buttonCharacteristic?.uuid {
            print("Notification state is now \(characteristic.isNotifying) for Button characteristic")
            readButtonValue()
            readLEDValue()
        }else
        if characteristic.uuid == rxCharacteristic?.uuid {
            if let count = characteristic.value?.count{
                var values0 = [UInt8](repeating:0, count: count)
                var values = [UInt8](repeating:0, count: count)
            
                characteristic.value?.copyBytes(to: &values0,count:values.count)
                var index:Int=1
                for i in values0{
                    values[count-index]=i
                    index += 1
                }
                let str = values0.map{ String(format:"%c",$0)}.joined() 
                print("rxキャラクタリスティックの値:",count,str,values0)
                var idx = str.startIndex
                rxCallbackHandler?(str)
                while idx < str.endIndex{
                    if str[idx]=="s" && str[str.index(after:idx)]==":"{
                        let ssid = str.components(separatedBy: ":")
                        if ssid.count>=2 {
                            ssidCallbackHandler?(ssid[1])
                        }
                    }
                    idx = str.index(after: idx)
                }
            }
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
                setService(target: service)
                if service.uuid == MmsensorPeripheral.WifiIdServiceUUID {
                    print("Discovered WifiId service!")
                    CharacteristicsUUIDs = [
                        MmsensorPeripheral.WifiIdUUID,
                        MmsensorPeripheral.BleIdUUID,
                        MmsensorPeripheral.RxUUID,
                        MmsensorPeripheral.TxUUID
                    ]
                }else
                if service.uuid == MmsensorPeripheral.LedServiceUUID {
                    print("Discovered LED service!")
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
                setCharacteristic(target: characteristic)
                if characteristic.uuid == MmsensorPeripheral.ledCharacteristicUUID {
                    if let readCharacteristic = ledCharacteristic{
                        peripheral.readValue(for: readCharacteristic)
                    }
                }else
                if characteristic.uuid == MmsensorPeripheral.WifiIdUUID {
                    if let readCharacteristic = wifiIdCharacteristic{
                        peripheral.readValue(for: readCharacteristic)
                    }
                }else
                if characteristic.uuid == MmsensorPeripheral.BleIdUUID {
                    if let readCharacteristic = bleIdCharacteristic{
                        peripheral.readValue(for: readCharacteristic)
                    }
                }else
                if characteristic.uuid == MmsensorPeripheral.TxUUID {
                    if let readCharacteristic = txCharacteristic{
                        peripheral.readValue(for: readCharacteristic)
                        //rxが発見済みの場合はＳＳＩＤのデータを入手するコマンドを送信する。
                        if nil != rxCharacteristic{
                            //getSsid()
                        }
                    }
                }else
                if characteristic.uuid == MmsensorPeripheral.RxUUID {
                    if let readCharacteristic = rxCharacteristic{
                        peripheral.readValue(for: readCharacteristic)
                        enableRxNotifications(rxCharacteristic!)
                        //txが発見済みの場合はＳＳＩＤのデータを入手するコマンドを送信する。
                        if nil != txCharacteristic{
                            //getSsid()
                        }
                    }
                }else{
                    //print("Discovered characteristic:\(aCharacteristic.uuid.uuidString)")
                }
                //print("device[\(index)]sevice:\(service.uuid.uuidString),\(characteristics.count)個のキャラクタリスティックを発見。")
     
            }
        }
    }
    /*
     * キャラクタリスティックの書き込み終了後にコールバック
     */
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic == ledCharacteristic {
            print("["+#function+"]LEDキャラクタリスティック",characteristic.value ?? "")
            //peripheral.readValue(for: ledCharacteristic!)
        }else
        if characteristic == txCharacteristic {
            print("["+#function+"]txキャラクタリスティック",characteristic.value ?? "")
            //peripheral.readValue(for: rxCharacteristic!)
        }else
        if characteristic == rxCharacteristic {
            print("["+#function+"]rxキャラクタリスティック",characteristic.value ?? "")
            //peripheral.readValue(for: rxCharacteristic!)
        }else{
            print("["+#function+"]未対応キャラクタリスティック",characteristic.value ?? "")
        }
    }
}
