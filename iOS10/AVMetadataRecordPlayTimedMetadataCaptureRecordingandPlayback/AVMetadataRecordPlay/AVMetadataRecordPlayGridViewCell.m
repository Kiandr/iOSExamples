/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
Thumbnail image collection view cell.
*/

#import "AVMetadataRecordPlayGridViewCell.h"

@interface AVMetadataRecordPlayGridViewCell ()
@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@end

@implementation AVMetadataRecordPlayGridViewCell

- (void)setThumbnailImage:(UIImage *)thumbnailImage {
    _thumbnailImage = thumbnailImage;
    self.imageView.image = thumbnailImage;
}

@end
