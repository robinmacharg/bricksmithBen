//==============================================================================
//
// File:		OverlayViewCategory.m
//
// Purpose:		Provides methods to add or remove "overlay" views to 
//				hardware-accelerated views such as NSOpenGLView. The overlay is 
//				visually indistinguishable from a subview, except that it has 
//				major performance advantages. 
//
// Modified:	11/22/2009 Allen Smith. Creation Date.
//
//==============================================================================
#import <AppKit/AppKit.h>


////////////////////////////////////////////////////////////////////////////////
//
// category OverlayViewCategory
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface NSView (OverlayViewCategory)

// Add/remove
- (void)addOverlayView:(null_unspecified NSView *)theView;
- (void)removeOverlayView:(null_unspecified NSView *)theView;

// Optional "delegate"-style methods
- (void)viewWillBecomeOverlay;
- (void)viewDidBecomeOverlay;
- (void)viewWillResignOverlay;
- (void)viewDidResignOverlay;

@end

NS_ASSUME_NONNULL_END

