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

public class CRPlotView: UIView {
    /// allows to make curve bezier between points to make smooth lines
    public var approximateMode = false
    
    /// points count of points that will be created between two relative points
    public var approximateAccuracy = 30

    /// total relative length for plot scene
    public var totalRelativeLength:CGFloat = 1
    
    /// start relative offset by x axes
    public var startRelativeX:CGFloat  = 0
    
    /// total relative height for plot scene
    public var totalRelativeHeight: CGFloat = 1
    
    //TODO: add doc and usage for the vertical axis
    public var isVerticalAxisInversed = false
    
    /// visible relative length that will be showed in view
    public var visibleLength:CGFloat = 1 {
        didSet {
            print( visibleLength )
            if visibleLength > totalRelativeLength {
                visibleLength = totalRelativeLength
            }
            
            if let maxZoom = maxZoomScale
            where visibleLength < totalRelativeLength / maxZoom {
                visibleLength = totalRelativeLength / maxZoom
            }
            
            updatePlot()
        }
    }
    
    /// will hide mark
    public var markHidden: Bool {
        set {
            markLayer.hidden = newValue
        }
        get {
            return markLayer.hidden
        }
    }
    
    /// background color will apply by interpolating between high and low colors, depend on *markRelativePosition*
    public var highColor: UIColor?
    public var lowColor: UIColor?
    
    
    public var maxZoomScale: CGFloat?
    public var edgeInsets = UIEdgeInsetsMake(22, 0, 0, 0)
    var markXPos: CGFloat {
        get {
            return markRelativePos * lengthPerXPoint
        }
        set {
            markRelativePos = newValue / lengthPerXPoint
        }
    }
    
    public var markRelativePos: CGFloat = 0 {
        didSet {
            moveMark( markXPos )
        }
    }
    
    public var points = [CGPoint]() {
        didSet {
            points = points.sort{ $0.x < $1.x }
            
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
                    layer.bounds = CGRectMake(0, 0, 8, 8)
                    layer.cornerRadius = 4
                    layer.backgroundColor = UIColor.redColor().CGColor
                    layer.position = point
                    pointLayers.append( layer )
                    plotLayer.addSublayer( layer )
                }
            }
            updatePlot()
        }
    }
    
    var pointLayers = [CALayer]()
    
    private let plotLayer: PlotShapeLayer = {
        let layer = PlotShapeLayer()
        layer.strokeEnd = 0
        layer.strokeColor = UIColor.whiteColor().CGColor
        
        layer.lineWidth = 1
        layer.backgroundColor = UIColor.clearColor().CGColor
        layer.fillColor = UIColor.clearColor().CGColor
        layer.lineJoin = kCALineJoinRound

        layer.shadowRadius = 6
        layer.shadowColor = UIColor.whiteColor().CGColor
        layer.shadowOffset = CGSizeMake(0, -2)
        layer.shadowOpacity = 1
        
        return layer
    }()
    
    private let markLayer: CALayer = {
       let layer = CALayer()
        layer.frame = CGRectMake(0, 0, 10, 10)
        layer.cornerRadius = layer.bounds.midX
        layer.backgroundColor = UIColor.whiteColor().CGColor
        
        layer.shadowRadius = 6
        layer.shadowColor = UIColor.whiteColor().CGColor
        layer.shadowOffset = CGSizeMake(0, 0)
        layer.shadowOpacity = 1
        layer.shadowPath = UIBezierPath(ovalInRect: CGRectInset(layer.frame, -6, -6)).CGPath
        return layer
    }()
    
    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.bounces = false
        return view
    }()
    
    private let maskLayer: PlotShapeLayer = {
        let layer = PlotShapeLayer()
        layer.backgroundColor = UIColor.clearColor().CGColor
        return layer
    }()
    
    private var lengthPerYPoint: CGFloat {
        return correctedBounds.height / totalRelativeHeight
    }
    private var lengthPerXPoint: CGFloat {
        return correctedBounds.width / visibleLength
    }
    
    private var threshold: CGFloat {
        return startRelativeX + visibleLength
    }
    
    private var correctedBounds: CGRect {
        return CGRect(x: bounds.minX + edgeInsets.left,
                      y: bounds.minY + edgeInsets.top,
                      width: bounds.width - edgeInsets.left - edgeInsets.right,
                      height: bounds.height - edgeInsets.top - edgeInsets.bottom)
    }
    
    //MARK: - UIView
    override public func awakeFromNib() {
        super.awakeFromNib()
        layer.backgroundColor = UIColor.clearColor().CGColor
        
        layer.mask = maskLayer
//        gradientLayer.mask = maskLayer
        backgroundGradient.mask = maskLayer
//        plotLayer.masksToBounds = true
        
        updatePlot()
        
        addSubview( scrollView )
        scrollView.layer.addSublayer( backgroundGradient )
        scrollView.layer.addSublayer( plotLayer )
        scrollView.layer.addSublayer( markLayer )
        
        let glowAnimation = createGlowAnimation()
        markLayer.addAnimation(glowAnimation, forKey: "glowAnimation")
        
        vertexGradient.backgroundColor = UIColor.clearColor().CGColor
        backgroundGradient.addSublayer( vertexGradient )
        
        
    }

    let vertexGradient: RadialGradientLayer = {
        let colors = [UIColor.whiteColor().colorWithAlphaComponent(0.6).CGColor,
                      UIColor.whiteColor().colorWithAlphaComponent(0).CGColor]
       let gradient = RadialGradientLayer(colors: colors)
        gradient.gradColors = colors
        
        return gradient
    }()
    
    let backgroundGradient: RadialGradientLayer = {
        let gradient = RadialGradientLayer()
        gradient.gradLocations = [0.0, 1.0]
        return gradient
    }()
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updatePlot()
        
        scrollView.setContentOffset(CGPointMake(startRelativeX * lengthPerXPoint, 0), animated: false)
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
        backgroundGradient.gradCenter = CGPointMake(totalBounds.midX, totalBounds.minY)
        vertexGradient.frame = CGRectMake(0, 0, totalBounds.width, bounds.height * 2)
        
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
        plotLayer.path = mainPath.CGPath
        maskLayer.path = mainPath.CGPath
    
        if isItDebug {
            let pnts = correctedPoints()
            for (index,point) in pnts.enumerate() {
                let layer = pointLayers[index]
                layer.position = point
            }
        }

        let shadowPath = mainPath
        shadowPath.appendPath(createShadowPath())
        shadowPath.closePath()
        
        plotLayer.shadowPath = shadowPath.CGPath
    }
    
    func moveMark(xValue: CGFloat) {
        let points = correctedPoints()
        
        guard !points.isEmpty else {
            return
        }
        
        var newPoints = [CGPoint]()
        
        var lastIndex = 0
        for (index,point) in points.enumerate() {
            if point.x > xValue || index == points.count - 1 {
                break
            }
            lastIndex = index
            newPoints.append( point )
        }
        
        guard !newPoints.isEmpty else {
            return
        }
        
        var correctedPoint = CGPointZero
        
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
        let colors = [topColor.CGColor, topColor.darkColor().CGColor]
        
        let strokeProgress = newLength / totalLength
        // correction according to top shift
        correctedPoint.y += correctedBounds.origin.y
        CATransaction.begin()
        CATransaction.setDisableActions( true )
        plotLayer.shadowColor = topColor.CGColor
        backgroundGradient.gradColors = colors
        backgroundGradient.setNeedsDisplay()
        plotLayer.strokeEnd = strokeProgress
        markLayer.position = correctedPoint
        CATransaction.commit()
        
    }
    
    func createShadowPath() -> UIBezierPath {
        let corrPoints: [CGPoint] = correctedPoints().map { point -> CGPoint in
            var newPoint = point
            newPoint.y += 4
            return newPoint
        }.reverse()
        
        let path = createLinearPlotPath( corrPoints )
        return path
    }
    
    func createGlowAnimation() -> CAAnimation {
        let glowAnim = CABasicAnimation(keyPath: "shadowRadius")
        glowAnim.fromValue = 3
        glowAnim.toValue   = 6
        
        let shadowPathAnim = CABasicAnimation(keyPath: "shadowPath")
        shadowPathAnim.fromValue = UIBezierPath(ovalInRect: markLayer.bounds).CGPath
        shadowPathAnim.toValue = UIBezierPath(ovalInRect: CGRectInset(markLayer.bounds, -6, -6)).CGPath
        
        let groupAnim = CAAnimationGroup()
        groupAnim.animations = [shadowPathAnim, glowAnim]
        groupAnim.duration  = 0.8
        groupAnim.repeatCount = Float.infinity
        groupAnim.fillMode  = kCAFillModeBackwards
        groupAnim.autoreverses = true
        
        return groupAnim
    }
    
    func vertexPoint() -> CGPoint {
        
        var point = topPoint()
        let gradFrame = backgroundGradient.frame
        
        let horizontalPercent: CGFloat = 0.08
        let verticalPercent: CGFloat   = 0.05
        
        let xPercentOffset = gradFrame.width * horizontalPercent
        let yPercentOffset = gradFrame.height * verticalPercent
        
        if point.x < gradFrame.midX {
            return CGPointMake(point.x + xPercentOffset, point.y + yPercentOffset)
        } else {
            return CGPointMake(point.x - xPercentOffset, point.y - yPercentOffset)
        }
        
    }
    
    func topPoint() -> CGPoint {
        
        guard !points.isEmpty else {
            return CGPointZero
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
            var point = CGPointMake($0.x, $0.y)
            
            //
            if isVerticalAxisInversed {
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
        
        correctedPoints.insert(firstPoint, atIndex: 0)
        correctedPoints.append(lastPoint)
        return correctedPoints
    }
}



extension UIColor {
    func darkColor() -> UIColor{
        let c = CGColorGetComponents(self.CGColor)
        let r: CGFloat = max(c[0] - 0.2, 0) 
        let g: CGFloat = max(c[1] - 0.2, 0) 
        let b: CGFloat = max(c[2] - 0.2, 0)
        let a: CGFloat = c[3]
        return UIColor(red:r, green:g, blue:b, alpha:a)
    }
    
    func interpolateToColor(toColor: UIColor, fraction: CGFloat) -> UIColor {
        var f = max(0, fraction)
        f = min(1, fraction)
        
        let c1 = CGColorGetComponents(self.CGColor)
        let c2 = CGColorGetComponents(toColor.CGColor)
        
        let r: CGFloat = CGFloat(c1[0] + (c2[0] - c1[0]) * f)
        let g: CGFloat = CGFloat(c1[1] + (c2[1] - c1[1]) * f)
        let b: CGFloat = CGFloat(c1[2] + (c2[2] - c1[2]) * f)
        let a: CGFloat = CGFloat(c1[3] + (c2[3] - c1[3]) * f)
        
        return UIColor(red:r, green:g, blue:b, alpha:a)
    }
}



