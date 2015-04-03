//
//  ViewController.swift
//  ColourInvariance
//
//  Created by Richard Zito on 21/03/2015.
//  Copyright (c) 2015 Richard Zito. All rights reserved.
//


import UIKit
import CoreMedia

class ViewController: UIViewController
{

    private var metalController: MetalController!
    private var camera: Camera!

    private var alphaFactorSlider: UISlider!
    private var invariantSwitch: UISwitch!
    private var cameraSwitch: UISwitch!
    
    private struct Layout
    {
        static let controlHeight: CGFloat = 40
    }
    
    init()
    {
        self.camera = Camera()
        self.metalController = MetalController()
        
        super.init(nibName: nil, bundle: nil)
    
        self.camera.delegate = self
        
    }

    required init(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.alphaFactorSlider = UISlider()
        self.alphaFactorSlider.addTarget(self, action: "sliderDidChangeValue:", forControlEvents: .ValueChanged)
        self.alphaFactorSlider.value = 0.45
        self.alphaFactorSlider.backgroundColor = UIColor(white: 0, alpha: 0.7)
        
        self.invariantSwitch = UISwitch()
        self.invariantSwitch.addTarget(self, action: "invariantSwitchDidChangeValue:", forControlEvents: .ValueChanged)
        self.invariantSwitch.on = true
        self.invariantSwitch.sizeToFit()
        
        self.cameraSwitch = UISwitch()
        self.cameraSwitch.addTarget(self, action: "cameraSwitchDidChangeValue:", forControlEvents: .ValueChanged)
        self.cameraSwitch.on = false
        self.cameraSwitch.sizeToFit()
        
        self.metalController.metalLayer.frame = self.view.bounds
        self.metalController.metalLayer.backgroundColor = UIColor.yellowColor().CGColor
        self.metalController.metalLayer.contentsGravity = kCAGravityResizeAspect
        self.view.layer.addSublayer(self.metalController.metalLayer)

        self.view.addSubview(self.alphaFactorSlider)
        self.view.addSubview(self.invariantSwitch)
        self.view.addSubview(self.cameraSwitch)
        
    }
    
    override func viewDidAppear(animated: Bool)
    {
        self.updateForUIState()
    }
    
    override func viewWillLayoutSubviews()
    {
        self.alphaFactorSlider.frame = CGRect(x: 0, y: self.view.bounds.height - Layout.controlHeight, width: self.view.bounds.size.width, height: Layout.controlHeight)
        self.invariantSwitch.frame = CGRectMake(0, self.alphaFactorSlider.frame.minY - Layout.controlHeight, self.invariantSwitch.frame.width, Layout.controlHeight)
        self.cameraSwitch.frame = CGRectMake(self.view.bounds.width - self.cameraSwitch.frame.width, self.alphaFactorSlider.frame.minY - Layout.controlHeight, self.cameraSwitch.frame.width, Layout.controlHeight)
    }
    
    private func updateForUIState()
    {
        self.metalController.alphaFactor = Float(self.alphaFactorSlider.value)
        self.metalController.invarianceEnabled = self.invariantSwitch.on
        
        if self.cameraSwitch.on
        {
            self.camera.start()
        }
        else
        {
            // image mode
            
            self.camera.stop()
            if let image = UIImage(named: "brick-wall.jpg")
            {
                self.metalController.setTextureSource(MetalController.Texture.Image(image), completion: nil)
            }
            else
            {
                self.metalController.setTextureSource(nil, completion: nil)
            }
        }
    }
    
    @objc private func sliderDidChangeValue(slider: UISlider)
    {
        self.updateForUIState()
    }
    
    @objc private func invariantSwitchDidChangeValue(switchControl: UISwitch)
    {
        self.updateForUIState()
    }
    
    @objc private func cameraSwitchDidChangeValue(switchControl: UISwitch)
    {
        self.updateForUIState()
    }
}

extension ViewController : CameraDelegate
{
    func cameraDidGenerateSampleBuffer(sampleBuffer: CMSampleBuffer)
    {
        let completionGroup = dispatch_group_create()
        
        dispatch_group_enter(completionGroup)
        self.metalController.setTextureSource(MetalController.Texture.SampleBuffer(sampleBuffer), completion: {
            dispatch_group_leave(completionGroup)
        })
        
        // wait until sample's been processed and we're ready for another one
        dispatch_group_wait(completionGroup, DISPATCH_TIME_FOREVER)

    }
    
}
