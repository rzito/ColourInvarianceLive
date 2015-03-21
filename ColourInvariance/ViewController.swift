//
//  ViewController.swift
//  ColourInvariance
//
//  Created by Richard Zito on 21/03/2015.
//  Copyright (c) 2015 Touchpress. All rights reserved.
//
/**

- http://www.robots.ox.ac.uk/~mobile/Papers/2014ICRA_maddern.pdf

*/


import UIKit

class ViewController: UIViewController {

    var imageView: UIImageView!
    var slider: UISlider!
    var image: UIImage!
    var invariantSwitch: UISwitch!
    var camera: Camera!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
    
        self.slider = UISlider(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 40))
        self.slider.addTarget(self, action: "sliderDidChangeValue:", forControlEvents: .ValueChanged)
        self.slider.value = 0.45
        self.slider.backgroundColor = UIColor.grayColor()
        
        self.invariantSwitch = UISwitch(frame: CGRectMake(0, self.view.bounds.size.height - 40, 50, 40))
        self.invariantSwitch.addTarget(self, action: "invariantSwitchDidChangeValue:", forControlEvents: .ValueChanged)
        self.invariantSwitch.on = false
        self.view.addSubview(self.invariantSwitch)
        
        self.image = UIImage(named: "paper-example.png")!
        
        self.imageView = UIImageView()
        self.imageView.frame = self.view.bounds
        self.imageView.contentMode = .ScaleAspectFit
        self.imageView.layer.setAffineTransform(CGAffineTransformMakeRotation(CGFloat(M_PI/2.0)))
        self.view.addSubview(self.imageView)

        self.camera = Camera()
        self.camera.delegate = self
        
        self.view.addSubview(self.slider)

        self.updateImage()
    }
    
    func updateImage()
    {
        
        if !self.invariantSwitch.on
        {
            self.imageView.image = self.image
        }
        else
        {
            let imageRef = self.image.CGImage!

            let width = CGImageGetWidth(imageRef)
            let height = CGImageGetHeight(imageRef)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let rawData = UnsafeMutablePointer<UInt8>.alloc(height * width * 4)
            
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            let bitsPerComponent = 8
            let context = CGBitmapContextCreate(rawData, width, height, bitsPerComponent, bytesPerRow, colorSpace,
                CGBitmapInfo(CGBitmapInfo.ByteOrder32Big.rawValue | CGImageAlphaInfo.PremultipliedLast.rawValue))
            
            CGContextDrawImage(context, CGRectMake(0, 0, CGFloat(width), CGFloat(height)), imageRef)
            
            let algoAlpha = Double(slider.value)
            
            makeImageDataColourInvariant(rawData, width, height, algoAlpha, .RGB)
            
            let image = CGBitmapContextCreateImage(context)
            self.imageView.image = UIImage(CGImage: image)
        }
    }

    func sliderDidChangeValue(slider: UISlider)
    {
        self.updateImage()
        self.camera.alphaParam = Double(slider.value)
    }
    
    func invariantSwitchDidChangeValue(switchControl: UISwitch)
    {
        self.updateImage()
    }
}


extension ViewController : CameraDelegate
{
    func cameraDidGenerateNewImage(image: CGImageRef)
    {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.imageView.layer.contents = image
        })
    }
}
