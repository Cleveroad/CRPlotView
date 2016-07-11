//
//  PlotShapeLayer.swift
//  CRPlotView
//
//  Created by Dmitry Pashinskiy on 5/31/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

class PlotShapeLayer: CAShapeLayer {
    
    override func actionForKey(event: String) -> CAAction? {
        if event == "path" {
            let animation = CABasicAnimation(keyPath: event)
            animation.duration = 0.25
            animation.fromValue = presentationLayer()?.valueForKey( event )
            return animation
        }
        
        return super.actionForKey( event )
    }
    
    override class func needsDisplayForKey(key: String) -> Bool {
        if key == "path" {
            return true
        }
        return super.needsDisplayForKey( key )
    }
}