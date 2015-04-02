//
//  MetalController.swift
//  ColourInvariance
//
//  Created by Richard Zito on 02/04/2015.
//  Copyright (c) 2015 Touchpress. All rights reserved.
//

import UIKit
import Metal


class MetalController {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLComputePipelineState
    let alphaFactor: Float = 0.5
    
    struct AlphaFactorUniform
    {
        var alphaFactor: Float
    }
    
    init()
    {
        self.device = MTLCreateSystemDefaultDevice()!
        
        let defaultLibrary = self.device.newDefaultLibrary()!
        self.commandQueue = self.device.newCommandQueue()
        
        let kernelFunction = defaultLibrary.newFunctionWithName("kernelShader")!
        self.pipelineState = self.device.newComputePipelineStateWithFunction(kernelFunction, error: nil)!
        
    }
    
    func invariantImageFromImage(image: UIImage) -> UIImage
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

        // create output texture
        let outTextureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(texture.pixelFormat, width: texture.width, height: texture.height, mipmapped: false)
        let outTexture = device.newTextureWithDescriptor(outTextureDescriptor)
        
        // set up command buffer
        let commandBuffer = self.commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.computeCommandEncoder()

        commandEncoder.setComputePipelineState(self.pipelineState)
        commandEncoder.setTexture(texture, atIndex: 0)
        commandEncoder.setTexture(outTexture, atIndex: 1)

        // populate uniforms
        var saturationFactor = AlphaFactorUniform(alphaFactor: self.alphaFactor)
        var buffer: MTLBuffer = device.newBufferWithBytes(&saturationFactor, length: sizeof(AlphaFactorUniform), options: nil)
        commandEncoder.setBuffer(buffer, offset: 0, atIndex: 0)
        
        // execute commands
        let threadGroupCount = MTLSizeMake(8, 8, 1)
        let threadGroups = MTLSizeMake(texture.width / threadGroupCount.width, texture.height / threadGroupCount.height, 1)
        
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // get image data from texture
        
        let imageSize = CGSize(width: texture.width, height: texture.height)
        let imageByteCount = Int(imageSize.width * imageSize.height * 4)
        
        var imageBytes = [UInt8](count: imageByteCount, repeatedValue: 0)
        outTexture.getBytes(&imageBytes, bytesPerRow: Int(bytesPerRow), fromRegion: region, mipmapLevel: 0)
        
        // create image from data
        
        let providerRef = CGDataProviderCreateWithCFData(
            NSData(bytes: &imageBytes, length: imageBytes.count * sizeof(UInt8))
        )
        
        let renderingIntent = kCGRenderingIntentDefault
        
        let outImageRef = CGImageCreate(Int(imageSize.width), Int(imageSize.height), bitsPerComponent, bitsPerPixel, bytesPerRow, rgbColorSpace, bitmapInfo, providerRef, nil, false, renderingIntent)
        
        return UIImage(CGImage: outImageRef)!
        
    }
    
}