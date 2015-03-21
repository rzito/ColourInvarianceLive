//
//  ImageProcessing.swift
//  ColourInvariance
//
//  Created by Richard Zito on 21/03/2015.
//  Copyright (c) 2015 Touchpress. All rights reserved.
//

import Foundation
import Accelerate

enum ColorMode {
    case BGR
    case RGB
}

func makeImageDataColourInvariant(imageData: UnsafeMutablePointer<UInt8>, width: Int, height: Int, sensorAlpha: Double, colorMode: ColorMode )
{
    let bytesPerPixel = 4
    
    let rgbStride: (Int,Int,Int) = {
        switch colorMode
        {
        case .BGR:
            return (2,1,0)
        case .RGB:
            return (0,1,2)
        }
    }()
    
    for pixelIdx in 0..<width*height
    {
        
        
        let ri = imageData[pixelIdx * bytesPerPixel + rgbStride.0]
        let gi = imageData[pixelIdx * bytesPerPixel + rgbStride.1]
        let bi = imageData[pixelIdx * bytesPerPixel + rgbStride.2]
    
        let value = 0.5 + logTable[gi] - sensorAlpha * logTable[bi] - (1.0 - sensorAlpha) * logTable[ri]
        
        let valUint = UInt8(min(1,max(0,value)) * 255)
        imageData[pixelIdx * bytesPerPixel + 0] = valUint
        imageData[pixelIdx * bytesPerPixel + 1] = valUint
        imageData[pixelIdx * bytesPerPixel + 2] = valUint
    
    }

}

private let logTable: [Double] = {
    var logs: [Double] = []
    for i in 0...255
    {
        logs += [log(Double(i)/255.0)]
    }
    return logs
}()

private extension Array
{
    subscript (index: UInt8) -> Element {
        return self[Int(index)]
    }
}

private extension UnsafeBufferPointer
{
    subscript (index: UInt8) -> T {
        return self[Int(index)]
    }
}