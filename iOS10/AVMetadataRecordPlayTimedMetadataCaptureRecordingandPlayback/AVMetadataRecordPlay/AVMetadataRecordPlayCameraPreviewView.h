/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
Camera preview view.
*/

@import UIKit;

@class AVCaptureSession;

@interface AVMetadataRecordPlayCameraPreviewView : UIView

@property (nonatomic) AVCaptureSession *session;

@end
