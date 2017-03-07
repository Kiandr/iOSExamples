/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
NSIndexSet convenience extensions.
*/

#import "AVMetadataRecordPlay+NSIndexSet+Convenience.h"

@import UIKit;

@implementation NSIndexSet (Convenience)

- (NSArray *)avMetadataRecordPlay_indexPathsFromIndexesWithSection:(NSUInteger)section
{
	NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:self.count];
	[self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		[indexPaths addObject:[NSIndexPath indexPathForItem:idx inSection:section]];
	}];
	return indexPaths;
}

@end

