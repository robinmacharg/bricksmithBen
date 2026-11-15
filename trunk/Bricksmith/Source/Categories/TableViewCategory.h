//==============================================================================
//
// File:		TableViewCategory.h
//
// Purpose:		NSTableView added functionality.
//
// Modified:	04/01/2012 Allen Smith. Creation Date.
//
//==============================================================================
#import <Cocoa/Cocoa.h>


NS_ASSUME_NONNULL_BEGIN

@interface NSTableView (TableViewCategory)

- (void) scrollRowToCenter:(NSInteger)rowIndex;

@end

NS_ASSUME_NONNULL_END
