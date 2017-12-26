//
//  BlinkyTableViewCell.swift
//  nRFBlinky
//
//  Created by Mostafa Berg on 28/11/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//
/*
* スキャン後の個々のアドバタイジングデータの表示
*/
import UIKit

class MmsensorTableViewCell:
 UITableViewCell////継承したクラス、スーパークラス
{
    
    static let reuseIdentifier = "blinkyPeripheralCell"
    private var lastUpdateTimestamp = Date()//テーブルVIEWオブジェクト作成時間
    @IBOutlet weak var peripheralName: UILabel!// 文字
    @IBOutlet weak var peripheralId: UILabel!// 文字
    @IBOutlet weak var peripheralRSSIIcon: UIImageView! // アイコンオブジェクト

    private var peripheral: MmsensorPeripheral!

    /*********** BlinkyPerieralを1行に表示   *************/
    public func setupViewWithPeripheral(_ aPeripheral: MmsensorPeripheral) {
        peripheral = aPeripheral
        peripheralName.text = aPeripheral.advertisedName!+":"+String(describing: peripheral!.RSSI.decimalValue)
        print("wifiID:\(String(describing: aPeripheral.wifiId)),bleId:\(String(describing: aPeripheral.bleId))")
        if let id = aPeripheral.bleId {
            peripheralId.text = "[\(id)]"
        }else
        if let id = aPeripheral.wifiId {
            peripheralId.text = "[\(id)]"
        }else{
            peripheralId.text = ""
        }
        
//        peripheralName.text = aPeripheral.

        if peripheral!.RSSI.decimalValue < -77 {
            peripheralRSSIIcon.image = #imageLiteral(resourceName: "rssi_2")
        } else if peripheral!.RSSI.decimalValue < -65 {
            peripheralRSSIIcon.image = #imageLiteral(resourceName: "rssi_3")
        } else if peripheral!.RSSI.decimalValue < -53 {
            peripheralRSSIIcon.image = #imageLiteral(resourceName: "rssi_4")
        } else {
            peripheralRSSIIcon.image = #imageLiteral(resourceName: "rssi_1")
        }
    }
    /*
     * RSSI更新のために
     * 秒単位で設定
     *     */
    public func peripheralUpdatedAdvertisementData(_ aPeripheral: MmsensorPeripheral) {
        if Date().timeIntervalSince(lastUpdateTimestamp) > 1.0 {//1秒間隔で更新
            lastUpdateTimestamp = Date()
            setupViewWithPeripheral(aPeripheral)
        }
    }
}
