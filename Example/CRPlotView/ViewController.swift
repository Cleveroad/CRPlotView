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

    //MARK: - IBOutlet
    @IBOutlet weak var sliderQuality: UISlider!
    @IBOutlet weak var plotView: CRPlotView!
    @IBOutlet weak var waveSlider: UISlider!
    
    //MARK: - Properties
    var timer = Timer()
    var visibleLength: CGFloat = 24
    var points = [CGPoint]()
    public var pointsArray = [CGPoint]()
    
    //MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
       
        plotView.totalRelativeHeight = 10
        plotView.totalRelativeLength = visibleLength
        plotView.maxZoomScale        = 10
        plotView.visibleLength       = visibleLength
        plotView.startRelativeX      = 0
        plotView.markRelativePos     = 12
        plotView.approximateMode     = true
        plotView.highColor = UIColor(red:0.45, green:0.84, blue:0.27, alpha:1.00)
        plotView.lowColor  = UIColor(red:1.00, green:0.09, blue:0.36, alpha:1.00)
        plotView.delegate = self
        update()
        let moveToNextPointSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(moveToNextPointAction(sender:)))
        moveToNextPointSwipeRecognizer.direction = [.left]
        let moveToPreviousPointSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(moveToPreviousPointAction(sender:)))
        moveToPreviousPointSwipeRecognizer.direction = [.right]
        view.addGestureRecognizer(moveToNextPointSwipeRecognizer)
        view.addGestureRecognizer(moveToPreviousPointSwipeRecognizer)
        sliderQuality.value = Float((Float(sliderQuality.maximumValue) * Float(plotView.markRelativePos)) / Float(visibleLength))
        let value = (plotView.frame.height - plotView.currentPoint.y) / plotView.frame.height
        waveSlider.value = waveSlider.maximumValue * Float(value)
    }
    
    //MARK: - Helper Methods
    func update() {
        pointsArray.append(contentsOf: test())
        plotView.reloadData()
        self.points = test()
    }
    
    //MARK: Test points
    func test() -> [CGPoint] {
        var points = [CGPoint]()
        points.append( CGPoint(x: 0, y: 5))
        points.append( CGPoint(x: 3, y: 2))
        points.append( CGPoint(x: 5, y: 5))
        points.append( CGPoint(x: 12, y: 8))
        points.append( CGPoint(x: 15, y: 10))
        points.append( CGPoint(x: 18, y: 2))
        points.append( CGPoint(x: 20, y: 0))
        points.append( CGPoint(x: 24, y: 2))
        
        return points
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

//MARK: - CRPlotViewDelegate
extension ViewController: CRPlotViewDelegate {
    public func plotView(_ plotView: CRPlotView, didMoveMark point: CGPoint) {
        waveSlider.setValue(Float(point.y), animated: false)
        sliderQuality.setValue(Float(point.x), animated: false)
    }

    func numberOfPointsInPlotView(in plotView: CRPlotView) -> UInt{
        return UInt(pointsArray.count)
    }
    
    func plotView(_ plotView: CRPlotView, pointAtIndex index: UInt) -> CGPoint{
        return pointsArray[Int(index)]
    }
}

//MARK: - Action
extension ViewController {
    @IBAction func sliderDidChangeValue(_ sender: UISlider) {
        let position = (CGFloat(sender.value) / 24) * visibleLength
        plotView.markRelativePos = position
        let value = (plotView.frame.height - plotView.currentPoint.y) / plotView.frame.height
        waveSlider.value = waveSlider.maximumValue * Float(value)
    }
    
    @IBAction func waveHighDidChange(_ sender: UISlider) {
        plotView.updateCurrentPoint(with: sender.value)
    }
    
    func moveToNextPointAction(sender: UISwipeGestureRecognizer) {
        plotView.moveMarkToNextPoint()
    }
    
    func moveToPreviousPointAction(sender: UISwipeGestureRecognizer) {
        plotView.moveMarkToPreviousPoint()
    }
}
