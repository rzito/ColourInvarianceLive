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
import CoreMedia

class ViewController: UIViewController {

    var slider: UISlider!
    var invariantSwitch: UISwitch!
    var camera: Camera!
    var metalController: MetalController!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.slider = UISlider(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: 40))
        self.slider.addTarget(self, action: "sliderDidChangeValue:", forControlEvents: .ValueChanged)
        self.slider.value = 0.45
        self.slider.backgroundColor = UIColor.grayColor()
        
        self.invariantSwitch = UISwitch(frame: CGRectMake(0, self.view.bounds.size.height - 40, 50, 40))
        self.invariantSwitch.addTarget(self, action: "invariantSwitchDidChangeValue:", forControlEvents: .ValueChanged)
        self.invariantSwitch.on = true
        
        self.camera = Camera()
        self.camera.delegate = self
        
        self.metalController = MetalController()

        self.metalController.metalLayer.frame = self.view.bounds
        self.metalController.invarianceEnabled = self.invariantSwitch.on
        self.metalController.alphaFactor = Float(slider.value)
        self.metalController.metalLayer.backgroundColor = UIColor.yellowColor().CGColor
        self.metalController.metalLayer.contentsGravity = kCAGravityResizeAspect
        self.view.layer.addSublayer(self.metalController.metalLayer)

        self.view.addSubview(self.slider)
        self.view.addSubview(self.invariantSwitch)
        
        self.camera.start()

    }
    
    func sliderDidChangeValue(slider: UISlider)
    {
        self.metalController.alphaFactor = Float(slider.value)
    }
    
    func invariantSwitchDidChangeValue(switchControl: UISwitch)
    {
        self.metalController.invarianceEnabled = switchControl.on
    }
}

extension ViewController : CameraDelegate
{
    func cameraDidGenerateSampleBuffer(sampleBuffer: CMSampleBuffer)
    {
        self.metalController.pendingSampleBuffer = sampleBuffer
    }
}
