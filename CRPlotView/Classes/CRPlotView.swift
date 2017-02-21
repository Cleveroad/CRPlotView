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
    func markLayerMoved(plotView: CRPlotView, with zoomScale: CGFloat)
    func plotView(plotView: CRPlotView, titleForVerticalAxisValue value: Float) -> String?
    func plotView (plotView: CRPlotView, titleForHorizontalAxisValue value: Float) -> String?
}


let lightBlueColor = UIColor(colorLiteralRed: 0/255, green: 176/255, blue: 255/255, alpha: 1.0)
let lightBlackColor = UIColor(colorLiteralRed: 100/255, green: 100/255, blue: 100/255, alpha: 1.0)

let isItDebug = false

open class CRPlotView: UIView, UIScrollViewDelegate {
    /// allows to make curve bezier between points to make smooth lines
    let strokeLayer = CAShapeLayer()
    let strokeGradient = CAGradientLayer()

    open var approximateMode = false
    open var touchPoint = CGPoint()
    open var xMaxCoordinate = Float()
    open var xMinCoordinate = Float()
    open var i = Int()
    open var strokePointsArray = [CGPoint]()
    open var result = [CGPoint]()
    open var constraintForXPosition = NSLayoutConstraint()
    /// points count of points that will be created between two relative points
    open var approximateAccuracy = 30
    open var delegate : CRPlotViewDelegate?
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
    
    fileprivate let yPositionTextLayer = CATextLayer()
    fileprivate let xPositionMaxLabel = UILabel()
    fileprivate let xPositionMinLabel = UILabel()
    fileprivate let xPositionNowLabel = UILabel()

   
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
    
    fileprivate var focusPoint: CGPoint = CGPoint.zero
    
    open func reloadData() {
        delegate?.numberOfPointsInPlotView(in: self)
        var result = [CGPoint]()
        var count = Int((delegate?.numberOfPointsInPlotView(in: self))!)
        var i = UInt()
        for i in 0..<Int(count) {
            result.append((delegate?.plotView(self, pointAtIndex: UInt(i)))!)
        }
        scrollView.delegate = self
        xPositionMinLabel.text = ("\(result.first!.x)")
        xPositionMaxLabel.text = ("\(result.last!.x)")
        self.points = result
        self.result = result
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
        yIndicatorLayer.addSublayer( yPositionTextLayer )
        let glowAnimation = createGlowAnimation()
        markLayer.add(glowAnimation, forKey: "glowAnimation")
        
        vertexGradient.backgroundColor = UIColor.clear.cgColor
        backgroundGradient.addSublayer( vertexGradient )
        let zoomPinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinchGestureRecognizerAction(_:)))
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognizer))
        self.addGestureRecognizer(panGesture)
        self.addGestureRecognizer(zoomPinchGesture)
        self.addSubview(xPositionMaxLabel)
        self.addSubview(xPositionMinLabel)
        self.addSubview(xPositionNowLabel)
      
        self.addLabels()
    }
    
    func panGestureRecognizer(_ sender: UIPanGestureRecognizer) -> Void {
        if sender.state == UIGestureRecognizerState.began {
            xPositionNowLabel .isHidden = true
            showYIndicator()
            self.reloadValuesOnXYAxis()
        }
        
        let newMarkXPos = sender.translation(in: self).x + markXPos
        moveMark(newMarkXPos)
      
        if sender.state == UIGestureRecognizerState.changed {
          self.delegate?.markLayerMoved(plotView: self, with: scrollView.contentSize.width)
//            currectPointStroke = currentPoint
//            for xCor in self.result{
//              if (Int(markRelativePos) == Int(xCor.x)) {
//                //xPositionNowLabel.isHidden = false
//                // xPositionNowLabel.text = ("\(Int(xCor.x))")
//                //print(xCor.y)
//                yPositionTextLayer.string = String(describing: xCor.y)
//              }
//            }
        }

      
        if sender.state == UIGestureRecognizerState.ended {
            markXPos = newMarkXPos
            showYIndicator()
            self.reloadValuesOnXYAxis()
      }
    }
    
    func pinchGestureRecognizerAction(_ sender: UIPinchGestureRecognizer) {
        if sender.state == .began {
            touchPoint = sender.location(in: self)
        }
        if sender.state == .changed {
            let currentScale = scrollView.contentSize.width / correctedBounds.width
            print(currentScale)
            let pinchLocation = sender.location(in: self)
            let centeredPinchLocation = CGPoint(x: touchPoint.x * currentScale - correctedBounds.midX, y: 0)
            zoomPlot(with: sender.scale, at: centeredPinchLocation)
            sender.scale = 1
        }
    }
  
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    yIndicatorLayer.frame = CGRect(x: 0, y: markLayer.position.y, width: scrollView.contentSize.width, height: 1)
    yPositionTextLayer.frame = CGRect(x: scrollView.contentOffset.x, y:-yPositionTextLayer.frame.height/2, width: 50, height: 50)
    var pathNew = createStrokePlotPath(points).cgPath
    strokeLayer.path = pathNew
    strokeGradient.mask = strokeLayer

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
        lineLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1)
        lineLayer.backgroundColor = UIColor.white.cgColor
        lineLayer.opacity = 0.5
        lineLayer.isHidden = false
        
        return lineLayer
        
    }()
    
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        updatePlot()
        addStroketoPoints(points: points)
        scrollView.setContentOffset(CGPoint(x: startRelativeX * lengthPerXPoint, y: 0), animated: false)
    }
    
    open func zoomPlot(with scale: CGFloat, at point: CGPoint) {
        let length = visibleLength * 1 / scale
        let relativeLength = max(min(length, self.totalRelativeLength), self.totalRelativeLength / self.maxZoomScale!)
        focusPoint = point
        CATransaction.begin()
        CATransaction.setDisableActions( true )
        visibleLength = relativeLength
        CATransaction.commit()
    }
}

//MARK: - Private Methods
private extension CRPlotView {
    
    func addLabels() {
        var labels: [UILabel] = [xPositionMaxLabel, xPositionMinLabel, xPositionNowLabel]
            for label in labels {
            label.textColor = UIColor.white.withAlphaComponent(0.5)
            label.textAlignment = NSTextAlignment .center
            label.font = UIFont.systemFont(ofSize: 12)
            label.translatesAutoresizingMaskIntoConstraints = false
        }

        let maxTrailingConstraint = NSLayoutConstraint(item: xPositionMaxLabel, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: 0)
        let maxBottomConstraint = NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: xPositionMaxLabel, attribute: .bottom, multiplier: 1, constant: 0)
        let maxWidthConstraint = NSLayoutConstraint(item: xPositionMaxLabel, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 40)
        let maxHeightConstraint = NSLayoutConstraint(item: xPositionMaxLabel, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 30)
        self.addConstraints([ maxWidthConstraint, maxBottomConstraint, maxHeightConstraint, maxTrailingConstraint])
        
        let minLeadingConstraint = NSLayoutConstraint(item: xPositionMinLabel, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 0)
        let minBottomConstraint = NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: xPositionMinLabel, attribute: .bottom, multiplier: 1, constant: 0)
        let minWidthConstraint = NSLayoutConstraint(item: xPositionMinLabel, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 40)
        let minHeightConstraint = NSLayoutConstraint(item: xPositionMinLabel, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 30)
        self.addConstraints([ minWidthConstraint, minBottomConstraint, minLeadingConstraint, minHeightConstraint])
        
         var nowCenterYConstraint = NSLayoutConstraint(item: xPositionNowLabel, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant:0)
        constraintForXPosition = nowCenterYConstraint
        let nowBottomConstraint = NSLayoutConstraint(item: xPositionNowLabel, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0)
        let nowWidthConstraint = NSLayoutConstraint(item: xPositionNowLabel, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 45)
        let nowHeightConstraint = NSLayoutConstraint(item: xPositionNowLabel, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 30)
        self.addConstraints([nowCenterYConstraint, nowBottomConstraint, nowWidthConstraint, nowHeightConstraint])
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.respondToLeftSwipeGesture), name: NSNotification.Name(rawValue: "LeftSwipe"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.respondToRightSwipeGesture), name: NSNotification.Name(rawValue: "RightSwipe"), object: nil)
    }
  
  func addStroketoPoints(points :[CGPoint]) {
    let color1 = UIColor.white.cgColor
    let color2 = UIColor.clear.cgColor
    strokeGradient.colors = [color1 as AnyObject, color2 as AnyObject]
    strokeGradient.startPoint = CGPoint(x: (currentPoint.x/layer.frame.width), y: 0.0)
    strokeGradient.endPoint = CGPoint(x: (currentPoint.x/layer.frame.width)-0.6, y: 0.0)
    strokeGradient.frame = bounds
    plotLayer.addSublayer(strokeGradient)
  }
    
  func culculatePointsfromCoordinate(coordinate :CGFloat) {
    for xCor in self.points{
            if ((xCor.x) <= coordinate) && ((xCor.x) >= markRelativePos)  {

        var ind = Int()
        ind = self.points.index(of: xCor)!
              //var strokePointsArray = [CGPoint]()
              
            //i = 0
             
               //  strokePointsArray[i] = points[ind]
                strokePointsArray .insert(xCor, at: Int(self.i))
               i += 1
            // strokePointsArray .append(xCor)
             //strokePointsArray .append(contentsOf: [points[ind]])
              
      }
    }
  }
    ///Search nearest point for given point if there no such point, creates it.
//    func point(at point: CGPoint) -> CGPoint {
//        let newPoint = CGPoint(x: plotView.markRelativePos, y: CGFloat(sender.value))
//        
//        var foundedIndex = -1
//        for (index,point) in points.enumerated() {
//            if (newPoint.x - 1)...(newPoint.x + 1) ~= point.x {
//                foundedIndex = index
//                break
//            }
//        }
//        
//        if foundedIndex == -1 {
//            points.append( newPoint )
//        } else {
//            let correctedPoint = CGPoint(x: points[foundedIndex].x, y: newPoint.y)
//            points[foundedIndex] = correctedPoint
//        }
//    }
    
    @objc func respondToLeftSwipeGesture() {
        for xCor in self.result{
            if (Int(markRelativePos) < Int(xCor.x)) {
              culculatePointsfromCoordinate(coordinate: CGFloat(xCor.x))
                self.setMarkPositionX(xPosition: xCor.x)
              
                self.reloadValuesOnXYAxis()
                self.delegate?.markLayerMoved(plotView: self, with: scrollView.contentSize.width)
                break
            }
        }
    }
    
    @objc func respondToRightSwipeGesture() {
        for xCor in self.result{
            if (Int(markRelativePos) <= Int(xCor.x)) {
                var ind = Int()
                 ind = self.result.index(of: xCor)!
                if ind == 0 {
                    self.setMarkPositionX(xPosition: self.result[ind].x)
                } else {
                   self.setMarkPositionX(xPosition: self.result[ind-1].x)
                }
                self.reloadValuesOnXYAxis()
                self.delegate?.markLayerMoved(plotView: self, with: scrollView.contentSize.width)
                break
            }
      }
  }
    
    func setMarkPositionX(xPosition: CGFloat ) {
        UIView.animate(withDuration: 0.5) {
            self.markLayer.frame = CGRect(x: 0, y:0, width: 10, height: 10)
             self.plotLayer.strokeEnd = xPosition
            self.markRelativePos = xPosition
          
          let animation = CAKeyframeAnimation()
          
          animation.keyPath = "position"
          animation.repeatCount = 0
          animation.duration = 3.0
          //animation.calculationMode = kCAAnimationLinear
          animation.path = self.plotLayer.path
          // animation.values = [CGPoint(x: 10, y: 10), CGPoint(x: 150, y: 32), CGPoint(x: 270, y: 0)]
          animation.values = self.strokePointsArray
          //animation.keyTimes = [0, 0.5, 1]
         // self.markLayer.add(animation, forKey: nil)
         // print(self.currentPoint.x / self.lengthPerXPoint)
        }
    }
    
    func reloadValuesOnXYAxis() {
      //var pathNew = createStrokePlotPath(points).cgPath
     // strokeLayer.path = pathNew
      //strokeGradient.mask = strokeLayer
      
      //currectPointStroke = currentPoint
        for xCor in self.points{
            if (Int(markRelativePos) == Int(xCor.x)) {
              
                xPositionNowLabel.isHidden = false
                xPositionNowLabel.text = ("\(Int(xCor.x))")
                yPositionTextLayer.string = String(describing: Int(xCor.y))
            }
        }
        for xCor in self.result{
            if (Int(markRelativePos) == Int(xCor.x)) {
                xPositionNowLabel.isHidden = false
                xPositionNowLabel.text = ("\(Int(xCor.x))")
                yPositionTextLayer.string = String(describing: Int(xCor.y))
                print("extrem")
            }
        }
        if xPositionNowLabel.layer.frame.intersects(xPositionMinLabel.layer.frame) || xPositionNowLabel.layer.frame.intersects(xPositionMaxLabel.layer.frame) {
            xPositionNowLabel.isHidden = true
        }
      if scrollView.contentSize.width / correctedBounds.width == 1 {
        constraintForXPosition.constant = markLayer.position.x - markLayer.frame.width*2
      } else {
       // constraintForXPosition.constant = (scrollView.contentSize.width * (markLayer.position.x - markLayer.frame.width*2)) / correctedBounds.width
        //constraintForXPosition.constant = (markLayer.position.x - markLayer.frame.width*2) / (scrollView.contentSize.width / correctedBounds.width)
      }
    }
    
    func updatePlotWithFocus() {
        scrollView.contentOffset = CGPoint(x: focusPoint.x, y: 0)
        updatePlot()
    }
    
    func updatePlot() {
      
        let size = CGSize(width: lengthPerXPoint * totalRelativeLength, height: correctedBounds.height)
        let totalBounds = CGRect(origin: correctedBounds.origin,
                                 size: size)
        scrollView.frame = bounds
        scrollView.contentSize = CGSize(width: lengthPerXPoint * totalRelativeLength, height: bounds.height)
        yIndicatorLayer.frame = CGRect(x: 0, y: markLayer.position.y, width: scrollView.contentSize.width, height: 1)
        yPositionTextLayer.frame = CGRect(x: scrollView.contentOffset.x, y:-yPositionTextLayer.frame.height/2, width: 50, height: 50)
      
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

        var pathNew = createStrokePlotPath(points).cgPath
        strokeLayer.path = pathNew
        strokeGradient.mask = strokeLayer
        currectPointStroke = currentPoint
        // correction according to top shift
        correctedPoint.y += correctedBounds.origin.y
        CATransaction.begin()
        CATransaction.setDisableActions( true )
        plotLayer.shadowColor = topColor.cgColor
        backgroundGradient.gradColors = colors
        backgroundGradient.setNeedsDisplay()
        plotLayer.strokeEnd = strokeProgress
        
        markLayer.position = correctedPoint
        yIndicatorLayer.frame = CGRect(x: scrollView.contentOffset.x, y: markLayer.position.y, width: UIScreen.main.bounds.width, height: 1)
        yPositionTextLayer.frame = CGRect(x: 0, y:-yPositionTextLayer.frame.height/2, width: 50, height: 50)
      
        yPositionTextLayer.fontSize = 20
        yPositionTextLayer.foregroundColor = UIColor.white.cgColor
      
        //yPositionTextLayer.string = String(describing: markLayer.position.y / lengthPerYPoint)
        CATransaction.commit()
    }
    
    func showYIndicator() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.yIndicatorLayer.isHidden = false
            self.setNeedsDisplay()
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
