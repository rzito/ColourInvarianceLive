//
//  Camera.swift
//  ColourInvariance
//
//  Created by Richard Zito on 21/03/2015.
//  Copyright (c) 2015 Touchpress. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import Accelerate

protocol CameraDelegate : class
{
    func cameraDidGenerateSampleBuffer(sampleBuffer: CMSampleBuffer)
}

class Camera : NSObject
{
    var delegate: CameraDelegate?
    
    let session: AVCaptureSession
    
    
    override init()
    {
        self.session = AVCaptureSession()
        self.session.sessionPreset = AVCaptureSessionPresetHigh
        
        
        super.init()
        
        let captureDevice = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).filter({ $0.position == AVCaptureDevicePosition.Back }).first as! AVCaptureDevice
        
        let captureDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(captureDevice, error: nil) as! AVCaptureDeviceInput
        self.session.addInput(captureDeviceInput)
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [ kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_32BGRA ]
        output.alwaysDiscardsLateVideoFrames = true
        let queue = dispatch_queue_create("MyQueue", nil);
        output.setSampleBufferDelegate(self, queue: queue)
        self.session.addOutput(output)

        let connection = output.connectionWithMediaType(AVMediaTypeVideo)
        connection.videoOrientation = .Portrait
        
    }

    func start()
    {
        self.session.startRunning()
    }
    
}


extension Camera : AVCaptureVideoDataOutputSampleBufferDelegate
{
   
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!)
    {
        self.delegate?.cameraDidGenerateSampleBuffer(sampleBuffer)
    }
   
}
