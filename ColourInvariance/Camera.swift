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
    func cameraDidGenerateNewImage(image: CGImageRef)
}

class Camera : NSObject
{
    var delegate: CameraDelegate?
    
    let session: AVCaptureSession
    
    var alphaParam = 0.45
    
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
        
        self.session.startRunning()
        
    }

}


extension Camera : AVCaptureVideoDataOutputSampleBufferDelegate
{
   
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!)
    {
        
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)

        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        // Get the number of bytes per row for the pixel buffer
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        
        // convert UnsafeMutablePointer to UInt8
        let baseAddressPointer = COpaquePointer(baseAddress)
        let imageAddressBuffer = UnsafeMutablePointer<UInt8>(baseAddressPointer)

        makeImageDataColourInvariant(imageAddressBuffer, width, height, self.alphaParam, .BGR)

        // Create a bitmap graphics context with the sample buffer data
        let colorSpace = CGColorSpaceCreateDeviceRGB();
        let bitmapInfo = CGBitmapInfo(CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue)
        let context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, bitmapInfo) // bgra
        // Create a Quartz image from the pixel data in the bitmap graphics context
        let quartzImage = CGBitmapContextCreateImage(context)!;
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
        self.delegate?.cameraDidGenerateNewImage(quartzImage)
        
    }
   
}
