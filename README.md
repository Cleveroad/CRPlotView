# CRPlotView

[![CI Status](http://img.shields.io/travis/Dmitry Pashinskiy/CRPlotView.svg?style=flat)](https://travis-ci.org/Dmitry Pashinskiy/CRPlotView)
[![Version](https://img.shields.io/cocoapods/v/CRPlotView.svg?style=flat)](http://cocoapods.org/pods/CRPlotView)
[![License](https://img.shields.io/cocoapods/l/CRPlotView.svg?style=flat)](http://cocoapods.org/pods/CRPlotView)
[![Platform](https://img.shields.io/cocoapods/p/CRPlotView.svg?style=flat)](http://cocoapods.org/pods/CRPlotView)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

CRPlotView is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "CRPlotView"
```
and run `pod install` in terminal.

```swift
import CRPlotView
```

## Usage

* CRPlotView uses a relative coordinate system. You can specify the maximum point on the axis Y and X by setup the `totalRelativeHeight` 
    and `totalRelativeLength`. 

* You can adjust the zoom in the limit using `maxZoomScale`, you can also specify the visible region be setting `visibleLength` (using relative coordinate system)
* Use `startRelativeX` to adjust begin of the plot canvas.

* If you want to have smooth curve lines, set `approximateMode` to true, and you can adjust precision by `approximateAccuracy`

* Background color will apply by interpolating between `highColor` and `lowColor` colors, dependce on *markRelativePos*

* Set `markRelativePos`(using relative coordinate system) by X axis to manage plot progress

* Set `points` to configure plot

* Set `isVerticalAxisInversed` to inverse point on Y axis

## Author

Dmitry Pashinskiy, pashinskiy.kh.cr@gmail.com

## License

CRPlotView is available under the MIT license. See the LICENSE file for more info.
