//
//  UIColor+CRPlotView.swift
//  Pods
//
//  Created by Vladyslav Denysenko on 3/9/17.
//
//

import UIKit

extension UIColor {
    func darkColor() -> UIColor{
        let c = self.cgColor.components
        let r: CGFloat = max(c![0] - 0.2, 0)
        let g: CGFloat = max(c![1] - 0.2, 0)
        let b: CGFloat = max(c![2] - 0.2, 0)
        let a: CGFloat = c![3]
        return UIColor(red:r, green:g, blue:b, alpha:a)
    }
    
    func interpolateToColor(_ toColor: UIColor, fraction: CGFloat) -> UIColor {
        var f = max(0, fraction)
        f = min(1, fraction)
        
        let c1 = self.cgColor.components
        let c2 = toColor.cgColor.components
        
        let r = c1![0] + (c2![0] - c1![0]) * f
        let g = c1![1] + (c2![1] - c1![1]) * f
        let b = c1![2] + (c2![2] - c1![2]) * f
        let a = c1![3] + (c2![3] - c1![3]) * f
        
        return UIColor(red:r, green:g, blue:b, alpha:a)
    }
}

