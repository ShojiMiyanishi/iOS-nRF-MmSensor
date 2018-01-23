//
//  ScannerTableViewController.swift
//  nRFBlinky
//
//  Created by Mostafa Berg on 28/11/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//
/*
 * スキャンテーブルの表示
 *
 */
import UIKit
import CoreBluetooth

class ScannerTableViewController:
 UITableViewController,     //　継承したクラス、スーパークラス
 CBPeripheralDelegate,      //　一覧にIDを表示するために接続するので、MmsensorPeripheralを利用しないで、peripheralからのコールバックを定義する。
 CBCentralManagerDelegate   //　利用するCoreBluetoothのセントラルマネージャのコールバック、プロトコル
{
    @IBOutlet var emptyPeripheralsView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals = [MmsensorPeripheral]()
    public var discoveredMmSensors = [MmSensor]()
    private var targetperipheral: MmsensorPeripheral?
    override var preferredStatusBarStyle: UIStatusBarStyle {
        print("["+#function+"]")
        return .lightContent
    }

    override func viewDidLoad() {
        print("["+#function+"]")
        super.viewDidLoad()
        centralManager = (((UIApplication.shared.delegate) as? AppDelegate)?.centralManager)!
        centralManager.delegate = self
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        print("["+#function+"]")
        super.viewWillTransition(to: size, with: coordinator)
        if view.subviews.contains(emptyPeripheralsView) {
            coordinator.animate(alongsideTransition: { (context) in
                let width = self.emptyPeripheralsView.frame.size.width
                let height = self.emptyPeripheralsView.frame.size.height
                if context.containerView.frame.size.height > context.containerView.frame.size.width {
                    self.emptyPeripheralsView.frame = CGRect(x: 0,
                                                             y: (context.containerView.frame.size.height / 2) - (height / 2),
                                                             width: width,
                                                             height: height)
                } else {
                    self.emptyPeripheralsView.frame = CGRect(x: 0,
                                                             y: 16,
                                                             width: width,
                                                             height: height)
                }
            })
        }
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        //print("["+#function+"]")
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //print("["+#function+"]")
        if discoveredPeripherals.count > 0 {
            hideEmptyPeripheralsView()
        } else {
            showEmptyPeripheralsView()
        }
        return discoveredPeripherals.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //print("["+#function+"]")
        let aCell = tableView.dequeueReusableCell(withIdentifier: MmsensorTableViewCell.reuseIdentifier, for: indexPath) as! MmsensorTableViewCell
        aCell.setupViewWithPeripheral(discoveredPeripherals[indexPath.row])
        return aCell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //print("["+#function+"]")
        centralManager.stopScan()
        activityIndicator.stopAnimating()
        targetperipheral = discoveredPeripherals[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        performSegue(withIdentifier: "PushBlinkyView", sender: nil)
    }
    
    // MARK: - CBCentralManagerDelegate
    //
    
    /*
     * ペリフェラル発見コールバック
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        //print("["+#function+"]")
        var advertisementEditData=advertisementData
        // locallnameのないデバイス対策
        if nil == advertisementData[CBAdvertisementDataLocalNameKey] {
            if let name = peripheral.name{
                advertisementEditData[CBAdvertisementDataLocalNameKey] = name + ".pName"
            }
        }
        let newMmSensor = MmSensor(id: peripheral.identifier)
        if !discoveredMmSensors.contains(newMmSensor){
            discoveredMmSensors.append(newMmSensor)
        }
        let index = discoveredMmSensors.index(of: newMmSensor)
        let newPeripheral = MmsensorPeripheral(
            withMmSensor: discoveredMmSensors[index!],
            withPeripheral: peripheral ,
            advertisementData: advertisementEditData, andRSSI: RSSI
        )
        if !discoveredPeripherals.contains(newPeripheral) {// peripheral.identifier を比較
            // 未知のペリフェラル
            print("["+#function+"]append:\(peripheral.name ?? "no name")")
            discoveredPeripherals.append(newPeripheral)
            tableView.reloadData()
            if let index = discoveredPeripherals.index(of: newPeripheral) {
                if nil == discoveredPeripherals[index].mmSensor.bleId &&
                    nil == discoveredPeripherals[index].mmSensor.wifiId
                {
                    discoveredPeripherals[index].celIndex=index
                    //print("connect to \(peripheral.name ?? "no name" ),\(peripheral.identifier)")
                    // ペリフェラルと接続
                    //discoveredPeripherals[index].connectForReadId(peripheral: peripheral)
                    var device=centralManager.retrievePeripherals(withIdentifiers: [newPeripheral.identifier])
                    //ペリフェラルと接続開始
                    if device.count>0{
                        centralManager.connect(device[0], options: nil)
                    }else{
                        var device=centralManager.retrieveConnectedPeripherals(withServices: [MmsensorPeripheral.WifiIdUUID])
                        if device.count>0{
                            centralManager.connect(device[0], options: nil)
                        }else{
                            centralManager.connect(peripheral, options: nil)
                        }
                    }
                }
            }
        } else {
            // 既知のペリフェラル
            if let index = discoveredPeripherals.index(of: newPeripheral) {
                discoveredPeripherals[index].updateRssi(RSSI)
                // 表示のアップデート
                if let aCell = tableView.cellForRow(at: [0,index]) as? MmsensorTableViewCell {
                    //print("update cell \(peripheral.name ?? "no name" ),\(peripheral.identifier)")
                    
                    aCell.peripheralUpdatedAdvertisementData(discoveredPeripherals[index])
                }
            }
        }
    }

    //  接続成功時に呼ばれる
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[\(#function)]\(peripheral.name ?? ""),\(peripheral.identifier)")
        peripheral.delegate = self
        peripheral.discoverServices([
            MmsensorPeripheral.WifiIdServiceUUID
        ])
    }
    //  切断時に呼ばれる
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[\(#function)]")
        print("[Disconnect]\(peripheral.name ?? ""),\(peripheral.identifier)")
        for device in discoveredPeripherals{
            if device.basePeripheral.identifier == peripheral.identifier{
                if let aCell = tableView.cellForRow(at: [0,device.celIndex]) as? MmsensorTableViewCell {
                    aCell.peripheralUpdatedAdvertisementData(device)
                    print("update:\(device.celIndex)")
                }
            }
        }
    }
    /*
     * 実行の順番
     * 1.viewWillAppear
     * 2.viewDidAppear
     * 3.centralManagerDidUpdateState
     */
    /*
     *  接続状況が変わるたびに呼ばれる BLEセントラルマネージャーの必須コールバック
     *      .poweredOn:セントラルマネージャーがアップしたとき
     *      .poweredOff:セントラルマネージャーが停止した時
     *
     */
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("["+#function+"]")
        if central.state != .poweredOn {
            print("Central is not powered on")
        } else {
            print("[centralManagerDidUpdateState]scanForPeripherals")
            activityIndicator.startAnimating()
            // スキャン開始
            startScan()
        }
    }
    func startScan(){
            // スキャン開始
            centralManager.scanForPeripherals(
                withServices: [
                        //MmsensorPeripheral.LedServiceUUID,
                        MmsensorPeripheral.WifiIdServiceUUID
                ],
                options: [
                        CBCentralManagerScanOptionAllowDuplicatesKey : true // 重複スキャンを行う
                ]
            )
    }

    // MARK: - UIViewController
    // viewが出現するときのコールバック
    override func viewWillAppear(_ animated: Bool) {
        //print("["+#function+"]")
        super.viewWillAppear(animated)
        discoveredPeripherals.removeAll()// 再利用するとキャラクタリスティックを操作できない。
        tableView.reloadData()
    }
    // viewが消去される時のコールバック
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        centralManager.delegate = self
        //print("["+#function+"]")
        if centralManager.state == .poweredOn {
            //print("[viewDidAppear]scanForPeripherals")
            activityIndicator.startAnimating()
            startScan()
        }
    }

    private func showEmptyPeripheralsView() {
        //print("["+#function+"]")
        if !view.subviews.contains(emptyPeripheralsView) {
            view.addSubview(emptyPeripheralsView)
            emptyPeripheralsView.alpha = 0
            emptyPeripheralsView.frame = CGRect(x: 0, y: (view.frame.height / 2) - (emptyPeripheralsView.frame.size.height / 2), width: view.frame.width, height: emptyPeripheralsView.frame.height)
            view.bringSubview(toFront: emptyPeripheralsView)
            UIView.animate(withDuration: 0.5, animations: {
                self.emptyPeripheralsView.alpha = 1
            })
        }
    }
    
    private func hideEmptyPeripheralsView() {
        //print("["+#function+"]")
        if view.subviews.contains(emptyPeripheralsView) {
            UIView.animate(withDuration: 0.5, animations: {
                self.emptyPeripheralsView.alpha = 0
            }, completion: { (completed) in
                self.emptyPeripheralsView.removeFromSuperview()
            })
        }
    }

    // MARK: - Segue and navigation
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        //print("["+#function+"]")
        return identifier == "PushBlinkyView"
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //print("["+#function+"]")
        if segue.identifier == "PushBlinkyView" {
            if let peripheral = targetperipheral {
                let destinationView = segue.destination as! BlinkyViewController
                destinationView.setCentralManager(centralManager)
                destinationView.setPeripheral(peripheral)
            }
        }
    }
    /***********************************************************************************************
     * IDを表示するためのBLEペリフェラルのコールバック
     ***********************************************************************************************/
    /*
     * サービススキャンでサービスを発見した時のコールバック
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("[\(#function)]")
        for device in discoveredPeripherals{
            if device.basePeripheral.identifier == peripheral.identifier{
                if let services = peripheral.services {
                    for service in services {
                        
                        //print("\(peripheral.name ?? "" ),Discovered \(service.uuid.uuidString)")

                        var CharacteristicsUUIDs:[CBUUID]!
                        device.setService( target: service )
                        if service.uuid == MmsensorPeripheral.WifiIdServiceUUID {
                            //print("Discovered WifiId service!")
                            CharacteristicsUUIDs = [
                                MmsensorPeripheral.WifiIdUUID,
                                MmsensorPeripheral.BleIdUUID
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
        }
    }
    /*
     * キャラクタリスティック発見時のコールバック
     *
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("[\(#function)]sevice:\(service.uuid.uuidString)")
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                print("sevice:\(service.uuid.uuidString),\(characteristic.uuid.uuidString)")
            }
        }else{
            print("device[\(index)]sevice:\(service.uuid.uuidString),no chara")
        }
        if let characteristics = service.characteristics {
            for device in discoveredPeripherals{
                for characteristic in characteristics {
                    device.setCharacteristic(target: characteristic)
                    if characteristic.uuid == MmsensorPeripheral.ledCharacteristicUUID {
                        peripheral.readValue(for: characteristic)
                    }else
                    if characteristic.uuid == MmsensorPeripheral.WifiIdUUID {
                        peripheral.readValue(for: characteristic)
                    }else
                    if characteristic.uuid == MmsensorPeripheral.BleIdUUID {
                        peripheral.readValue(for: characteristic)
                    }else
                    if characteristic.uuid == MmsensorPeripheral.RxUUID {
                        peripheral.readValue(for: characteristic)
                    }else
                    if characteristic.uuid == MmsensorPeripheral.TxUUID {
                        peripheral.readValue(for: characteristic)
                    }else{
                        //print("Discovered characteristic:\(aCharacteristic.uuid.uuidString)")
                    }
                    //print("sevice:\(service.uuid.uuidString),\(characteristics.count)個のキャラクタリスティックを発見。")
         
                }
            }
        }
    }
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
        for device in discoveredPeripherals{
            if device.basePeripheral.identifier == peripheral.identifier{
                if let count = characteristic.value?.count{
                    var values0 = [UInt8](repeating:0, count: count)
                    var values = [UInt8](repeating:0, count: count)
                
                    characteristic.value?.copyBytes(to: &values0,count:values.count)
                    var index:Int=1
                    for i in values0{
                        values[count-index]=i
                        index += 1
                    }
                    if characteristic.uuid==MmsensorPeripheral.BleIdUUID{
                        let hexStr = values.map{
                            String(format: "%.2hhx",$0)
                        }.joined()
                        device.mmSensor.bleId=hexStr
                        print("[\(index)][\(#function)]ID:\(hexStr),bleId:\(String(describing: device.mmSensor.bleId))")
                    }else
                    if characteristic.uuid==MmsensorPeripheral.WifiIdUUID{
                        let hexStr = values.map{
                            String(format: "%.2hhx",$0)
                        }.joined()
                        device.mmSensor.wifiId=hexStr
                        print("[\(index)][\(#function)]ID:\(hexStr),wifiId:\(device.mmSensor.wifiId)")
                    }else{
                        //print("[\(#function)]bleIdCharacteristic:\(bleIdCharacteristic.uuid.uuidString)")
                        print("[\(#function)]characteristic.UUID:\(characteristic.uuid)")
                        print("[\(#function)]characteristic:\(characteristic)")
                    }
                }
                if nil != device.mmSensor.wifiId && nil != device.mmSensor.bleId{
                    centralManager.cancelPeripheralConnection(peripheral)
                }
            }
        }
    }
    
}
