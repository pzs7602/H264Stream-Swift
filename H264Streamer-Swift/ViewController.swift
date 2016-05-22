//
//  ViewController.swift
//  H264Streamer-Swift
//
//  Created by pan zhansheng on 16/5/13.
//  Copyright © 2016年 pan zhansheng. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

enum NALUType:Int{
    case SliceNoneIDR = 1
    case SliceIDR = 5
    case SPS = 7
    case PPS = 8
}
class ViewController: UIViewController {

    
//    @IBOutlet weak var videoView: VideoView!
    var videoView: VideoView!
    var spsData:NSData?
    var ppsData:NSData?
    var videoFormatDescr:CMVideoFormatDescriptionRef?
    var videoFormatDescriptionAvailable:Bool = false

    func getNALUType(NALU:NSData) -> Int{
        let count = NALU.length/sizeof(UInt8)
        var bytes = [UInt8](count:count,repeatedValue:0)
        NALU.getBytes(&bytes,length:count*sizeof(UInt8))
        return Int(bytes[0] & 0x1F)
    }
    func handleSPS(NALU:NSData)
    {
        self.spsData = NALU.copy() as? NSData
    }
    func handlePPS(NALU:NSData)
    {
        self.ppsData = NALU.copy() as? NSData
    }
    @IBAction func streamVideo(sender:AnyObject)
    {
        // 处理 1000 个 NALU block
        for k in 0..<100{
            let resource = NSString(format:"nalu_%03d",k)
            let path = NSBundle.mainBundle().pathForResource(resource as String, ofType: "bin")
            let data = NSData(contentsOfFile: path!)
            self.parseNALU(data!)
        }
    }
    func updateFormatDescriptionIfPossible()
    {
        // create CMVideoFormatDescriptionRef from SPS/PPS
        if self.spsData != nil && self.ppsData != nil{
            var uint8spsData = [UInt8](count: self.spsData!.length/sizeof(UInt8), repeatedValue: 0)
            // convert NSData to [UInt8]
            self.spsData?.getBytes(&uint8spsData, length: self.spsData!.length)
            let pointerSPS = UnsafePointer<UInt8>(uint8spsData)
            
            var uint8ppsData = [UInt8](count: self.ppsData!.length/sizeof(UInt8), repeatedValue: 0)
            // convert NSData to [UInt8]
            self.ppsData?.getBytes(&uint8ppsData, length: self.ppsData!.length)
            let pointerPPS = UnsafePointer<UInt8>(uint8ppsData)
            let dataParamArray = [pointerSPS,pointerPPS]
            let parameterSetPointers = UnsafePointer<UnsafePointer<UInt8>>(dataParamArray)
//            let parameterSetSizes = [self.spsData?.length,self.ppsData?.length]
            let sizeParamArray = [uint8spsData.count, uint8ppsData.count]
            
            // set parameter set sizes
            let parameterSetSizes = UnsafePointer<Int>(sizeParamArray)

            let status:OSStatus = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,2,parameterSetPointers,parameterSetSizes,4,&self.videoFormatDescr)
            
            self.videoFormatDescriptionAvailable = true
            print("Updated CMVideoFormatDescription. Creation: \((status == noErr) ? "successfully." : "failed.\(status.description)").")

        }
    }
    func handleSlice(NALU:NSData)
    {
        if self.videoFormatDescriptionAvailable{
            // the length of the NALU is in big endian
            var NALUlengthInBigEndian = CFSwapInt32HostToBig(UInt32(NALU.length))
            // create the slice
            let slice:NSMutableData = NSMutableData(bytes: &NALUlengthInBigEndian, length: 4)
            // append the content of the NALU
            slice.appendData(NALU)
            
            // create the video block
            var videoBlock:CMBlockBufferRef? = nil
            
//            var samplePtr = UnsafeMutablePointer<[UInt8]>.alloc(1)
//            var uint8Data = [UInt8](count: slice.length/sizeof(UInt8), repeatedValue: 0)
            // convert NSData to [UInt8]
//            slice.getBytes(&uint8Data, length: uint8Data.count)
//            samplePtr.memory = uint8Data
            let samplePtr = UnsafeMutablePointer<UInt8>(slice.bytes)
            var status:OSStatus = CMBlockBufferCreateWithMemoryBlock(nil,samplePtr,slice.length,kCFAllocatorNull,nil,0,slice.length,0,&videoBlock)

            print("BlockBufferCreation:\((status == kCMBlockBufferNoErr) ? "successfully." : "failed.")")
            
            // create the CMSampleBuffer
            var sbRef:CMSampleBufferRef?
            let sampleSizeArray = [slice.length]
            status = CMSampleBufferCreate(kCFAllocatorDefault,videoBlock,true,nil,nil,self.videoFormatDescr,1,0,nil,1,sampleSizeArray,&sbRef)
            
            print("SampleBufferCreate:\((status == noErr) ? "successfully." : "failed.")")
            /* Enqueue the CMSampleBuffer in the AVSampleBufferDisplayLayer */
            let attachments:CFArrayRef = CMSampleBufferGetSampleAttachmentsArray(sbRef!, true)!
            let dict:CFMutableDictionaryRef? = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),CFMutableDictionaryRef.self)
            // set kCMSampleAttachmentKey_DisplayImmediately key to kCFBooleanTrue
            // pay attention to unsafeBitCast type conversion below
            CFDictionarySetValue(dict ,unsafeBitCast(kCMSampleAttachmentKey_DisplayImmediately, UnsafePointer<Void>.self), unsafeAddressOf(kCFBooleanTrue))
            
            let mes = (self.videoView.videoLayer!.status == AVQueuedSampleBufferRenderingStatus.Unknown)
                ? "unknown"
                : (
                    (self.videoView.videoLayer!.status == AVQueuedSampleBufferRenderingStatus.Rendering)
                        ? "rendering"
                        :"failed"
            )
            print("Error: \(self.videoView.videoLayer!.error), Status: \(mes)")
            self.videoView.videoLayer!.enqueueSampleBuffer(sbRef!)
            self.videoView.videoLayer!.setNeedsDisplay()
            print(" ")
        }
    }
    func parseNALU(NALU:NSData)
    {
        let type = self.getNALUType(NALU)
        print("NALU with Type:\(naluTypesStrings[type]) received.")
        switch(type){
        case NALUType.SliceNoneIDR.rawValue,NALUType.SliceIDR.rawValue:
            self.handleSlice(NALU)
            
        case NALUType.SPS.rawValue:
            self.handleSPS(NALU)
            self.updateFormatDescriptionIfPossible()
            
        case NALUType.PPS.rawValue:
            self.handlePPS(NALU)
            self.updateFormatDescriptionIfPossible()
            
        default: break
            
        }
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.videoView = VideoView(frame:CGRectMake(0, 0, self.view.bounds.width, self.view.bounds.height))
        self.view.addSubview(self.videoView)
        let tapGesture:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        self.view.addGestureRecognizer(tapGesture)
        print("view=\(self.videoView.bounds.width)")
        
    }
    @IBAction func tapAction(sender: AnyObject) {
        print("tap")
        self.streamVideo(self)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

