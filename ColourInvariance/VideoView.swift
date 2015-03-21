//
//  VideoView.swift
//  ColourInvariance
//
//  Created by Richard Zito on 21/03/2015.
//  Copyright (c) 2015 Touchpress. All rights reserved.
//

import UIKit
import AVFoundation

class VideoView : UIView
{
    override class func layerClass() -> AnyClass
    {
        return AVCaptureVideoPreviewLayer.self
    }

    init(captureSession: AVCaptureSession)
    {
        super.init(frame: CGRectZero)
        (self.layer as! AVCaptureVideoPreviewLayer).session = captureSession
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}