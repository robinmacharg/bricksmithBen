//==============================================================================
//
// File:		LDrawDocument+Editing.m
//
// Purpose:		High-level editing activities (move, nudge, rotate, select, hide),
//				the traditional actions, and the Edit, Tools and Piece menus.
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

@implementation LDrawDocument (Editing)

#pragma mark -
#pragma mark ACTIVITIES
#pragma mark -
//These are *high-level* calls to modify the structure of the model. They call 
// down to appropriate low-level calls (in the "Undoable Activities" section).


//========== moveSelectionBy: ==================================================
//
// Purpose:		Moves all selected (and moveable) directives in the direction 
//				indicated by movementVector.
//
//==============================================================================
- (void) moveSelectionBy:(Vector3) movementVector
{
	NSArray         *selectedObjects    = [self selectedObjects];
	LDrawDirective  *currentObject      = nil;
	NSInteger       counter             = 0;
	
	//find the nudgable items
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		
//		if([currentObject isKindOfClass:[LDrawDrawableElement class]])
        if([currentObject conformsToProtocol:@protocol(LDrawMovableDirective)])
			[self moveDirective: (LDrawDrawableElement*)currentObject
					inDirection: movementVector];
	}
	
}//end moveSelectionBy:


//========== nudgeSelectionBy: =================================================
//
// Purpose:		Nudges all selected (and nudgeable) directives in the direction 
//				indicated by nudgeVector, which should be normalized. The exact 
//				amount nudged is dependent on the directives themselves, but we 
//				give them our best estimate based on the grid granularity.
//
//==============================================================================
- (void) nudgeSelectionBy:(Vector3)nudgeVector
{
	NSArray                 *selectedObjects    = [self selectedObjects];
	LDrawDrawableElement    *firstNudgable      = nil;
	id                      currentObject       = nil;
	float                   nudgeMagnitude      = [BricksmithUtilities gridSpacingForMode:self->gridMode];
	NSInteger               counter             = 0;
	
	// We do not normalize the nudge vector - nudge might be set to a multiple of the grid on purpose.
	
	nudgeVector.x *= nudgeMagnitude;
	nudgeVector.y *= nudgeMagnitude;
	nudgeVector.z *= nudgeMagnitude;
	
	//find the first selected item that can actually be moved.
	for(counter = 0; counter < [selectedObjects count] && firstNudgable == nil; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		
//		if([currentObject isKindOfClass:[LDrawDrawableElement class]])
//			firstNudgable = currentObject;
        if([currentObject conformsToProtocol:@protocol(LDrawMovableDirective)])
            firstNudgable = currentObject;

	}
	
	if(firstNudgable != nil)
	{
		//compute the absolute movement for the relative nudge. The actual 
		// movement for a nudge is dependent on the axis along which the 
		// nudge is occurring (because Lego follows different vertical and
		// horizontal scales). But we must move all selected parts by the 
		// SAME AMOUNT, otherwise they would get oriented all over the place.
		nudgeVector = [firstNudgable displacementForNudge:nudgeVector];
		
		[self moveSelectionBy:nudgeVector];
	}
}//end nudgeSelectionBy:


//========== rotateSelectionAround: ============================================
//
// Purpose:		Rotates all selected parts in a clockwise direction around the 
//				specified axis. The rotationAxis should be either 
//				+/- i, +/- j or +/- k.
//
//				This method is used by the rotate toolbar methods. It chooses 
//				the actual number of degrees based on the current grid mode.
//
//==============================================================================
- (void) rotateSelectionAround:(Vector3)rotationAxis
{
	NSArray			*selectedObjects	= [self selectedObjects]; //array of LDrawDirectives.
	RotationModeT	 rotationMode		= RotateAroundSelectionCenter;
	Tuple3			 rotation			= {0};
	float			 degreesToRotate	= 0;
	
	//Determine magnitude of nudge.
	switch([self gridSpacingMode])
	{
		case gridModeFine:
			degreesToRotate = GRID_ROTATION_FINE;	//15 degrees
			break;
		case gridModeMedium:
			degreesToRotate = GRID_ROTATION_MEDIUM;	//45 degrees
			break;
		case gridModeCoarse:
			degreesToRotate = GRID_ROTATION_COARSE;	//90 degrees
			break;
	}
	
	//normalize just in case someone didn't get the message!
	rotationAxis = V3Normalize(rotationAxis);
	
	rotation.x = rotationAxis.x * degreesToRotate;
	rotation.y = rotationAxis.y * degreesToRotate;
	rotation.z = rotationAxis.z * degreesToRotate;
	
	TransformComponents rotateComponents    = IdentityComponents;
	Matrix4             addedRotation       = IdentityMatrix4;

	//Create a new matrix that causes the rotation we want.
	//  (start with identity matrix)
	rotateComponents.rotate.x = radians(rotation.x);
	rotateComponents.rotate.y = radians(rotation.y);
	rotateComponents.rotate.z = radians(rotation.z);
	addedRotation = Matrix4CreateTransformation(&rotateComponents);
	
	// If we are in part orientation mode with one part, try to find it and
	// change to ITS coordinate system.
	if([selectedObjects count] == 1 && self->gridOrientation == gridOrientationPart)
	{
		id obj = [selectedObjects objectAtIndex:0];
		if([obj isKindOfClass:[LDrawPart class]])
		{
			LDrawPart * part = (LDrawPart *) obj;
			Matrix4 orig = [part transformationMatrix];
			
			orig.element[3][0] = 0.0;
			orig.element[3][1] = 0.0;
			orig.element[3][2] = 0.0;
			
			Matrix4 origInv = Matrix4Invert(orig);
			
			// To make the rotation be "part relative" we basically change TO the
			// part (inverse of part is world->part), apply the rotation, then change
			// back (part matrix is part->world).
			addedRotation = Matrix4Multiply(Matrix4Multiply(origInv,addedRotation),orig);

			if(Matrix4DecomposeTransformation(addedRotation, &rotateComponents))
			{
				rotation.x = degrees(rotateComponents.rotate.x);
				rotation.y = degrees(rotateComponents.rotate.y);
				rotation.z = degrees(rotateComponents.rotate.z);
			}
		}
	}
	
	//Just one part selected; rotate around that part's origin. That is 
	// presumably what the part's author intended to be the rotation point.
	if([selectedObjects count] == 1){
		rotationMode = RotateAroundPartPositions;
	}
	//More than one part selected. We now must make a "best guess" about 
	// what to rotate around. So we will go with the center of the bounding 
	// box of the selection.
	else
		rotationMode = RotateAroundSelectionCenter;
	
	
	[self rotateSelection:rotation mode:rotationMode fixedCenter:NULL];
	
}//end rotateSelectionAround


//========== rotateSelection:mode:fixedCenter: =================================
//
// Purpose:		Rotates the selected parts according to the specified mode.
//
// Parameters:	rotation	= degrees x,y,z to rotate
//				mode		= how to derive the rotation centerpoint
//				fixedCenter	= explicit centerpoint, or NULL if mode not equal to 
//							  RotateAroundFixedPoint
//
//==============================================================================
- (void) rotateSelection:(Tuple3)rotation
					mode:(RotationModeT)mode
			 fixedCenter:(Point3 *)fixedCenter
{
	NSArray     *selectedObjects    = [self selectedObjects]; //array of LDrawDirectives.
	id          currentObject       = nil;
	Box3        selectionBounds     = [LDrawUtilities boundingBox3ForDirectives:selectedObjects];
	Point3      rotationCenter      = {0};
	NSInteger   counter             = 0;
	
	if(mode == RotateAroundSelectionCenter)
	{
		rotationCenter = V3Midpoint(selectionBounds.min, selectionBounds.max);
	}
	else if(mode == RotateAroundFixedPoint)
	{
		if(fixedCenter != NULL)
			rotationCenter = *fixedCenter;
	}
	
	//rotate everything that can be rotated. That would be parts and only parts.
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		
		if([currentObject isKindOfClass:[LDrawPart class]])
		{
			if(mode == RotateAroundPartPositions)
				rotationCenter = [(LDrawPart*)currentObject position];
		
			[self rotatePart:currentObject
				   byDegrees:rotation
				 aroundPoint:rotationCenter ];
		}
	}
	
}//end rotateSelection:mode:fixedCenter:


//========== selectDirective:byExtendingSelection:==============================
//
// Purpose:		Selects the specified directive.
//				Pass nil to deselect all.
//
//				If shouldExtend is YES, this method toggles the selection of the 
//				given directive. Otherwise, the given directive is made the 
//				exclusive selection in the document. 
//
//				if withScrolling is true, the outliner is auto-scrolled to 
//				reveal the new selection.  This can be turned off for 
//				performance: when "select-all" is invoked on a huge model,
//				scrolling time can take tens of seconds.
//
//==============================================================================
- (void) selectDirective:(LDrawDirective *) directiveToSelect
    byExtendingSelection:(BOOL) shouldExtend
{
	NSArray     *ancestors      = [directiveToSelect ancestors];
	NSInteger   indexToSelect   = 0;
	NSInteger   counter         = 0;
	
	if(directiveToSelect == nil)
		[fileContentsOutline deselectAll:nil];
	else
	{
		//Expand the hierarchy all the way down to the directive we are about to 
		// select.
		for(counter = 0; counter < [ancestors count]; counter++)
			[fileContentsOutline expandItem:[ancestors objectAtIndex:counter]];
		
		//Now we can safely select the directive. It is guaranteed to be visible, 
		// since we expanded all its ancestors.
		indexToSelect = [fileContentsOutline rowForItem:directiveToSelect];
		
		//If we are doing multiple selection (shift-click), we want to deselect 
		// already-selected parts.
		if(		[[fileContentsOutline selectedRowIndexes] containsIndex:indexToSelect]
			&&	shouldExtend == YES )
		{
			[fileContentsOutline deselectRow:indexToSelect];
		}
		else
		{
			[fileContentsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:indexToSelect]
							 byExtendingSelection:shouldExtend];
		}
		
		[fileContentsOutline scrollRowToVisible:indexToSelect];
	}
	
}//end selectDirective:byExtendingSelection:

//========== selectDirectives: ================================================
//
// Purpose:		Selects an array of directives.  This function changes the 
//				selection to be these and only these directives, deselecting
//				all others in the process.
//
//				This is used for marquee selection - when changing a lot of
//				selection it's more CPU efficient to change them all at once. 
//
// Notes:		This routine will perform multiple disclosures of items in the
//				hierarchy as needed to make the selection.  It does not attempt
//				to scroll to the selected items, as they could be spread all 
//				over the place.
//
//==============================================================================
- (void) selectDirectives:(NSArray *) directivesToSelect
{
	NSInteger   indexToSelect   = 0;
	NSInteger   counter         = 0;
	NSInteger	d				= 0;
	NSInteger	total			= [directivesToSelect count];
	
	if(total == 0)
		[fileContentsOutline deselectAll:nil];
	else
	{
		for(d = 0; d < total; ++d)
		{
			LDrawDirective * directive = [directivesToSelect objectAtIndex:d];			
			NSArray     *ancestors      = [directive ancestors];

			//Expand the hierarchy all the way down to the directive we are about to 
			// select.
			for(counter = 0; counter < [ancestors count]; counter++)
				[fileContentsOutline expandItem:[ancestors objectAtIndex:counter]];
		}

		NSMutableIndexSet * indices = [NSMutableIndexSet indexSet];
		
		for(d = 0; d < total; ++d)
		{
			LDrawDirective * directive = [directivesToSelect objectAtIndex:d];			
		
			indexToSelect = [fileContentsOutline rowForItem:directive];
		
			if([indices containsIndex:indexToSelect])
			{
				// Allen says don't do "toggle" behavior with shift-marquee select.  
				// If we did want a toggle, we'd enable this.
				//[indices removeIndex:indexToSelect];			
			}
			else
			{
				[indices addIndex:indexToSelect];
			}
		
		}
		[fileContentsOutline selectRowIndexes:indices byExtendingSelection:NO];
	}
	
}//end selectDirectives:

//========== setSelectionToHidden: =============================================
//
// Purpose:		Hides or shows all the hideable selected elements.
//
//==============================================================================
- (void) setSelectionToHidden:(BOOL)hideFlag
{
	NSArray     *selectedObjects    = [self selectedObjects];
	id          currentObject       = nil;
	NSInteger   counter             = 0;
	
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		if([currentObject respondsToSelector:@selector(setHidden:)])
			[self setElement:currentObject toHidden:hideFlag]; //undoable hook.
	}
		
}//end setSelectionToHidden:


//========== setZoomPercentage: ================================================
//
// Purpose:		Zooms the selected LDraw view to the specified percentage.
//
//==============================================================================
- (void) setZoomPercentage:(CGFloat)newPercentage
{
	[self->mostRecentLDrawView setZoomPercentage:newPercentage];
	
}//end setZoomPercentage:


#pragma mark -
#pragma mark ACTIONS
#pragma mark -
//traditional -(void)action:(id)sender type action methods.
// Generally called directly by User Interface controls.


//========== changeLDrawColor: =================================================
//
// Purpose:		Responds to color-change messages sent down the responder chain 
//				by the LDrawColorPanelController. Upon the receipt of this 
//				message, the window should change the color of all the selected 
//				objects to the new color specified in the panel. 
//
//==============================================================================
- (void) changeLDrawColor:(id)sender
{
	NSArray     *selectedObjects    = [self selectedObjects];
	id          currentObject       = nil;
	LDrawColor  *newColor           = [sender LDrawColor];
	NSInteger   counter             = 0;
	
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
	
		if([currentObject conformsToProtocol:@protocol(LDrawColorable)])
			[self setObject:currentObject toColor:newColor];
	}
	if([selectedObjects count] > 0)
		[[self documentContents] noteNeedsDisplay];
		
}//end changeLDrawColor:




//========== insertLDrawPart: ==================================================
//
// Purpose:		We are being prompted to insert a new part into the model.
//
// Parameters:	sender = PartBrowserDataSource generating the insert request.
//
//==============================================================================
- (void) insertLDrawPart:(id)sender
{
	NSString	*partName	= [sender selectedPartName];
	
	//We got a part; let's add it!
	if(partName != nil)
		[self addPartNamed:partName];
	
	// part-insertion may have been generated by a Part Browser panel which was 
	// in the foreground. Now that the part is inserted, we want the editor 
	// window in the foreground. 
	[[self foremostWindow] makeKeyAndOrderFront:sender];
	
}//end insertLDrawPart:


//========== nudge: ============================================================
//
// Purpose:		Called by LDrawGLView when it wants to nudge the selection.
//
//==============================================================================
- (void) nudge:(id)sender
{
	LDrawGLView *glView     = sender;
	LDrawPart * part;
	Matrix4 xform = IdentityMatrix4;
	
	if(self->gridOrientation == gridOrientationPart)
	{
		NSArray * sel = [self selectedObjects];
		if([sel count] > 0 &&
			[(part = [sel objectAtIndex:0]) respondsToSelector:@selector(transformationMatrix)])
		{
			xform = [part transformationMatrix];
			xform.element[3][0] = 0.0f;
			xform.element[3][1] = 0.0f;
			xform.element[3][2] = 0.0f;
		}
	}
	
	Vector3     nudgeVector = [glView nudgeVectorForMatrix:xform];
	
	[self nudgeSelectionBy:nudgeVector];
	
}//end nudge:


//========== panelMoveParts: ===================================================
//
// Purpose:		The move panel wants to move parts.
//
// Parameters:	sender = MovePanel generating the move request.
//
//==============================================================================
- (void) panelMoveParts:(id)sender
{
	Vector3			movement		= [sender movementVector];
	
	[self moveSelectionBy:movement];
	
}//end panelMoveParts


//========== panelRotateParts: =================================================
//
// Purpose:		The rotation panel wants to rotate! It's up to us to interrogate 
//				the rotation panel to figure out how exactly this rotation is 
//				supposed to be done.
//
// Parameters:	sender = RotationPanel generating the rotation request.
//
//==============================================================================
- (void) panelRotateParts:(id)sender
{
	Tuple3			angles			= [sender angles];
	RotationModeT	rotationMode	= [sender rotationMode];
	Point3			centerPoint		= [sender fixedPoint];
	
	//the center may not be valid, but that will get taken care of by the 
	// rotation mode.
	
	[self rotateSelection:angles
					 mode:rotationMode
			  fixedCenter:&centerPoint];
	
}//end panelRotateParts


#pragma mark -
#pragma mark Edit Menu

//========== cut: ==============================================================
//
// Purpose:		Respond to an Edit->Cut action.
//
//==============================================================================
- (IBAction) cut:(id)sender {

	NSUndoManager	*undoManager		= [self undoManager];

	[self copy:sender];
	[self delete:sender]; //that was easy.

	[undoManager setActionName:NSLocalizedString(@"", nil)];
	
}//end cut:


//========== copy: =============================================================
//
// Purpose:		Respond to an Edit->Copy action.
//
//==============================================================================
- (IBAction) copy:(id)sender {

	NSPasteboard	*pasteboard			= [NSPasteboard generalPasteboard];
	NSArray			*selectedObjects	= [self selectedObjects];
	
	[self writeDirectives:selectedObjects
			 toPasteboard:pasteboard];
	
}//end copy:


//========== paste: ============================================================
//
// Purpose:		Respond to an Edit->Paste action, pasting the contents off the 
//				standard copy/paste pasteboard.
//
//==============================================================================
- (IBAction) paste:(id)sender
{
	NSPasteboard	*pasteboard			= [NSPasteboard generalPasteboard];
	NSUndoManager	*undoManager		= [self undoManager];
	
	[self pasteFromPasteboard:pasteboard preventNameCollisions:YES parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"", nil)];
	
}//end paste:


//========== delete: ===========================================================
//
// Purpose:		A delete request has arrived from somplace--it could be the 
//				menus, the window, the outline view, etc. Our job is to delete
//				the current selection now.
//
// Notes:		This method conveniently has the same name as one in NSText; 
//				that allows us to use the same menu item for both textual and 
//				part delete.
//
//==============================================================================
- (IBAction) delete:(id)sender
{
	NSArray         *selectedObjects    = [self selectedObjects];
	LDrawDirective  *currentObject      = nil;
	NSInteger       counter;

	// Clear the selection FIRST.  We already have a copy of the doomed objects;
	// if we don't clear the selection, deleting the objs OUT of the selection
	// will cause massive thrash of the outliner.
	[fileContentsOutline deselectAll:sender];
	
	//We'll just try to delete everything. Count backwards so that if a 
	// deletion fails, it's the thing at the top rather than the bottom that 
	// remains.
	for(counter = [selectedObjects count]-1; counter >= 0; counter--)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		if([self canDeleteDirective:currentObject displayErrors:YES] == YES)
		{	//above method will display an error if the directive can't be deleted.
			[self deleteDirective:currentObject];
		}
	}
	
	[[self documentContents] noteNeedsDisplay];
		
}//end delete:


//========== selectAll: ========================================================
//
// Purpose:		Selects all the visible LDraw elements in the active model. This 
//				does not select the steps or model--only the contained elements 
//				themselves. Hidden elements are also ignored.
//
//==============================================================================
- (IBAction) selectAll:(id)sender
{
	LDrawModel  *activeModel    = [[self documentContents] activeModel];
	NSArray     *elements       = [activeModel allEnclosedElements];
	id          currentElement  = nil;
	NSInteger   counter         = 0;
	
	NSMutableArray * visibleElements = [NSMutableArray arrayWithCapacity:[elements count]];
	
	for(counter = 0; counter < [elements count]; counter++)
	{
		currentElement = [elements objectAtIndex:counter];
		if(		[currentElement respondsToSelector:@selector(isHidden)] == NO
			||	[currentElement isHidden] == NO)
		{
			[visibleElements addObject:currentElement];
		}
	}

	// Use bulk directive set rather than calling selectDirective over and over.
	// selectDirective 4000 times is too slow - too much notification traffic.
	[self selectDirectives:visibleElements];
	
}//end selectAll:


//========== duplicate: ========================================================
//
// Purpose:		Makes a copy of the selected object.
//
//==============================================================================
- (IBAction) duplicate:(id)sender
{
	// To take advantage of all the exceptionally cool copy/paste code we 
	// already have, -duplicate: simply "copies" the selection onto a private 
	// pasteboard then "pastes" it right back in. This avoids destroying the 
	// general pasteboard, but allows us some fabulous code reuse. (In case you 
	// haven't noticed, I'm proud of this!) 
	NSPasteboard	*pasteboard			= [NSPasteboard pasteboardWithName:@"BricksmithDuplicationPboard"];
	NSArray			*selectedObjects	= [self selectedObjects];
	NSUndoManager	*undoManager		= [self undoManager];
	
	[self writeDirectives:selectedObjects toPasteboard:pasteboard];
	[self pasteFromPasteboard:pasteboard preventNameCollisions:YES parent:nil index:NSNotFound];

	[undoManager setActionName:NSLocalizedString(@"UndoDuplicate", nil)];
	
}//end duplicate:

//========== find: ========================================================
//
// Purpose:		Opens the Find Parts dialog
//
//==============================================================================
- (IBAction) find:(id)sender
{
    SearchPanelController *searchPanel = [SearchPanelController searchPanel];
    [[searchPanel window] makeKeyAndOrderFront:sender];
} // end find:

//========== splitStep: ========================================================
//
// Purpose:		splitStep splits the selected directives out of their current
//				steps and puts them into a newly created step; the newly 
//				created step is inserted directly after the last parent step of
//				the selection.  (Users can use this to rapidly 'break down' a
//				monolithic pile of bricks into sane steps.)
//
// Notes:		The function will only move selection directives that are 
//				children of steps from a single model.
//
//==============================================================================
- (IBAction) splitStep:(id)sender
{
	NSUndoManager			*undoManager		= [self undoManager];
	NSArray					*directives =			[self selectedObjects];
													//[NSArray arrayWithArray:selectedDirectives];	
	NSMutableArray			*movedDirectives = [NSMutableArray arrayWithCapacity:[directives count]];
	LDrawContainer			*containingModel = nil;
	NSInteger				highestIndex = 0;
	LDrawStep				*newStep = nil;

	[fileContentsOutline deselectAll:sender];

	for(id child in directives)
	{
		LDrawDirective * parent = [child enclosingDirective];
		if(parent)
		{
			LDrawContainer * model = [parent enclosingDirective];
			if(model)
			{
				if(containingModel == nil) 
					containingModel = model;
				if(containingModel == model)
				{
					highestIndex = MAX(highestIndex, [containingModel indexOfDirective:parent]);
					[movedDirectives addObject:child];
					[self deleteDirective:child];
				}
			}
		}		
	}
	
	if([movedDirectives count] == 0)
		return;

	newStep = [LDrawStep emptyStep];
	[self addDirective:newStep toParent:containingModel atIndex:highestIndex+1];
	
	for(id child in movedDirectives)
	{
		[self addDirective:child toParent:newStep];
	}

	[undoManager setActionName:NSLocalizedString(@"UndoSplitStep", nil)];
	
	[self flushDocChangesAndSelect:movedDirectives];

}//end splitStep:


//========== splitModel: =======================================================
//
// Purpose:		Copy each part from a MPD sub-model into its location in the
//				parent model.  This basically turns a reference to a sub-model
//				into a big pile of bricks that can be directly edited.
//
// Notes:		Only parts are copied; any step information and primitives in
//				the sub-module are ignored.
//
//==============================================================================
- (IBAction) splitModel:(id)sender
{
	NSUndoManager			*undoManager		= [self undoManager];
	NSArray					*directives			= [self selectedObjects];
	NSMutableArray *		addedParts			= [NSMutableArray arrayWithCapacity:10];
		
	for(id thing in directives)
	{
		// Skip non-parts.
		if(![thing isKindOfClass:[LDrawPart class]])
			continue;
		
		// Skip parts that represent library bricks or that can't be resolved.
		LDrawPart * anchor = (LDrawPart *) thing;
		LDrawModel * model = [anchor referencedMPDSubmodel];
		if(model == nil)
			model = [anchor referencedPeerFile];
		if(model == nil)
			continue;
		
		// Save the transform that the whole part was under, and kill the part.
		Matrix4 xfrm = [anchor transformationMatrix];
		LDrawContainer * anchorParent = [anchor enclosingDirective];
		[self deleteDirective:anchor];
		
		[model applyToAllParts:^(LDrawPart * part){
		
			// For each part, calculate its final location and add it.
			Matrix4 local = [part transformationMatrix];
			Matrix4 global = Matrix4Multiply(local, xfrm);
			
			LDrawPart *newPart        = [[LDrawPart alloc] init];
			[newPart setLDrawColor:[part LDrawColor]];
			[newPart setDisplayName:[part displayName]];
			[newPart setTransformationMatrix:&global];
			
			[self addStepComponent:newPart parent:anchorParent index:NSNotFound];
			
			[addedParts addObject:newPart];
		}];
	}
	
	[undoManager setActionName:NSLocalizedString(@"undoSplitModel", nil)];
	
	[self flushDocChangesAndSelect:addedParts];
}//end splitModel:



//========== orderFrontMovePanel: ==============================================
//
// Purpose:		Opens the advanced rotation panel that provides fine part 
//				rotation controls.
//
//==============================================================================
- (IBAction) orderFrontMovePanel:(id)sender
{
	MovePanel *panel = [MovePanel movePanel];
	
	[panel makeKeyAndOrderFront:self];

}//end orderFrontMovePanel:


//========== orderFrontRotationPanel: ==========================================
//
// Purpose:		Opens the advanced rotation panel that provides fine part 
//				rotation controls.
//
//==============================================================================
- (IBAction) orderFrontRotationPanel:(id)sender
{
	RotationPanelController *rotateController = [RotationPanelController rotationPanel];
	
	[[rotateController window] makeKeyAndOrderFront:self];

}//end openRotationPanel:


#pragma mark -

//========== quickRotateClicked: ===============================================
//
// Purpose:		One of the quick rotation shortcuts was clicked. Build a 
//				rotation in the requested direction (deduced from the sender's 
//				tag). 
//
//==============================================================================
- (IBAction) quickRotateClicked:(id)sender
{
	menuTagsT	tag			= [sender tag];
	Vector3		rotation	= ZeroPoint3;
	
	switch(tag)
	{
		case rotatePositiveXTag:	rotation = V3Make( 1,  0,  0);	break;
		case rotateNegativeXTag:	rotation = V3Make(-1,  0,  0);	break;
		case rotatePositiveYTag:	rotation = V3Make( 0,  1,  0);	break;
		case rotateNegativeYTag:	rotation = V3Make( 0, -1,  0);	break;
		case rotatePositiveZTag:	rotation = V3Make( 0,  0,  1);	break;
		case rotateNegativeZTag:	rotation = V3Make( 0,  0, -1);	break;
		default:													break;
	}
	[self rotateSelectionAround:rotation];
	
}//end quickRotateClicked:


//========== randomizeLDrawColors: =============================================
//
// Purpose:		Randomizes every part in the selection to be one of the parts
//				found in the selection.
//
//				This is meant for a power tool, e.g. if you want to turn a big
//				pile of 1x1 plates into "gravel", you can color the entire set
//				gray and then change a few to the other colors (maybe black,
//				brown, etc.).  randomimzeLDrawColors will randomize the entire
//				set.
//
// Notes:		We try to avoid consecutive colors - if the underlying bricks
//				were built "in order", this gives an author a way to avoid
//				aestheticly ugly blocks of repeating colors that are present
//				in true random distributions.
//
//				This routine depends on LDrawColors hasing into sets with
//				deduplication.  This _does_ work for colors that come from
//				the palettte, but I have not tested it with models that use
//				custom colors in an LDraw directive in their MPD file.
//
//				The random numbers come from -randomSource, which is rand()
//				unless a caller (a test) has set its own.
//
//==============================================================================
- (void) randomizeLDrawColors:(id)sender
{
	// Build a hash set of all colors
	NSArray     *selectedObjects    = [self selectedObjects];
	id          currentObject       = nil;
	NSUInteger  counter             = 0;
	NSUInteger	count				= [selectedObjects count];
	NSMutableSet *	allColors		= [NSMutableSet setWithCapacity:count];
	
	if(count == 0)
		return;
	
	for(counter = 0; counter < count; ++counter)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		if([currentObject conformsToProtocol:@protocol(LDrawColorable)])
		{
			[allColors addObject:[currentObject LDrawColor]];
		}
	}

	NSUInteger colorCount = [allColors count];
	if(colorCount > 0)
	{
		NSArray * allColorsArray = [allColors allObjects];
		int (^nextRandom)(void) = [self randomSource];
		if(nextRandom == nil)
			nextRandom = ^int(void) { return rand(); };

		int last = -1;

		for(counter = 0; counter < count; ++counter)
		{
			currentObject = [selectedObjects objectAtIndex:counter];
			if([currentObject conformsToProtocol:@protocol(LDrawColorable)])
			{
				int r = nextRandom() % colorCount;
				// Try to avoid consecutives if we have enough palette --
				// this technically makes the distribution not random, but
				// it probably looks better unless the parts are just super
				// tiny.
				while(colorCount > 1 && r == last)
				{
					r = nextRandom() % colorCount;
				}
				last = r;
				LDrawColor * randomColor = [allColorsArray objectAtIndex:r];
				
				// We don't have to worry about undo; setObject:toColor
				// builds undo steps, and AppKit merges them into a single
				// giant 
				[self setObject:currentObject toColor:randomColor];
			}
		}
		[[self documentContents] noteNeedsDisplay];
	}
}//end randomizeLDrawColors:


//========== changeOrigin: =====================================================
//
// Purpose:		Movs every part in the selection's parent model so that the
//				selected part is at 0,0,0.
//
//				Also, find all uses of this MPD model and adjust their location
//				in the opposite direction so parent models are not visually
//				affected.
//
// Notes:		By moving the parts in the sub-model and moving the use of the
//				sub-model in the opposite direction, this routine makes no
//				visual changes to the model, while changing the point around
//				which it rotates.
//
//==============================================================================
- (IBAction) changeOrigin:(id)sender
{
	NSUndoManager       *	undoManager    = [self undoManager];
	NSArray *				directives = [self selectedObjects];

	id thing = [directives objectAtIndex:0];
	if (![thing isKindOfClass:[LDrawPart class]])
		return;
	
	LDrawPart * anchor = (LDrawPart *) thing;
	
	Matrix4 anchorMatrix = [anchor transformationMatrix];
	Matrix4 correction = Matrix4Invert(anchorMatrix);
	
	LDrawModel * parentModel = [anchor enclosingModel];
	
	// Iterate the model and move every part based on the anchor part's
	// inverse transform.  This also moves the anchor to 0,0,0.
	[parentModel applyToAllParts:^(LDrawPart * part){
		Matrix4 old = [part transformationMatrix];
		Matrix4 newM = Matrix4Multiply(old, correction);
		TransformComponents oldComp = [part transformComponents];
		
		[[undoManager prepareWithInvocationTarget:self]
			setTransformation:oldComp forPart:part];
		
		[part setTransformationMatrix:&newM];
	}];

	// Iterate sub-models.  For every _other_ sub-model, search every
	// part and apply the anchor's transform to restore the model.
	NSArray * submodels = [[anchor enclosingFile] submodels];
	for(LDrawModel* model in submodels)
	{
		if(model != parentModel)
		{
			[model applyToAllParts:^(LDrawPart * part){
			
				if([part referencedMPDSubmodel] == parentModel)
				{
					Matrix4 old = [part transformationMatrix];
					Matrix4 newM = Matrix4Multiply(anchorMatrix, old);
					TransformComponents oldComp = [part transformComponents];
					
					[[undoManager prepareWithInvocationTarget:self]
						setTransformation:oldComp forPart:part];
					
					[part setTransformationMatrix:&newM];
				}
			}];
		}
	}
	
	[undoManager setActionName:NSLocalizedString(@"UndoChangeOrigin", nil)];
	[[self documentContents] noteNeedsDisplay];
	
}//end changeOrigin:


#pragma mark -
#pragma mark Tools Menu

//========== showInspector: ====================================================
//
// Purpose:		Opens the inspector window. It may have something in it; it may 
//				not. That's up to the document.
//
//				I presume this method will take precedence over the one in 
//				LDrawApplication when a document is opened. This is not 
//				necessarily a good thing, but oh well.
//
//==============================================================================
- (IBAction) showInspector:(id)sender
{
	[[LDrawApplication sharedInspector] show:sender];
	
}//end showInspector:


//========== toggleFileContentsDrawer: =========================================
//
// Purpose:		Either open or close the file contents outline.
//
// Notes:		Now that the file contents is part of the main window, this has 
//				gotten quite a bit more complicated. 
//
//==============================================================================
- (IBAction) toggleFileContentsDrawer:(id)sender
{
	NSView	*firstSubview	= [[self->fileContentsSplitView subviews] objectAtIndex:0];
	CGFloat	maxPosition		= 0.0;
	
	// We collapse or un-collapse the split view.
	if([self->fileContentsSplitView isSubviewCollapsed:firstSubview])
	{
		// Un-collapse the view
		maxPosition = [[self->fileContentsSplitView delegate] splitView:self->fileContentsSplitView
												 constrainMinCoordinate:0.0
															ofSubviewAt:0];
															
		[self->fileContentsSplitView setPosition:maxPosition ofDividerAtIndex:0];
	}
	else
	{
		// Collapse the view
		[self->fileContentsSplitView setPosition:0.0 ofDividerAtIndex:0];
	}
	
}//end toggleFileContentsDrawer:


//========== gridGranularityMenuChanged: =======================================
//
// Purpose:		We just used the menubar to change the granularity of the grid. 
//				This is rather irritating because we need to manage the other 
//				visual indicators of the selection:
//				1) the checkmark in the menu itself
//				2) the selection in the toolbar's grid widget.
//				The menu we will handle in -validateMenuItem:.
//				The toolbar is trickier.
//
//==============================================================================
- (IBAction) gridGranularityMenuChanged:(id)sender
{
	NSInteger           menuTag     = [sender tag];
	gridSpacingModeT    newGridMode = gridModeFine;;
	
	
	switch(menuTag)
	{
		case gridFineMenuTag:
			newGridMode = gridModeFine;
			break;
		
		case gridMediumMenuTag:
			newGridMode = gridModeMedium;
			break;
		
		case gridCoarseMenuTag:
			newGridMode = gridModeCoarse;
			break;
	}
	
	[self setGridSpacingMode:newGridMode];
	
}//end gridGranularityMenuChanged:


//========== gridOrientationModeChanged: =======================================
//
// Purpose:		We just used the menubar to change the orientation of the grid.
//				This is rather irritating because we need to manage the other 
//				visual indicators of the selection:
//				1) the checkmark in the menu itself
//				2) the selection in the toolbar's grid widget.
//				The menu we will handle in -validateMenuItem:.
//				The toolbar is trickier.
//
//==============================================================================
- (IBAction) gridOrientationModeChanged:(id)sender
{
	NSInteger				menuTag		= [sender tag];
	gridOrientationModeT	newMode		= gridOrientationModel;
	
	switch(menuTag)
	{
		case coordModelMenuTag:
			newMode = gridOrientationModel;
			break;
			
		case coordPartMenuTag:
			newMode = gridOrientationPart;
			break;
	}
	
	[self setGridOrientationMode:newMode];

}//end gridOrientationModeChanged:


//========== showDimensions: ===================================================
//
// Purpose:		Shows the dimensions window for this model.
//
//==============================================================================
- (IBAction) showDimensions:(id)sender
{
	DimensionsPanel *dimensions = nil;
	
	dimensions = [DimensionsPanel dimensionPanelForFile:[self documentContents]];
	
	[[self windowForSheet] beginSheet:dimensions
					completionHandler:nil];
		  
}//end showDimensions


//========== showPieceCount: ===================================================
//
// Purpose:		Shows the dimensions window for this model.
//
//==============================================================================
- (IBAction) showPieceCount:(id)sender
{
	PieceCountPanel *pieceCount = nil;
	
	pieceCount = [PieceCountPanel pieceCountPanelForFile:[self documentContents]];
	
	[[self windowForSheet] beginSheet:pieceCount
					completionHandler:nil];
		  
}//end showPieceCount:


#pragma mark -
#pragma mark Piece Menu

//========== showParts: ========================================================
//
// Purpose:		Un-hides all selected parts.
//
//==============================================================================
- (IBAction) showParts:(id)sender
{
	[self setSelectionToHidden:NO];	//unhide 'em
	
}//end showParts:


//========== hideParts: ========================================================
//
// Purpose:		Hides all selected parts so that they are not drawn.
//
//==============================================================================
- (IBAction) hideParts:(id)sender
{
	[self setSelectionToHidden:YES]; //hide 'em
	
}//end hideParts:


//========== showAllParts: =====================================================
//
// Purpose:		Unhides all hidden parts.
//
//==============================================================================
- (IBAction) showAllParts:(id)sender
{
	LDrawModel  *activeModel    = [[self documentContents] activeModel];
	NSArray     *elements       = [activeModel allEnclosedElements];
	id          currentElement  = nil;
	NSInteger   counter         = 0;
	
	// Show everything
	for(counter = 0; counter < [elements count]; counter++)
	{
		currentElement = [elements objectAtIndex:counter];
		
		if(		[currentElement respondsToSelector:@selector(setHidden:)]
		   &&	[currentElement isHidden] == YES)
		{
			[self setElement:currentElement toHidden:NO]; //undoable hook.
		}
	}
}//end showAllParts:


//========== gotoModel: ========================================================
//
// Purpose:		If a single part is selected and the part is an MPD sub-model,
//				This changes the current edited submodel to the selected parts'
//				model.
//
//				If a single part is selected and it's a peer file on disk, this
//				opens the .ldr file in a new document.
//
//==============================================================================
- (IBAction) gotoModel:(id)sender
{
	NSArray     *selectedObjects    = [self selectedObjects];
	
	if([selectedObjects count] == 1)
	{
		id currentObject = [selectedObjects objectAtIndex:0];
		
		if([currentObject respondsToSelector:@selector(referencedMPDSubmodel)])
		{
			LDrawModel * m = [currentObject referencedMPDSubmodel];
			if(m != nil)
			{
				if ([m isKindOfClass:[LDrawMPDModel class]])
				{
					[self setActiveModel:(LDrawMPDModel*) m];
				}
			}
		}

		if([currentObject respondsToSelector:@selector(referencedPeerFile)])
		{
			LDrawModel * m = [currentObject referencedPeerFile];
			if(m != nil)
			{
				NSString * fp = [[m enclosingFile] path];
				[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:fp  isDirectory:FALSE]
																					   display:YES
																			 completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {}];
			}
		}		
	}
}//end gotoModel:


//========== snapSelectionToGrid: ==============================================
//
// Purpose:		Aligns all selected parts to the current grid setting.
//
//==============================================================================
- (void) snapSelectionToGrid:(id)sender
{	
	NSUserDefaults      *userDefaults       = [NSUserDefaults standardUserDefaults];
	NSArray             *selectedObjects    = [self selectedObjects];
	id                  currentObject       = nil;
	float               gridSpacing         = 0;
	float               degreesToRotate     = 0;
	NSInteger           counter             = 0;
	TransformComponents snappedComponents   = IdentityComponents;
	
	//Determine granularity of grid.
	switch([self gridSpacingMode])
	{
		case gridModeFine:
			gridSpacing		= [userDefaults floatForKey:GRID_SPACING_FINE];
			degreesToRotate	= GRID_ROTATION_FINE;	//15 degrees
			break;
		
		case gridModeMedium:
			gridSpacing		= [userDefaults floatForKey:GRID_SPACING_MEDIUM];
			degreesToRotate	= GRID_ROTATION_MEDIUM;	//45 degrees
			break;
		
		case gridModeCoarse:
			gridSpacing		= [userDefaults floatForKey:GRID_SPACING_COARSE];
			degreesToRotate	= GRID_ROTATION_COARSE;	//90 degrees
			break;
	}
	
	//nudge everything that can be rotated. That would be parts and only parts.
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		
		if([currentObject isKindOfClass:[LDrawPart class]])
		{
			snappedComponents = [currentObject 
										componentsSnappedToGrid:gridSpacing
												   minimumAngle:degreesToRotate];
			[self setTransformation:snappedComponents
							forPart:currentObject];
		}
		
	}//end update loop
	
	[[self documentContents] noteNeedsDisplay];
		
}//end snapSelectionToGrid

@end
