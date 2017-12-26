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
 UITableViewController,//継承したクラス、スーパークラス
 CBCentralManagerDelegate //利用するCoreBluetoothのセントラルマネージャのコールバック、プロトコル
{
    @IBOutlet var emptyPeripheralsView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals = [MmsensorPeripheral]()
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
        print("["+#function+"]")
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("["+#function+"]")
        if discoveredPeripherals.count > 0 {
            hideEmptyPeripheralsView()
        } else {
            showEmptyPeripheralsView()
        }
        return discoveredPeripherals.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("["+#function+"]")
        let aCell = tableView.dequeueReusableCell(withIdentifier: MmsensorTableViewCell.reuseIdentifier, for: indexPath) as! MmsensorTableViewCell
        aCell.setupViewWithPeripheral(discoveredPeripherals[indexPath.row])
        return aCell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("["+#function+"]")
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
        let newPeripheral = MmsensorPeripheral(withPeripheral: peripheral, advertisementData: advertisementEditData, andRSSI: RSSI)
        if !discoveredPeripherals.contains(newPeripheral) {
            discoveredPeripherals.append(newPeripheral)
            tableView.reloadData()
        } else {
            if let index = discoveredPeripherals.index(of: newPeripheral) {
                print("connect to \(peripheral.name ?? "no name" )")
                // ペリフェラルと接続
                self.centralManager.connect(peripheral, options: nil)
                // テーブルに行を追加
                if let aCell = tableView.cellForRow(at: [0,index]) as? MmsensorTableViewCell {
                    
                    aCell.peripheralUpdatedAdvertisementData(newPeripheral)
                }
            }
        }
    }

    //  接続成功時に呼ばれる
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[\(#function)]")
        for device in discoveredPeripherals{
            if peripheral.identifier.uuidString == device.idUuid.uuidString{
                peripheral.delegate = device
                device.discoverMmSensorServices()
                return
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
                        MmsensorPeripheral.BleIdServiceUUID,
                        MmsensorPeripheral.WifiIdServiceUUID
                ],
                options: [
                        CBCentralManagerScanOptionAllowDuplicatesKey : true // 重複スキャンを行う
                ]
            )
    }

    // MARK: - UIViewController
    override func viewWillAppear(_ animated: Bool) {
        print("["+#function+"]")
        super.viewWillAppear(animated)
        discoveredPeripherals.removeAll()
        tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        centralManager.delegate = self
        print("["+#function+"]")
        if centralManager.state == .poweredOn {
            print("[viewDidAppear]scanForPeripherals")
            activityIndicator.startAnimating()
            startScan()
        }
    }

    private func showEmptyPeripheralsView() {
        print("["+#function+"]")
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
        print("["+#function+"]")
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
        print("["+#function+"]")
        return identifier == "PushBlinkyView"
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("["+#function+"]")
        if segue.identifier == "PushBlinkyView" {
            if let peripheral = targetperipheral {
                let destinationView = segue.destination as! BlinkyViewController
                destinationView.setCentralManager(centralManager)
                destinationView.setPeripheral(peripheral)
            }
        }
    }
}
