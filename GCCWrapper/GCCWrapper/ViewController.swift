//
//  ViewController.swift
//  GCCWrapper
//
//  Created by kofktu on 2017. 2. 3..
//  Copyright © 2017년 Kofktu. All rights reserved.
//

import UIKit
import KofktuSDK

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Scan", style: .plain, target: self, action: #selector(onScan))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: - Action
    @IBAction func onSetup() {
        let media = GCCMediaAudio(contentUrl: "https://dl.dropboxusercontent.com/u/55180996/Music/SymphonyNo.5.mp3",
                                  title: "제목",
                                  subtitle: "내용",
                                  imageUrl: "https://lh3.googleusercontent.com/sclRoFqqx9WvPY0WmvrHVvG8IayZkmAuD3rib66xEhZQx7uXazYOoXCmkkMlogExTNA=w300",
                                  imageSize: CGSize(width: 300.0, height: 300.0))
        GCCWrapper.default.loadMedia(media)
    }
    
    @IBAction func onPlay() {
        GCCWrapper.default.play()
    }
    
    @IBAction func onPause() {
        GCCWrapper.default.pause()
    }
    
    @IBAction func onStop() {
        GCCWrapper.default.stop()
    }
    
    @IBAction func onSeekPrev() {
        GCCWrapper.default.seekTo(position: GCCWrapper.default.streamPosition - 10.0)
    }
    
    @IBAction func onSeekNext() {
        GCCWrapper.default.seekTo(position: GCCWrapper.default.streamPosition + 10.0)
    }
    
    @IBAction func onScan() {
        GCCWrapper.default.startScan()
    }
}
