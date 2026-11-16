//==============================================================================
//
// File:		LDrawDocument+Menus.m
//
// Purpose:		The scope bar, the View menu, and menu and toolbar validation and
//				construction (model menus, related parts menus).
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

#if WANT_RELATED_PARTS
// Modes to build a submenu for related parts:
enum {
	rpm_list_child = 0,			// List our choices in a sub-menu by child part name.
	rpm_list_role = 1,			// List our chioces in a sub-menu by their role.
	rpm_merged = 2				// List only one item wiht name and roll - used when we only have one choice to shorten menus.
};

//---------- AppendChoicesToNewItem --------------------------------------------
//
// Purpose:		Build a menu item with a sub-menu of roles or children for 
//				related parts.
//
// Notes:		In the "merged" mode, subs should contain one item and we ignore
//				child name.  Instead of making a menu item with sub-menu, we 
//				make the single menu item "the" command.  When we have only one
//				choice, this lets us limit the menu depth.
//
//------------------------------------------------------------------------------
void AppendChoicesToNewItem(
					NSMenu *	parent_menu,	// Menu we append to
					NSString *	child_name,		// Unmerged: name of the menu item that shows the sub-menu
					NSArray *	subs,			// Array of RelatedPart objects to list in the sub-menu
					int			menu_style)		// Way to list menus.
{
	NSUInteger i, counter;
	NSMenuItem * my_item = nil;
	NSMenu * choices_menu = nil;

	if(menu_style != rpm_merged)
	{
		my_item = [[NSMenuItem alloc] initWithTitle:child_name action:NULL keyEquivalent:@""];
		[parent_menu addItem:my_item];
		
		choices_menu = [[NSMenu alloc] initWithTitle:@"choices"];
		[my_item setSubmenu:choices_menu];
	}
	else
		choices_menu = parent_menu;
		
	counter = [subs count];
	for(i = 0; i < counter; ++i)
	{
		RelatedPart * ps = [subs objectAtIndex:i];

		NSString * title = nil;
		switch(menu_style) {
		case rpm_list_child: title = [ps childName]; break;
		case rpm_list_role: title = [ps role]; break;
		case rpm_merged: title = [NSString stringWithFormat:@"%s: %s", [[ps role] UTF8String], [[ps childName] UTF8String]]; break;
		}

		NSMenuItem * ps_item = [[NSMenuItem alloc] initWithTitle:title action:@selector(addRelatedPartClicked:) keyEquivalent:@""];
		[choices_menu addItem:ps_item];		
		[ps_item setRepresentedObject:ps];
	}
	
}//end AppendChoicesToNewItem
#endif


@implementation LDrawDocument (Menus)

#pragma mark -
#pragma mark Scope Bar

//========== viewAll: ==========================================================
//
// Purpose:		Turn off Step Display.
//
//==============================================================================
- (IBAction) viewAll:(id)sender
{
	// Call the simple method. This also takes care of button state for us.
	[self setStepDisplay:NO];
	
}//end viewAll:


//========== viewSteps: ========================================================
//
// Purpose:		Turn on Step Display.
//
//==============================================================================
- (IBAction) viewSteps:(id)sender
{
	// Call the simple method. This also takes care of button state for us.
	[self setStepDisplay:YES];

}//end viewSteps:


//========== stepFieldChanged: =================================================
//
// Purpose:		This allows you to type in a specific step and go to it.
//
//==============================================================================
- (IBAction) stepFieldChanged:(id)sender
{
	LDrawMPDModel   *activeModel    = [[self documentContents] activeModel];
	NSInteger       numberSteps     = [[activeModel steps] count];
	NSInteger       requestedStep   = [sender integerValue]; // 1-relative
	NSInteger       actualStep      = 0; // 1-relative
	
	// The user's number may have been out of range.
	actualStep = CLAMP(requestedStep, 1, numberSteps);
	
	[self setCurrentStep:(actualStep - 1)]; // convert to 0-relative
	
	// If we had to clamp, that is a user error. Tell him.
	if(actualStep != requestedStep)
		NSBeep();
		
}//end stepFieldChanged:


//========== stepNavigatorClicked: =============================================
//
// Purpose:		The step navigator is a segmented control that presents a back 
//				and forward button. 
//
//==============================================================================
- (IBAction) stepNavigatorClicked:(id)sender
{
	// Back == 0; Forward == 1
	if([sender selectedSegment] == 0)
		[self backOneStep:sender];
	else
		[self advanceOneStep:sender];
	
}//end stepNavigatorClicked:


#pragma mark -
#pragma mark View Menu

//========== zoomActual: =======================================================
//
// Purpose:		Zoom to 100%.
//
//==============================================================================
- (IBAction) zoomActual:(id)sender
{
	[mostRecentLDrawView setZoomPercentage:100];
	
}//end zoomActual:


//========== zoomIn: ===========================================================
//
// Purpose:		Enlarge the scale of the current LDraw view.
//
//==============================================================================
- (IBAction) zoomIn:(id)sender
{
	[mostRecentLDrawView zoomIn:sender];
	
}//end zoomIn:


//========== zoomOut: ==========================================================
//
// Purpose:		Shrink the scale of the current LDraw view.
//
//==============================================================================
- (IBAction) zoomOut:(id)sender
{
	[mostRecentLDrawView zoomOut:sender];
	
}//end zoomOut:


//========== viewOrientationSelected: ==========================================
//
// Purpose:		The user has chosen a new viewing angle from a menu.
//				sender is the menu item, whose tag is the viewing angle. We'll 
//				just pass this off to the appropriate view.
//
// Note:		This method will get skipped entirely if an LDrawGLView is the 
//				first responder; the message will instead go directly there 
//				because this method has the same name as the one in LDrawGLView.
//
//==============================================================================
- (IBAction) viewOrientationSelected:(id)sender
{
	[self->mostRecentLDrawView viewOrientationSelected:sender];
	
}//end viewOrientationSelected:


//========== toggleStepDisplay: ================================================
//
// Purpose:		Turns step display (like Lego instructions) on or off for the 
//				active model.
//
//==============================================================================
- (IBAction) toggleStepDisplay:(id)sender
{
	LDrawMPDModel	*activeModel	= [[self documentContents] activeModel];
	BOOL			 stepDisplay	= [activeModel stepDisplay];
	
	if(stepDisplay == NO) //was off; so turn it on.
		[self setStepDisplay:YES];
	else //on; turn it off now
		[self setStepDisplay:NO];
	
}//end toggleStepDisplay:


//========== advanceOneStep: ===================================================
//
// Purpose:		Moves the step display forward one step.
//
//==============================================================================
- (IBAction) advanceOneStep:(id)sender
{
	LDrawMPDModel   *activeModel    = [[self documentContents] activeModel];
	NSInteger       currentStep     = [activeModel maximumStepIndexForStepDisplay];
	NSInteger       numberSteps     = [[activeModel steps] count];
	
	[self setCurrentStep: (currentStep+1) % numberSteps ];
	
}//end advanceOneStep:


//========== backOneStep: ======================================================
//
// Purpose:		Displays the previous step.
//
//==============================================================================
- (IBAction) backOneStep:(id)sender
{
	LDrawMPDModel   *activeModel    = [[self documentContents] activeModel];
	NSInteger       currentStep     = [activeModel maximumStepIndexForStepDisplay];
	NSInteger       numberSteps     = [[activeModel steps] count];
	
	// Wrap around?
	if(currentStep == 0)
		currentStep = numberSteps;
	
	[self setCurrentStep: (currentStep-1) % numberSteps ];

}//end backOneStep:


//========== useSelectionForRotationCenter: ====================================
//
// Purpose:		Defines the model's rotation center.
//
//==============================================================================
- (IBAction) useSelectionForRotationCenter:(id)sender
{
	NSMutableArray *selectedDrawables = [NSMutableArray array];
	
	for(id currentDirective in self->selectedDirectives)
	{
		if([currentDirective isKindOfClass:[LDrawDrawableElement class]])
		{
			[selectedDrawables addObject:currentDirective];
		}
	}
	
	if([selectedDrawables count] == 0)
	{
		[[self->documentContents activeModel] setRotationCenter:ZeroPoint3];
	}
	else
	{
		[[self->documentContents activeModel] setRotationCenter:[(LDrawDrawableElement*)[selectedDrawables objectAtIndex:0] position]];
	}
	
}//end useSelectionForRotationCenter:


//========== clearRotationCenter: ==============================================
//
// Purpose:		Resets rotation center to the origin.
//
//==============================================================================
- (IBAction) clearRotationCenter:(id)sender
{
	[[self->documentContents activeModel] setRotationCenter:ZeroPoint3];
		
}//end clearRotationCenter:


#pragma mark -
#pragma mark MENUS
#pragma mark -

//========== validateMenuItem: =================================================
//
// Purpose:		Determines whether the given menu item should be available.
//				This method is called automatically each time a menu is opened.
//				We identify the menu item by its tag, which is defined in 
//				MacLDraw.h.
//
//==============================================================================
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	NSInteger       tag             = [menuItem tag];
	NSArray         *selectedItems  = [self selectedObjects];
	LDrawPart       *selectedPart   = [self selectedPart];
	NSPasteboard    *pasteboard     = [NSPasteboard generalPasteboard];
	LDrawMPDModel   *activeModel    = [[self documentContents] activeModel];
	BOOL            enable          = NO;
	NSUInteger		selCount		= [selectedItems count];
	id				selTypes		= nil;
	
	if(selCount > 0)
	{
		selTypes = [[selectedItems objectAtIndex:0] class];
		
		for(id obj in selectedItems)
		{
			id mt = [obj class];
			if(mt != selTypes)
			{
				selTypes = nil;
				break;
			}
		}
	}
	
	switch(tag)
	{
        ////////////////////////////////////////
        //
        // File Menu
        //
        ////////////////////////////////////////

        case revealInFinderTag:
            enable = YES;
            if ([self fileURL] == nil) {
                enable = NO;
            }
            break;

		////////////////////////////////////////
		//
		// Edit Menu
		//
		////////////////////////////////////////

		case cutMenuTag:
		case copyMenuTag:
		case deleteMenuTag:
		case duplicateMenuTag:
		case rotatePositiveXTag:
		case rotateNegativeXTag:
		case rotatePositiveYTag:
		case rotateNegativeYTag:
		case rotatePositiveZTag:
		case rotateNegativeZTag:
			if([selectedItems count] > 0)
				enable = YES;
			break;
		
		case changeOriginMenuTag:
			if(selCount == 1 && selTypes == [LDrawPart class])
				enable = YES;
			break;
		
		case splitModelMenuTag:
			if(selCount > 0 && selTypes == [LDrawPart class])
				enable = YES;
			break;
		
		case splitStepMenuTag:
			// We can only split a step if the selection is entirely direct children of steps.
			// Also, all parent steps must be from the same model.
			if([selectedItems count] > 0)
			{
				LDrawModel * commonModel = nil;
				enable = YES;
				for(id currentDirective in self->selectedDirectives)
				{
					LDrawModel * model = [currentDirective enclosingModel];
					LDrawContainer * parent = [currentDirective enclosingDirective];
					if(commonModel == nil)
						commonModel = model;
						
					if(parent == nil || model == nil ||					// Selection has no parent or
						model != commonModel ||							// Two selections have different MPD models or
						![parent isKindOfClass:[LDrawStep class]])		// Not a part of a step.
					{
						enable = NO;
						break;
					}
				}
			}	
			else
				enable = NO;
			break;
			
		
		case pasteMenuTag:
			if([[pasteboard types] containsObject:LDrawDirectivePboardType])
				enable = YES;
			break;
		
		
		////////////////////////////////////////
		//
		// Tools Menu
		//
		////////////////////////////////////////
		
		//The grid menus are always enabled, but this is a fine place to keep 
		// track of their state.
		case gridFineMenuTag:
			[menuItem setState:(self->gridMode == gridModeFine)];
			enable = YES;
			break;
		case gridMediumMenuTag:
			[menuItem setState:(self->gridMode == gridModeMedium)];
			enable = YES;
			break;
		case gridCoarseMenuTag:
			[menuItem setState:(self->gridMode == gridModeCoarse)];
			enable = YES;
			break;
		
		case coordModelMenuTag:
			[menuItem setState:(self->gridOrientation == gridOrientationModel)];
			enable = YES;
			break;
			
		case coordPartMenuTag:
			[menuItem setState:(self->gridOrientation == gridOrientationPart)];
			enable = YES;
			break;
			
		////////////////////////////////////////
		//
		// View Menu
		//
		////////////////////////////////////////
		
		case useSelectionForSpinCenterMenuTag:
			enable = ([selectedItems count] > 0);
			break;
		
		case resetSpinCenterMenuTag:
			enable = !V3EqualPoints(ZeroPoint3, [[self->documentContents activeModel] rotationCenter]);
			break;

		case stepDisplayMenuTag:
			[menuItem setState:([activeModel stepDisplay])];
			enable = YES;
			break;
			
		case nextStepMenuTag:
			enable = ([activeModel stepDisplay] == YES);
			break;
		case previousStepMenuTag:
			enable = ([activeModel stepDisplay] == YES);
			break;
		
		
		////////////////////////////////////////
		//
		// Piece Menu
		//
		////////////////////////////////////////
			
		case hidePieceMenuTag:
			enable = [self elementsAreSelectedOfVisibility:YES]; //there are visible parts to hide.
			break;
			
		case showPieceMenuTag:
			enable = [self elementsAreSelectedOfVisibility:NO]; //there are invisible parts to show.
			break;
			
		case snapToGridMenuTag:
			enable = (selectedPart != nil);
			break;
		
		case gotoModelMenuTag:
			enable = (selectedPart != nil && [selectedItems count] == 1);
			break;		
				
		////////////////////////////////////////
		//
		// Model Menu
		//
		////////////////////////////////////////
		
		case addModelSelectionMenuTag:
			if(selCount > 0 && selTypes == [LDrawPart class])
				enable = YES;
			break;
		
		case submodelReferenceMenuTag:
			//we can't insert a reference to the active model into itself.
			// That would be an inifinite loop.
			enable = (activeModel != [menuItem representedObject]);
			break;

		case relatedPartMenuTag:
			// Related parts is enabled if it has a sub-menu, which happens when we have
			// usable suggestions.
			enable = [menuItem submenu] != nil;
			break;

		case lsynthHoseMenuTag:
		case lsynthBandMenuTag:
            // This is just like inserting a part
			enable = YES;
            break;

        case lsynthHoseConstraintMenuTag:
		case lsynthBandConstraintMenuTag:
            // We can only insert a constraint into an LDrawLSynth part.
            // Ensure it (or a constraint) is selected
            enable = ([selectedPart isKindOfClass:[LDrawLSynth class]] ||
                      [[fileContentsOutline parentForItem:selectedPart] isKindOfClass:[LDrawLSynth class]]);
            break;

// TODO: add these in later
//        case lsynthSurroundINSIDEOUTSIDETag:
//            // INSIDE/OUTSIDE pairs can only surround constraints under a single LSynth part
//            // Valid selections are therefore an LSynth part, a single constraint or multiple
//            // contiguous constraints.
//            enable = NO;
//
//            // Single object selected, and is constraint or LSynth part
//            if ([selectedItems count] == 1) {
//                if ([[selectedItems objectAtIndex:0] isKindOfClass:[LDrawLSynth class]] ||
//                    [[fileContentsOutline parentForItem:[selectedItems objectAtIndex:0]] isKindOfClass:[LDrawLSynth class]]) {
//                    enable = YES;
//                }
//            }
//
//            // More than one thing selected.  Check they are direct siblings and contiguous
//            else {
//                NSMutableSet *parents = [[NSMutableSet alloc] init];
//                for (LDrawDirective *directive in selectedItems) {
//                    [parents addObject:[fileContentsOutline parent]];
//
//                }
//            }
//
//            break;
//
//        case lsynthInvertINSIDEOUTSIDETag:
//            enable = YES;
//            break;

        case lsynthInsertINSIDETag:
            enable = YES;
            break;

        case lsynthInsertOUTSIDETag:
            enable = YES;
            break;



		////////////////////////////////////////
		//
		// Something else.
		//
		////////////////////////////////////////
		
		default:
			//We are an NSDocument; it has its own validator to track certain 
			// items.
			enable = [super validateMenuItem:menuItem];
			break;
	}
	
	return enable;
	
}//end validateMenuItem:


//========== validateToolbarItem: ==============================================
//
// Purpose:		Toolbar validation: eye candy that probably slows everything to 
//				a crawl.
//
//==============================================================================
- (BOOL)validateToolbarItem:(NSToolbarItem *)item
{
	LDrawPart		*selectedPart	= [self selectedPart];
//	NSArray			*selectedItems	= [self selectedObjects];
	NSString		*identifier		= [item itemIdentifier];
	BOOL			 enabled		= NO;
	
	//Must have something selected.
	//Must have a part selected.
	if([identifier isEqualToString:TOOLBAR_SNAP_TO_GRID]  )
	{
		if(selectedPart != nil)
			enabled = YES;
	}
	
	//We don't have special conditions for it; give it a pass.
	else
		enabled = YES;

	return enabled;
	
}//end validateToolbarItem:


#pragma mark -

//========== addModelsToMenus ==================================================
//
// Purpose:		Creates a menu used to switch the active model. A list of all 
//				the models in the document is inserted into the Models menu in 
//				the application's menu bar; the active model gets a check next 
//				to it.
//
//				We also regenerate the Insert Reference submenu (for inserting 
//				MPD submodels as parts in a different model). They require 
//				additional validation which occurs in validateMenuItem.
//
//==============================================================================
- (void) addModelsToMenus
{
	NSMenu          *mainMenu           = [NSApp mainMenu];
	NSMenu          *modelMenu          = [[mainMenu itemWithTag:modelsMenuTag] submenu];
	NSMenu          *referenceMenu      = [[modelMenu itemWithTag:insertReferenceMenuTag] submenu];
	NSInteger       separatorIndex      = [modelMenu indexOfItemWithTag:modelsSeparatorMenuTag];
	NSMenuItem      *modelItem          = nil;
	NSMenuItem      *referenceItem      = nil;
	NSArray         *models             = [[self documentContents] submodels];
	LDrawMPDModel   *currentModel       = nil;
	NSString        *modelDescription   = nil;
	NSInteger       counter             = 0;
	
	[self clearModelMenus];
	
	//Create menu items for each model.
	for(counter = 0; counter < [models count]; counter++)
	{
		currentModel		= [models objectAtIndex:counter];
		modelDescription	= [currentModel browsingDescription];
		
		//
		// Active Model menu items
		//
		modelItem = [[NSMenuItem alloc] init];
		[modelItem setTitle:modelDescription];
		[modelItem setRepresentedObject:currentModel];
		[modelItem setTarget:self];
		[modelItem setAction:@selector(modelSelected:)];
		
		//
		// MPD reference menu items
		//
		referenceItem = [[NSMenuItem alloc] init];
		[referenceItem setTitle:modelDescription];
		[referenceItem setRepresentedObject:currentModel];
		//We set the same tag for all items in the reference menu.
		// Validation will distinguish them with their represented objects.
		[referenceItem setTag:submodelReferenceMenuTag];
		[referenceItem setTarget:self];
		[referenceItem setAction:@selector(addSubmodelReferenceClicked:)];
		
		//
		// Insert the new item at the end.
		//
		[modelMenu insertItem:modelItem atIndex:separatorIndex+counter+1];
		[referenceMenu addItem:referenceItem];
		[[addReferenceButton menu] addItem:[referenceItem copy]];
		[[self->submodelPopUpMenu menu] addItem:[modelItem copy]];
		
		//
		// Set (or re-set) the selected state
		//
		if([[self documentContents] activeModel] == currentModel)
		{
			[modelItem setState:NSControlStateValueOn];
			[self->submodelPopUpMenu selectItemAtIndex:counter];
		}
	}
	
}//end addModelsToMenus


//========== clearModelMenus ===================================================
//
// Purpose:		Removes all submodels from the menus. There are two places we 
//				track the submodels: in the Model menu (for selecting the active 
//				model, and in the references submenu (for inserting submodels as 
//				parts).
//
//==============================================================================
- (void) clearModelMenus
{
	NSMenu      *mainMenu       = [NSApp mainMenu];
	NSMenu      *modelMenu      = [[mainMenu itemWithTag:modelsMenuTag] submenu];
	NSMenu      *referenceMenu  = [[modelMenu itemWithTag:insertReferenceMenuTag] submenu];
	NSInteger   separatorIndex  = [modelMenu indexOfItemWithTag:modelsSeparatorMenuTag];
	NSInteger   counter         = 0;
	
	//Kill all model menu items.
	for(counter = [modelMenu numberOfItems]-1; counter > separatorIndex; counter--)
		[modelMenu removeItemAtIndex: counter];
	
	for(counter = [referenceMenu numberOfItems]-1; counter >= 0; counter--)
		[referenceMenu removeItemAtIndex:counter];
		
	for(counter = [addReferenceButton numberOfItems]-1; counter > 0; counter--)
		[self->addReferenceButton removeItemAtIndex:counter];
		
	[self->submodelPopUpMenu removeAllItems];
	
}//end clearModelMenus


//========== buildRelatedPartsMenus ============================================
//
// Purpose:		This kills and rebuilds the related-parts menu.
//
//==============================================================================
- (void) buildRelatedPartsMenus
{
	NSMenu      *mainMenu       = [NSApp mainMenu];
	NSMenu      *modelMenu      = [[mainMenu itemWithTag:modelsMenuTag] submenu];
	NSMenuItem	*relatedItem	= [modelMenu itemWithTag:relatedPartMenuTag];

#if WANT_RELATED_PARTS

	if ([relatedItem hasSubmenu])
	{
		[relatedItem setSubmenu:nil];
	}
	
	// We're going to go looking for the selection's part name.  This code will find
	// a string if the entire selection shares a single part-type, or nil if we have
	// no parts selected or two parts with different reference names.
	//
	// This is over-kill for now, but written in anticipation of someday being able
	// to add a related child to a set of parents that all can accept the same
	// relation.
	NSString *	parentName = nil;
	NSUInteger	selCount, pidx;
	
	selCount = [selectedDirectives count];
	for(pidx = 0; pidx < selCount; ++pidx)
	{
		LDrawDirective * p = [selectedDirectives objectAtIndex:pidx];
		if([p isKindOfClass:[LDrawPart class]])
		{
			LDrawPart * pp = (LDrawPart *) p;
			NSString * this_name = [pp referenceName];
			if(parentName == nil || [this_name compare:parentName] == NSOrderedSame)
			{
				parentName = this_name;
			} 
			else
			{
				parentName = nil;
				break;
			}
		}
	}
	
	// For now: require not only same parent, but also that we have only one part
	// selected, because we can only insert the child for one part.
	if(parentName != nil && selCount > 0)
	{
		RelatedParts * s = [RelatedParts sharedRelatedParts];
		
		NSArray * kids = [s getChildPartList:parentName];
		NSArray * roles = [s getChildRoleList:parentName];
		
		assert(([kids count] == 0) == ([roles count] == 0));
		
		if([kids count])
		{
			NSMenu * kids_and_roles = [[NSMenu alloc] initWithTitle:@"Related Parts"];
			
			[relatedItem setSubmenu:kids_and_roles];
			[relatedItem setEnabled:TRUE];
			
			// If we only have one role or one child type of part, don't build two-level menus - there's no need.
			BOOL is_flat = ([kids count] == 1 || [roles count] == 1);
			
			NSUInteger count, i;
			
			// Do all children
			count = [kids count];
			for (i = 0; i < count; ++i)
			{
				NSString * child = [kids objectAtIndex:i];
				NSArray * choices = [s getRelatedPartList:parentName withChild:child];
				// If this particular relation has only one child fo the role, we will 'flatten' the menu, rather than having a menu item that has a submenu with
				// only one meu item.
				AppendChoicesToNewItem(kids_and_roles,[[choices objectAtIndex:0] childName],choices,(is_flat || [choices count] == 1) ? rpm_merged : rpm_list_role);
			}
			
			// If we made the 'flat' menu, we don't need a second menu by roles - everything is there in the first menu.
			if(!is_flat)
			{
				[kids_and_roles addItem:[NSMenuItem separatorItem]];
				
				count = [roles count];
				for(i = 0; i < count; ++i)
				{
					NSString * role = [roles objectAtIndex:i];
					NSArray * choices = [s getRelatedPartList:parentName withRole:role];
					AppendChoicesToNewItem(kids_and_roles,role,choices,[choices count] == 1 ? rpm_merged : rpm_list_child);
				}
			}			
		}
	}
	
#else /* WANT_RELATED_PARTS */

	// We can't (as faras I know) use macros to remove UI.  So instead we simply delete our menu item the first time we find
	// it if the related parts UI is disabled.

	if(relatedItem != nil)
	{
		[modelMenu removeItem:relatedItem];
	}

#endif	/* WANT_RELATED_PARTS */
	
}//end buildRelatedPartsMenus

@end
