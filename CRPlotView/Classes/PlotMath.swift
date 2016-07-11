//
//  CRPlotMath.swift
//  CRPlotView
//
//  Created by Dmitry Pashinskiy on 5/31/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

func distance(p1: CGPoint, p2: CGPoint) -> CGFloat {
    let dx = p2.x - p1.x;
    let dy = p2.y - p1.y;
    return sqrt(dx*dx + dy*dy);
}

func pointBetween(p1: CGPoint, p2: CGPoint, progress: CGFloat) -> CGPoint {
    let x = p1.x + (p2.x - p1.x) * progress
    let y = p1.y + (p2.y - p1.y) * progress
    return CGPointMake(x, y)
}



//MARK: - For Linear Behaviour
func lengthLinearPath(points:[CGPoint]) -> CGFloat {
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

func createLinearPlotPath(points: [CGPoint]) -> UIBezierPath{
    let path = UIBezierPath()
    guard !points.isEmpty else {
        return path
    }
    
    path.moveToPoint(points.first!)
    
    for i in 1..<points.count {
        path.addLineToPoint( points[i] )
    }
    
    return path
}





//MARK: - Help methods



func bezierPoint(start:CGPoint, end:CGPoint, p1:CGPoint, p2:CGPoint, progress: CGFloat) -> CGPoint {
    
    let Q1 = pointBetween(start, p2:p1, progress:progress)
    let Q2 = pointBetween(p1, p2:p2, progress:progress)
    let Q3 = pointBetween(p2, p2:end, progress:progress)
    
    let R1 = pointBetween(Q1, p2:Q2, progress:progress)
    let R2 = pointBetween(Q2, p2:Q3, progress:progress)
    
    let B = pointBetween(R1, p2:R2, progress:progress)
    
    return B
}

func midPointCreate(p1:CGPoint, _ p2:CGPoint) -> CGPoint {
    return CGPointMake((p1.x + p2.x) / 2, (p1.y + p2.y) / 2)
}

func createPlotPath(points:[CGPoint]) -> UIBezierPath {
    
    let path = UIBezierPath()
    path.moveToPoint( points.first! )
    
    
        for i in 1..<points.count {
            let prevPoint = points[i-1]
            let point = points[i]
    
            let controlPoints = controlPointsCreate(prevPoint, point)
            path.addCurveToPoint(point,
                                 controlPoint1: controlPoints.first,
                                 controlPoint2: controlPoints.second)
        }
    return path
}

func controlPointsCreate(p1: CGPoint, _ p2 : CGPoint) -> (first: CGPoint, second: CGPoint) {
    let midPoint = midPointCreate(p1, p2)
    let topPoint = CGPointMake(midPoint.x, max(p1.y, p2.y))
    let bottomPoint = CGPointMake(midPoint.x, min(p1.y, p2.y))
    return p1.y > p2.y ?
        (first: topPoint, second: bottomPoint) :
        (first: bottomPoint, second: topPoint)
}

func approximateBezierCurve(points:[CGPoint], accuracy: Int = 30) -> [CGPoint] {
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

func cubicBezierLength(start: CGPoint, p1:CGPoint, p2:CGPoint, end:CGPoint, accuracy: Int = 30) -> CGFloat {
    
    var current = CGPointZero
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


func cosAngleBetweenVectors(a: CGVector, b: CGVector) -> CGFloat {
    let scalarProduct = scalarProductVector(a, vector2: b)
    let aModule = moduleVector(a)
    let bModule = moduleVector(b)
    
    return scalarProduct / (aModule * bModule)
}

func moduleVector(vector: CGVector) -> CGFloat {
    return sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
}

func scalarProductVector(vector1: CGVector, vector2: CGVector) -> CGFloat {
    return
        vector1.dx * vector2.dx +
        vector1.dy * vector2.dy
}

func CGVectorMake(p1: CGPoint, p2: CGPoint) -> CGVector {
    return CGVector(dx: p2.x - p1.x, dy: p2.y - p1.y)
}



func angleBetweenPoints(p1: CGPoint, p2: CGPoint) -> CGFloat {
    let originPoint = CGPointMake(p2.x - p1.x, p2.y - p1.y)
    let bearingRadians = atan2f(Float(originPoint.y), Float(originPoint.x))
    var bearingDegrees = bearingRadians * (180 / Float(M_PI))
    bearingDegrees = bearingDegrees > 0.0 ? bearingDegrees : (360.0 + bearingDegrees)
    return CGFloat(bearingDegrees - 90)
    
}




