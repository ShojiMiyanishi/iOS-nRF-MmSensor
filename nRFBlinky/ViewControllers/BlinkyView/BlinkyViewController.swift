//
//  BlinkyViewController.swift
//  nRFBlinky
//
//  Created by Mostafa Berg on 01/12/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//
/*
 * 接続した後の表示
 */
import UIKit
import CoreBluetooth

class BlinkyViewController:
 UITableViewController,//継承したクラス、スーパークラス
 CBCentralManagerDelegate//利用するコールバック、プロトコル
{
    
    //MARK: - Outlets and Actions
    
    @IBOutlet weak var bleId: UILabel!
    @IBOutlet weak var wifiId: UILabel!
    @IBOutlet weak var ssidLabel: UILabel!
    @IBOutlet weak var securityLabel: UILabel!
    @IBOutlet weak var ledStateLabel: UILabel!
    @IBOutlet weak var ledToggleSwitch: UISwitch!
    @IBOutlet weak var rxLabel: UILabel!
    
    @IBAction func ledToggleSwitchDidChange(_ sender: Any) {
        handleSwitchValueChange(newValue: ledToggleSwitch.isOn)
    }

    //MARK: - Properties
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    private var hapticGenerator : NSObject? //Only available on iOS 10 and above
    private var mmsensorPeripheral : MmsensorPeripheral!
    private var centralManager : CBCentralManager!
    
    //MARK: - Implementation
    public func setCentralManager(_ aManager: CBCentralManager) {
        centralManager = aManager
        centralManager.delegate = self
    }
    
    public func setPeripheral(_ aPeripheral: MmsensorPeripheral) {
        let peripheralName = aPeripheral.mmSensor.advertisedName ?? "Unknown Device"
        title = "\(peripheralName)"
        mmsensorPeripheral = aPeripheral
        //print("connect to \(peripheral.name ?? "no name" ),\(peripheral.identifier)")
        let device=centralManager.retrievePeripherals(withIdentifiers: [aPeripheral.identifier])
        //ペリフェラルと接続開始
        if device.count>0{
            centralManager.connect(device[0], options: nil)
        }else{
            centralManager.connect(mmsensorPeripheral.basePeripheral, options: nil)
        }
    }
    
    private func handleSwitchValueChange(newValue isOn: Bool){
        if isOn {
            //mmsensorPeripheral.turnOnLED()
            //mmsensorPeripheral.getSsid()
            mmsensorPeripheral.smartConfig()
            ledStateLabel.text = "ON"
        } else {
            //mmsensorPeripheral.turnOffLED()
            //mmsensorPeripheral.getList()
            mmsensorPeripheral.smartConfig()
            ledStateLabel.text = "OFF"
        }
    }
    
    private func setupDependencies() {
        //This will run on iOS 10 or above
        //and will generate a tap feedback when the button is tapped on the Dev kit.
        prepareHaptics()
        
        //Set default text to Reading ...
        //As soon as peripheral enables notifications the values will be notified
        ssidLabel.text = "SSID: Reading ..."
        securityLabel.text = "Security: Reading..."
        ledStateLabel.text    = "Reading ..."
        ledToggleSwitch.isEnabled = false
        if let id = mmsensorPeripheral.mmSensor.bleId {
            bleId.text = "BLE:\(id)"
        }else{
            bleId.text = "BLE: Reading..."
        }
        if let id = mmsensorPeripheral.mmSensor.wifiId {
            wifiId.text = "LAN: \(id)"
        }else{
            wifiId.text = "LAN: Reading..."
        }
        wifiId.center.x = view.center.x

        //print("adding button notification and led write callback handlers")
        
        mmsensorPeripheral.setSsidCallback { (str) -> (Void) in
            DispatchQueue.main.async {
                let text=str.components(separatedBy: ",")
                switch text.count {
                case 2:
                    self.ssidLabel.text = "SSID: \(text[0])"
                    let numStr=text[1].components(separatedBy: NSCharacterSet.decimalDigits.inverted)
                    if let num=Int(numStr.joined()){
                        switch num{
                        case 0 : self.securityLabel.text = "Security: Open"
                        case 1 : self.securityLabel.text = "Security: Wep"
                        case 2 : self.securityLabel.text = "Security: WPA PSK"
                        case 3 : self.securityLabel.text = "Security: WPA2 PSK"
                        case 4 : self.securityLabel.text = "Security: WPA/WPA2 PSK"
                        case 5 : self.securityLabel.text = "Security: WPA2 Enterprise"
                        default:
                            self.securityLabel.text = "Security: \(String(describing: num))"+text[1]
                        }
                    }else{
                        self.securityLabel.text = "Security: \(text[1]).\(text[1].count)"
                    }
                default:
                    self.ssidLabel.text = "SSID: \(str)"
                }
            }
        }
        
        mmsensorPeripheral.setBleIdCallback { (str) -> (Void) in
            DispatchQueue.main.async {
                self.rxLabel.text = "\(str)"
            }
        }
        
        mmsensorPeripheral.setLEDCallback { (isOn) -> (Void) in
            DispatchQueue.main.async {
                if !self.ledToggleSwitch.isEnabled {
                    self.ledToggleSwitch.isEnabled = true
                }
                
                if isOn {
                    self.ledStateLabel.text = "ON"
                    if self.ledToggleSwitch.isOn == false {
                        self.ledToggleSwitch.setOn(true, animated: true)
                    }
                } else {
                    self.ledStateLabel.text = "OFF"
                    if self.ledToggleSwitch.isOn == true {
                        self.ledToggleSwitch.setOn(false, animated: true)
                    }
                }
            }
        }
        mmsensorPeripheral.setRxCallback { (str) -> (Void) in
            DispatchQueue.main.async {
                self.rxLabel.text = "BLE:\(str)"
            }
        }
        mmsensorPeripheral.setBleIdCallback { (str) -> (Void) in
            DispatchQueue.main.async {
                self.bleId.text = "BLE:\(str)"
            }
        }
        mmsensorPeripheral.setWifiIdCallback { (str) -> (Void) in
            DispatchQueue.main.async {
                self.wifiId.text = "LAN: \(str)"
            }
        }
    }
    //MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    //MARK: - UIViewController
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard mmsensorPeripheral.basePeripheral.state != .connected else {
            //View is coming back from a swipe, everything is already setup
            return
        }
        //This is the first time view appears, setup the subviews and dependencies
        setupDependencies()
    }

    // viewが消去される時
    override func viewDidDisappear(_ animated: Bool) {
        print("removing button notification and led write callback handlers")
        mmsensorPeripheral.removeCallback()
        centralManager.cancelPeripheralConnection(mmsensorPeripheral.basePeripheral)
        
        if mmsensorPeripheral.basePeripheral.state == .connected {
            centralManager.cancelPeripheralConnection(mmsensorPeripheral.basePeripheral)
        }
        super.viewDidDisappear(animated)
    }

    //MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            dismiss(animated: true, completion: nil)
        }
    }

    // 接続完了コールバック
    //      サービス検索開始
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("["+#function+"]")
        if peripheral == mmsensorPeripheral.basePeripheral {
            mmsensorPeripheral.discoverMmSensorServices()
        }
    }
    
    // 切断時のコールバック
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if peripheral == mmsensorPeripheral.basePeripheral {
            print("blinky disconnected.")
            navigationController?.popToRootViewController(animated: true)
        }
    }

    private func prepareHaptics() {
        if #available(iOS 10.0, *) {
            hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
            (hapticGenerator as? UIImpactFeedbackGenerator)?.prepare()
        }else{
            print()
            print("hapticGenerator is not #available")
            print()
        }
    }
    private func buttonTapHapticFeedback() {
        if #available(iOS 10.0, *) {
            (hapticGenerator as? UIImpactFeedbackGenerator)?.impactOccurred()
        }else{
            print()
            print("hapticGenerator is not #available")
            print()
        }
    }
}
