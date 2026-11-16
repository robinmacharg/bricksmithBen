//==============================================================================
//
// File:		LDrawDocument+Viewers.m
//
// Purpose:		The 3D viewers: LDrawGLView delegate and mouse coordinates, the
//				split view delegate, and viewport management.
//
//				A category of LDrawDocument, split out of LDrawDocument.m (P4) so
//				that P10 can port it on its own. Shared declarations and the
//				instance variables are in LDrawDocument+Private.h.
//
//  Created by Allen Smith on 2/14/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawDocument+Private.h"
#import "Bricksmith-Swift.h"

@implementation LDrawDocument (Viewers)

#pragma mark -
#pragma mark MOUSE COORDINATES
#pragma mark -

//========== LDrawGLView:mouseIsOverPoint:confidence: ==========================
//
// Purpose:		Display the 3D world coordinates of the mouse as it hovers over 
//				the model. 
//
//==============================================================================
- (void) LDrawGLView:(LDrawGLView *)glView mouseIsOverPoint:(Point3)modelPoint confidence:(Tuple3)confidence
{
	[self->coordinateFieldX setFloatValue:modelPoint.x];
	[self->coordinateFieldY setFloatValue:modelPoint.y];
	[self->coordinateFieldZ setFloatValue:modelPoint.z];
	
	NSColor *questionableColor	= [NSColor colorWithCalibratedWhite:0.3 alpha:1.0];
	NSColor *confidentColor 	= [NSColor colorWithCalibratedWhite:0.1 alpha:1.0];
	
	[self->coordinateFieldX setTextColor:(confidence.x == 0.0) ? questionableColor : confidentColor];
	[self->coordinateFieldY setTextColor:(confidence.y == 0.0) ? questionableColor : confidentColor];
	[self->coordinateFieldZ setTextColor:(confidence.z == 0.0) ? questionableColor : confidentColor];
	[self->coordinateLabelX setTextColor:(confidence.x == 0.0) ? questionableColor : confidentColor];
	[self->coordinateLabelY setTextColor:(confidence.y == 0.0) ? questionableColor : confidentColor];
	[self->coordinateLabelZ setTextColor:(confidence.z == 0.0) ? questionableColor : confidentColor];
	
	[self->coordinateFieldX setHidden:NO];
	[self->coordinateFieldY setHidden:NO];
	[self->coordinateFieldZ setHidden:NO];
	[self->coordinateLabelX setHidden:NO];
	[self->coordinateLabelY setHidden:NO];
	[self->coordinateLabelZ setHidden:NO];
}


//========== LDrawGLViewMouseExited: ===========================================
//
// Purpose:		The mouse location is no longer relevant to coordinate display. 
//				This could be because the mouse exited the view, or because it 
//				is controlling a tool which is not coordinate sensitive. 
//
//==============================================================================
- (void) LDrawGLViewMouseNotPositioning:(LDrawGLView *)glView
{
	[self->coordinateFieldX setHidden:YES];
	[self->coordinateFieldY setHidden:YES];
	[self->coordinateFieldZ setHidden:YES];
	[self->coordinateLabelX setHidden:YES];
	[self->coordinateLabelY setHidden:YES];
	[self->coordinateLabelZ setHidden:YES];
}


#pragma mark -
#pragma mark LDRAW GL VIEW
#pragma mark -

//**** LDrawGLView ****
//========== LDrawGLView:acceptDrop: ===========================================
//
// Purpose:		The user has deposited some drag-anddrop parts into an 
//			    LDrawGLView. Now they need to be imported into the model. 
//
// Notes:		Just like in -duplicate: and 
//				-outlineView:acceptDrop:item:childIndex:, we appropriate the 
//				pasting architecture to simplify importing the parts.
//
//==============================================================================
- (void) LDrawGLView:(LDrawGLView *)glView
		  acceptDrop:(id < NSDraggingInfo >)info
		  directives:(NSArray *)directives
{
	NSPasteboard    *pasteboard         = [NSPasteboard pasteboardWithName:@"BricksmithDragAndDropPboard"];
	NSUndoManager   *undoManager        = [self undoManager];
	NSInteger       selectionCount      = [self->selectedDirectives count];
	id              currentDirective    = nil;
	id              dragPart            = nil;
	Point3          originalPosition    = ZeroPoint3;
	Point3          dragPosition        = ZeroPoint3;
	Vector3         displacement        = ZeroPoint3;
	NSInteger       counter             = 0;
	NSInteger       dropDirectiveIndex  = 0;
	
	// Being dragged within the same document. We must simply apply the 
	// transforms from the dragged parts to the original parts, which have been 
	// hidden during the drag. 
	//
	// Exception: If we have no current selection, it means this was a copy 
	//			  drag. Just paste instead of updating.
	if(		[[info draggingSource] respondsToSelector:@selector(LDrawDirective)]
	   &&	[[info draggingSource] LDrawDirective] == [self documentContents]
	   &&	selectionCount > 0 )
	{
		for(counter = 0; counter < selectionCount; counter++)
		{
			currentDirective	= [self->selectedDirectives objectAtIndex:counter];
			
			if([currentDirective isKindOfClass:[LDrawDrawableElement class]])
			{
				dragPart		= [directives objectAtIndex:dropDirectiveIndex];
				originalPosition= [(LDrawDrawableElement*)currentDirective position];
				dragPosition	= [(LDrawDrawableElement*)dragPart position];
				displacement	= V3Sub(dragPosition, originalPosition);

				[self moveDirective:currentDirective inDirection:displacement];
				[currentDirective setHidden:NO];
				
				dropDirectiveIndex++;
			}
		}
	}
	else
	{
		[self writeDirectives:directives toPasteboard:pasteboard];
		[self pasteFromPasteboard:pasteboard preventNameCollisions:YES parent:nil index:NSNotFound];
		[undoManager setActionName:NSLocalizedString(@"UndoDrop", nil)];
	}
	
}//end LDrawGLView:acceptDrop:


//**** LDrawGLView ****
//========== LDrawGLViewBecameFirstResponder: ==================================
//
// Purpose:		One of our model views just became active, so we need to update 
//				our display to represent that view's characteristics.
//
//==============================================================================
- (void) LDrawGLViewBecameFirstResponder:(LDrawGLView *)glView
{
	// We used bindings to sync up the ever-in-limbo zoom control.
	[self setMostRecentLDrawView:glView];

}//end LDrawGLViewBecameFirstResponder:


//========== LDrawGLView:dragHandleDidMove: ====================================
//
// Purpose:		A primitive's geometry is being directly manipulated.
//
//==============================================================================
- (void) LDrawGLView:(LDrawGLView *)glView dragHandleDidMove:(LDrawDragHandle *)dragHandle
{
	// Ben says: this call is unnecessary for now because the GL renderer tickles the document
	// too.  Some day ideally directives would signal their change to their parents and observers;
	// if we're looking at a triangle, the drag handles would single through the drag handle.
	[self updateInspector];
}


//========== LDrawGLViewPartDragEnded: =========================================
//
// Purpose:		Part drag has ended, successfully or unsuccessfully. This is our 
//				opportunity to clean up.
//
//==============================================================================
- (void) LDrawGLViewPartDragEnded:(LDrawGLView*)glView
{
	self->selectedDirectivesBeforeCopyDrag = nil;
}


//========== LDrawGLViewPartsWereDraggedIntoOblivion: ==========================
//
// Purpose:		The parts which originated the most recent drag operation have 
//				apparently been dragged clear out of the document. Maybe they 
//				went into another document. Maybe they got dragged into empty 
//				space. Whereever they went, they are gone now. 
//
//				The trouble is that when we started dragging them, we just *hid* 
//				them, in anticipation of their landing back within the document. 
//				(It was too much trouble to delete them at the beginning, 
//				because then we might have to reconstruct where they were in the 
//				model hierarchy if they did stay in the same document.) Now that 
//				we know they are really truly gone, we need to delete their 
//				hidden ghosts. 
//
//==============================================================================
- (void) LDrawGLViewPartsWereDraggedIntoOblivion:(LDrawGLView *)glView
{
	NSArray *directivesToDelete = [self->selectedDirectives mutableCopy];
	id		currentDirective	= nil;
	
	for(currentDirective in directivesToDelete)
	{
		if([currentDirective isKindOfClass:[LDrawDrawableElement class]])
		{
			// Even though the directive has been drag-deleted, we still need to 
			// delete it in an undo-friendly way. That means we need to restore 
			// its visibility, since we hid the part when dragging began. 
			[currentDirective setHidden:NO];
		
			[self deleteDirective:currentDirective];
		}
	}
	
}//end LDrawGLViewPartsWereDraggedIntoOblivion:


//========== LDrawGLViewPreferredPartTransform: ================================
//
// Purpose:		Returns the part transform which would be nice applied to new 
//			    parts. This is used during Drag-and-Drop to unpack directives 
//			    and show them in the right place. 
//
//==============================================================================
- (TransformComponents) LDrawGLViewPreferredPartTransform:(LDrawGLView *)glView
{
	TransformComponents	components	 = IdentityComponents;
	
	// If we have a previously-selected part, honor it.
	if(self->lastSelectedPart != nil)
		components = [self->lastSelectedPart transformComponents];
		
	return components;
	
}//end LDrawGLViewPreferredPartTransform:


//**** LDrawGLView ****

//============ markPreviousSelection ============================================
//
// Purpose:		This function marks the current selection - each time 
//				wantsToSelectDirectives is called the new selection is calculated
//				relative to this marked one.  This sets the baseline for when the
//				marquee constantly rebuilds the selection.
//
//==============================================================================
- (void) markPreviousSelection
{
	if(self->markedSelection)
	{
		markedSelection = NULL;
	}
	
	markedSelection = [self selectedObjects];
}//end markPreviousSelection


//============ unmarkPreviousSelection ============================================
//
// Purpose:		This function purges the saved selection - it is called when the
//				marquee drag finishes to save memory.
//
//==============================================================================
- (void) unmarkPreviousSelection
{
	if(markedSelection)
	{
		markedSelection = NULL;
	}
}//end unmarkPreviousSelection


//========== LDrawGLView:wantsToSelectDirectives:selectionMode: ========
//
// Purpose:		The given LDrawView has decided some directives should be 
//				selected, probably because the user marquee selected.
//				If the array is empty, the old selection is still preserved if
//				"extension" is used.
//
//==============================================================================
- (void)	LDrawGLView:(LDrawGLView *)glView
 wantsToSelectDirectives:(NSArray *)directivesToSelect selectionMode:(SelectionModeT) selectionMode
 {
	if(markedSelection)
	{
		// Since we are going to do a bulk selection, calculate 
		// the union of the past selection and this one if we are
		// extending.  Otherwise we only want the new selection.
		NSMutableArray * all;
		NSArray * sel = (all = (selectionMode != SelectionReplace)
			? [NSMutableArray arrayWithArray:markedSelection] 
			: [NSMutableArray arrayWithArray:directivesToSelect]) ;
		
		if(selectionMode == SelectionExtend)
			[all addObjectsFromArray:directivesToSelect];
		else if(selectionMode == SelectionSubtract)
			[all removeObjectsInArray:directivesToSelect];
		else if(selectionMode == SelectionIntersection)
		{
			NSMutableSet *orig = [NSMutableSet setWithArray:markedSelection];
			[orig intersectSet:[NSSet setWithArray:directivesToSelect]];
			sel = [orig allObjects];
		}
		
		if([sel count])		
		{
			[self selectDirectives:sel];
		}
		else 
		{
			[self selectDirective:nil byExtendingSelection:NO];
		}
		
	}
	
}//end LDrawGLView:wantsToSelectDirectives:selectionMode:


//========== LDrawGLView:wantsToSelectDirective:byExtendingSelection: ==========
//
// Purpose:		The given LDrawView has decided some directive should be 
//				selected, probably because the user clicked on it.
//				Pass nil to mean deselect.
//
//==============================================================================
- (void)	LDrawGLView:(LDrawGLView *)glView
 wantsToSelectDirective:(LDrawDirective *)directiveToSelect
   byExtendingSelection:(BOOL) shouldExtend
{
	[self selectDirective:directiveToSelect byExtendingSelection:shouldExtend];
	
}//end LDrawGLView:wantsToSelectDirective:byExtendingSelection:


//========== LDrawGLView:willBeginDraggingHandle: ==============================
//
// Purpose:		The view is about to begin direct primitive geometry 
//				manipulation. We need to record the object state for undo. 
//
//==============================================================================
- (void) LDrawGLView:(LDrawGLView *)glView willBeginDraggingHandle:(LDrawDragHandle *)dragHandle
{
	LDrawDirective *primitive = [dragHandle target];
	
	[self preserveDirectiveState:primitive];
}


//========== LDrawGLView:writeDirectivesToPasteboard:asCopy: ===================
//
// Purpose:		Begin a drag-and-drop part insertion initiated in the directive 
//				view. 
//
// Notes:		The parts you see being dragged around are always copies of the 
//				originals. When we aren't actually doing a copy drag, we just 
//				hide the originals. At the end of the drag, we update the 
//				originals with the new dragged positions, unhide them, and 
//				discard the stuff on the pasteboard. This frees us from having 
//				to remember what step each dragged element belonged to. 
//
//==============================================================================
- (BOOL)         LDrawGLView:(LDrawGLView *)glView
 writeDirectivesToPasteboard:(NSPasteboard *)pasteboard
					  asCopy:(BOOL)copyFlag
{
	NSInteger       selectionCount      = [self->selectedDirectives count];
	NSMutableArray  *archivedParts      = [NSMutableArray array];
	id              currentDirective    = nil;
	NSData          *partData           = nil;
	NSInteger       counter             = 0;
	BOOL            success             = NO;
	
	// Archive selected moveable directives.
	for(counter = 0; counter < selectionCount; counter++)
	{
		currentDirective = [self->selectedDirectives objectAtIndex:counter];
		
		if([currentDirective isKindOfClass:[LDrawDrawableElement class]])
		{
			partData	= [NSKeyedArchiver archivedDataWithRootObject:currentDirective];
			[archivedParts addObject:partData];
			
			if(copyFlag == NO)
			{
				// Not copying; we want the dragging instance to be the only 
				// visual manifestation of this part as it moves. 
				[currentDirective setHidden:YES];
			}
		}
	}
	
	// If copying, DESELECT all current directives as a visual indicator that 
	// the originals will stay put. 
	if(copyFlag == YES)
	{
		self->selectedDirectivesBeforeCopyDrag = [self->selectedDirectives copy];
		[self selectDirective:nil byExtendingSelection:NO];
	}
	
	// Set up pasteboard
	if([archivedParts count] > 0)
	{
		[pasteboard declareTypes:[NSArray arrayWithObject:LDrawDraggingPboardType] owner:self];
		[pasteboard setPropertyList:archivedParts forType:LDrawDraggingPboardType];
		
		success = YES;
	}

	return success;
	
}//end LDrawGLView:writeDirectivesToPasteboard:asCopy:


#pragma mark -
#pragma mark SPLIT VIEW
#pragma mark -

//**** NSSplitView ****
//========== splitView:canCollapseSubview: =====================================
//
// Purpose:		Collapsing is good if we don't like this multipane view deal.
//
//==============================================================================
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return YES;
	
}//end splitView:canCollapseSubview:


//**** NSSplitView ****
//========== splitView:shouldCollapseSubview:forDoubleClickOnDividerAtIndex: ===
//
// Purpose:		Allow split views to collapse when their divider is 
//				double-clicked. 
//
//==============================================================================
- (BOOL)				splitView:(NSSplitView *)splitView
			shouldCollapseSubview:(NSView *)subview
	forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
	return YES;
	
}//end splitView:shouldCollapseSubview:forDoubleClickOnDividerAtIndex:


//**** NSSplitView ****
//========== splitView:constrainMinCoordinate:ofSubviewAt: =====================
//
// Purpose:		Allow the file Contents split view to collapse by giving it a 
//				minimum size. 
//
//==============================================================================
- (CGFloat)   splitView:(NSSplitView *)sender
 constrainMinCoordinate:(CGFloat)proposedMin
			ofSubviewAt:(NSInteger)offset
{
	CGFloat	actualMin	= 0.0;

	if(		sender == self->fileContentsSplitView
	   &&	offset == 0 )
	{
		actualMin = 100; // only return a collapsible minimum for the file contents
	}
	else
		actualMin = proposedMin;
	
	return actualMin;
	
}//end splitView:constrainMinCoordinate:ofSubviewAt:


//**** NSSplitView ****
//========== splitView:constrainMaxCoordinate:ofSubviewAt: =====================
//
// Purpose:		Allow the graphics detail view to collapse by defining a maximum 
//				extent for the the main graphic view. (It's counter-intuitive!)
//
//==============================================================================
- (CGFloat)   splitView:(NSSplitView *)sender
 constrainMaxCoordinate:(CGFloat)proposedMax
			ofSubviewAt:(NSInteger)offset
{
	CGFloat	actualMax	= 0.0;
	
	// In order to allow the detail column to collapse, we have to do something 
	// strange: specify a maximum position for the main graphic view pane. When 
	// the divider is dragged more than halfway beyond that maximum point, the 
	// detail column (view index 1) automatically collapses. Weird...
	if(		sender == self->viewportArranger
		&&	offset == 0 ) // yes, that offset is correct. This method is NEVER called with offset == 1.
	{
		actualMax = NSMaxX([sender frame]) - 80; // min size of 80 for the detail column
	}
	else
		actualMax = proposedMax;
	
	return actualMax;
	
}//end splitView:constrainMinCoordinate:ofSubviewAt:


//**** NSSplitView ****
//========== splitView:resizeSubviewsWithOldSize: ==============================
//
// Purpose:		Do yucky MANUAL resizing of the split view subviews.
//
//				We use this method to make sure that the size of the File 
//				Contents sidebar remains CONSTANT while the window is being 
//				resized. This is how all Apple applications with sidebars 
//				behave, and it is good. 
//
//==============================================================================
- (void) splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	// Make sure the width of the File Contents column remains constant during 
	// live window resize. 
	if(		sender == self->fileContentsSplitView
		&&	[[[sender window] contentView] inLiveResize] == YES )
	{
		NSView	*fileContentsPane	= [[sender subviews] objectAtIndex:0];
		NSView	*graphicPane		= [[sender subviews] objectAtIndex:1];
		NSSize	totalSize			= [sender frame].size;
		NSSize	graphicPaneSize		= [graphicPane frame].size;
		
		// The graphic pane absorbs ALL width changes.
		graphicPaneSize.width		=	totalSize.width 
									 -	[sender dividerThickness]
									 -	NSWidth([fileContentsPane frame]);
		
		[graphicPane setFrameSize:graphicPaneSize];
	}
	
	// If there are only two view columns configured, make sure the rightmost 
	// column remains constant during live window resize. This fit's Allen's 
	// Preferred Viewport Layout, in which there is a set of detail views on the 
	// right. People who prefer otherwise are up a creek.
	if(		sender == self->viewportArranger
		&&	[[[sender window] contentView] inLiveResize] == YES
		&&	[[sender subviews] count] == 2 )
	{
		NSView	*mainViewPane		= [[sender subviews] objectAtIndex:0];
		NSView	*detailViewsPane	= [[sender subviews] objectAtIndex:1];
		NSSize	totalSize			= [sender frame].size;
		NSSize	mainViewPaneSize	= [mainViewPane frame].size;
		
		// The graphic pane absorbs ALL width changes.
		mainViewPaneSize.width		=	totalSize.width 
									 -	[sender dividerThickness]
									 -	NSWidth([detailViewsPane frame]);
		
		[mainViewPane setFrameSize:mainViewPaneSize];
	}
	
	// Allow the split view to finish normal calculations. For the File Contents 
	// split view, this does height resizing for us. For all other split views, 
	// it just does behavior as normal. 
	[sender adjustSubviews];
	
}//end splitView:resizeSubviewsWithOldSize:


#pragma mark -
#pragma mark VIEWPORT MANAGEMENT
#pragma mark -

//========== all3DViewports ====================================================
//
// Purpose:		Returns an array of all the LDrawGLViews managed by the 
//				document and displaying the document contents. 
//
//==============================================================================
- (NSArray<LDrawGLView*> *) all3DViewports
{
	NSArray<LDrawViewerContainer*>* viewerContainers	= [self->viewportArranger allViewports];
	NSMutableArray<LDrawGLView*>*	viewports			= [NSMutableArray array];

	// Count up all the GL views in each column
	for(LDrawViewerContainer* currentViewer in viewerContainers)
	{
		LDrawGLView* currentGLView = currentViewer.glView;
		
		[viewports addObject:currentGLView];
	}
	
	return viewports;
	
}//end all3DViewports


//========== connectLDrawGLView: ===============================================
//
// Purpose:		Associates the given LDrawGLView with this document.
//
//==============================================================================
- (void) connectLDrawGLView:(LDrawGLView *)glView
{
	[glView setDelegate:self];
	
	[glView setTarget:self];
	[glView setForwardAction:@selector(advanceOneStep:)];
	[glView setBackAction:@selector(backOneStep:)];
	[glView setNudgeAction:@selector(nudge:)];
	
	[glView setGridSpacingMode:[self gridSpacingMode]];
	
}//end connectLDrawGLView:


//========== main3DViewport ====================================================
//
// Purpose:		This is the viewport anointed "main", where we reflect things 
//				like the current step orientation. 
//
//==============================================================================
- (LDrawGLView *) main3DViewport
{
	NSArray<LDrawGLView*>*	allViewports	= [self all3DViewports];
	CGFloat 				largestArea 	= 0.0;
	CGFloat 				currentArea 	= 0.0;
	NSSize					currentSize 	= NSZeroSize;
	LDrawGLView*			largestViewport = nil;

	// Find the largest viewport. We'll assume that's the one the user wants to 
	// be the main one. 
	for(LDrawGLView *currentViewport in allViewports)
	{
		currentSize = currentViewport.frame.size;
		currentArea = currentSize.width * currentSize.height;
		
		if(currentArea > largestArea)
		{
			largestArea     = currentArea;
			largestViewport = currentViewport;
		}
	}
		
	return largestViewport;
	
}//end main3DViewport


//========== updateViewportAutosaveNamesAndRestore: ============================
//
// Purpose:		Sets the autosave names for all the viewports. Call this after 
//				the viewport configuration changes. 
//
// Parameters:	shouldRestore	- pass YES to also read settings from prefs.
//
//==============================================================================
- (void) updateViewportAutosaveNamesAndRestore:(BOOL)shouldRestore
{
	NSArray<LDrawGLView*>*	viewports		= [self all3DViewports];
	LDrawGLView*			glView			= nil;
	NSUInteger				viewportCount	= [viewports count];
	NSUInteger				counter 		= 0;

	// Recreate whatever was in use last
	for(counter = 0; counter < viewportCount; counter++)
	{
		glView          = [viewports objectAtIndex:counter];
		
		[glView setAutosaveName:[NSString stringWithFormat:@"fileGraphicView_%ld", (long)counter]];
		[glView setAutosaveName:[NSString stringWithFormat:@"fileGraphicView_%ld", (long)counter]];
		
		if(shouldRestore == YES)
			[glView restoreConfiguration];
	}

}//end updateViewportAutosaveNamesAndRestore:


#pragma mark -

//========== viewportArranger:didAddViewport: ==================================
//
// Purpose:		A new viewport has been added. Time to update the world!
//
// Parameters:	sourceView	- the view the newViewport is being split from. Will 
//				be nil if this is called during restoring the viewports from 
//				preferences. 
//
//==============================================================================
- (void) viewportArranger:(ViewportArranger *)viewportArrangerIn
		   didAddViewport:(LDrawViewerContainer *)newViewport
		   sourceViewport:(LDrawViewerContainer *)sourceView
{
	LDrawGLView *glView         = newViewport.glView;
	LDrawGLView *sourceGLView   = nil;
	
	[self connectLDrawGLView:glView];
	
	[self loadDataIntoDocumentUI];
	
	// This doesn't work during viewport restoration. Didn't attempt to debug 
	// it; just moved the code to -windowControllerDidLoadNib: 
//	[glView scrollCenterToPoint:NSMakePoint( NSMidX([glView frame]), NSMidY([glView frame]) )];
	
	// Opening zoom level
	// Note: The zoom level when first opening the document is set to default 
	//		 values. But we aren't able to determine which views get what values 
	//		 until *all* the views have been fully restored. So we can't do it 
	//		 here. 
	if(sourceView != nil)
	{
		// Make the new view look like the old one.
		sourceGLView = [sourceView glView];
		
		[glView setViewOrientation:[sourceGLView viewOrientation]];
		[glView setProjectionMode:[sourceGLView projectionMode]];
		[glView setZoomPercentage:[sourceGLView zoomPercentage]];
		[glView setLocationMode:[sourceGLView locationMode]];
	}
	
	[self updateViewportAutosaveNamesAndRestore:NO];


}//end viewportArranger:didAddViewport:


//========== viewportArranger:willRemoveViewports: =============================
//
// Purpose:		3D viewports are about to be removed (but they haven't been 
//				quite yet). 
//
//==============================================================================
- (void) viewportArranger:(ViewportArranger *)viewportArranger
	  willRemoveViewports:(NSSet<LDrawViewerContainer*> *)removingViewports
{
	NSArray<LDrawViewerContainer*>* allViewports			= [self->viewportArranger allViewports];
	BOOL							removingMostRecentView	= NO;

	// Are we removing the most recently-used view?
	for(LDrawViewerContainer* container in removingViewports)
	{
		if(container.glView == self->mostRecentLDrawView)
		{
			removingMostRecentView = YES;
			break;
		}
	}

	// If the current most-recent viewport is being removed, we need to make a 
	// new viewport "most-recent." That's because we have bindings observers 
	// watching the most recent view, and we'll crash if they're still observing 
	// when the view deallocates. 
	if(removingMostRecentView)
	{
		// Make the first viewport not being removed the most recent.
		for(LDrawViewerContainer* container in allViewports)
		{
			if([removingViewports containsObject:container] == NO)
			{
				[self setMostRecentLDrawView:[container glView]];
				break;
			}
		}
	}
	
}//end viewportArranger:willRemoveViewports:


//========== viewportArrangerDidRemoveViewports: ===============================
//
// Purpose:		A viewport (or maybe a whole bunch of them) has been removed. We 
//				don't get told which one, but that's because we don't need to 
//				know. 
//
//==============================================================================
- (void) viewportArrangerDidRemoveViewports:(ViewportArranger *)viewportArranger
{
	[self updateViewportAutosaveNamesAndRestore:NO];
	
}//end viewportArrangerDidRemoveViewports:

@end
