//==============================================================================
//
// File:		LDrawDocument.m
//
// Purpose:		Document controller for an LDraw document.
//
//				Opens the document and manages its editor and viewer. This is 
//				the central class of the application's user interface.
//
// Threading:	The LDrawFile encapsulated in this class is a shared resource. 
//				We must take care not to edit it while it is being drawn in 
//				another thread. As such, all the calls in the "Undoable 
//				Activities" section are bracketed with the appropriate locking
//				calls. (ANY edit of the document should be undoable.)
//
//  Created by Allen Smith on 2/14/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawDocument.h"
#import "LDrawDocument+Private.h"



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


@implementation LDrawDocument

// Keep the original ivar names, so the existing direct uses in this file are unchanged.
@synthesize toolbarController = toolbarController;
@synthesize bindingsController = bindingsController;
@synthesize partBrowserDrawer = partBrowserDrawer;
@synthesize partsBrowser = partsBrowser;
@synthesize viewAllButton = viewAllButton;
@synthesize viewStepsButton = viewStepsButton;
@synthesize submodelPopUpMenu = submodelPopUpMenu;
@synthesize scopeStepControlsContainer = scopeStepControlsContainer;
@synthesize stepField = stepField;
@synthesize stepNavigator = stepNavigator;
@synthesize fileContentsSplitView = fileContentsSplitView;
@synthesize fileContentsOutline = fileContentsOutline;
@synthesize addReferenceButton = addReferenceButton;
@synthesize viewportArranger = viewportArranger;
@synthesize coordinateLabelX = coordinateLabelX;
@synthesize coordinateLabelY = coordinateLabelY;
@synthesize coordinateLabelZ = coordinateLabelZ;
@synthesize coordinateFieldX = coordinateFieldX;
@synthesize coordinateFieldY = coordinateFieldY;
@synthesize coordinateFieldZ = coordinateFieldZ;
@synthesize lastSelectedPart = lastSelectedPart;
@synthesize selectedDirectives = selectedDirectives;
@synthesize selectedDirectivesBeforeCopyDrag = selectedDirectivesBeforeCopyDrag;
@synthesize gridMode = gridMode;
@synthesize gridOrientation = gridOrientation;
@synthesize mostRecentLDrawView = mostRecentLDrawView;
@synthesize markedSelection = markedSelection;

//========== init ==============================================================
//
// Purpose:		Sets up a new untitled document.
//
//==============================================================================
- (id) init
{
//	[[RelatedParts sharedRelatedParts] dump];
    self = [super init];
    if (self)
	{
		[self setDocumentContents:[LDrawFile file]];
		[self setGridSpacingMode:gridModeMedium];
    }
	markedSelection = NULL;
    return self;
	
}//end init


#pragma mark -
#pragma mark DOCUMENT
#pragma mark -

//========== windowNibName =====================================================
//
// Purpose:		Returns the name of the Nib file used to display this document.
//
//==============================================================================
- (NSString *) windowNibName
{
    // If you need to use a subclass of NSWindowController or if your document 
	// supports multiple NSWindowControllers, you should remove this method and 
	// override -makeWindowControllers instead.
    return @"LDrawDocument";
	
}//end windowNibName


//========== windowControllerDidLoadNib: =======================================
//
// Purpose:		awakeFromNib for document-based programs.
//
//==============================================================================
- (void) windowControllerDidLoadNib:(NSWindowController *) aController
{
	NSNotificationCenter	*notificationCenter 	= [NSNotificationCenter defaultCenter];
	NSUserDefaults			*userDefaults			= [NSUserDefaults standardUserDefaults];
	NSWindow				*window 				= [aController window];
	NSToolbar				*toolbar				= nil;
	NSString				*savedSizeString		= nil;
	NSInteger				drawerState 			= 0;
	NSUInteger				counter 				= 0;
	NSNumberFormatter		*coordinateFormatter	= [[NSNumberFormatter alloc] init];

    [super windowControllerDidLoadNib:aController];
	
	// Create the toolbar.
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"LDrawDocumentToolbar"];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setDelegate:self->toolbarController];
	[window setToolbar:toolbar];
	
	
	// Set our size to whatever it was last time. (We don't do the whole frame 
	// because we want the origin to be nicely staggered as documents open; that 
	// normally happens automatically.)
	savedSizeString = [userDefaults objectForKey:DOCUMENT_WINDOW_SIZE];
	if(savedSizeString != nil)
	{
		NSSize	size	= NSSizeFromString(savedSizeString);
		[window resizeToSize:size animate:NO];
	}
	
	
	//Set up the window state based on what is found in preferences.
	drawerState = [userDefaults integerForKey:PART_BROWSER_DRAWER_STATE];
	if(		drawerState == NSDrawerOpenState
	   &&	[userDefaults boolForKey:PART_BROWSER_STYLE_KEY] == PartBrowserShowAsDrawer)
	{
		[partBrowserDrawer open];
		[self->partsBrowser scrollSelectedCategoryToCenter];
	}
	
	
	// File Contents Outline setup
	[fileContentsOutline setDoubleAction:@selector(showInspector:)];
	[fileContentsOutline setVerticalMotionCanBeginDrag:YES];
	[fileContentsOutline registerForDraggedTypes:[NSArray arrayWithObject:LDrawDirectivePboardType]];
	
	
	// We have to do the splitview saving manually. C'mon Apple, get with it!
	// Note: They did in Leopard. These calls will use the system function 
	//		 there. 
	[fileContentsSplitView	setAutosaveName:@"fileContentsSplitView"];
	[viewportArranger		setAutosaveName:@"HorizontalLDrawSplitview2.1"];
	[self updateViewportAutosaveNamesAndRestore:YES];
	
	// Mouse hover coordinates
	[coordinateFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[coordinateFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	[coordinateFormatter setMaximumFractionDigits:0];
	[coordinateFormatter setMinimumFractionDigits:0];
	
	[self->coordinateFieldX setFormatter:coordinateFormatter];
	[self->coordinateFieldY setFormatter:coordinateFormatter];
	[self->coordinateFieldZ setFormatter:coordinateFormatter];
	
	
	// update scope step display controls
	[self setStepDisplay:NO];
	
	//Display our model.
	[self loadDataIntoDocumentUI];
	
	// Set opening zoom percentages
	[[self foremostWindow] layoutIfNeeded]; // zoomToFit needs view sizes
	LDrawGLView	*mainViewport = [self main3DViewport];
	{
		NSArray<LDrawGLView*>	*allViewports		= [self all3DViewports];
		LDrawGLView 			*currentViewport	= nil;

		for(counter = 0; counter < [allViewports count]; counter++)
		{
			currentViewport = [allViewports objectAtIndex:counter];
			
			// For brand new viewports which are not yet displaying a model, set 
			// the default zoom factor. 
			if(currentViewport == mainViewport)
			{
				[currentViewport setZoomPercentage:100];
			}
			else
			{
				[currentViewport setZoomPercentage:75];
			}

			// Scrolling to center doesn't seem to work at restoration time, so 
			// do it again here. 
			[currentViewport scrollCenterToModelPoint:ZeroPoint3];

			// For views which are displaying a model, we'll fit the model onscreen
			// (This has no effect for empty models)
			CGFloat unfitZoom	= [currentViewport zoomPercentage];
			CGFloat fitZoom 	= 0.0;

			[currentViewport zoomToFit:nil];
			fitZoom = [currentViewport zoomPercentage];

			// Back out a wee bit so the user has some room to work with his model
			if(unfitZoom != fitZoom)
			{
				[currentViewport setZoomPercentage:(fitZoom * 0.9)];
			}
 		}
	}
	[[self foremostWindow] makeFirstResponder:mainViewport]; //so we can move it immediately.
	
	//Notifications we want.
	[notificationCenter addObserver:self
						   selector:@selector(syntaxColorChanged:)
							   name:LDrawSyntaxColorsDidChangeNotification
							 object:nil ];
	
	[notificationCenter addObserver:self
						   selector:@selector(docChanged:)
							   name:LDrawDirectiveDidChangeNotification
							 object:[self documentContents] ];

	[notificationCenter addObserver:self
						   selector:@selector(partChanged:)
							   name:LDrawDirectiveDidChangeNotification
							 object:nil ];

	[notificationCenter addObserver:self
						   selector:@selector(stepChanged:)
							   name:LDrawStepDidChangeNotification
							 object:nil ];
	
	[notificationCenter addObserver:self
						   selector:@selector(activeModelChanged:)
							   name:LDrawFileActiveModelDidChangeNotification
							 object:[self documentContents] ];
							 
	[notificationCenter addObserver:self
						   selector:@selector(libraryReloaded:)
							   name:LDrawPartLibraryReloaded
							object:nil];
	
	
	//---------- Cleanup for legacy systems ------------------------------------
	// Ewww!
	
	// (none currently necessary!)

	// Release memory
	
}//end windowControllerDidLoadNib:


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//========== documentContents ==================================================
//
// Purpose:		Returns the logical representation of the LDraw file this 
//				document represents.
//
//==============================================================================
- (LDrawFile *) documentContents
{
	return documentContents;
	
}//end documentContents


//========== foremostWindow ====================================================
//
// Purpose:		Returns the main editing window.
//
//==============================================================================
- (NSWindow *) foremostWindow
{
	return [[[self windowControllers] objectAtIndex:0] window];
	
}//end foremostWindow


//========== gridSpacingMode ===================================================
//
// Purpose:		Returns the current granularity of the positioning grid being 
//				used in this document.
//
//==============================================================================
- (gridSpacingModeT) gridSpacingMode
{
	return gridMode;
	
}//end gridSpacingMode


//========== gridOrientationMode ===============================================
//
// Purpose:		Returns the current grid orientation of the positioning grid
//				being used in this document.
//
//==============================================================================
- (gridOrientationModeT) gridOrientationMode
{
	return gridOrientation;
	
}//end gridOrientationMode


//========== partBrowserDrawer =================================================
//
// Purpose:		Returns the drawer for a part browser attached to the document 
//			    window. Note that the user can set a preference to show the Part 
//			    Browser as a single floating panel rather than a drower on each 
//			    window. 
//
//==============================================================================
- (NSDrawer *) partBrowserDrawer
{
	return self->partBrowserDrawer;

}//end partBrowserDrawer


//========== viewingAngle ======================================================
//
// Purpose:		Returns the modelview rotation for the focused LDrawGLView.
//
//==============================================================================
- (Tuple3) viewingAngle
{
	Tuple3	angle	= [self->mostRecentLDrawView viewingAngle];
	
	return angle;
	
}//end viewingAngle


#pragma mark -


//========== setActiveModel: ===================================================
//
// Purpose:		Changes the current active (displayed) submodel, preserving as 
//				much of the viewing state as is appropriate. 
//
// Notes:		You should call this rather than setting the active model 
//				directly on the LDrawFile. 
//
//==============================================================================
- (void) setActiveModel:(LDrawMPDModel *)newActiveModel
{
	LDrawMPDModel	*oldActiveModel		= [[self documentContents] activeModel];
	BOOL			stepDisplayMode		= [oldActiveModel stepDisplay];
	
	if(newActiveModel != oldActiveModel)
	{
		// Allow the old model to draw in its entirety if it is referenced by the 
		// new model. 
		[oldActiveModel setStepDisplay:NO];
		
		// Set the new model and make sure its step display state matches the 
		// previous step display state. 
		[[self documentContents] setActiveModel:newActiveModel];
		[self setStepDisplay:stepDisplayMode];;
		
		//A notification will be generated that updates the models menu.
	}
}//end setActiveModel:


//========== setCurrentStep: ===================================================
//
// Purpose:		Sets the current maximum step displayed in step display mode and 
//				updates the UI. 
//
// Notes:		This does not activate step display if it isn't on.
//				This also does not do anything if the step is not changing.
//
// Parameters:	requestedStep	- the 0-relative step number. Does not do 
//								  bounds-checking. 
//
//==============================================================================
- (void) setCurrentStep:(NSInteger)requestedStepIndex
{
	LDrawMPDModel	*activeModel		= [[self documentContents] activeModel];
	NSInteger		currentStepIndex	= [activeModel maximumStepIndexForStepDisplay];
	LDrawStep		*requestedStep		= [[activeModel steps] objectAtIndex:requestedStepIndex];
	
	if(currentStepIndex != requestedStepIndex)
	{
		[activeModel setMaximumStepIndexForStepDisplay:requestedStepIndex];
		
		// Update UI
		
		[self->stepField setIntegerValue:(requestedStepIndex + 1)]; // make 1-relative
		
		if([activeModel stepDisplay] == YES)
		{
			// Set the viewer to the step's rotation
			// Note: This is pretty annoying if you are trying to build your 
			//		 model and flip between steps. So I'm going to try 
			//		 restricting it to only happen when the step demands that 
			//		 the viewing angle change. 
			if([requestedStep stepRotationType] != LDrawStepRotationNone)
			{
				[self updateViewingAngleToMatchStep];
			}
				
			[[self documentContents] noteNeedsDisplay];
		}
	}
	
}//end setCurrentStep:


//========== setDocumentContents: ==============================================
//
// Purpose:		Sets the logical representation of the LDraw file this 
//				document represents to newContents. This method should be called 
//				when the document is first created.
//
// Notes:		This method intentionally avoids making the user interface aware 
//				of the new contents. This is because this method is generally 
//				called prior to loading the Nib file. (It also gets called when 
//				reverting.) There is a separate method, -loadDataIntoDocumentUI,
//				to sync the UI.
//
//==============================================================================
- (void) setDocumentContents:(LDrawFile *)newContents
{
	
	// This is going to be an editable container now, so we need to know when it 
	// changes. 
	[newContents setPostsNotifications:YES];
	
	documentContents = newContents;
	
	[[LDrawApplication sharedOpenGLContext] makeCurrentContext];
		
}//end setDocumentContents:


//========== setGridSpacingMode: ===============================================
//
// Purpose:		Sets the current granularity of the positioning grid being used 
//				in this document. 
//
//==============================================================================
- (void) setGridSpacingMode:(gridSpacingModeT)newMode
{
	NSArray<LDrawGLView*>*	graphicViews	= [self all3DViewports];
	NSUInteger				counter 		= 0;

	self->gridMode = newMode;
	
	// Update bits of UI
	[self->toolbarController setGridSpacingMode:newMode];
	
	for(counter = 0; counter < [graphicViews count]; counter++)
	{
		[[graphicViews objectAtIndex:counter] setGridSpacingMode:newMode];
	}
	
}//end setGridSpacingMode:


//========== setGridOrientationMode: ===========================================
//
// Purpose:		Sets the current grid orientation of the positioning grid being
//				used in this document.
//
//==============================================================================
- (void) setGridOrientationMode:(gridOrientationModeT)newMode
{
	self->gridOrientation = newMode;
	[self->toolbarController setGridOrientationMode:newMode];
	
}//end setGridOrientationMode:


//========== setLastSelectedPart: ==============================================
//
// Purpose:		The document keeps track of the part most recently selected in 
//				the file contents outline. This method is called each time a new 
//				part is selected. The transformation matrix of the previously 
//				selected part is then used when new parts are added.
//
//==============================================================================
- (void) setLastSelectedPart:(LDrawPart *)newPart
{
	
	lastSelectedPart = newPart;
	
}//end setLastSelectedPart:


//========== setMostRecentLDrawView: ===========================================
//
// Purpose:		Sets the 3D view with which we interacted the most recently. 
//
// Note:		This accessor method is mainly here to provide KVO compliance so 
//				Cocoa will automatically generate the necessary change messages 
//				for binding which observe the most recent view. 
//
//==============================================================================
- (void) setMostRecentLDrawView:(LDrawGLView *)viewIn
{
	self->mostRecentLDrawView = viewIn;
	
}//end setMostRecentLDrawView:


//========== setStepDisplay: ===================================================
//
// Purpose:		Turns step display (like Lego instructions) on or off for the 
//				active model.
//
//==============================================================================
- (void) setStepDisplay:(BOOL)showStepsFlag
{
	LDrawMPDModel	*activeModel	= [[self documentContents] activeModel];
	
	if(showStepsFlag != [activeModel stepDisplay])
	{
		if(showStepsFlag == YES)
		{
			[activeModel setStepDisplay:YES];
			[self setCurrentStep:0];
			
			// Force viewing angle update when turning on step display. 
			// -setCurrentStep only does this if the step has actually changed. 
			[self updateViewingAngleToMatchStep];
		}
		else // turn it off now
		{
			[activeModel setStepDisplay:NO];
		}
		
		[[self documentContents] noteNeedsDisplay];
	}
	
	// Set scope button state no matter what. The scope buttons are really 
	// toggle buttons which call this method; if you click "Steps" and step 
	// display is already on, you want the button to *stay* selected. This makes 
	// sure that happens. 
	[self->viewAllButton   setState:(showStepsFlag == NO)];
	[self->viewStepsButton setState:(showStepsFlag == YES)];
	
	[self->scopeStepControlsContainer setHidden:(showStepsFlag == NO)];
	[self->stepField setIntegerValue:[activeModel maximumStepIndexForStepDisplay] + 1];
	
}//end setStepDisplay:


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
#pragma mark NOTIFICATIONS
#pragma mark -


//========== libraryReloaded: ==================================================
//
// Purpose:		The library has been reloaded.  We need to notify our entire
//				set of directives that the library parts might have changed.
//				The directives don't do this themselves to avoid overhead.
//
//==============================================================================
- (void)libraryReloaded:(NSNotification *)notification
{
	[LDrawUtilities unresolveLibraryParts:documentContents];
}//end libraryReloaded


//========== activeModelChanged: ===============================================
//
// Purpose:		The file we are displaying has changed its active model.
//
//==============================================================================
- (void)activeModelChanged:(NSNotification *)notification
{
	//[fileContentsOutline reloadData];
	
	//Update the models menu.
	[self addModelsToMenus];
	
	[self setLastSelectedPart:nil];
	
}//end activeModelDidChange:


//**** NSDrawer ****
//========== drawerWillOpen: ===================================================
//
// Purpose:		The Parts Browser drawer is opening.
//
//==============================================================================
- (void)drawerWillOpen:(NSNotification *)notification
{
	if([notification object] == self->partBrowserDrawer)
	{
		// We have a problem. When the main window is resized while the drawer is 
		// closed, the OpenGLView moves, but the OpenGL drawing region doesn't! To 
		// fix this problem, we need to adjust the drawer's size while it is open; 
		// that causes the OpenGL to synchronize itself properly. 
		//
		// This doesn't feel like the right solution to this problem, but it works.
		// Also listed are some other things I tried that didn't work.
		
		//Works, but animation is very chunky. (better than adjusting the window, though)
		NSSize contentSize = [partBrowserDrawer contentSize];
		
		contentSize.height += 1;
		[partBrowserDrawer setContentSize:contentSize];
		contentSize.height -= 1;
		[partBrowserDrawer setContentSize:contentSize];

		//Fails.
		//	[partsBrowser->partPreview reshape];
		
		//Uh-uh.
		//	NSView *contentView = [partBrowserDrawer contentView];
		//	[contentView resizeWithOldSuperviewSize:[partBrowserDrawer contentSize]];
		
		//Nope.
		//	[contentView resizeSubviewsWithOldSize:[partBrowserDrawer contentSize]];
		
		//Ferget it.
		//	[contentView setNeedsDisplay:YES];
		
		//Works, but ruins nice animation.
		//	if(drawerState == NSDrawerClosedState){
		//		NSWindow *parentWindow = [partBrowserDrawer parentWindow];
		//		NSRect parentFrame = [parentWindow frame];
		//		parentFrame.size.width += 1;
		//		[parentWindow setFrame:parentFrame display:NO];
		//		parentFrame.size.width -= 1;
		//		[parentWindow setFrame:parentFrame display:NO];
		//	}
	}
}//end drawerWillOpen:


//========== partChanged: ======================================================
//
// Purpose:		Somewhere, somehow, a part (or some other LDrawDirective) was 
//				changed.  This method handles updating the UI.
//
// Notes:		partChanged is called for -any- part being changed; as a result
//				it gets called a lot.  To keep things fast, partChanged does
//				basically no work directly.  Instead it reposts a notification
//				on the top level LDrawFile for this document.  
//
//				The reposted notification is queued and coalesced with 
//				NSNotificationQueue; the result is that we get one big change
//				notification on our document after many change notifications
//				on parts.  See docChanged for more.
//
//==============================================================================
- (void) partChanged:(NSNotification *)notification
{
	LDrawDirective *changedDirective = [notification object];
	LDrawFile *docContents = [self documentContents];

	// Since the document sends out part changes too, make sure it isn't the doc
	// itself sending - if it is, we'd get into an endless loop.  (Because we 
	// listen to ALL LDrawDirectiveDidChangeNotification notifications, posting
	// calls us again, with changedDirective == docContents).
	if(changedDirective != docContents)
	{	
		// Since we listen to all parts, we have to check whether this part is
		// from our document or some other document.
		if([[changedDirective ancestors] containsObject:docContents])		
		{
			// Post a notification that our doc changed; LDrawGLView needs this 
			// to refresh drawing, and we ned it to redo our menus.
			NSNotification * doc_notification = 
				[NSNotification notificationWithName:LDrawDirectiveDidChangeNotification 
											 object:docContents];
		
			// Notification is queued and coalesced; 
			[[NSNotificationQueue defaultQueue] 
				   enqueueNotification:doc_notification 
						  postingStyle:NSPostASAP 
						 coalesceMask:NSNotificationCoalescingOnName|NSNotificationCoalescingOnSender
							forModes:NULL];
		}
	}
}//end partChanged:


//========== docChanged: =======================================================
//
// Purpose:		This notification is sent to us when something in our document
//				has changed; it's the asynchronous coalesced result of
//				partChanged being called within our document.
//
// Notes:		This notification is always asynchronous and coalesced; the 
//				result is that it happens about once for an entire edit or undo
//				operation.  This is where we do the expensive stuff like
//				resync the hierarchy and update the menus.
//
//==============================================================================
- (void)docChanged:(NSNotification *)notification
{
	// This functionality was in partChanged through Bricksmith 3.0.
	[fileContentsOutline selectObjects:selectedDirectives];
	[fileContentsOutline reloadData];

	[self updateInspector];

	// Technically we don't need to redo the model menu on every UI edit.  In the
	// future we should add specific notifications or directive observations to
	// detect this case. But 3.0 and earlier ran this once for every edit (when
	// part changes were escalated to doc changes) and then twice on real model
	// changes (because we'd hit the case on the model and again on the doc).
	//
	// In practice it doesn't matter - for now, for the test cases we have,
	// rebuilding the menus is relatively cheap.  A user can only add so many
	// MPD parts to a file without going completely insane.
	[self addModelsToMenus];

}//end docChanged:


//========== stepChanged: ======================================================
//
// Purpose:		A step changed its numeric attributes, e.g. the viewing angle,
//				typically by the inspector editing.  We get a direct 
//				notification from the step and can resync our viewing angles
//				if needed.
//
//==============================================================================
- (void)stepChanged:(NSNotification *)notification
{
	LDrawDirective *changedDirective = [notification object];
	LDrawFile *docContents = [self documentContents];

	if([[changedDirective ancestors] containsObject:docContents])		
	if([[docContents activeModel] stepDisplay] == YES)
	{
		// TODO: new notification for this to get out of hot path?!?
		[self updateViewingAngleToMatchStep];
	}
}//end stepChanged:


//========== syntaxColorChanged: ===============================================
//
// Purpose:		The preferences have been updated; we need to refresh our data 
//				display.
//
//==============================================================================
- (void) syntaxColorChanged:(NSNotification *)notification
{
	[fileContentsOutline reloadData];
	
}//end syntaxColorChanged:


//**** NSWindow ****
//========== windowDidBecomeMain: ==============================================
//
// Purpose:		The window has come to the foreground.
//
//==============================================================================
- (void) windowDidBecomeMain:(NSNotification *)aNotification
{
	[self updateInspector];

	[self addModelsToMenus];
	[self buildRelatedPartsMenus];
	
}//end windowDidBecomeMain:


//**** NSWindow ****
//========== windowDidResize: ==================================================
//
// Purpose:		As the window changes size, we must record the new dimensions 
//				for autosaving purposes. 
//
// Notes:		Snow Leopard adds windowDidEndLiveResize which may be more 
//				appropriate. 
//
//==============================================================================
- (void) windowDidResize:(NSNotification *)notification
{
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	NSWindow		*window			= [notification object];
	
	// Don't do anything for the resizing that happens during awakeFromNib.
	if([window isVisible])
	{
		// In Leopard, we don't have any control over split view autosaving. It 
		// is saved every time the split view resizes. Since the split view size 
		// is dependent on the window size, we must save it at the same time. 
		// Otherwise, we could open a new document after resizing another one 
		// and the split views would not match the window size. 
	
		[userDefaults setObject:NSStringFromSize([window frame].size)
						 forKey:DOCUMENT_WINDOW_SIZE];
	}
	
}//end windowDidResize:


//**** NSWindow ****
//========== windowWillClose: ==================================================
//
// Purpose:		The window is about to close; let's save some state info.
//
//==============================================================================
- (void) windowWillClose:(NSNotification *)notification
{
	NSUserDefaults	*userDefaults	= [NSUserDefaults standardUserDefaults];
	NSWindow		*window			= [notification object];
	
	[userDefaults setInteger:[partBrowserDrawer state]	forKey:PART_BROWSER_DRAWER_STATE];
	
	//Un-inspect everything
	[[LDrawApplication sharedInspector] inspectObjects:nil];
	
	// Bug: if this document isn't the foremost window, this will botch up the 
	//		menu! Remember, we can close windows in the background. 
	if([window isMainWindow] == YES){
		[self clearModelMenus];
	}
	
	[self->bindingsController setContent:nil];
	
}//end windowWillClose:


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


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== addModel: =========================================================
//
// Purpose:		Add newModel to the current file.
//
// Notes:		Duplicate model names are verboten if renameModels is true, so 
//				if newModel's name matches an existing model name, an approriate 
//				"copy X" will be appended automatically. 
//
//				There is a bug here in that if several models having references 
//				to one another are pasted at once into a file with name 
//				conflicts, the file reference structure of the pasted models 
//				will point to the wrong names once this method does its renaming 
//				magic. To this I respond, "don't do that."
//
//==============================================================================
- (void) addModel:(LDrawMPDModel *)newModel atIndex:(NSInteger)insertAtIndex preventNameCollisions:(BOOL)renameModels
{
	NSString        *proposedModelName  = [newModel modelName];
	NSUndoManager   *undoManager        = [self undoManager];
	NSInteger       rowForItem          = 0;
	
	// Derive a non-duplicating name for this new model
	if(renameModels == YES)
	{
		while([[self documentContents] modelWithName:proposedModelName] != nil)
		{
			proposedModelName = [StringUtilities nextCopyPathForFilePath:proposedModelName];
		}
		[newModel setModelName:proposedModelName];
	}
	
	// Insert
	if(insertAtIndex == NSNotFound)
	{
		[self addDirective:newModel toParent:[self documentContents]];
	}
	else
	{
		[self addDirective:newModel toParent:[self documentContents] atIndex:insertAtIndex];
	}
	
	// Select the new model.
	// Ben says: why is it legal for us to directly synchronously select the mode? (This is one of the 
	// only cases where we do?)  Adding a directive to the parent file (which is what adding a model
	// does) causes us to get a notification _directly_ off of the doc's file. Notifications off of 
	// the doc's file are handled synchronously, so by the time we get here, we are totally UI-synced.
	//
	// This is good because we are also going to hierarchy-expand our new model to reveal its first
	// step, so we this code is going to have to talk to the outliner no matter what.
	[fileContentsOutline expandItem:newModel];
	rowForItem = [fileContentsOutline rowForItem:newModel];
	[fileContentsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:rowForItem]
					 byExtendingSelection:NO];
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddModel", nil)];
	
}//end addModel:


//========== addStep:parent:index: =============================================
//
// Purpose:		Adds newStep to the currently-displayed model. If you specify an 
//				index, it will be inserted there. Otherwise, the step appears at 
//				the end of the list. 
//
//==============================================================================
- (void) addStep:(LDrawStep *)newStep parent:(LDrawMPDModel*)selectedModel index:(NSInteger)insertAtIndex
{
	NSUndoManager	*undoManager	= [self undoManager];
	
	// Synchronize our addition with the model currently active.
	if(selectedModel == nil)
		selectedModel = [[self documentContents] activeModel];
	else
		[[self documentContents] setActiveModel:selectedModel];
	
	// Insert
	if(insertAtIndex == NSNotFound)
	{
		[self addDirective:newStep toParent:selectedModel];
	}
	else
	{
		[self addDirective:newStep toParent:selectedModel atIndex:insertAtIndex];
	}
	
	[undoManager setActionName:NSLocalizedString(@"UndoAddStep", nil)];	
	[self flushDocChangesAndSelect:[NSArray arrayWithObject:newStep]];
	
}//end addStep:


//========== addPartNamed: =====================================================
//
// Purpose:		Adds a part with the given name to the current step in the 
//				currently-displayed model.
//
//==============================================================================
- (void) addPartNamed:(NSString *)partName
{
	LDrawPart           *newPart        = [[LDrawPart alloc] init];
	NSUndoManager       *undoManager    = [self undoManager];
	LDrawColor          *selectedColor  = [[LDrawColorPanelController sharedColorPanel] LDrawColor];
	TransformComponents transformation  = IdentityComponents;
	
	//We got a part; let's add it!
	if(partName != nil)
	{
		//Set up the part attributes
		[newPart setLDrawColor:selectedColor];
		[newPart setDisplayName:partName];
		
		if(self->lastSelectedPart != nil)
		{
			// Collect the transformation from the previous part and apply it to 
			// the new one. 
			transformation = [lastSelectedPart transformComponents];
			[newPart setTransformComponents:transformation];
		}
		
		[self addStepComponent:newPart parent:nil index:NSNotFound];
		
		[undoManager setActionName:NSLocalizedString(@"UndoAddPart", nil)];
		[self flushDocChangesAndSelect:[NSArray arrayWithObject:newPart]];
	}
}//end addPartNamed:


//========== addStepComponent: =================================================
//
// Purpose:		Adds newDirective to the bottom of the current step, or after 
//				the currently-selected element in the step if there is one.
//
// Parameters:	newDirective: a directive which can be added to a step. These 
//						include parts, geometric primitives, and comments.
//				parent - requested target step; if nil, uses the default behavior
//				insertAtIndex - index in parent.
//
// Note:			This routine _no longer_ selects the added step component!  All
//				code that calls addStepComponent must manage selection on its
//				own.  Selection has been pulled out of addStepComponent because
//				many operations involve a large number of step components;
//				editing the selection per directive turns into a huge
//				performance problem.
//
//==============================================================================
- (void) addStepComponent:(LDrawDirective *)newDirective
				   parent:(LDrawContainer*)parent
					index:(NSInteger)insertAtIndex
{
	LDrawContainer	*targetContainer	= parent;
	LDrawMPDModel	*selectedModel		= [self selectedModel];

	// Synchronize our addition with the model currently active.
	if(selectedModel == nil)
		selectedModel = [[self documentContents] activeModel];
	else
		[[self documentContents] setActiveModel:selectedModel];
	
	// We may have the model itself selected, in which case we will add this new 
	// element to the very bottom of the model.
	if(targetContainer == nil)
	{
		LDrawContainer *selectedContainer = [self selectedContainer];
		
		if(		selectedContainer != nil
		   &&	[selectedContainer isKindOfClass:[LDrawFile class]] == NO
		   &&	[selectedContainer isKindOfClass:[LDrawModel class]] == NO
		   &&	[selectedContainer isKindOfClass:[LDrawStep class]] == NO
           &&   [selectedContainer acceptsDroppedDirective:newDirective] == YES)
		{
			// If we have an "interesting" container selected -- like a texture 
			// -- that accepts the dropped directive add directives to it instead
			// of at the end of the model. The theory here is that these special
			// containers are kind of their  own little world, and as long as you
			// have one selected, you should continue working within it.
			targetContainer = selectedContainer;
		}        
        // We can't find a container that wants this part so add it to the bottom of the model
		else
		{
			targetContainer = [selectedModel visibleStep];
		}
	}
	if(insertAtIndex == NSNotFound)
	{
		// At a user's request, all new components are inserted in the last 
		// visible step. That's how duplicating drag-and-drops work anyway. 
		[self addDirective:newDirective toParent:targetContainer ];
	}
	else
	{
		[self addDirective:newDirective toParent:targetContainer atIndex:insertAtIndex ];
	}

	// This code used to do a synchronous doc update and select the part right here.
	// This has been removed and hoisted out to the calling code - pretty much anyone
	// calling this should call flushDocChangesAndSelect.

	// Allow us to immediately use the keyboard to move the new part.
	[[self foremostWindow] makeFirstResponder:mostRecentLDrawView];
	
}//end addStepComponent:


#pragma mark -

//========== canDeleteDirective:displayErrors: =================================
//
// Purpose:		Tests whether the specified directive should be allowed to be 
//				deleted. If errorFlag is YES, also displays an appropriate error 
//				sheet explaining the reasons why directive cannot be deleted.
//
//==============================================================================
- (BOOL) canDeleteDirective:(LDrawDirective *)directive
			  displayErrors:(BOOL)errorFlag
{
	LDrawContainer	*parentDirective	= [directive enclosingDirective];
	BOOL			 isLastDirective	= ([[parentDirective subdirectives] count] <= 1);
	NSAlert			*alert				= nil;
	NSString		*message			= nil;
	NSString		*informative		= nil;
	BOOL			 canDelete			= YES;
	
	if([directive isKindOfClass:[LDrawModel class]] && isLastDirective == YES)
	{
		canDelete = NO;
		informative = NSLocalizedString(@"DeleteLastModelInformative", nil);
	}
	else if([directive isKindOfClass:[LDrawStep class]] && isLastDirective == YES)
	{
		canDelete = NO;
		informative = NSLocalizedString(@"DeleteLastStepInformative", nil);
	}
	
	if(canDelete == NO && errorFlag == YES)
	{
		message = NSLocalizedString(@"DeleteDirectiveError", nil);
		message = [NSString stringWithFormat:message, [directive browsingDescription]];
		
		alert = [[NSAlert alloc] init];		
		[alert setMessageText:message];
		[alert setInformativeText:informative];
		
		[alert addButtonWithTitle:NSLocalizedString(@"OKButtonName", nil)];
		
		[alert beginSheetModalForWindow:[self windowForSheet]
					  completionHandler:nil];

		
	}
	
	
	return canDelete;
	
}//end canDeleteDirective:displayErrors:


//========== elementsAreSelectedOfVisibility: ==================================
//
// Purpose:		Returns YES if there are elements selected which have the 
//				requested visibility. 
//
//==============================================================================
- (BOOL) elementsAreSelectedOfVisibility:(BOOL)visibleFlag
{
	NSArray     *selectedObjects    = [self selectedObjects];
	id          currentObject       = nil;
	NSInteger   counter             = 0;
	BOOL        invisibleSelected   = NO;
	BOOL        visibleSelected     = NO;
	
	
	for(counter = 0; counter < [selectedObjects count]; counter++)
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		if([currentObject respondsToSelector:@selector(isHidden)])
		{
			invisibleSelected	= invisibleSelected || [currentObject isHidden];
			visibleSelected		= visibleSelected   || ([currentObject isHidden] == NO);
		}
	}
	
	if(visibleFlag == YES)
		return visibleSelected;
	else
		return invisibleSelected;
		
}//end elementsAreSelectedOfVisibility:


//========== formatDirective:withStringRepresentation: =========================
//
// Purpose:		Applies syntax coloring to the specified directive, which will 
//				be displayed with the text representation.
//
//==============================================================================
- (NSAttributedString *) formatDirective:(LDrawDirective *)item
				withStringRepresentation:(NSString *)representation
{
	NSUserDefaults			*userDefaults	= [NSUserDefaults standardUserDefaults];
	NSString				*colorKey		= nil; //preference key for object's syntax color.
	NSColor					*syntaxColor	= nil;
	NSNumber				*obliqueness	= [NSNumber numberWithDouble:0.0]; //italicize?
	NSAttributedString		*styledString	= nil;
	NSMutableDictionary		*attributes		= [NSMutableDictionary dictionary];
	NSMutableParagraphStyle	*paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
	//We want the text to appear nicely truncated in its column.
	// By setting the column to wrap and then setting the paragraph wrapping to 
	// truncate, we achieve the desired effect.
	[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	
	//Find the specified syntax color for the directive.
	if([item isKindOfClass:[LDrawModel class]])
		colorKey = SYNTAX_COLOR_MODELS_KEY;
	
	else if([item isKindOfClass:[LDrawStep class]])
		colorKey = SYNTAX_COLOR_STEPS_KEY;
	
	else if([item isKindOfClass:[LDrawComment class]])
		colorKey = SYNTAX_COLOR_COMMENTS_KEY;
		
	else if([item isKindOfClass:[LDrawPart class]])
		colorKey = SYNTAX_COLOR_PARTS_KEY;

    else if ([item isKindOfClass:[LDrawLSynth class]] ||
             [item isKindOfClass:[LDrawLSynthDirective class]])
        colorKey = SYNTAX_COLOR_PARTS_KEY;

	else if([item isKindOfClass:[LDrawLine				class]] ||
	        [item isKindOfClass:[LDrawTriangle			class]] ||
			[item isKindOfClass:[LDrawQuadrilateral		class]] ||
			[item isKindOfClass:[LDrawConditionalLine	class]]    )
		colorKey = SYNTAX_COLOR_PRIMITIVES_KEY;
	
	else if([item isKindOfClass:[LDrawColor class]])
		colorKey = SYNTAX_COLOR_COLORS_KEY;
	
	else
		colorKey = SYNTAX_COLOR_UNKNOWN_KEY;
	
	//We have the syntax coloring we want.
	syntaxColor = [userDefaults colorForKey:colorKey];
	
	if([item respondsToSelector:@selector(isHidden)])
		if([(id)item isHidden])
			obliqueness = [NSNumber numberWithDouble:0.5];
	
	
	//Assemble the attributes dictionary.
	[attributes setObject:paragraphStyle	forKey:NSParagraphStyleAttributeName];
	[attributes setObject:syntaxColor		forKey:NSForegroundColorAttributeName];
	[attributes setObject:obliqueness		forKey:NSObliquenessAttributeName];
	
	//Create the attributed string.
    styledString = [[NSAttributedString alloc]
							initWithString:representation
								attributes:attributes ];
	
	//Release stuff we created or copied.
	
	return styledString;

}//end formatDirective:withStringRepresentation:


//========== loadDataIntoDocumentUI ============================================
//
// Purpose:		Informs the document's user interface widgets about the contents 
//				of the document they are supposed to be representing.
//
//				There are two occasions when this method must be called:
//					1) immediately after the document UI has first been loaded
//						(in windowControllerDidLoadNib:)
//					2) when reverting the document.
//						(in revertToSavedFromFile:ofType:)
//
//==============================================================================
- (void) loadDataIntoDocumentUI
{
	NSArray<LDrawGLView*>*	graphicViews	= [self all3DViewports];
	NSUInteger				counter 		= 0;

	for(counter = 0; counter < [graphicViews count]; counter++)
	{
		[[graphicViews objectAtIndex:counter] setLDrawDirective:[self documentContents]];
	}
	[self->fileContentsOutline	reloadData];
	
	[self addModelsToMenus];
	
	[self buildRelatedPartsMenus];

}//end loadDataIntoDocumentUI


//========== selectedContainer =================================================
//
// Purpose:		Returns the step that encloses (or is) the current selection, or
//				nil if there is no step in the selection chain.
//
//==============================================================================
- (LDrawContainer *) selectedContainer
{
	NSInteger		selectedRow 		= [fileContentsOutline selectedRow];
	id				selectedItem		= [fileContentsOutline itemAtRow:selectedRow];
	LDrawContainer	*selectedContainer	= nil;
	
	// Hack alert!
	// If we are doing a copy-drag operation, remember the original selection 
	// and use it. (We can't use the current selection during copy drag because 
	// we clear it when the drag begins.)
	if([self->selectedDirectivesBeforeCopyDrag count] > 0)
		selectedItem = [selectedDirectivesBeforeCopyDrag objectAtIndex:0];
	
	// Find selected container
	if([selectedItem isKindOfClass:[LDrawContainer class]])
		selectedContainer = selectedItem;
	else
		selectedContainer = [selectedItem enclosingDirective];
	
	return selectedContainer;
	
}//end selectedContainer


//========== selectedObjects ===================================================
//
// Purpose:		Returns the LDraw objects currently selected in the file.
//
//==============================================================================
- (NSArray *) selectedObjects
{
	NSIndexSet      *selectedIndexes    = [fileContentsOutline selectedRowIndexes];
	NSUInteger      currentIndex        = [selectedIndexes firstIndex];
	NSMutableArray  *selectedObjects    = [NSMutableArray arrayWithCapacity:[selectedIndexes count]];
	id              currentObject       = nil;
	
	//Search through all the indexes and get the objects associated with them.
	while(currentIndex != NSNotFound){
	
		currentObject = [fileContentsOutline itemAtRow:currentIndex];
		[selectedObjects addObject:currentObject];
		
		currentIndex = [selectedIndexes indexGreaterThanIndex:currentIndex];
	}
	
	return selectedObjects;
	
}//end selectedObjects


//========== selectedModel =====================================================
//
// Purpose:		Returns the model that encloses the current selection, or nil 
//				if there is no selection.
//
// Note:		If you intend to use this method's output to figure out which 
//				model to display, then you need to convert a nil case into the 
//				active model.
//
//==============================================================================
- (LDrawMPDModel *) selectedModel
{
	NSInteger   selectedRow     = [fileContentsOutline selectedRow];
	id          selectedItem    = [fileContentsOutline itemAtRow:selectedRow];
	
	return (LDrawMPDModel*)[selectedItem enclosingModel];

}//end selectedModel


//========== selectedModel =====================================================
//
// Purpose:		Returns the step that encloses (or is) the current selection, or  
//				nil if there is no step in the selection chain.
//
//==============================================================================
- (LDrawStep *) selectedStep
{
	NSInteger   selectedRow     = [fileContentsOutline selectedRow];
	id          selectedItem    = [fileContentsOutline itemAtRow:selectedRow];
	
	return [selectedItem enclosingStep];

}//end selectedStep


//========== selectedStepComponent =============================================
//
// Purpose:		Returns the drawable LDraw element that is currently selected.
//				(e.g., Part, Quadrilateral, Triangle, etc.)
//
//				Returns nil if the selection is not one of these atomic LDraw
//				commands.
//
//==============================================================================
- (LDrawDirective *) selectedStepComponent
{
	NSInteger   selectedRow     = [fileContentsOutline selectedRow];
	id          selectedItem    = [fileContentsOutline itemAtRow:selectedRow];
	
	//If a model is selected, a step can't be!
	if(		selectedItem == nil
       ||	[selectedItem isKindOfClass:[LDrawFile class]]
	   ||	[selectedItem isKindOfClass:[LDrawModel class]]
	   ||	[selectedItem isKindOfClass:[LDrawStep class]] )
		return nil;
	
	else { //it's not a file, model, or step; whatever it is, it's what we are 
			// looking for.
		return selectedItem;
	}
}//end selectedStep


//========== selectedPart ======================================================
//
// Purpose:		Returns the first part that is currently selected, or nil if no 
//				part is selected.
//
//==============================================================================
- (LDrawPart *) selectedPart
{
	NSArray     *selectedObjects    = [self selectedObjects];
	id          currentObject       = nil;
	NSInteger   counter             = 0;
	
	while(counter < [selectedObjects count])
	{
		currentObject = [selectedObjects objectAtIndex:counter];
		if([currentObject isKindOfClass:[LDrawPart class]])
			break;
		else
			counter++;
	}
	
	//Either we just found one, on we found nothing.
	return currentObject;
}//end 


//========== updateInspector ===================================================
//
// Purpose:		Updates the Inspector to display the currently-selected objects.
//				This should be called in response to any potentially state-
//				changing actions on a directive.
//
//==============================================================================
- (void) updateInspector
{
	NSArray *selectedObjects = [self selectedObjects];
	
	[[LDrawApplication sharedInspector] inspectObjects:selectedObjects];
	[[LDrawColorPanelController sharedColorPanel] updateSelectionWithObjects:selectedObjects];
	
}//end updateInspector


//========== updateViewingAngleToMatchStep =====================================
//
// Purpose:		Sets the viewing angle of the main viewport to the angle 
//				requested by the current step for Step Display mode. 
//
//==============================================================================
- (void) updateViewingAngleToMatchStep
{
	LDrawMPDModel       *activeModel        = [[self documentContents] activeModel];
	NSInteger           requestedStep       = [activeModel maximumStepIndexForStepDisplay];
	Tuple3              viewingAngle        = [activeModel rotationAngleForStepAtIndex:requestedStep];
	ViewOrientationT    viewOrientation     = [LDrawUtilities viewOrientationForAngle:viewingAngle];
	LDrawGLView         *affectedViewport   = [self main3DViewport];
	
	// Set the Viewing angle
	if(viewOrientation != ViewOrientation3D)
		[affectedViewport setProjectionMode:ProjectionModeOrthographic];
	else
		[affectedViewport setProjectionMode:ProjectionModePerspective];
	
	[affectedViewport setViewOrientation:viewOrientation];
	[affectedViewport setViewingAngle:viewingAngle];
	[affectedViewport setLocationMode:LocationModeModel];
	
}//end updateViewingAngleToMatchStep


//========== writeDirectives:toPasteboard: =====================================
//
// Purpose:		Writes objects to the given pasteboard, ensuring that each 
//				directive is written only once.
//
//				This method places two arrays on the pasteboard for these types:
//				* LDrawDirectivePboardType: array of LDrawDirectives converted 
//							to NSData objects.
//				* NSStringPboardType: array of strings representing the objects 
//							in the format written to an LDraw file.
//
// Notes:		This method will clear the contents of the pasteboard.
//
//==============================================================================
- (void) writeDirectives:(NSArray *)directives
			toPasteboard:(NSPasteboard *)pasteboard
{
	//Pasteboard types.
	NSArray			*pboardTypes		= [NSArray arrayWithObjects:
												LDrawDirectivePboardType, //Bricksmith's preferred type.
												NSStringPboardType, //representation for other applications.
												nil ];
	LDrawDirective	*currentObject		= nil;
	NSMutableArray	*objectsToCopy		= [NSMutableArray array];
	//list of containers we've already archived. We don't want to re-archive any 
	// of their children.
	NSMutableArray	*archivedContainers	= [NSMutableArray array];
	NSData			*data				= nil;
	NSString		*string				= nil;
	//list of LDrawDirectives which have been converted to data.
	NSMutableArray	*archivedObjects	= [NSMutableArray array];
	//list of LDrawDirectives which have been converted to strings.
	NSMutableString	*stringedObjects	= [NSMutableString stringWithCapacity:256];
	NSInteger		counter				= 0;
	
	//Write out the selected objects, but only once for each object. 
	// Don't write out items whose parent is selected; the parent will 
	// automatically write its children.
	for(counter = 0; counter < [directives count]; counter++)
	{
		currentObject = [directives objectAtIndex:counter];
		//If we haven't already run into this object (via its parent container)
		// then we want to write it out. Otherwise, it will be copied implicitly 
		// along with its parent rather than copied explicitly.
		if([currentObject isAncestorInList:archivedContainers] == NO){
			[objectsToCopy addObject:currentObject];
		}
		//If this object is a container, we must record that it has been 
		// archived. Either it was archived just now, or it was archived 
		// earlier when its parent was archived.
		if([currentObject isKindOfClass:[LDrawContainer class]]){
			[archivedContainers addObject:currentObject];
		}
	}
	
	
	//Now that we have figured out *what* to copy, convert it into the 
	// *representations* we will use to copy.
	for(counter = 0; counter < [objectsToCopy count]; counter++)
	{
		currentObject = [objectsToCopy objectAtIndex:counter];
		
		//Convert the object into the two representations we know how to write.
		data	= [NSKeyedArchiver archivedDataWithRootObject:currentObject];
		string	= [currentObject write];
		
		//Save the representations into the arrays we'll write to the pasteboard.
		[archivedObjects addObject:data];
		[stringedObjects appendFormat:@"%@\n", string];
								//not using CRLF here because any Mac program that 
								// knows enough to do DOS line-endings will automatically
								// add them to pasted content.
	}
	
	
	//Set up our pasteboard.
	[pasteboard declareTypes:pboardTypes owner:nil];
	
	//Internally, Bricksmith uses archived LDrawDirectives to copy/paste.
	[pasteboard setPropertyList:archivedObjects forType:LDrawDirectivePboardType];
	
	//For other applications, however, we provide the LDraw file contents for 
	// the objects. Note that these strings cannot be pasted back into the 
	// program.
	[pasteboard setString:stringedObjects forType:NSStringPboardType];
	
}//end writeDirectives:toPasteboard:


//========== pasteFromPasteboard: ==============================================
//
// Purpose:		Paste the directives on the given pasteboard into the document.
//				The pasteboard must contain LDrawDirectivePboardType.
//
//				By generalizing the method in this way, we allow pasting off 
//				private internal pasteboards too. This method is used by 
//				-duplicate: in order to leverage the existing copy/paste code 
//				without wantonly destroying the contents of the General 
//				Pasteboard.
//
// Returns:		The objects added, or nil if nothing was on the pasteboard.
//
// Parameters:	pasteboard		- where the archived directives live
//				renameModels	- add "copy X" suffixes to pasted models as needed. 
//				parent			- add objects to this component (pass nil for default behavior)
//				insertAtIndex	- child index within parent (pass NSNotFound for default behavior)
//
//==============================================================================
- (NSArray *) pasteFromPasteboard:(NSPasteboard *) pasteboard
			preventNameCollisions:(BOOL)renameModels
						   parent:(LDrawContainer*)parent
							index:(NSInteger)insertAtIndex
{
	NSArray         *objects        = nil;
	id              currentObject   = nil; //some kind of unarchived LDrawDirective
	NSData          *data           = nil;
	NSMutableArray  *addedObjects   = [NSMutableArray array];
	NSInteger       counter         = 0;
		
	//We must make sure we have the proper pasteboard type available.
 	if([[pasteboard types] containsObject:LDrawDirectivePboardType])
	{
		//Unarchived everything and dump it into our file.
		objects = [pasteboard propertyListForType:LDrawDirectivePboardType];
		for(counter = 0; counter < [objects count]; counter++)
		{
			NSInteger real_index = insertAtIndex;
			if(real_index != NSNotFound)	real_index += counter;
			data			= [objects objectAtIndex:counter];
			currentObject	= [NSKeyedUnarchiver unarchiveObjectWithData:data];

            // Reset the object icon if we can.  New parents get a chance later (in e.g. outlineView:acceptDrop:)
            // to change them if they want
            if ([[currentObject class] respondsToSelector:@selector(defaultIconName)]) {
                NSString *iconName = [[currentObject class] performSelector:@selector(defaultIconName)];
                if (iconName) {
                    [currentObject setIconName:iconName];
                }
            }

			//Now pop the data into our file.
			if([currentObject isKindOfClass:[LDrawModel class]])
                [self addModel:currentObject atIndex:real_index preventNameCollisions:renameModels];
			else if([currentObject isKindOfClass:[LDrawStep class]])
				[self addStep:currentObject parent:(LDrawMPDModel*)parent index:real_index];
			else
			{
				[self addStepComponent:currentObject parent:parent index:real_index];
			}
			
			[addedObjects addObject:currentObject];
		}
		
		[self flushDocChangesAndSelect:addedObjects];

	}
	
	return addedObjects;
	
}//end pasteFromPasteboard:


//========== flushDocChangesAndSelect: =========================================
//
// Purpose:		This routine does two tasks that are almost always done 
//				together in most UI code:
//
//				(1) it "flushes" pending asynchronous UI updates by
//					directly posting a directive change (on our doc's file)
//					synchronously with coalescing. When this finishes, the 
//					outliner, model menu, etc. are all "synced up".
//
//				(2) it then completely changes the selection to a new set
//					of directives.  That could be 0, 1 or many directives.
//
// Notes:		This routine should be done once at the end of an editing
//				function; the sync and selection change are quite affordable
//				performance wise if they are done once per user edit.
//
//				This function should _not_ be done in lower level utility 
//				functions, undoable methods, or inside an iteration loop.
//
//				Typical use will be to make a series of low level directive
//				changes (all which post async doc updates) and then flush and
//				select once when all editing work is finished.
//==============================================================================
- (void) flushDocChangesAndSelect:(NSArray*)directives
{
	LDrawFile *docContents = [self documentContents];

	// Post a notification that our doc changed; LDrawGLView needs this 
	// to refresh drawing, and we ned it to redo our menus.
	NSNotification * doc_notification = 
		[NSNotification notificationWithName:LDrawDirectiveDidChangeNotification 
									 object:docContents];

	// Notification is queued and coalesced; 
	[[NSNotificationQueue defaultQueue] 
			enqueueNotification:doc_notification 
				postingStyle:NSPostNow 
				coalesceMask:NSNotificationCoalescingOnName|NSNotificationCoalescingOnSender
					forModes:NULL];
					
	[self selectDirectives:directives];
}//end flushDocChangesAndSelect:


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		We're crossing over Jordan; we're heading to that mansion just 
//				over the hilltop (the gold one that's silver-lined).
//
// Note:		We DO NOT RELEASE TOP-LEVEL NIB OBJECTS HERE! NSWindowController 
//				does that automagically.
//
//==============================================================================
- (void) dealloc
{
	if ([NSThread isMainThread])
	{
		[[ModelManager sharedModelManager] documentSignOut:documentContents];
	}
	else
	{
		// This punt to the main thread tries to ensure that in the case when
		// our doc is dropped from a worker dispatch Q.  This happens on Sierra
		// and newer when we quit and save during the quit.
	
		// I think if we use documentContents we capture self - which takes a ref
		// from inside dealloc which blows up the obj-C runtime.
		LDrawFile * doc = documentContents;
		dispatch_async(dispatch_get_main_queue(),^{
			[[ModelManager sharedModelManager] documentSignOut:doc];
		});
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	
}//end dealloc

@end
