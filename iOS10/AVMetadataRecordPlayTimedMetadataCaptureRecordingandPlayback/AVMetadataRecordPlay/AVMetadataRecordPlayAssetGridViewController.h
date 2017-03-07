/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
Grid of assets view controller.
*/

@import UIKit;
@import Photos;
@import AVFoundation;

#import "AVMetadataRecordPlayPlayerViewController.h"

@interface AVMetadataRecordPlayAssetGridViewController : UICollectionViewController

@property (nonatomic) PHFetchResult *assetsFetchResults;
@property (nonatomic) PHAssetCollection *assetCollection;
@property (nonatomic) AVAsset *selectedAsset;

@end
