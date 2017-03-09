//
//  CRPlotView.swift
//  CRPlotView
//
//  Created by Dmitry Pashinskiy on 5/26/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import UIKit


public protocol CRPlotViewDelegate{
    func numberOfPointsInPlotView(in plotView: CRPlotView) -> UInt
    func plotView(_ plotView: CRPlotView, pointAtIndex index: UInt) -> CGPoint
    func plotView(_ plotView: CRPlotView, didMoveMark point: CGPoint)
}


let lightBlueColor = UIColor(colorLiteralRed: 0/255, green: 176/255, blue: 255/255, alpha: 1.0)
let lightBlackColor = UIColor(colorLiteralRed: 100/255, green: 100/255, blue: 100/255, alpha: 1.0)

let isItDebug = false

open class CRPlotView: UIView {
    let markTrackingCurveOffset: CGFloat = 2
    /// allows to make curve bezier between points to make smooth lines
    open var approximateMode = true
    open var touchPoint = CGPoint()
    open var xMaxCoordinate = Float()
    open var xMinCoordinate = Float()
    open var i = Int()
    open var strokePointsArray = [CGPoint]()
    open var constraintForXPosition = NSLayoutConstraint()
    /// points count of points that will be created between two relative points
    open var approximateAccuracy = 30
    open var delegate: CRPlotViewDelegate?
    /// total relative length for plot scene
    open var totalRelativeLength:CGFloat = 1
    
    /// start relative offset by x axes
    open var startRelativeX:CGFloat  = 0
    
    /// total relative height for plot scene
    open var totalRelativeHeight: CGFloat = 1
    
    /// visible relative length that will be showed in view
    open var visibleLength:CGFloat = 1 {
        didSet {
            if visibleLength > totalRelativeLength {
                visibleLength = totalRelativeLength
            }
            
            if let maxZoom = maxZoomScale, visibleLength < totalRelativeLength / maxZoom {
                visibleLength = totalRelativeLength / maxZoom
            }
            updatePlotWithFocus()
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
    
    var markYPos: Int {
        return Int(round(totalRelativeHeight - (currentPoint.y - edgeInsets.top) / lengthPerYPoint + offsetCurveRelativeHeight))
    }
    
    open var markRelativePos: CGFloat = 0 {
        didSet {
            showXValueLabel()
            moveMark(markXPos)
        }
    }
    
    open var currentPoint: CGPoint {
        set {
            markLayer.position = newValue
        }
        get {
            return markLayer.position
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
    
    open var originalPoints = [CGPoint]() {
        didSet {
            originalPoints = originalPoints.sorted { $0.x < $1.x }
        }
    }
    
    //MARK: - Layers
    var pointLayers = [CALayer]()
  
    fileprivate let plotLayer: PlotShapeLayer = {
        let layer = PlotShapeLayer()
        layer.strokeColor = UIColor.clear.cgColor
        layer.lineWidth = 5
        layer.backgroundColor = UIColor.clear.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineJoin = kCALineJoinRound
        layer.shadowRadius = 6
        layer.shadowColor = UIColor.white.cgColor
        layer.shadowOffset = CGSize(width: 0, height: -2)
        layer.shadowOpacity = 1
        
        return layer
    }()

    fileprivate let offsetCurveGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [UIColor.clear.cgColor, UIColor.white.cgColor]
        layer.locations = [0.0, 1]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 0.75, y: 0)
        
        return layer
    }()
    
    fileprivate let offsetCurveMaskLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.backgroundColor = UIColor.clear.cgColor
        
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
        return correctedBounds.height / totalRelativeHeight - offsetCurveRelativeHeight
    }
    
    fileprivate var offsetCurveRelativeHeight: CGFloat {
        return markTrackingCurveOffset / (correctedBounds.height / totalRelativeHeight)
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
    
    fileprivate let vertexGradient: RadialGradientLayer = {
        let colors = [UIColor.white.withAlphaComponent(0.6).cgColor,
                      UIColor.white.withAlphaComponent(0).cgColor]
        let gradient = RadialGradientLayer(colors: colors)
        gradient.gradColors = colors
        
        return gradient
    }()
    
    fileprivate let backgroundGradient: RadialGradientLayer = {
        let gradient = RadialGradientLayer()
        gradient.gradLocations = [0.0, 1.0]
        return gradient
    }()
    
    fileprivate let yIndicatorLineLayer: CALayer = {
        let lineLayer = CALayer()
        lineLayer.backgroundColor = UIColor.white.cgColor
        lineLayer.opacity = 0.5
        lineLayer.isHidden = false
        
        return lineLayer
    }()
    
    fileprivate var focusPoint: CGPoint = CGPoint.zero
    
    //MARK: - Indication
    fileprivate let yPositionLabel: UILabel = {
        let positionLabel = UILabel(frame: CGRect(x: 0, y:0, width: 30, height: 30))
        positionLabel.textAlignment = .center
        positionLabel.textColor = UIColor.white
        
        return positionLabel
    }()
    
    fileprivate let yIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        
        return view
    }()
    
    fileprivate let xPositionMaxLabel = UILabel()
    fileprivate let xPositionMinLabel = UILabel()
    fileprivate let xPositionNowLabel = UILabel()
    
    //MARK: - Life Cycle
    override open func awakeFromNib() {
        super.awakeFromNib()
        addSubview(scrollView)
        setupPlotLayers()
        setupGestureRecognizers()
        setupStatusLabels()
        updatePlot()
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        updatePlot()
        updateYIndicationView()
        showXValueLabel()
        scrollView.setContentOffset(CGPoint(x: startRelativeX * lengthPerXPoint, y: 0), animated: false)
    }
    
    //MARK: - Actions
    func panGestureRecognizerAction(_ sender: UIPanGestureRecognizer) -> Void {
        let newMarkXPos = sender.translation(in: self).x + markXPos
        moveMark(newMarkXPos)
      
        if sender.state == .began {
            hideXValueLabel()
        }
        
        if sender.state == UIGestureRecognizerState.changed {
            currectPointStroke = currentPoint
            delegate?.plotView(self, didMoveMark: CGPoint(x: newMarkXPos / lengthPerXPoint, y: CGFloat(markYPos)))
            updateYIndicationView()
        }

        if sender.state == UIGestureRecognizerState.ended {
            markXPos = newMarkXPos
            showXValueLabel()
        }
    }
    
    func pinchGestureRecognizerAction(_ sender: UIPinchGestureRecognizer) {
        if sender.state == .began {
            touchPoint = sender.location(in: scrollView)
        }
        if sender.state == .changed {
            let currentScale = scrollView.contentSize.width / correctedBounds.width
            let centeredPinchLocation = CGPoint(x: touchPoint.x * currentScale - correctedBounds.midX, y: 0)
            zoomPlot(with: sender.scale, at: centeredPinchLocation)
            sender.scale = 1
        }
    }
}

//MARK: - API
public extension CRPlotView {
    func zoomPlot(with scale: CGFloat, at point: CGPoint) {
        let length = visibleLength * 1 / scale
        let relativeLength = max(min(length, self.totalRelativeLength), self.totalRelativeLength / self.maxZoomScale!)
        focusPoint = point
        CATransaction.begin()
        CATransaction.setDisableActions( true )
        visibleLength = relativeLength
        CATransaction.commit()
    }
    
    func reloadData() {
        guard let delegate = delegate else {
            return
        }
        
        var result = [CGPoint]()
        var count = Int(delegate.numberOfPointsInPlotView(in: self))
        for index in 0..<Int(count) {
            result.append(delegate.plotView(self, pointAtIndex: UInt(index)))
        }
        
        if let firstPoint = result.first, let lastPoint = result.last {
            xPositionMinLabel.text = ("\(firstPoint.x)")
            xPositionMaxLabel.text = ("\(lastPoint.x)")
        }

        points = result
        originalPoints = result
    }
    
    func updateCurrentPoint(with value: Float) {
        let newPoint = CGPoint(x: markRelativePos, y: CGFloat(value))
    
        var foundedIndex = -1
        for (index,point) in originalPoints.enumerated() {
            if (newPoint.x - 1)...(newPoint.x + 1) ~= point.x {
                foundedIndex = index
                break
            }
        }
        
        if foundedIndex == -1 {
            originalPoints.append(newPoint)
        } else {
            let correctedPoint = CGPoint(x: originalPoints[foundedIndex].x, y: newPoint.y)
            originalPoints[foundedIndex] = correctedPoint
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        points = originalPoints
        CATransaction.commit()
    }
    
    func moveMarkToNextPoint() {
        let pointsGreaterThenCurrent = originalPoints.filter { $0.x > markRelativePos }
        
        guard let nextRelativePoint = pointsGreaterThenCurrent.first else {
            return
        }
        
        let movingPoints = correctedPoints().filter { $0.x > markXPos && $0.x < nextRelativePoint.x * lengthPerXPoint }
        
        for movePoint in movingPoints {
            moveMark(movePoint.x)
        }
        
        markRelativePos = nextRelativePoint.x
    }
    
    func moveMarkToPreviousPoint() {
        let pointsLessThenCurrent = originalPoints.filter { $0.x < markRelativePos }
        
        guard let previousRelativePoint = pointsLessThenCurrent.last else {
            return
        }
        
        let movingPoints = correctedPoints().filter { $0.x < markXPos && $0.x > previousRelativePoint.x * lengthPerXPoint }.reversed()
        
        for movePoint in movingPoints {
            moveMark(movePoint.x)
        }
        
        markRelativePos = previousRelativePoint.x
    }
}

//MARK: - Setup
private extension CRPlotView {
    func setupPlotLayers() {
        layer.backgroundColor = UIColor.clear.cgColor
        layer.mask = maskLayer
        backgroundGradient.mask = maskLayer
        scrollView.layer.addSublayer(offsetCurveGradientLayer)
        scrollView.layer.addSublayer(backgroundGradient)
        scrollView.layer.addSublayer(plotLayer)
        scrollView.layer.addSublayer(markLayer)
        let glowAnimation = createGlowAnimation()
        markLayer.add(glowAnimation, forKey: "glowAnimation")
        vertexGradient.backgroundColor = UIColor.clear.cgColor
        backgroundGradient.addSublayer(vertexGradient)
        setupYInicationView()
    }
    
    func setupYInicationView() {
        addSubview(yIndicatorView)
        updateYIndicationView()
        yIndicatorView.addSubview(yPositionLabel)
        yIndicatorView.layer.addSublayer(yIndicatorLineLayer)
    }
    
    func setupGestureRecognizers() {
        let zoomPinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinchGestureRecognizerAction(_:)))
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognizerAction(_:)))
        addGestureRecognizer(panGesture)
        addGestureRecognizer(zoomPinchGesture)
    }
    
    func setupStatusLabels() {
        addSubview(xPositionMaxLabel)
        addSubview(xPositionMinLabel)
        addSubview(xPositionNowLabel)
        
        var labels: [UILabel] = [xPositionMaxLabel, xPositionMinLabel, xPositionNowLabel]
        for label in labels {
            label.textColor = UIColor.white.withAlphaComponent(0.5)
            label.textAlignment = NSTextAlignment.center
            label.font = UIFont.systemFont(ofSize: 12)
            label.translatesAutoresizingMaskIntoConstraints = false
        }
        
        setupMaxXLabelConstraints()
        setupMinXLabelConstraints()
        setupCurrentXLabelConstraints()
    }
    
    func setupMaxXLabelConstraints() {
        let maxTrailingConstraint = NSLayoutConstraint(item: xPositionMaxLabel, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: 0)
        let maxBottomConstraint = NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: xPositionMaxLabel, attribute: .bottom, multiplier: 1, constant: 0)
        let maxWidthConstraint = NSLayoutConstraint(item: xPositionMaxLabel, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 40)
        let maxHeightConstraint = NSLayoutConstraint(item: xPositionMaxLabel, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 30)
        
        addConstraints([ maxWidthConstraint, maxBottomConstraint, maxHeightConstraint, maxTrailingConstraint])
    }
    
    func setupMinXLabelConstraints() {
        let minLeadingConstraint = NSLayoutConstraint(item: xPositionMinLabel, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 0)
        let minBottomConstraint = NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: xPositionMinLabel, attribute: .bottom, multiplier: 1, constant: 0)
        let minWidthConstraint = NSLayoutConstraint(item: xPositionMinLabel, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 40)
        let minHeightConstraint = NSLayoutConstraint(item: xPositionMinLabel, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 30)
        
        addConstraints([ minWidthConstraint, minBottomConstraint, minLeadingConstraint, minHeightConstraint])
    }
    
    func setupCurrentXLabelConstraints() {
        var nowCenterYConstraint = NSLayoutConstraint(item: xPositionNowLabel, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant:0)
        constraintForXPosition = nowCenterYConstraint
        let nowBottomConstraint = NSLayoutConstraint(item: xPositionNowLabel, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0)
        let nowWidthConstraint = NSLayoutConstraint(item: xPositionNowLabel, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 45)
        let nowHeightConstraint = NSLayoutConstraint(item: xPositionNowLabel, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 30)
        
        addConstraints([nowCenterYConstraint, nowBottomConstraint, nowWidthConstraint, nowHeightConstraint])
    }
}

//MARK: - Private Methods
private extension CRPlotView {
    func updateYIndicationView() {
        let yPositionString = "\(markYPos)"
        yIndicatorView.frame = CGRect(x: 0, y: 0, width: correctedBounds.width, height: yPositionLabel.bounds.width)
        yIndicatorLineLayer.frame = CGRect(x: yPositionLabel.bounds.width, y: yIndicatorView.bounds.midY, width: correctedBounds.width - yPositionLabel.bounds.width, height: 1)
        yPositionLabel.text = yPositionString
        yIndicatorView.center = CGPoint(x: correctedBounds.width / 2, y: currentPoint.y)
    }
    
    func hideXValueLabel() {
        UIView.animate(withDuration: 0.3) {
            self.xPositionNowLabel.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        }
    }
    
    func showXValueLabel() {
        xPositionNowLabel.text = "\(Int(round(markRelativePos)))"
        xPositionNowLabel.isHidden = false
        if xPositionNowLabel.layer.frame.intersects(xPositionMinLabel.layer.frame) || xPositionNowLabel.layer.frame.intersects(xPositionMaxLabel.layer.frame) {
            xPositionNowLabel.isHidden = true
        }
        constraintForXPosition.constant = markLayer.position.x - markLayer.frame.width*2
        
        UIView.animate(withDuration: 0.3) { 
            self.xPositionNowLabel.transform = CGAffineTransform.identity
        }
    }
    
    func updatePlotWithFocus() {
        scrollView.setContentOffset(CGPoint(x: focusPoint.x, y: 0), animated: false)
        updatePlot()
    }
    
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
        
        newPoints.append(correctedPoint)
        
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
        updateYIndicationView()
        updateOffsetCurve(for: newPoints)
        CATransaction.commit()
    }
    
    func updateOffsetCurve(for points: [CGPoint]) {
        var offsetMaskPath = offsetCurvePath(with: points, offset: markTrackingCurveOffset).cgPath
        let color1 = UIColor.clear.cgColor
        let color2 = UIColor.white.cgColor
        offsetCurveGradientLayer.colors = [color1 as AnyObject, color2 as AnyObject]
        offsetCurveGradientLayer.frame = CGRect(origin: correctedBounds.origin, size: CGSize(width: currentPoint.x, height: correctedBounds.height))
        offsetCurveMaskLayer.path = offsetMaskPath
        offsetCurveGradientLayer.mask = offsetCurveMaskLayer
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
  
    func offsetCurvePath(with originPoints: [CGPoint], offset: CGFloat) -> UIBezierPath {
      var offsetPoints = [CGPoint]()
      for pointIndex in 0..<originPoints.count - 1 {
            let firstPoint = originPoints[pointIndex]
            let secondPoint = originPoints[pointIndex + 1]
            
            let deltaX = secondPoint.x - firstPoint.x
            let deltaY = secondPoint.y - firstPoint.y
            
            let angleTng = deltaY / deltaX
            let angle = atan(angleTng)
            let offsetRotationAngle = angle + 90
            
            let offsetPointX = firstPoint.x - offset * cos(offsetRotationAngle)
            let offsetPointY = firstPoint.y - offset * sin(offsetRotationAngle)
            
            let offsetPoint = CGPoint(x: offsetPointX, y: offsetPointY)
            
            offsetPoints.append(offsetPoint)
      }
        
      let reversedOrignPoints = originPoints.reversed()
      offsetPoints.append(contentsOf: reversedOrignPoints)
      offsetPoints = offsetPoints.filter({$0.x <= currentPoint.x + markTrackingCurveOffset})
        
      let offsetPath = createLinearPlotPath(offsetPoints)
        
      return offsetPath
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
            var point = CGPoint(x: $0.x, y: $0.y - markTrackingCurveOffset / deltaY)
            point.y = totalRelativeHeight - point.y
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
