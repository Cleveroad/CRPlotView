//
//  ViewController.swift
//  CRPlotView
//
//  Created by Dmitry Pashinskiy on 05/26/2016.
//  Copyright (c) 2016 Dmitry Pashinskiy. All rights reserved.
//

import UIKit
import CRPlotView

class ViewController: UIViewController {

    var points = [CGPoint]()
    @IBOutlet weak var sliderQuality: UISlider!
    @IBOutlet weak var plotView: CRPlotView!
    @IBOutlet weak var waveSlider: UISlider!
    
    
    var timer = NSTimer()
    var visibleLength: CGFloat = 24
    override func viewDidLoad() {
        super.viewDidLoad()
        
        plotView.totalRelativeHeight = 10
        plotView.totalRelativeLength = 24
        plotView.maxZoomScale        = 10
        plotView.visibleLength       = visibleLength
        plotView.startRelativeX      = 0
        plotView.markRelativePos     = 12
        plotView.approximateMode     = true

        plotView.highColor = UIColor(red:0.28, green:0.67, blue:0.16, alpha:1)// [UIColor colorWithRed:0.28 green:0.67 blue:0.16 alpha:1]
        plotView.lowColor  = UIColor(red:0.76, green:0.53, blue:0.55, alpha:1)
        
        update()
    }
    
    func update() {
        points = bassPoints()
//        points = sinusoud()
//        points = randomPoints(100)
//        points = straightLine()
        plotView.points = points
    }
    
    
    
    // types of plot points
    func sinusoud() -> [CGPoint] {
        var points = [CGPoint]()
        points.append( CGPointMake(0, 2))
        points.append( CGPointMake(6, 8))
        points.append( CGPointMake(12, 2))
        points.append( CGPointMake(18, 8))
        points.append( CGPointMake(24, 2))
        return points
    }
    func straightLine() -> [CGPoint] {
        var points = [CGPoint]()
        points.append( CGPointMake(0, 0))
        points.append( CGPointMake(6, 0))
        points.append( CGPointMake(12, 0))
        points.append( CGPointMake(18, 0))
        points.append( CGPointMake(24, 0))
        return points
    }
    func randomPoints(count: Int) -> [CGPoint] {
        var points = [CGPoint]()
        for _ in 0..<count {
            let x = CGFloat(arc4random_uniform(UInt32(plotView.totalRelativeLength) * 100)) / 100
            let y = CGFloat(arc4random_uniform(UInt32(plotView.totalRelativeHeight) * 100)) / 100
            let point = CGPointMake(x, y)
            points.append( point )
        }
        
        points = points.sort{$0.x < $1.x}
        return points
    }
    
    func bassPoints() -> [CGPoint] {
        var points = [CGPoint]()
        points.append( CGPointMake(0, 6))
        points.append( CGPointMake(6, 4))
        points.append( CGPointMake(10, 5))
        points.append( CGPointMake(16, 1))
        points.append( CGPointMake(20, 4))
        points.append( CGPointMake(24, 3))
        return points
    }
}



//MARK: - Action
extension ViewController {
    
    @IBAction func sliderDidChangeValue(sender: UISlider) {
        plotView.markRelativePos = (CGFloat(sender.value) / 10) * 24
    }
    
    @IBAction func waveHighDidChange(sender: UISlider) {
        let newPoint = CGPointMake(plotView.markRelativePos, CGFloat(10 - sender.value))
        
        var foundedIndex = -1
        for (index,point) in points.enumerate() {
            if (newPoint.x - 1)...(newPoint.x + 1) ~= point.x {
                foundedIndex = index
                break
            }
        }
        
        if foundedIndex == -1 {
            points.append( newPoint )
        } else {
            let correctedPoint = CGPointMake(points[foundedIndex].x, newPoint.y)
            points[foundedIndex] = correctedPoint
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions( true )
        plotView.points = points
        CATransaction.commit()
    }
    
    @IBAction func pinchTapped(sender: UIPinchGestureRecognizer) {
        
        let length = visibleLength * 1/sender.scale
        let relativeLength = max(min(length, plotView.totalRelativeLength), plotView.totalRelativeLength / plotView.maxZoomScale!)
        
        switch sender.state {
        case .Changed:
            CATransaction.begin()
            CATransaction.setDisableActions( true )
            plotView.visibleLength = relativeLength
            CATransaction.commit()
            break
            
        default:
            visibleLength = relativeLength
        }
        
    }
}


func ColorRGB(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 255) -> UIColor {
    return UIColor(red: r/255, green: g/255, blue: b/255, alpha: a/255)
}








