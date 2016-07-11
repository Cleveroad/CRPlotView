//
//  RadialGradientLayer.swift
//  Pods
//
//  Created by Dmitry Pashinskiy on 6/10/16.
//
//

import UIKit

class RadialGradientLayer: CALayer {
    
    var gradColors: [CGColor] = [UIColor.whiteColor().CGColor, UIColor.clearColor().CGColor] {
        didSet {
            self.backgroundColor = gradColors.last
        }
    }

    var gradCenter: CGPoint?
    var gradRadius: CGFloat?
    var gradLocations: [CGFloat] = [0.0, 0.5]
    
    
    override init(layer: AnyObject) {
        super.init(layer: layer)
    }
    
    init(colors: [CGColor]? = nil, radius: CGFloat? = nil, center: CGPoint? = nil) {
        gradCenter = center
        gradRadius = radius
        gradColors = colors ?? [UIColor.whiteColor().CGColor, UIColor.clearColor().CGColor]
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init()
    }
    
    override func drawInContext(ctx: CGContext) {
        super.drawInContext( ctx )
        
        let radius = self.gradRadius ?? max(bounds.width, bounds.height)
        let center = self.gradCenter ?? CGPoint(x: bounds.midX, y: bounds.midY)
        let colors = gradColors
        
        var gradient = CGGradientCreateWithColors(CGColorSpaceCreateDeviceRGB(), colors, gradLocations)
        CGContextDrawRadialGradient(ctx, gradient, center, 0, center, radius / 2, .DrawsBeforeStartLocation)
    }
}

//class RadialGradientLayer: CALayer {
//    
//    override init(){
//        
//        super.init()
//        
////        needsDisplayOnBoundsChange = true
//    }
//    
//    init(center:CGPoint,radius:CGFloat,colors:[CGColor]){
//        
//        self.center = center
//        self.radius = radius
//        self.colors = colors
//        
//        super.init()
//        
//    }
//    
//    required init(coder aDecoder: NSCoder) {
//        super.init()
//    }
//    
//    var center:CGPoint = CGPointMake(50,50)
//    var radius:CGFloat = 20
//    var colors:[CGColor] = [UIColor(red: 251/255, green: 237/255, blue: 33/255, alpha: 1.0).CGColor ,
//                            UIColor(red: 251/255, green: 179/255, blue: 108/255, alpha: 1.0).CGColor]
//    
//    override func drawInContext(ctx: CGContext!) {
//        
//        CGContextSaveGState(ctx)
//        
//        
//        let gradCenter = CGPoint(x: bounds.midX, y: bounds.midY)
//        let gradRadius = max(bounds.width, bounds.height)
//        colors = [UIColor.whiteColor().colorWithAlphaComponent(0).CGColor,
//                  UIColor.whiteColor().colorWithAlphaComponent(0.5).CGColor]
//        
//        
//        
//        var colorSpace = CGColorSpaceCreateDeviceRGB()
//        
//        //        let gradColors:[CGFloat] = [1,1,1,0.5,
//        //                                    1,1,1,0]
//        var locations:[CGFloat] = [0.0, 1.0]
//        
//        var gradient = CGGradientCreateWithColors(colorSpace, colors, [0.0,0.5])
//        
//        var startPoint = CGPointMake(0, self.bounds.height)
//        var endPoint = CGPointMake(self.bounds.width, self.bounds.height)
//        
//        CGContextDrawRadialGradient(ctx, gradient, gradCenter, 0.0, gradCenter, gradRadius, .DrawsBeforeStartLocation)
//    }
//    
//}