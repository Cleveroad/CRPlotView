//
//  CRPlotView.swift
//  CRPlotView
//
//  Created by Dmitry Pashinskiy on 5/26/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

let lightBlueColor = UIColor(colorLiteralRed: 0/255, green: 176/255, blue: 255/255, alpha: 1.0)
let lightBlackColor = UIColor(colorLiteralRed: 100/255, green: 100/255, blue: 100/255, alpha: 1.0)


let isItDebug = false

open class CRPlotView: UIView {
    /// allows to make curve bezier between points to make smooth lines
    open var approximateMode = false
    
    /// points count of points that will be created between two relative points
    open var approximateAccuracy = 30
    
    /// total relative length for plot scene
    open var totalRelativeLength:CGFloat = 1
    
    /// start relative offset by x axes
    open var startRelativeX:CGFloat  = 0
    
    /// total relative height for plot scene
    open var totalRelativeHeight: CGFloat = 1
    
    //TODO: add doc and usage for the vertical axis
    open var isVerticalAxisInversed = false
    
    /// visible relative length that will be showed in view
    open var visibleLength:CGFloat = 1 {
        didSet {
            print( visibleLength )
            if visibleLength > totalRelativeLength {
                visibleLength = totalRelativeLength
            }
            
            if let maxZoom = maxZoomScale
                , visibleLength < totalRelativeLength / maxZoom {
                visibleLength = totalRelativeLength / maxZoom
            }
            
            updatePlot()
        }
    }
    
    /// will hide mark
    open var markHidden: Bool {
        set {
            markLayer.isHidden = newValue
        }
        get {
            return markLayer.isHidden
        }
    }
    
    /// background color will apply by interpolating between high and low colors, depend on *markRelativePosition*
    open var highColor: UIColor?
    open var lowColor: UIColor?
    
    
    open var maxZoomScale: CGFloat?
    open var edgeInsets = UIEdgeInsetsMake(22, 0, 0, 0)
    var markXPos: CGFloat {
        get {
            return markRelativePos * lengthPerXPoint
        }
        set {
            markRelativePos = newValue / lengthPerXPoint
        }
    }
    
    open var markRelativePos: CGFloat = 0 {
        didSet {
            moveMark( markXPos )
        }
    }
    
    open var currentPoint: CGPoint {
        set {
            
        }
        get {
            let currentPointPosition = self.markLayer.position
            let percent = (self.frame.height - currentPointPosition.y) / self.frame.height
            return self.markLayer.position
        }
    }
    
    open var points = [CGPoint]() {
        didSet {
            points = points.sorted{ $0.x < $1.x }
            
            if approximateMode {
                points = approximateBezierCurve(points, accuracy: approximateAccuracy)
            }
            
            let corrPoints = correctedPoints()
            
            if isItDebug {
                for layer in pointLayers {
                    layer.removeFromSuperlayer()
                }
                pointLayers.removeAll()
                
                for point in corrPoints {
                    let layer = CALayer()
                    layer.bounds = CGRect(x: 0, y: 0, width: 8, height: 8)
                    layer.cornerRadius = 4
                    layer.backgroundColor = UIColor.red.cgColor
                    layer.position = point
                    pointLayers.append( layer )
                    plotLayer.addSublayer( layer )
                }
            }
            updatePlot()
        }
    }
    
    var pointLayers = [CALayer]()
    
    fileprivate let plotLayer: PlotShapeLayer = {
        let layer = PlotShapeLayer()
        layer.strokeEnd = 0
        layer.strokeColor = UIColor.white.cgColor
        
        layer.lineWidth = 1
        layer.backgroundColor = UIColor.clear.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineJoin = kCALineJoinRound
        
        layer.shadowRadius = 6
        layer.shadowColor = UIColor.white.cgColor
        layer.shadowOffset = CGSize(width: 0, height: -2)
        layer.shadowOpacity = 1
        
        return layer
    }()
    
    fileprivate let markLayer: CALayer = {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
        layer.cornerRadius = layer.bounds.midX
        layer.backgroundColor = UIColor.white.cgColor
        
        layer.shadowRadius = 6
        layer.shadowColor = UIColor.white.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowOpacity = 1
        layer.shadowPath = UIBezierPath(ovalIn: layer.frame.insetBy(dx: -6, dy: -6)).cgPath
        return layer
    }()
    
    fileprivate let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.bounces = false
        return view
    }()
    
    fileprivate let maskLayer: PlotShapeLayer = {
        let layer = PlotShapeLayer()
        layer.backgroundColor = UIColor.clear.cgColor
        return layer
    }()
    
    fileprivate var lengthPerYPoint: CGFloat {
        return correctedBounds.height / totalRelativeHeight
    }
    fileprivate var lengthPerXPoint: CGFloat {
        return correctedBounds.width / visibleLength
    }
    
    fileprivate var threshold: CGFloat {
        return startRelativeX + visibleLength
    }
    
    fileprivate var correctedBounds: CGRect {
        return CGRect(x: bounds.minX + edgeInsets.left,
                      y: bounds.minY + edgeInsets.top,
                      width: bounds.width - edgeInsets.left - edgeInsets.right,
                      height: bounds.height - edgeInsets.top - edgeInsets.bottom)
    }
    
    //MARK: - NEW
    
    open func calculatedPoints(_ values: [CGFloat]) -> [CGPoint] {
        var result = [CGPoint]()
        let maxPointX = totalRelativeLength
        let step = maxPointX / CGFloat (values.count - 1)
        var currentXPosition = CGFloat (0.0)
        for (_, item) in values.enumerated() {
            result.append( CGPoint(x: currentXPosition, y: item))
            currentXPosition += step;
        }
        return result
    }
    
    //MARK: - UIView
    override open func awakeFromNib() {
        super.awakeFromNib()
        layer.backgroundColor = UIColor.clear.cgColor
        
        layer.mask = maskLayer
        backgroundGradient.mask = maskLayer
        
        updatePlot()
        
        addSubview( scrollView )
        scrollView.layer.addSublayer( backgroundGradient )
        scrollView.layer.addSublayer( plotLayer )
        scrollView.layer.addSublayer( markLayer )
        scrollView.layer.addSublayer( yIndicatorLayer )
        
        let glowAnimation = createGlowAnimation()
        markLayer.add(glowAnimation, forKey: "glowAnimation")
        
        vertexGradient.backgroundColor = UIColor.clear.cgColor
        backgroundGradient.addSublayer( vertexGradient )
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognizer))
        self.addGestureRecognizer(panGesture)
    }
    
    func panGestureRecognizer(_ sender: UIPanGestureRecognizer) -> Void {
        
        if sender.state == UIGestureRecognizerState.began {
            showYIndicator()
        }
        
        let newMarkXPos = sender.translation(in: self).x + markXPos
        moveMark(newMarkXPos)
        if sender.state == UIGestureRecognizerState.ended {
            markXPos = newMarkXPos
            hideYIndicator()
        }
    }
    
    let vertexGradient: RadialGradientLayer = {
        let colors = [UIColor.white.withAlphaComponent(0.6).cgColor,
                      UIColor.white.withAlphaComponent(0).cgColor]
        let gradient = RadialGradientLayer(colors: colors)
        gradient.gradColors = colors
        
        return gradient
    }()
    
    let backgroundGradient: RadialGradientLayer = {
        let gradient = RadialGradientLayer()
        gradient.gradLocations = [0.0, 1.0]
        return gradient
    }()
    
    let yIndicatorLayer: CALayer = {
        
        let lineLayer = CALayer()
        lineLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0.5)
        lineLayer.backgroundColor = UIColor.white.cgColor
        lineLayer.opacity = 0.5
        lineLayer.isHidden = true
        
        return lineLayer
        
    }()
    
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        updatePlot()
        
        scrollView.setContentOffset(CGPoint(x: startRelativeX * lengthPerXPoint, y: 0), animated: false)
    }
}

//MARK: - Private Methods
private extension CRPlotView {
    
    func updatePlot() {
        
        let size = CGSize(width: lengthPerXPoint * totalRelativeLength, height: correctedBounds.height)
        let totalBounds = CGRect(origin: correctedBounds.origin,
                                 size: size)
        
        scrollView.frame = bounds
        scrollView.contentSize = CGSize(width: lengthPerXPoint * totalRelativeLength, height: bounds.height)
        
        plotLayer.frame = totalBounds
        backgroundGradient.frame = totalBounds
        backgroundGradient.gradCenter = CGPoint(x: totalBounds.midX, y: totalBounds.minY)
        vertexGradient.frame = CGRect(x: 0, y: 0, width: totalBounds.width, height: bounds.height * 2)
        
        let pnt = topPoint()
        let newPnt = vertexPoint()
        
        vertexGradient.position = newPnt
        
        backgroundGradient.setNeedsDisplay()
        vertexGradient.setNeedsDisplay()
        
        moveMark( markXPos )
        guard !points.isEmpty else {
            return
        }
        
        let finalPoints = correctedPoints()
        let partPoints = [finalPoints.first!, finalPoints[1]]
        let length = lengthLinearPath(partPoints)
        let totalLength = lengthLinearPath(finalPoints)
        
        plotLayer.strokeStart = length / totalLength
        
        let mainPath = createLinearPlotPath(finalPoints)
        plotLayer.path = mainPath.cgPath
        maskLayer.path = mainPath.cgPath
        
        if isItDebug {
            let pnts = correctedPoints()
            for (index,point) in pnts.enumerated() {
                let layer = pointLayers[index]
                layer.position = point
            }
        }
        
        let shadowPath = mainPath
        shadowPath.append(createShadowPath())
        shadowPath.close()
        
        plotLayer.shadowPath = shadowPath.cgPath
    }
    
    func moveMark(_ xValue: CGFloat) {
        let points = correctedPoints()
        
        guard !points.isEmpty else {
            return
        }
        
        var newPoints = [CGPoint]()
        
        var lastIndex = 0
        for (index,point) in points.enumerated() {
            if point.x > xValue || index == points.count - 1 {
                break
            }
            lastIndex = index
            newPoints.append( point )
        }
        
        guard !newPoints.isEmpty else {
            return
        }
        
        var correctedPoint = CGPoint.zero
        
        let startBoundPoint = points[1]
        let endBoundPoint   = points[points.count - 2]
        
        
        if xValue < startBoundPoint.x {
            correctedPoint = startBoundPoint
        } else if xValue > endBoundPoint.x {
            correctedPoint = endBoundPoint
        } else {
            let nextPoint = points[lastIndex+1]
            let lastPoint = newPoints.last!
            let multiplierY = (xValue - lastPoint.x) / (nextPoint.x - lastPoint.x)
            
            correctedPoint = pointBetween(lastPoint, p2: nextPoint, progress: multiplierY)
        }
        
        
        newPoints.append( correctedPoint )
        
        let newLength = lengthLinearPath(newPoints)
        let totalLength = lengthLinearPath(points)
        
        let colorCoefficient:CGFloat = 1 - (correctedPoint.y / lengthPerYPoint / totalRelativeHeight)
        
        let topColor = lowColor!.interpolateToColor(highColor!, fraction: colorCoefficient)
        let colors = [topColor.cgColor, topColor.darkColor().cgColor]
        
        let strokeProgress = newLength / totalLength
        // correction according to top shift
        correctedPoint.y += correctedBounds.origin.y
        CATransaction.begin()
        CATransaction.setDisableActions( true )
        plotLayer.shadowColor = topColor.cgColor
        backgroundGradient.gradColors = colors
        backgroundGradient.setNeedsDisplay()
        plotLayer.strokeEnd = strokeProgress
        markLayer.position = correctedPoint
        yIndicatorLayer.position = CGPoint(x: UIScreen.main.bounds.width / 2, y: correctedPoint.y)
        print(markLayer.position)
        
        CATransaction.commit()
    }
    
    func showYIndicator() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.yIndicatorLayer.isHidden = false
        }
    }
    
    func hideYIndicator() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.yIndicatorLayer.isHidden = true
        }
        
    }
    
    func createShadowPath() -> UIBezierPath {
        let corrPoints: [CGPoint] = correctedPoints().map { point -> CGPoint in
            var newPoint = point
            newPoint.y += 4
            return newPoint
            }.reversed()
        
        let path = createLinearPlotPath( corrPoints )
        return path
    }
    
    func createGlowAnimation() -> CAAnimation {
        let glowAnim = CABasicAnimation(keyPath: "shadowRadius")
        glowAnim.fromValue = 3
        glowAnim.toValue   = 6
        
        let shadowPathAnim = CABasicAnimation(keyPath: "shadowPath")
        shadowPathAnim.fromValue = UIBezierPath(ovalIn: markLayer.bounds).cgPath
        shadowPathAnim.toValue = UIBezierPath(ovalIn: markLayer.bounds.insetBy(dx: -6, dy: -6)).cgPath
        
        let groupAnim = CAAnimationGroup()
        groupAnim.animations = [shadowPathAnim, glowAnim]
        groupAnim.duration  = 0.8
        groupAnim.repeatCount = Float.infinity
        groupAnim.fillMode  = kCAFillModeBackwards
        groupAnim.autoreverses = true
        
        return groupAnim
    }
    
    func vertexPoint() -> CGPoint {
        
        let point = topPoint()
        let gradFrame = backgroundGradient.frame
        
        let horizontalPercent: CGFloat = 0.08
        let verticalPercent: CGFloat   = 0.05
        
        let xPercentOffset = gradFrame.width * horizontalPercent
        let yPercentOffset = gradFrame.height * verticalPercent
        
        if point.x < gradFrame.midX {
            return CGPoint(x: point.x + xPercentOffset, y: point.y + yPercentOffset)
        } else {
            return CGPoint(x: point.x - xPercentOffset, y: point.y - yPercentOffset)
        }
        
    }
    
    func topPoint() -> CGPoint {
        
        guard !points.isEmpty else {
            return CGPoint.zero
        }
        
        var topPoint: CGPoint!
        topPoint = points.first
        for point in points {
            if topPoint.y > point.y {
                topPoint = point
            }
        }
        return CGPoint(x: topPoint.x * lengthPerXPoint, y: topPoint.y * lengthPerYPoint)
    }
    
    // logic for total layout on scroll view
    func correctedPoints() -> [CGPoint] {
        
        guard !points.isEmpty else {
            return points
        }
        
        let deltaX = lengthPerXPoint
        let deltaY = lengthPerYPoint
        
        // converting to real coordinates on the view
        var correctedPoints: [CGPoint] = points.map {
            var point = CGPoint(x: $0.x, y: $0.y)
            
            //
            if !isVerticalAxisInversed {
                point.y = 10 - point.y
            }
            
            point.x *= deltaX
            point.y *= deltaY
            return point
        }
        
        var firstPoint = correctedPoints.first!
        var lastPoint  = correctedPoints.last!
        
        firstPoint.x -= 1
        firstPoint.y = bounds.height + 1
        
        lastPoint.x += 1
        lastPoint.y = bounds.height + 1
        
        correctedPoints.insert(firstPoint, at: 0)
        correctedPoints.append(lastPoint)
        return correctedPoints
    }
}

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
