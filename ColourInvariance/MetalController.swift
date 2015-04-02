//
//  MetalController.swift
//  ColourInvariance
//
//  Created by Richard Zito on 02/04/2015.
//  Copyright (c) 2015 Touchpress. All rights reserved.
//

import UIKit
import Metal
import CoreMedia

class MetalController {
    
    let metalLayer: CAMetalLayer
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    let colourInvariantPipelineState: MTLComputePipelineState
    let colourPipelineState: MTLComputePipelineState

    var alphaFactor: Float = 0.45
    var invarianceEnabled: Bool = true

    var textureCache: Unmanaged<CVMetalTextureCacheRef>?
    
    var pendingSampleBuffer: CMSampleBufferRef?
    {
        didSet
        {
            self.createTexturesFromPendingSampleBuffer()
        }
    }
    
    var inTexture: MTLTexture?
    
    struct AlphaFactorUniform
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
    
    func createTexturesFromPendingSampleBuffer()
    {
        if let sampleBuffer = self.pendingSampleBuffer
        {
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            
            let pixelFormat = MTLPixelFormat.BGRA8Unorm;

            var texture: Unmanaged<CVMetalTextureRef>?

            let width = CVPixelBufferGetWidth(pixelBuffer);
            let height = CVPixelBufferGetHeight(pixelBuffer);
            
            CVMetalTextureCacheCreateTextureFromImage(nil, self.textureCache?.takeUnretainedValue(), pixelBuffer, nil, pixelFormat, width, height, 0, &texture);
            let textureRGB = CVMetalTextureGetTexture(texture?.takeRetainedValue());
            
            dispatch_sync(dispatch_get_main_queue()) {
                self.inTexture = textureRGB
                self.render()
            }

            CVMetalTextureCacheFlush(self.textureCache?.takeUnretainedValue(), CVOptionFlags(0))
            
        }
        
    }
    
    func render()
    {
        if let inTexture = self.inTexture
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
            //        commandBuffer.waitUntilCompleted()
            drawable.present()
            
        }
    }
    
    func setTextureFromImage(image: UIImage)
    {
        // get image data
        let imageRef = image.CGImage
        let imageWidth = CGImageGetWidth(imageRef)
        let imageHeight = CGImageGetHeight(imageRef)

        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let bitsPerPixel = bytesPerPixel * bitsPerComponent
        let bytesPerRow = bytesPerPixel * imageWidth
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        var rawData = [UInt8](count: Int(imageWidth * imageHeight * 4), repeatedValue: 0)
        
        let bitmapInfo = CGBitmapInfo(CGBitmapInfo.ByteOrder32Big.rawValue | CGImageAlphaInfo.PremultipliedLast.rawValue)
        
        let context = CGBitmapContextCreate(&rawData, imageWidth, imageHeight, bitsPerComponent, bytesPerRow, rgbColorSpace, bitmapInfo)
        
        CGContextDrawImage(context, CGRectMake(0, 0, CGFloat(imageWidth), CGFloat(imageHeight)), imageRef)
        
        // create texture from image data
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: Int(imageWidth), height: Int(imageHeight), mipmapped: true)
        
        let texture = self.device.newTextureWithDescriptor(textureDescriptor)
        
        let region = MTLRegionMake2D(0, 0, Int(imageWidth), Int(imageHeight))
        texture.replaceRegion(region, mipmapLevel: 0, withBytes: &rawData, bytesPerRow: Int(bytesPerRow))

        self.inTexture = texture
        
    }
    
}