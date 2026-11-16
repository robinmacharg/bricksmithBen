//==============================================================================
//
// File:		LDrawDocument+ModelsMenu.m
//
// Purpose:		The Models menu (adding models, steps, parts, primitives, comments,
//				related parts, minifigures) and its LSynth submenu.
//
//				A category of LDrawDocument, split out of LDrawDocument.m (P4) so
//				that P10 can port it on its own. Shared declarations and the
//				instance variables are in LDrawDocument+Private.h.
//
//  Created by Allen Smith on 2/14/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawDocument+Private.h"

@implementation LDrawDocument (ModelsMenu)

#pragma mark -
#pragma mark Models Menu

//========== addModelClicked: ==================================================
//
// Purpose:		Create a new model and add it to the current file.
//
//==============================================================================
- (IBAction) addModelClicked:(id)sender
{
	LDrawMPDModel	*newModel		= [LDrawMPDModel model];

	[self addModel:newModel atIndex:NSNotFound preventNameCollisions:YES];
	[self setActiveModel:newModel];
	
}//end modelSelected


//========== addModelFromSelectionClicked: =====================================
//
// Purpose:		Creates a new sub-model whose contents are the currently
//				selected parts.  Parts are moved to the sub-model, using the
//				first selected part as the origin.
//
//				A new part is placed in the current model referencing the newly
//				made sub-mode.  This means the user sees the same contents, but
//				via a reference.
//
//==============================================================================
- (IBAction) addModelFromSelectionClicked:(id)sender
{
	NSUndoManager       *	undoManager    = [self undoManager];
	NSArray *				directives = [self selectedObjects];
	NSUInteger				count = [directives count];
	NSUInteger				index;
	LDrawPart *				anchor = nil;
	
	// Find the anchor directive - this will define the location of the
	// sub-part.
	for(index = 0; index < count; ++index)
	{
		id directive = [directives objectAtIndex:index];
		if ([directive isKindOfClass:[LDrawPart class]])
		{
			anchor = (LDrawPart *) directive;
			break;
		}
	}
	
	if(anchor == nil)
		return;
	
	LDrawContainer * anchorParent = [anchor enclosingDirective];
	[fileContentsOutline deselectAll:sender];
	Matrix4 anchorMatrix = [anchor transformationMatrix];
	Matrix4 correction = Matrix4Invert(anchorMatrix);

	// Build a new model.
	LDrawMPDModel	*newModel		= [LDrawMPDModel model];
	[self addModel:newModel atIndex:NSNotFound preventNameCollisions:YES];
	
	for(index = 0; index < count; ++index)
	{
		// For each selected directive, find all of its sub-parts and
		// change its transform.
		id directive = [directives objectAtIndex:index];
		if([directive respondsToSelector:@selector(applyToAllParts:)])
		{
			[directive applyToAllParts:^(LDrawPart * part){
				Matrix4 old = [part transformationMatrix];
				Matrix4 newM = Matrix4Multiply(old, correction);
				TransformComponents oldComp = [part transformComponents];
				
				[[undoManager prepareWithInvocationTarget:self]
					setTransformation:oldComp forPart:part];

				[part setTransformationMatrix:&newM];
			}];
		}
	}
	
	// Move each directive from the current model to the new sub-model.
	LDrawStep * step = [[newModel steps] lastObject];
	
	for(index = 0; index < count; ++index)
	{
		LDrawDirective * d = [directives objectAtIndex:index];
		[self deleteDirective:d];
		
		[self addDirective:d toParent:step atIndex:[[step subdirectives] count]];
	}
	
	// Add one new part that refers to the new sub-model.
	LDrawColor          *selectedColor  = [[LDrawColorPanelController sharedColorPanel] LDrawColor];
	LDrawPart           *newPart        = [[LDrawPart alloc] init];
	[newPart setLDrawColor:selectedColor];
	[newPart setDisplayName:[newModel modelName]];
	[newPart setTransformationMatrix:&anchorMatrix];
	[self addStepComponent:newPart parent:anchorParent index:NSNotFound];
	
		
	[undoManager setActionName:NSLocalizedString(@"UndoModelFromSelection", nil)];
	
	NSArray * movedDirectives = [NSArray arrayWithObject:newPart];
	[self flushDocChangesAndSelect:movedDirectives];
	
}//end addModelFromSelectionClicked:


//========== addStepClicked: ===================================================
//
// Purpose:		Adds a new step wherever it belongs.
//
//==============================================================================
- (IBAction) addStepClicked:(id)sender
{
	LDrawStep		*newStep		= [LDrawStep emptyStep];

	[self addStep:newStep parent:[self selectedModel] index:NSNotFound];
	
}//end addStepClicked:


//========== addPartClicked: ===================================================
//
// Purpose:		Adds a new step to the currently-displayed model. If a part of 
//				the model is already selected, the step will be added after 
//				selection. Otherwise, the step appears at the end of the list.
//
//==============================================================================
- (IBAction) addPartClicked:(id)sender
{	
	NSUserDefaults				*userDefaults			= [NSUserDefaults standardUserDefaults];
	PartBrowserStyleT			partBrowserStyle		= [userDefaults integerForKey:PART_BROWSER_STYLE_KEY];
	PartBrowserPanelController	*partBrowserController	= nil;
	
	switch(partBrowserStyle)
	{
		case PartBrowserShowAsDrawer:
			
			//is it open?
			if([self->partBrowserDrawer state] == NSDrawerOpenState)
				[self->partsBrowser addPartClicked:sender];
			else
				[self->partBrowserDrawer open];
			
			break;
			
		case PartBrowserShowAsPanel:
			
			partBrowserController = [PartBrowserPanelController sharedPartBrowserPanel];
			
			//is it open and foremost?
			if([[partBrowserController window] isKeyWindow] == YES)
				[[partBrowserController partBrowser] addPartClicked:sender];
			else
				[[partBrowserController window] makeKeyAndOrderFront:sender];
			
			break;
	} 
	
}//end addPartClicked:


//========== addSubmodelReferenceClicked: ======================================
//
// Purpose:		Add a reference in the current model to the MPD submodel 
//				selected.
//
// Parameters:	sender: the NSMenuItem representing the submodel to add.
//
//==============================================================================
- (void) addSubmodelReferenceClicked:(id)sender
{
	NSString		*partName			= nil;
	LDrawMPDModel	*referencedModel = [[self documentContents] modelWithName:nil];
	LDrawMPDModel	*destinationModel	= [self selectedModel];
	BOOL			circularReference	= NO;
	
	if(destinationModel == nil)
		destinationModel = [[self documentContents] activeModel];
		
	partName			= [[sender representedObject] modelName];
	referencedModel 	= [[self documentContents] modelWithName:partName];
	circularReference	= [referencedModel containsReferenceTo:[destinationModel modelName]];
	
	//We got a part; let's add it!
	if(partName != nil && circularReference == NO){
		[self addPartNamed:partName];
	}
	
	if(circularReference)
	{
		NSAlert *alert = [[NSAlert alloc] init];
		
		[alert setMessageText:NSLocalizedString(@"CircularReferenceMessage", nil)];
		[alert setInformativeText:NSLocalizedString(@"CircularReferenceInformative", nil)];
		
		NSBeep();
		[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:nil];
	}
}//end addSubmodelReferenceClicked:


//========== addLineClicked: ===================================================
//
// Purpose:		Adds a new line primitive to the currently-displayed model.
//
//==============================================================================
- (IBAction) addLineClicked:(id)sender
{
	LDrawLine       *newLine        = [[LDrawLine alloc] init];
	NSUndoManager   *undoManager    = [self undoManager];
	LDrawColor      *selectedColor  = [[LDrawColorPanelController sharedColorPanel] LDrawColor];
	Point3          position        = ZeroPoint3;
	
	if(self->lastSelectedPart)
	{
		position = [lastSelectedPart position];
	}
	[newLine setVertex1:position];
	[newLine setVertex2:V3Make(position.x + 80, position.y - 80, position.z)];
	
	[newLine setLDrawColor:selectedColor];
	
	[self addStepComponent:newLine parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddLine", nil)];
	[self flushDocChangesAndSelect:[NSArray arrayWithObject:newLine]];
	
}//end addLineClicked:


//========== addTriangleClicked: ===============================================
//
// Purpose:		Adds a new triangle primitive to the currently-displayed model.
//
//==============================================================================
- (IBAction) addTriangleClicked:(id)sender
{
	LDrawTriangle	*newTriangle	= [[LDrawTriangle alloc] init];
	NSUndoManager	*undoManager	= [self undoManager];
	LDrawColor      *selectedColor  = [[LDrawColorPanelController sharedColorPanel] LDrawColor];
	Point3          position        = ZeroPoint3;
	
	if(self->lastSelectedPart)
	{
		position = [lastSelectedPart position];
	}
	[newTriangle setVertex1:position];
	[newTriangle setVertex2:V3Make(position.x + 80, position.y -   0, position.z)];
	[newTriangle setVertex3:V3Make(position.x + 40, position.y -  40, position.z)];
	
	[newTriangle setLDrawColor:selectedColor];
	
	[self addStepComponent:newTriangle parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddTriangle", nil)];
	[self flushDocChangesAndSelect:[NSArray arrayWithObject:newTriangle]];
	
}//end addTriangleClicked:


//========== addQuadrilateralClicked: ==========================================
//
// Purpose:		Adds a new quadrilateral primitive to the currently-displayed 
//				model.
//
//==============================================================================
- (IBAction) addQuadrilateralClicked:(id)sender
{
	LDrawQuadrilateral  *newQuadrilateral   = [[LDrawQuadrilateral alloc] init];
	NSUndoManager       *undoManager        = [self undoManager];
	LDrawColor          *selectedColor      = [[LDrawColorPanelController sharedColorPanel] LDrawColor];
	Point3              position            = ZeroPoint3;
	
	if(self->lastSelectedPart)
	{
		position = [lastSelectedPart position];
	}
	[newQuadrilateral setVertex1:position];
	[newQuadrilateral setVertex2:V3Make(position.x + 80, position.y -   0, position.z)];
	[newQuadrilateral setVertex3:V3Make(position.x + 80, position.y -  80, position.z)];
	[newQuadrilateral setVertex4:V3Make(position.x +  0, position.y -  80, position.z)];
	
	[newQuadrilateral setLDrawColor:selectedColor];
	
	[self addStepComponent:newQuadrilateral parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddQuadrilateral", nil)];
	[self flushDocChangesAndSelect:[NSArray arrayWithObject:newQuadrilateral]];
	
}//end addQuadrilateralClicked:


//========== addConditionalClicked: ============================================
//
// Purpose:		Adds a new conditional-line primitive to the currently-displayed 
//				model.
//
//==============================================================================
- (IBAction) addConditionalClicked:(id)sender
{
	LDrawConditionalLine    *newConditional = [[LDrawConditionalLine alloc] init];
	NSUndoManager           *undoManager    = [self undoManager];
	LDrawColor              *selectedColor  = [[LDrawColorPanelController sharedColorPanel] LDrawColor];
	
	[newConditional setLDrawColor:selectedColor];
	
	[self addStepComponent:newConditional parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddConditionalLine", nil)];
	[self flushDocChangesAndSelect:[NSArray arrayWithObject:newConditional]];
	
}//end addConditionalClicked:


//========== addCommentClicked: ================================================
//
// Purpose:		Adds a new comment primitive to the currently-displayed model.
//
//==============================================================================
- (IBAction) addCommentClicked:(id)sender
{
	LDrawComment	*newComment		= [[LDrawComment alloc] init];
	NSUndoManager	*undoManager	= [self undoManager];
	
	[self addStepComponent:newComment parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddComment", nil)];
	[self flushDocChangesAndSelect:[NSArray arrayWithObject:newComment]];		
}//end addCommentClicked:


//========== addRawCommandClicked: =============================================
//
// Purpose:		Adds a new comment primitive to the currently-displayed model.
//
//==============================================================================
- (IBAction) addRawCommandClicked:(id)sender
{
	LDrawMetaCommand	*newCommand		= [[LDrawMetaCommand alloc] init];
	NSUndoManager		*undoManager	= [self undoManager];
	
	[self addStepComponent:newCommand parent:nil index:NSNotFound];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddMetaCommand", nil)];
	[self flushDocChangesAndSelect:[NSArray arrayWithObject:newCommand]];
}//end addCommentClicked:


//========== addRelatedPartClicked: ============================================
//
// Purpose:		Adds the related child part for a selected parent part.
//
// Notes:		Right now we use the last selected part as a cheat for the 
//				parent we need to insert.  Someday if I can figure out how to
//				insert multiple parts in a single undo, we can iterate on the 
//				selection and add one part per selection.  This would speed up
//				adding the same glass to a whole pile of windows, for example.
//
//==============================================================================
- (IBAction) addRelatedPartClicked:(id)sender
{
#if WANT_RELATED_PARTS
	RelatedPart *		relatedPart 	= [sender representedObject];	
	NSString *			partName		= [relatedPart child];
	NSUndoManager		*undoManager	= [self undoManager];
	LDrawColor			*selectedColor	= [[LDrawColorPanelController sharedColorPanel] LDrawColor];
	TransformComponents transformation	= IdentityComponents;
	id					parentPart		= nil;
	LDrawPart * 		newPart 		= nil;
	NSUInteger			i				= 0;
	NSUInteger			counter 		= 0;

	// We have to save the selection up-front - as we go adding parts, the selection
	// will change out from under us.
	NSArray *			parentParts		= [NSArray arrayWithArray:selectedDirectives];			 // Selection at start that spawns new parts
	NSMutableArray *	newParts		= [NSMutableArray arrayWithCapacity:[parentParts count]];// All new parts added, one for each selected part.
		
	// Step 1: for each selected part, we are going to add one child part.
	
	counter = [parentParts count];
	for(i = 0; i < counter; ++i)
	{
		parentPart = [parentParts objectAtIndex:i];
		if([parentPart isKindOfClass:[LDrawPart class]])
		{
			// Create our new part to match the parent.
			newPart        = [[LDrawPart alloc] init];
			[newPart setLDrawColor:selectedColor];
			[newPart setDisplayName:partName];
			
			// Collect the transformation from the previous part and apply it to 
			// the new one.  Ideally we'd use the selection someday, but
			// we can only add one directive for now.
			transformation = [parentPart transformComponents];
			transformation = [relatedPart calcChildPosition:transformation];			
			[newPart setTransformComponents:transformation];
			
			// Add the part to our model and remember it for later.
			[self addStepComponent:newPart parent:nil index:NSNotFound];
			[newParts addObject:newPart]; 
		}
	}

	[self flushDocChangesAndSelect:newParts];
	[undoManager setActionName:NSLocalizedString(@"UndoAddRelatedPart", nil)];
#endif	
}//end addRelatedPartClicked


//========== addMinifigure: ====================================================
//
// Purpose:		Create a new minifigure with the amazing Minifigure Generator 
//				and add it to the model.
//
//==============================================================================
- (void) addMinifigure:(id)sender
{
	MinifigureDialogController  *minifigDialog  = [MinifigureDialogController new];
	NSInteger                   result          = NSModalResponseCancel;
	LDrawMPDModel               *minifigure     = nil;
	
	result = [minifigDialog runModal];
	if(result == NSModalResponseOK)
	{
		minifigure = [minifigDialog minifigure];
		[self addModel:minifigure atIndex:NSNotFound preventNameCollisions:YES];
	}
	
	
}//end addMinifigure:


//========== modelSelected: ====================================================
//
// Purpose:		A new model from the Models menu was chosen to be the active 
//				model.
//
// Parameters:	sender: an NSMenuItem representing the model to make active.
//
//==============================================================================
- (void) modelSelected:(id)sender
{
	LDrawMPDModel	*newActiveModel		= [sender representedObject];

	[self setActiveModel:newActiveModel];
		
}//end modelSelected


#pragma mark Models Menu - LSynth Submenu

//========== insertSynthesizableDirective: =====================================
//
// Purpose:		Insert a synthesizable directive into the model.  This is a
//              hose, band or part.
//
// Parameters:	sender: an NSMenuItem representing the model to make active.
//
//==============================================================================
- (void) insertSynthesizableDirective:(id)sender
{
    LDrawLSynth		*synthesizedObject	= [[LDrawLSynth alloc] init];
	NSDictionary	*synthEntry			= [sender representedObject];
	NSString		*type				= [synthEntry objectForKey:@"LSYNTH_TYPE"];
    LDrawColor		*selectedColor		= [[LDrawColorPanelController sharedColorPanel] LDrawColor];
    NSUndoManager	*undoManager		= [self undoManager];
	NSString		*undoName			= nil;

    [synthesizedObject setLDrawColor:selectedColor];
    [synthesizedObject setLsynthType:type];

    // The represented object passed in from the menu click indicates whether it's a band or a hose.
    // All well and good, and useful when e.g. deciding how and whether to display constraints.
    // However we also have to consider Parts, which can be either Band Parts or Hose Parts, and
    // need to retain their Part-ness.  To this end we must do a manual lookup of the actual class.
    // TODO: another place that config should provide a convenience method for this
    if ([[[[LDrawApplication shared] lsynthConfiguration] getQuickRefHoses] containsObject:type])
	{
        [synthesizedObject setLsynthClass:LSYNTH_HOSE];
    }
    else if ([[[[LDrawApplication shared] lsynthConfiguration] getQuickRefBands] containsObject:type])
	{
        [synthesizedObject setLsynthClass:LSYNTH_BAND];
    }
    else if ([[[[LDrawApplication shared] lsynthConfiguration] getQuickRefParts] containsObject:type])
	{
        [synthesizedObject setLsynthClass:LSYNTH_PART];
    }
	
	[self addStepComponent:synthesizedObject parent:nil index:NSNotFound];

	undoName = [NSString stringWithFormat:NSLocalizedString(@"UndoAddLSynth", nil), [synthEntry objectForKey:@"title"]];
	[undoManager setActionName:undoName];
	[self flushDocChangesAndSelect:[NSArray arrayWithObject:synthesizedObject]];

}//end insertSynthesizedDirective:


//========== insertLSynthConstraint: =======================================
//
// Purpose:		Insert a synthesizable directive constraint into the model.
//              We don't distinguish between hose or band constraints since
//              both types can be used for either synthesizable type.
//
// Parameters:	sender: an NSMenuItem representing the constraint to insert
//
//==============================================================================
-(void) insertLSynthConstraint:(id)sender
{
    NSUndoManager	*undoManager		= [self undoManager];
	
    // We are fussier than for synthesizable containers; we can *only* be added to them.
    // We just have to worry about the relative position

    if(self->lastSelectedPart != nil)
	{
        LDrawPart *constraint = [[LDrawPart alloc] init];
        [constraint setDisplayName:[[sender representedObject] objectForKey:@"partName"]];
        [constraint setLDrawColor:[[ColorLibrary sharedColorLibrary] colorForCode:LDrawCurrentColor]]; // parent's colour
		
        LDrawContainer *parent = nil;
        NSInteger index = NSNotFound;
        LDrawLSynth *synthesizablePart = nil;
        TransformComponents transformation = [lastSelectedPart transformComponents];
        [constraint setTransformComponents:transformation];
		
        // LDrawLSynth part selected, add at the end
        if ([self->lastSelectedPart isKindOfClass:[LDrawLSynth class]])
		{
            parent = (LDrawLSynth *)self->lastSelectedPart;
            index = [[parent subdirectives] count];
            synthesizablePart = (LDrawLSynth *)parent;
			
            //  Add our constraint, resynthesize and mark as needing display
			[self addDirective:constraint toParent:parent atIndex:index];
            [synthesizablePart synthesize];
			[synthesizablePart noteNeedsDisplay];
        }
		
        // If a constraint is selected (i.e. a part with an LDrawLSynth parent) add ourselves after it
        else if (	[self->lastSelectedPart isKindOfClass:[LDrawDirective class]]
				 &&	[[fileContentsOutline parentForItem:self->lastSelectedPart] isMemberOfClass:[LDrawLSynth class]])
		{
			parent = [fileContentsOutline parentForItem:self->lastSelectedPart];
			int row = [parent indexOfDirective:self->lastSelectedPart];
			index = row + 1;
			synthesizablePart = (LDrawLSynth *)parent;

			//  Add our constraint, resynthesize and mark as needing display
			[self addDirective:constraint toParent:parent atIndex:index];
			[synthesizablePart synthesize];
			[synthesizablePart noteNeedsDisplay];
        }
		
        else {
            NSLog(@"BIG FAT CONSTRAINT ADDING ERROR");
        }
		
		// Show the new element.
		if(parent)
		{
			[self flushDocChangesAndSelect:[NSArray arrayWithObject:constraint]];
			[undoManager setActionName:NSLocalizedString(@"UndoAddLSynthConstraint", nil)];
		}
		
    }
} // end insertLSynthConstraint

-(void) surroundLSynthConstraints:(id)sender
{
    NSLog(@"surroundLSynthConstraints");
}

-(void) invertLSynthConstraintSelection:(id)sender
{
    NSLog(@"invertLSynthConstraintSelection");
}

//========== insertINSIDEOUTSIDELSynthDirective: ===============================
//
// Purpose:		Insert an LSynth direction directive, INSIDE or OUTSIDE, which
//              causes a constraint to switch the side the band passes it.
//
//==============================================================================
-(void) insertINSIDEOUTSIDELSynthDirective:(id)sender
{
    NSUndoManager	*undoManager		= [self undoManager];

    if(self->lastSelectedPart != nil)
	{
        LDrawLSynthDirective	*direction	= [[LDrawLSynthDirective alloc] init];
        LDrawContainer			*parent		= nil;
        NSInteger				index		= NSNotFound;
		NSString				*undoName	= nil;

        // Set direction based on menuItem tag
        if ([(NSMenuItem *)sender tag] == lsynthInsertINSIDETag) {
            [direction setStringValue:@"INSIDE"];
			undoName = NSLocalizedString(@"UndoAddLSynthInside", nil);
        }
        else if ([(NSMenuItem *)sender tag] == lsynthInsertOUTSIDETag) {
            [direction setStringValue:@"OUTSIDE"];
			undoName = NSLocalizedString(@"UndoAddLSynthOutside", nil);
        }
        else if ([(NSMenuItem *)sender tag] == lsynthInsertCROSSTag) {
            [direction setStringValue:@"CROSS"];
			undoName = NSLocalizedString(@"UndoAddLSynthCross", nil);
        }

        // LDrawLSynth part selected, add at the end
        if ([self->lastSelectedPart isKindOfClass:[LDrawLSynth class]])
		{
            parent = (LDrawLSynth *)self->lastSelectedPart;
            index = [[parent subdirectives] count];
        }

        // If a constraint is selected (i.e. a part with an LDrawLSynth parent) add ourselves after it
        else if (	[self->lastSelectedPart isKindOfClass:[LDrawDirective class]]
				 &&	[[fileContentsOutline parentForItem:self->lastSelectedPart] isMemberOfClass:[LDrawLSynth class]])
		{
            parent = [fileContentsOutline parentForItem:self->lastSelectedPart];
            int row = [parent indexOfDirective:self->lastSelectedPart];
            index = row + 1;
        }

		[self addDirective:direction toParent:parent atIndex:index];
        [(LDrawLSynth *)parent synthesize];
        [parent noteNeedsDisplay];
		
		// Show the new element.
		if(parent)
		{
			[self flushDocChangesAndSelect:[NSArray arrayWithObject:direction]];			
			// Allow us to immediately use the keyboard to move the new part.
			[[self foremostWindow] makeFirstResponder:mostRecentLDrawView];
			
			[undoManager setActionName:undoName];
		}

    }
}//end insertINSIDEOUTSIDELSynthDirective:

@end
