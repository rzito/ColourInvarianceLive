//
//  MetalController.swift
//  ColourInvariance
//
//  Created by Richard Zito on 02/04/2015.
//  Copyright (c) 2015 Richard Zito. All rights reserved.
//

import UIKit
import Metal
import CoreMedia

class MetalController {
    
    let metalLayer: CAMetalLayer
    
    let textureUpdateQueue = dispatch_queue_create("com.mycompany.colourinvariance.textureupdate", DISPATCH_QUEUE_SERIAL)

    var alphaFactor: Float = 0.45
    var invarianceEnabled: Bool = true
    
    enum Texture
    {
        case SampleBuffer(CMSampleBufferRef)
        case Image(UIImage)
    }
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    private let colourInvariantPipelineState: MTLComputePipelineState
    private let colourPipelineState: MTLComputePipelineState

    private var textureCache: Unmanaged<CVMetalTextureCacheRef>?
    
    private var texture: MTLTexture?
    
    // Matches struct in shader
    private struct AlphaFactorUniform
    {
        var alphaFactor: Float
    }
    
    init()
    {
        
        self.device = MTLCreateSystemDefaultDevice()!

        self.metalLayer = CAMetalLayer()
        self.metalLayer.framebufferOnly = false
        self.metalLayer.drawsAsynchronously = true
        self.metalLayer.device = self.device
        
        let defaultLibrary = self.device.newDefaultLibrary()!
        self.commandQueue = self.device.newCommandQueue()
        
        let colourInvariantFunction = defaultLibrary.newFunctionWithName("colourInvariantShader")!
        self.colourInvariantPipelineState = self.device.newComputePipelineStateWithFunction(colourInvariantFunction, error: nil)!

        let colourFunction = defaultLibrary.newFunctionWithName("colourShader")!
        self.colourPipelineState = self.device.newComputePipelineStateWithFunction(colourFunction, error: nil)!

        CVMetalTextureCacheCreate(nil, nil, self.device, nil, &self.textureCache);

    }
    
    deinit
    {
        self.textureCache?.release()
    }
    
    func setTextureSource(textureSource: Texture?, completion: (() -> Void)?)
    {
        if let textureSource = textureSource
        {
            dispatch_async(self.textureUpdateQueue) {
                
                switch textureSource
                {
                case .SampleBuffer(let sampleBuffer):
                    self.setSourceTextureFromSampleBuffer(sampleBuffer, completion: completion)
                case .Image(let image):
                    self.setSourceTextureFromImage(image, completion: completion)
                }
                
            }
        }
        else
        {
            dispatch_async(self.textureUpdateQueue) {
                
                UIGraphicsBeginImageContext(CGSizeMake(16, 16))
                let context = UIGraphicsGetCurrentContext()
                CGContextClearRect(context, CGRectMake(0, 0, 16, 16))
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                self.setSourceTextureFromImage(image, completion: completion)
                
            }

        }
    }
    
    private func setSourceTextureFromSampleBuffer(sampleBuffer: CMSampleBufferRef, completion: (() -> Void)?)
    {
        assert(!NSThread.isMainThread(), "Texture update not to be called on main thread")
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        let pixelFormat = MTLPixelFormat.BGRA8Unorm;
        
        var texture: Unmanaged<CVMetalTextureRef>?
        
        let width = CVPixelBufferGetWidth(pixelBuffer);
        let height = CVPixelBufferGetHeight(pixelBuffer);
        
        CVMetalTextureCacheCreateTextureFromImage(nil, self.textureCache?.takeUnretainedValue(), pixelBuffer, nil, pixelFormat, width, height, 0, &texture);
        let textureRGB = CVMetalTextureGetTexture(texture?.takeRetainedValue());
        
        dispatch_sync(dispatch_get_main_queue()) {
            self.texture = textureRGB

            self.render()
            completion?()
        }
        
        CVMetalTextureCacheFlush(self.textureCache?.takeUnretainedValue(), CVOptionFlags(0))
    
    }
    
    private func setSourceTextureFromImage(image: UIImage, completion: (() -> Void)?)
    {
        
        assert(!NSThread.isMainThread(), "Texture update not to be called on main thread")

        // get image data
        let imageRef = image.CGImage
        let imageWidth = CGImageGetWidth(imageRef)
        let imageHeight = CGImageGetHeight(imageRef)
        let bitsPerComponent = CGImageGetBitsPerComponent(imageRef)
        let bytesPerRow = CGImageGetBytesPerRow(imageRef)
        let colorSpace = CGImageGetColorSpace(imageRef)
        
        var rawData = [UInt8](count: Int(bytesPerRow * imageHeight), repeatedValue: 0)
        
        let bitmapInfo = CGBitmapInfo(CGBitmapInfo.ByteOrder32Big.rawValue | CGImageAlphaInfo.PremultipliedLast.rawValue)
        
        let context = CGBitmapContextCreate(&rawData, imageWidth, imageHeight, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo)
        
        CGContextDrawImage(context, CGRectMake(0, 0, CGFloat(imageWidth), CGFloat(imageHeight)), imageRef)
        
        // create texture from image data
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: Int(imageWidth), height: Int(imageHeight), mipmapped: false)
        
        let texture = self.device.newTextureWithDescriptor(textureDescriptor)
        
        let region = MTLRegionMake2D(0, 0, Int(imageWidth), Int(imageHeight))
        texture.replaceRegion(region, mipmapLevel: 0, withBytes: &rawData, bytesPerRow: Int(bytesPerRow))
        
        dispatch_sync(dispatch_get_main_queue()) {
            self.texture = texture
            self.render()
            completion?()
        }
        
    }
    
    private func render()
    {
        assert(NSThread.isMainThread(), "Render expected to be called on main thread")
        
        if let inTexture = self.texture
        {
            // set up command buffer
            let commandBuffer = self.commandQueue.commandBuffer()
            let commandEncoder = commandBuffer.computeCommandEncoder()
            
            commandEncoder.setComputePipelineState(self.invarianceEnabled ? self.colourInvariantPipelineState : self.colourPipelineState)
            
            let imageWidth = inTexture.width
            let imageHeight = inTexture.height

            self.metalLayer.drawableSize = CGSize(width: CGFloat(imageWidth), height: CGFloat(imageHeight))

            let drawable = self.metalLayer.nextDrawable()

            commandEncoder.setTexture(inTexture, atIndex: 0)
            commandEncoder.setTexture(drawable.texture, atIndex: 1)

            var alphaFactorUniform = AlphaFactorUniform(alphaFactor: self.alphaFactor)
            var uniformBuffer: MTLBuffer = self.device.newBufferWithBytes(&alphaFactorUniform, length: sizeof(AlphaFactorUniform), options: nil)
            commandEncoder.setBuffer(uniformBuffer, offset: 0, atIndex: 0)
            
            let threadGroupCount = MTLSizeMake(8, 8, 1)
            let threadGroups = MTLSizeMake(imageWidth / threadGroupCount.width, imageHeight / threadGroupCount.height, 1)
            
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            commandBuffer.commit()

            drawable.present()
            
        }
    }
    
}