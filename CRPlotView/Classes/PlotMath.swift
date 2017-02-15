//
//  CRPlotMath.swift
//  CRPlotView
//
//  Created by Dmitry Pashinskiy on 5/31/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

public var currectPointStroke = CGPoint()

func distance(_ p1: CGPoint, p2: CGPoint) -> CGFloat {
    let dx = p2.x - p1.x;
    let dy = p2.y - p1.y;
    return sqrt(dx*dx + dy*dy);
}

func pointBetween(_ p1: CGPoint, p2: CGPoint, progress: CGFloat) -> CGPoint {
    let x = p1.x + (p2.x - p1.x) * progress
    let y = p1.y + (p2.y - p1.y) * progress
    return CGPoint(x: x, y: y)
}



//MARK: - For Linear Behaviour
func lengthLinearPath(_ points:[CGPoint]) -> CGFloat {
    var length: CGFloat = 0
    guard !points.isEmpty else {
        return length
    }
    
    var prevPoint = points.first!
    for i in 0..<points.count {
        length += distance(prevPoint, p2: points[i])
        prevPoint = points[i]
    }
    return length
}

func createLinearPlotPath(_ points: [CGPoint]) -> UIBezierPath{
    let path = UIBezierPath()
    guard !points.isEmpty else {
        return path
    }
    
    path.move(to: points.first!)
    
    for i in 1..<points.count {
        path.addLine( to: points[i] )
    }
    
    return path
}

func createStrokePlotPath(_ points: [CGPoint]) -> UIBezierPath{
  let path = UIBezierPath()
  guard !points.isEmpty else {
    return path
  }
  let pointsTo = points.filter { (point) -> Bool in
    point.x <= currectPointStroke.x
  }
  
  for i in 1..<pointsTo.count {
    if points[i].x >= currectPointStroke.x {
      
    }
  }
  path.move(to: pointsTo.first!)
  for i in 1..<pointsTo.count {
    path.addLine( to: points[i] )
  }
  var pointsNew = pointsTo
  for i in 1..<pointsNew.count {
    pointsNew[i].y = points[i].y + 3
  }
  pointsNew.reverse()

  path.addLine(to: pointsNew.first!)
  for i in 1..<pointsNew.count {
    path.addLine( to: pointsNew[i])
  }
  path.addLine(to: points.first!)
 
  path.close()
  return path
}

//MARK: - Help methods

func bezierPoint(_ start:CGPoint, end:CGPoint, p1:CGPoint, p2:CGPoint, progress: CGFloat) -> CGPoint {
    
    let Q1 = pointBetween(start, p2:p1, progress:progress)
    let Q2 = pointBetween(p1, p2:p2, progress:progress)
    let Q3 = pointBetween(p2, p2:end, progress:progress)
    
    let R1 = pointBetween(Q1, p2:Q2, progress:progress)
    let R2 = pointBetween(Q2, p2:Q3, progress:progress)
    
    let B = pointBetween(R1, p2:R2, progress:progress)
    
    return B
}

func midPointCreate(_ p1:CGPoint, _ p2:CGPoint) -> CGPoint {
    return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
}

func createPlotPath(_ points:[CGPoint]) -> UIBezierPath {
    
    let path = UIBezierPath()
    path.move( to: points.first! )
    
    
        for i in 1..<points.count {
            let prevPoint = points[i-1]
            let point = points[i]
    
            let controlPoints = controlPointsCreate(prevPoint, point)
            path.addCurve(to: point,
                                 controlPoint1: controlPoints.first,
                                 controlPoint2: controlPoints.second)
        }
    return path
}

func controlPointsCreate(_ p1: CGPoint, _ p2 : CGPoint) -> (first: CGPoint, second: CGPoint) {
    let midPoint = midPointCreate(p1, p2)
    let topPoint = CGPoint(x: midPoint.x, y: max(p1.y, p2.y))
    let bottomPoint = CGPoint(x: midPoint.x, y: min(p1.y, p2.y))
    return p1.y > p2.y ?
        (first: topPoint, second: bottomPoint) :
        (first: bottomPoint, second: topPoint)
}

func approximateBezierCurve(_ points:[CGPoint], accuracy: Int = 30) -> [CGPoint] {
    var finalPoints = [CGPoint]()
    
    guard !points.isEmpty else {
        return finalPoints
    }
    
    var prevPnt = points.first!
    var currPnt: CGPoint!
    var midPnts: (first: CGPoint, second: CGPoint)!
    
    finalPoints.append( prevPnt )
    
    for i in 1..<points.count {
        currPnt = points[i]
        midPnts = controlPointsCreate(prevPnt, currPnt)
        
        var progress: CGFloat = 0
        var progressPoint: CGPoint!
        for i in 0..<accuracy {
            progress = CGFloat(i) / CGFloat(accuracy)
            progressPoint = bezierPoint(prevPnt, end: currPnt,
                                     p1: midPnts.first, p2: midPnts.second,
                                     progress: progress)
            finalPoints.append( progressPoint )
        }
        prevPnt = currPnt
    }
    finalPoints.append( currPnt )
    return finalPoints
}

func cubicBezierLength(_ start: CGPoint, p1:CGPoint, p2:CGPoint, end:CGPoint, accuracy: Int = 30) -> CGFloat {
    
    var current = CGPoint.zero
    var previous = bezierPoint(start, end:end,
                               p1:p1, p2:p2, progress: 0)
    
    var length:CGFloat = 0
    for i in 1...accuracy {
        let t = CGFloat(i) / CGFloat(accuracy)
        current = bezierPoint(start, end:end,
                              p1:p1, p2:p2, progress: t)
        
        length += distance(previous, p2:current)
        previous = current
    }
    return length
}




//MARK : - Vector logic


func cosAngleBetweenVectors(_ a: CGVector, b: CGVector) -> CGFloat {
    let scalarProduct = scalarProductVector(a, vector2: b)
    let aModule = moduleVector(a)
    let bModule = moduleVector(b)
    
    return scalarProduct / (aModule * bModule)
}

func moduleVector(_ vector: CGVector) -> CGFloat {
    return sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
}

func scalarProductVector(_ vector1: CGVector, vector2: CGVector) -> CGFloat {
    return
        vector1.dx * vector2.dx +
        vector1.dy * vector2.dy
}

func CGVectorMake(_ p1: CGPoint, p2: CGPoint) -> CGVector {
    return CGVector(dx: p2.x - p1.x, dy: p2.y - p1.y)
}



func angleBetweenPoints(_ p1: CGPoint, p2: CGPoint) -> CGFloat {
    let originPoint = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
    let bearingRadians = atan2f(Float(originPoint.y), Float(originPoint.x))
    var bearingDegrees = bearingRadians * (180 / Float(M_PI))
    bearingDegrees = bearingDegrees > 0.0 ? bearingDegrees : (360.0 + bearingDegrees)
    return CGFloat(bearingDegrees - 90)
    
}




