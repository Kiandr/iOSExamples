/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
UICollectionView convenience extensions.
*/

#import "AVMetadataRecordPlay+UICollectionView+Convenience.h"

@implementation UICollectionView (Convenience)

- (NSArray *)avMetadataRecordPlay_indexPathsForElementsInRect:(CGRect)rect
{
	NSArray *allLayoutAttributes = [self.collectionViewLayout layoutAttributesForElementsInRect:rect];
	if (allLayoutAttributes.count == 0) { return nil; }
	NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:allLayoutAttributes.count];
	for (UICollectionViewLayoutAttributes *layoutAttributes in allLayoutAttributes) {
		NSIndexPath *indexPath = layoutAttributes.indexPath;
		[indexPaths addObject:indexPath];
	}
	return indexPaths;
}

@end

