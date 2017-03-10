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
    
    override func action(forKey event: String) -> CAAction? {
        if event == "path" {
            let animation = CABasicAnimation(keyPath: event)
            animation.duration = 0.25
            animation.fromValue = presentation()?.value( forKey: event )
            return animation
        }
        
        return super.action( forKey: event )
    }
    
    override class func needsDisplay(forKey key: String) -> Bool {
        if key == "path" {
            return true
        }
        
        return super.needsDisplay( forKey: key )
    }
}
