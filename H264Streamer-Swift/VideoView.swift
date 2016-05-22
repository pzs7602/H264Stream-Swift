//
//  VideoView.swift
//  H264Streamer-Swift
//
//  Created by pan zhansheng on 16/5/13.
//  Copyright © 2016年 pan zhansheng. All rights reserved.
//

import UIKit
import AVFoundation

class VideoView: UIView {

    var videoLayer:AVSampleBufferDisplayLayer?
    func setupVideoLayer()
    {
        self.videoLayer = AVSampleBufferDisplayLayer()
        self.videoLayer?.bounds = self.bounds
        self.videoLayer?.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds))
        self.videoLayer?.videoGravity = AVLayerVideoGravityResizeAspect
        self.videoLayer?.backgroundColor = UIColor.blueColor().CGColor
        let _cmTimebasePointer = UnsafeMutablePointer<CMTimebase?>.alloc(1)
        CMTimebaseCreateWithMasterClock( kCFAllocatorDefault, CMClockGetHostTimeClock(), _cmTimebasePointer)
        
        self.videoLayer!.controlTimebase = _cmTimebasePointer[0]
        CMTimebaseSetTime(self.videoLayer!.controlTimebase!, CMTimeMake(5, 1));
        CMTimebaseSetRate(self.videoLayer!.controlTimebase!, 1.0)
        
//        self.videoLayer!.autoresizingMask = [UIViewAutoresizing.FlexibleWidth,UIViewAutoresizing.FlexibleHeight]
        
        self.layer.addSublayer(self.videoLayer!)
        _cmTimebasePointer.dealloc(1)
    }
    override init(frame:CGRect)
    {
        super.init(frame:frame)
        self.setupVideoLayer()
        print("videoView init")
    }
    
    convenience init()
    {
        self.init(frame:CGRectMake(0,0,100,100))
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
}
