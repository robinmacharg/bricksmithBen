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
