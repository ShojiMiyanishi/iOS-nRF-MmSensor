//
//  RootViewController.swift
//  nRFBlinky
//
//  Created by Mostafa Berg on 28/11/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//

import UIKit

/*
 * アプリケーション起動時最初に表示されるview。 ロゴ
 */
class RootViewController: UINavigationController {
    @IBOutlet var wirelessByNordicView: UIView!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //
        //wirelessByNordicViewはstoryboarの「Wireless By Nordic View」を参照
        //参照情報は、ストーリーボードのファイルに記録されている。
        if !view.subviews.contains(wirelessByNordicView) {
            view.addSubview(wirelessByNordicView)
            wirelessByNordicView.frame =
                 CGRect(
                    x: 0,
                    y: (view.frame.height - wirelessByNordicView.frame.size.height),
                    width: view.frame.width,
                    height: wirelessByNordicView.frame.height
                 )
            view.bringSubview(toFront: wirelessByNordicView)
        }
    }
    //表示時のトランジッションの定義
    override func viewWillTransition(
            to size: CGSize,
            with coordinator: UIViewControllerTransitionCoordinator
            ) 
    {
        super.viewWillTransition(to: size, with: coordinator)
        self.wirelessByNordicView.alpha = 0
        if view.subviews.contains(wirelessByNordicView) {
            coordinator.animateAlongsideTransition(
                in: self.view,
                animation: {
                    (context) in
                        self.wirelessByNordicView.alpha = 0
                        self.wirelessByNordicView.frame =
                        CGRect(
                            x: 0,
                            y: (context.containerView.frame.size.height - 27),
                            width: context.containerView.frame.size.width,
                            height: 27
                    )
                },
                completion: {
                    (context) in
                        UIView.animate(
                            withDuration: 3.5,
                            animations: {
                                self.wirelessByNordicView.alpha = 1
                        }
                    )
                }
            )
        }
    }
}
