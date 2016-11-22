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
    
    
    var timer = Timer()
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

        plotView.highColor = UIColor(red:0.28, green:0.67, blue:0.16, alpha:1)
        plotView.lowColor  = UIColor(red:0.76, green:0.53, blue:0.55, alpha:1)
        
        update()
    }
    
    func update() {
        points = bassPoints()
        plotView.points = points
    }
    
    
    // types of plot points
    func sinusoud() -> [CGPoint] {
        var points = [CGPoint]()
        points.append( CGPoint(x: 0, y: 2))
        points.append( CGPoint(x: 6, y: 8))
        points.append( CGPoint(x: 12, y: 2))
        points.append( CGPoint(x: 18, y: 8))
        points.append( CGPoint(x: 24, y: 2))
        return points
    }
    func straightLine() -> [CGPoint] {
        var points = [CGPoint]()
        points.append( CGPoint(x: 0, y: 0))
        points.append( CGPoint(x: 6, y: 0))
        points.append( CGPoint(x: 12, y: 0))
        points.append( CGPoint(x: 18, y: 0))
        points.append( CGPoint(x: 24, y: 0))
        return points
    }
    func randomPoints(_ count: Int) -> [CGPoint] {
        var points = [CGPoint]()
        for _ in 0..<count {
            let x = CGFloat(arc4random_uniform(UInt32(plotView.totalRelativeLength) * 100)) / 100
            let y = CGFloat(arc4random_uniform(UInt32(plotView.totalRelativeHeight) * 100)) / 100
            let point = CGPoint(x: x, y: y)
            points.append( point )
        }
        
        points = points.sorted{$0.x < $1.x}
        return points
    }
    
    func bassPoints() -> [CGPoint] {
        var points = [CGPoint]()
        points.append( CGPoint(x: 0, y: 6))
        points.append( CGPoint(x: 6, y: 4))
        points.append( CGPoint(x: 10, y: 5))
        points.append( CGPoint(x: 16, y: 1))
        points.append( CGPoint(x: 20, y: 4))
        points.append( CGPoint(x: 24, y: 3))
        return points
    }
}



//MARK: - Action
extension ViewController {
    
    @IBAction func sliderDidChangeValue(_ sender: UISlider) {
        let position = (CGFloat(sender.value) / 10) * 24
        plotView.markRelativePos = position
        let value = (plotView.frame.height - plotView.currentPoint.y) / plotView.frame.height
        waveSlider.value = waveSlider.maximumValue * Float(value)
    }
    
    @IBAction func waveHighDidChange(_ sender: UISlider) {
        let newPoint = CGPoint(x: plotView.markRelativePos, y: CGFloat(10 - sender.value))
        
        var foundedIndex = -1
        for (index,point) in points.enumerated() {
            if (newPoint.x - 1)...(newPoint.x + 1) ~= point.x {
                foundedIndex = index
                break
            }
        }
        
        if foundedIndex == -1 {
            points.append( newPoint )
        } else {
            let correctedPoint = CGPoint(x: points[foundedIndex].x, y: newPoint.y)
            points[foundedIndex] = correctedPoint
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions( true )
        plotView.points = points
        CATransaction.commit()
    }
    
    @IBAction func pinchTapped(_ sender: UIPinchGestureRecognizer) {
        
        let length = visibleLength * 1 / sender.scale
        let relativeLength = max(min(length, plotView.totalRelativeLength), plotView.totalRelativeLength / plotView.maxZoomScale!)
                
        switch sender.state {
        case .changed:
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









