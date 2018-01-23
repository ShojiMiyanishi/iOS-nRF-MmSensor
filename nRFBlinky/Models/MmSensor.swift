//
//  MmSensor.swift
//  mmSensor
//
//  Created by 宮西 昭次 on H30/01/15.
//  Copyright © 平成30年 Nordic Semiconductor ASA. All rights reserved.
//

import Foundation
//
//  BlinkyPeripheral.swift
//  nRFBlinky
//
//  Created by Mostafa Berg on 28/11/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//

import UIKit
import CoreBluetooth

class MmSensor:
 NSObject
// CBPeripheralDelegate   // peripheralからのコールバック
{
    // スキャン開始は　
    // ScannerTableViewController.swftの
    // centralManagerDidUpdateState
    // override func viewDidAppear(_ animated: Bool)
    // で開始されている。
    //MARK: - Properties
    //
    public private(set) var identifier:UUID
    public var advertisedName      : String?   //アドバタイズデータに入っているname
    public var bleId              : String!    // BleIdキャラクタリスティック
    public var wifiId              : String!    // BleIdキャラクタリスティック

    public private(set) var advertisedServices  : [CBUUID]? //検索サービスUUID
    
    //MARK: - Services and Characteristic properties
    //

    init(   id : UUID )
    {
        identifier = id
    }
    

    //MARK: - NSObject protocols
    // 比較のオーバライド
    // identifierを使用して比較
    override func isEqual(_ object: Any?) -> Bool {
        if object is MmsensorPeripheral {
            let peripheralObject = object as! MmsensorPeripheral
            return peripheralObject.identifier == identifier
        } else if object is CBPeripheral {
            let peripheralObject = object as! CBPeripheral
            return peripheralObject.identifier == identifier
        } else if object is MmSensor {
            let peripheralObject = object as! MmSensor
            return peripheralObject.identifier == identifier
        } else {
            return false
        }
    }
    
}
