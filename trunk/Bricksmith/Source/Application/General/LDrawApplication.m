//==============================================================================
//
// File:		LDrawApplication.h
//
// Purpose:		This is the "application controller." Here we find application-
//				wide instance variables and actions, as well as application 
//				delegate code for startup and shutdown.
//
// Note:		Do not confuse this class with BricksmithApplication, which is 
//				an NSApplication subclass.
//
//  Created by Allen Smith on 2/14/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import "LDrawApplication.h"

#import <Sparkle/Sparkle.h>

#import "DonationDialogController.h"
#import "Inspector.h"
#import "LDrawColorPanelController.h"
#import "LDrawDocument.h"
#import "LDrawPaths.h"
#import "MacLDraw.h"
#import "PartBrowserPanelController.h"
#import "PartLibrary.h"
#import "PartLibraryController.h"
#import "LSynthConfiguration.h"
#import "PreferencesDialogController.h"
#import "ToolPalette.h"
#import "TransformerIntMinus1.h"
#import "MLCadIni.h"

@implementation LDrawApplication

//---------- initialize ----------------------------------------------[static]--
//
// Purpose:		Load things that need to be loaded *extremely* early in startup.
//
//------------------------------------------------------------------------------
+ (void) initialize
{
	TransformerIntMinus1 *minus1Transformer = [[[TransformerIntMinus1 alloc] init] autorelease];
	
	[NSValueTransformer setValueTransformer:minus1Transformer
									forName:@"TransformerIntMinus1" ];
}//end initialize


#pragma mark -
#pragma mark ACCESSORS
#pragma mark -

//---------- isRunningTests ------------------------------------------[static]--
//
// Purpose:		YES when the app is hosting unit tests (XCTest sets
//				XCTestConfigurationFilePath) or was launched by a UI test
//				(which sets BRICKSMITH_TEST_MODE=1 in its launch environment).
//
// Notes:		Test mode keeps what documents need (shared GL context,
//				Inspector, LSynth configuration) but skips every side effect
//				outside the process: LDraw folder discovery and the defaults
//				write it makes, the part catalog load (tests inject their own
//				library), Sparkle, the donation prompt, untitled documents,
//				autosave and the defaults written at quit.
//
//------------------------------------------------------------------------------
+ (BOOL) isRunningTests
{
	static BOOL				testing	= NO;
	static dispatch_once_t	once;

	dispatch_once(&once, ^{
		NSDictionary *environment = [[NSProcessInfo processInfo] environment];
		testing =	[environment objectForKey:@"XCTestConfigurationFilePath"] != nil
				||	[[environment objectForKey:@"BRICKSMITH_TEST_MODE"] isEqualToString:@"1"];
	});

	return testing;

}//end isRunningTests


//---------- openGLPixelFormat ---------------------------------------[static]--
//
// Purpose:		Returns the pixel format used in Bricksmith OpenGL views.
//
//------------------------------------------------------------------------------
+ (NSOpenGLPixelFormat *) openGLPixelFormat
{
	NSOpenGLPixelFormat				*pixelFormat		= nil;
	NSOpenGLPixelFormatAttribute	pixelAttributes[]	= {
															NSOpenGLPFANoRecovery, // Enable automatic use of OpenGL "share" contexts for Core Animation.
															NSOpenGLPFADoubleBuffer,
															NSOpenGLPFADepthSize,		32,
															NSOpenGLPFASampleBuffers,	1, // enable line antialiasing
															NSOpenGLPFASamples,			4, // antialiasing beauty
															0};

	pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes: pixelAttributes];
	return [pixelFormat autorelease];
}


//========== shared ============================================================
///
/// @abstract	Returns the singleton LDrawApplication.
///
//==============================================================================
+ (LDrawApplication *) shared
{
	return (LDrawApplication *)[NSApp delegate];
}


//---------- sharedInspector -----------------------------------------[static]--
//
// Purpose:		Returns the inspector object, which is created when the 
//				application launches.
//
// Note:		This method is static, so we don't have to keep passing pointers 
//				to this class around.
//
//------------------------------------------------------------------------------
+ (Inspector *) sharedInspector
{
	return [[LDrawApplication shared] inspector];
	
}//end sharedInspector


//---------- sharedOpenGLContext -------------------------------------[static]--
//
// Purpose:		Returns the OpenGLContext which unifies our display-list tags.
//				Every LDrawGLView should share this context.
//
//------------------------------------------------------------------------------
+ (NSOpenGLContext *) sharedOpenGLContext
{
	return [[LDrawApplication shared] openGLContext];
	
}//end sharedOpenGLContext


//---------- sharedPartLibraryController -----------------------------[static]--
//
// Purpose:		Returns the object which manages the part libary.
//
// Note:		This method is static, so we don't have to keep passing pointers 
//				to this class around.
//
//------------------------------------------------------------------------------
+ (PartLibraryController *) sharedPartLibraryController
{
	//Rather than making the part library a global variable, I decided to make 
	// it an instance variable of the Application Controller class, of which 
	// there is only one instance. This class is the application delegate too.
	PartLibraryController *libraryController = [[LDrawApplication shared] partLibraryController];
	
	return libraryController;
	
}//end sharedPartLibrary


//========== inspector =========================================================
//
// Purpose:		Returns the local instance of the inspector, which should be 
//				the only copy of it in the program.
//
//==============================================================================
- (Inspector *) inspector
{
	return inspector;
	
}//end inspector


//========== partLibraryController =============================================
//
// Purpose:		Returns the local instance of the part library controller, which 
//				should be the only copy of it in the program. You can access the 
//				part library itself through this object. 
//
//==============================================================================
- (PartLibraryController *) partLibraryController
{
	return partLibraryController;
	
}//end partLibraryController


//========== lsynthConfiguration ===============================================
//
// Purpose:		Returns the local instance of the LSynth configuration.
//
//==============================================================================
- (LSynthConfiguration *) lsynthConfiguration
{
	return lsynthConfiguration;
	
}//end lsynthConfiguration


//========== sharedOpenGLContext ===============================================
//
// Purpose:		Returns the OpenGLContext which unifies our display-list tags.
//				Every LDrawGLView should share this context.
//
//==============================================================================
- (NSOpenGLContext *) openGLContext
{
	return self->sharedGLContext;
	
}//end openGLContext


#pragma mark -
#pragma mark ACTIONS
#pragma mark -

//#pragma mark -
#pragma mark Application Menu

//========== doPreferences =====================================================
//
// Purpose:		Show the preferences window.
//
//==============================================================================
- (IBAction) doPreferences:(id)sender
{
	[PreferencesDialogController doPreferences];
	
}//end doPreferences:


//========== doDonate: =========================================================
//
// Purpose:		Takes the user to a webpage where they can give me money!
//				(Here's hoping.)
//
//==============================================================================
- (IBAction) doDonate:(id)sender
{
	NSURL *donationURL = [NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=6985549"];

	[[NSWorkspace sharedWorkspace] openURL:donationURL];
	
}//end doDonate:


#pragma mark -
#pragma mark Tools Menu

//========== showInspector: ====================================================
//
// Purpose:		Opens the inspector window. It may have something in it; it may 
//				not. That's up to the document.
//
//==============================================================================
- (IBAction) showInspector:(id)sender
{
	[inspector show:sender];
	
}//end showInspector:


//========== doPartBrowser: ====================================================
//
// Purpose:		Show or toggle the Part Browser, depending on the user's style 
//			    preference. 
//
//==============================================================================
- (IBAction) doPartBrowser:(id)sender 
{
	NSUserDefaults				*userDefaults		= [NSUserDefaults standardUserDefaults];
	PartBrowserStyleT			newStyle			= [userDefaults integerForKey:PART_BROWSER_STYLE_KEY];
	NSDocumentController		*documentController = [NSDocumentController sharedDocumentController];
	PartBrowserPanelController	*partBrowser		= nil;

	switch(newStyle)
	{
		case PartBrowserShowAsDrawer:
			
			//toggle the part browser on the foremost document
			[[[documentController currentDocument] partBrowserDrawer] toggle:sender];
			
			break;
			
		case PartBrowserShowAsPanel:
			
			//open the shared part browser.
			partBrowser = [PartBrowserPanelController sharedPartBrowserPanel];
			[[partBrowser window] makeKeyAndOrderFront:sender];
			
			break;
	} 
	
}//end doPartBrowser:


//========== showMouseTools: ===================================================
//
// Purpose:		Opens the mouse tools palette, used to control the mouse cursor 
//				mode (e.g., selection, zooming, etc.).
//
//==============================================================================
- (IBAction) showMouseTools:(id)sender
{
	[[ToolPalette sharedToolPalette] showToolPalette:sender];
	
}//end showMouseTools:


//========== hideMouseTools: ===================================================
//
// Purpose:		Closes the mouse tools palette.
//
//==============================================================================
- (IBAction) hideMouseTools:(id)sender
{
	[[ToolPalette sharedToolPalette] hideToolPalette:sender];
	
}//end hideMouseTools:


#pragma mark -
#pragma mark Part Menu

//========== showColors: =======================================================
//
// Purpose:		Opens the colors panel.
//
//==============================================================================
- (IBAction) showColors:(id)sender
{
	LDrawColorPanelController *colorPanel = [LDrawColorPanelController sharedColorPanel];
	
	[[colorPanel window] makeKeyAndOrderFront:sender];
	
	// It seems some DOS old-timers want to enter colors WITHOUT EVER CLICKING 
	// THE MOUSE. So, we assume that if the color panel was summoned by its key 
	// equivalent, we are probably dealing with one of these rabid anti-mouse 
	// people. We automatically make the color search field key, so they can 
	// enter color codes to their heart's content. 
	if([[NSApp currentEvent] type] == NSKeyDown)
		[colorPanel focusSearchField:sender];
	
}//end showColors:


#pragma mark -
#pragma mark Help Menu

//========== doHelp: ===========================================================
//
// Purpose:		Display the Bricksmith tutorial.
//
//==============================================================================
- (IBAction) doHelp:(id)sender
{
	[self openHelpAnchor:@"index"];
	
}//end doHelp:


//========== doKeyboardShortcutHelp: ===========================================
//
// Purpose:		Display a help page about keyboard shortcuts.
//
// Notes:		Don't use Help Viewer. See addendum  in -doHelp:.
//
//==============================================================================
- (IBAction) doKeyboardShortcutHelp:(id)sender
{
	[self openHelpAnchor:@"KeyboardShortcuts"];
	
}//end doKeyboardShortcutHelp:


//========== doGettingNewPartsHelp: ============================================
//
// Purpose:		Display a help page about installing unofficial LDraw parts.
//
// Notes:		Don't use Help Viewer. See addendum  in -doHelp:.
//
//==============================================================================
- (IBAction) doGettingNewPartsHelp:(id)sender
{
	[self openHelpAnchor:@"AboutLDraw"];
	
}//end doKeyboardShortcutHelp:


#pragma mark -
#pragma mark DELEGATES

#pragma mark -
#pragma mark NSApplication

//**** NSApplication ****
//========== applicationWillFinishLaunching: ===================================
//
// Purpose:		The application has opened; this comes before anything else 
//				(i.e., opening files) but after the application is set up.
//
//==============================================================================
- (void) applicationWillFinishLaunching:(NSNotification *)aNotification
{
	NSOpenGLPixelFormat *pixelFormat    = [LDrawApplication openGLPixelFormat];
	NSUserDefaults      *userDefaults   = [NSUserDefaults standardUserDefaults];
	
	//Make sure the standard preferences exist so they will be available 
	// throughout the application.
	[PreferencesDialogController ensureDefaults];
	
	[LDrawUtilities setColumnizesOutput:[userDefaults boolForKey:COLUMNIZE_OUTPUT_KEY]];
	[LDrawUtilities setDefaultAuthor:[self userName]];
	
	//Create shared objects.
	self->inspector					= [Inspector new];
	self->partLibraryController		= [[PartLibraryController alloc] init];
    self->lsynthConfiguration       = [LSynthConfiguration sharedInstance];
	self->sharedGLContext			= [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
	
	[sharedGLContext makeCurrentContext];

	// Tests inject their own LDraw library; never touch the user's.
	// Unit tests set it in-process; UI tests (separate process) pass it in
	// the environment as BRICKSMITH_TEST_LDRAW_PATH.
	if([LDrawApplication isRunningTests] == YES)
	{
		NSString *testLibrary = [[[NSProcessInfo processInfo] environment] objectForKey:@"BRICKSMITH_TEST_LDRAW_PATH"];
		if(testLibrary != nil)
			[[LDrawPaths sharedPaths] setPreferredLDrawPath:testLibrary];
	}
	else
	{
		//Try to define an LDraw path before the application even finishes starting.
		[self findLDrawPath];

		//Load the parts into the library; see if they loaded properly.
		[partLibraryController loadPartCatalog:^(BOOL success) {
			if(success == NO)
			{
				//No path has been chosen yet.
				// We must choose one now.
				[self doPreferences:self];
				//When the preferences dialog opens, it will automatically search for
				// the prefs path. Failing to find it, it will force the user to choose
				// a new one.
			}
		}];
	}
	
    // Parse the LSynth config file, using the bundled lsynth.mpd or a custom config file
    NSString *lsynthConfigPath;
    if ([[userDefaults stringForKey:LSYNTH_CONFIGURATION_PATH_KEY] length] == 0) {
        lsynthConfigPath = [[LSynthConfiguration sharedInstance] defaultConfigPath];
//        lsynthConfigPath = [[NSBundle mainBundle] pathForResource:@"lsynth" ofType:@"mpd"];
    }
    else {
        lsynthConfigPath = [userDefaults stringForKey:LSYNTH_CONFIGURATION_PATH_KEY];
    }
    [self->lsynthConfiguration parseLsynthConfig:lsynthConfigPath];

	// Register for Notifications
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(partBrowserStyleDidChange:)
												 name:LDrawPartBrowserStyleDidChangeNotification
											   object:nil ];
	
}//end applicationWillFinishLaunching:


//**** NSApplication ****
//========== applicationDidFinishLaunching: ====================================
//
// Purpose:		The application has finished launching.
//
//==============================================================================
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification 
{
	NSUserDefaults		*userDefaults		= [NSUserDefaults standardUserDefaults];
	BOOL				 showPartBrowser	= [userDefaults boolForKey:PART_BROWSER_PANEL_SHOW_AT_LAUNCH];

	if([LDrawApplication isRunningTests] == YES)
	{
		// No windows of our own, and no autosaved files from test documents.
		[[NSDocumentController sharedDocumentController] setAutosavingDelay:0];
		return;
	}

	[self populateLSynthModelMenus];
	
	if(		showPartBrowser == YES
	   &&	[userDefaults integerForKey:PART_BROWSER_STYLE_KEY] == PartBrowserShowAsPanel)
	{
		[[[PartBrowserPanelController sharedPartBrowserPanel] window] makeKeyAndOrderFront:self];
	}
	
	#if DEBUG
	[[NSDocumentController sharedDocumentController] setAutosavingDelay:30 ];	// Debug build?  Save quick - no need to lose work when an assert() fires.
	#else
	[[NSDocumentController sharedDocumentController] setAutosavingDelay:300];
	#endif
	
}//end applicationDidFinishLaunching:


//**** NSApplication ****
//========== applicationShouldOpenUntitledFile: ================================
//
// Purpose:		Test runs start with no documents; tests open their own.
//
//==============================================================================
- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return ([LDrawApplication isRunningTests] == NO);

}//end applicationShouldOpenUntitledFile:


//**** NSApplication ****
//========== applicationWillTerminate: =========================================
//
// Purpose:		Bricksmith is quitting. Do any necessary pre-quit work, such as 
//				saving out preferences.
//
//==============================================================================
- (void)applicationWillTerminate:(NSNotification *)notification
{
	if([LDrawApplication isRunningTests] == YES)
		return; // never write the user's defaults from a test run

	NSUserDefaults		*userDefaults		= [NSUserDefaults standardUserDefaults];
	PartBrowserPanelController	*partBrowserPanel	= [PartBrowserPanelController sharedPartBrowserPanel];

	[userDefaults setBool:[[partBrowserPanel window] isVisible]
				   forKey:PART_BROWSER_PANEL_SHOW_AT_LAUNCH ];
				   
	[userDefaults synchronize];

}//end applicationWillTerminate:


//========== applicationShouldTerminate: =======================================
//
// Purpose:		We might have to gently remind the user that he ought to support 
//				this great project, um, monetarily. 
//
//==============================================================================
- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender
{
	if([LDrawApplication isRunningTests] == YES)
		return NSTerminateNow; // a modal prompt would hang the test run

	DonationDialogController	*donation = [[DonationDialogController alloc] init];

	if([donation shouldShowDialog] == YES && suppressDonationPrompt == NO)
	{
		[donation runModal];
	}
	
	[donation release];
	
	return NSTerminateNow;
	
}//end applicationShouldTerminate:


//========== validateMenuItem: =================================================
//
// Purpose:		Determines whether the given menu item should be available.
//				This method is called automatically each time a menu is opened.
//				We identify the menu item by its tag, which is defined in 
//				MacLDraw.h.
//
// Notes:		Menu items targeted at the document are handled in 
//				LDrawDocument. 
//
//==============================================================================
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	NSInteger       tag             = [menuItem tag];
	BOOL            enable          = NO;
	
	switch(tag)
	{
		////////////////////////////////////////
		//
		// Tools Menu
		//
		////////////////////////////////////////
			
		case showMouseToolsMenuTag:
			[menuItem setHidden:[[ToolPalette sharedToolPalette] isVisible]];
			enable = YES;
			break;
			
		case hideMouseToolsMenuTag:
			[menuItem setHidden:([[ToolPalette sharedToolPalette] isVisible] == NO)];
			enable = YES;
			break;
			
		default:
			enable = YES;
			break;
			
	}
	
	return enable;
	
}//end validateMenuItem:


// MARK: - SPUUpdaterDelegate (Sparkle)

//========== updater:mayPerformUpdateCheck:error: ==============================
//
// Purpose:		Debug builds must never update themselves from the live
//				appcast (which would replace a development build with the
//				released app). Refusing here writes no user defaults, so
//				Release builds on the same machine are unaffected.
//
//==============================================================================
- (BOOL) updater:(SPUUpdater *)updater
mayPerformUpdateCheck:(SPUUpdateCheck)updateCheck
		   error:(NSError * __autoreleasing *)error
{
#if !DEBUG
	if([LDrawApplication isRunningTests] == NO)
		return YES;
#endif
	if(error != NULL)
	{
		*error = [NSError errorWithDomain:SUSparkleErrorDomain
									 code:SUNoUpdateError
								 userInfo:@{NSLocalizedDescriptionKey:
											@"Update checks are disabled in Debug builds and test runs."}];
	}
	return NO;
}//end updater:mayPerformUpdateCheck:error:


//========== updaterWillRelaunchApplication: ===================================
//
// Purpose:		Sparkle is about to install an update and relaunch.
//
//==============================================================================
- (void) updaterWillRelaunchApplication:(SPUUpdater *)updater
{
	// Asking for money in the middle of an update process is a bit distracting.
	suppressDonationPrompt = YES;
}


#pragma mark -
#pragma mark NOTIFICATIONS
#pragma mark -

//========== partBrowserStyleDidChange: ========================================
//
// Purpose:		Reconfigure the part browser display based on new user 
//				preferences.
//
//==============================================================================
- (void) partBrowserStyleDidChange:(NSNotification *)notification
{
	NSUserDefaults          *userDefaults       = [NSUserDefaults standardUserDefaults];
	PartBrowserStyleT       newStyle            = [userDefaults integerForKey:PART_BROWSER_STYLE_KEY];
	NSDocumentController    *documentController = [NSDocumentController sharedDocumentController];
	NSArray                 *documents          = [documentController documents];
	NSInteger               documentCount       = [documents count];
	NSInteger               counter             = 0;
	
	switch(newStyle)
	{
		case PartBrowserShowAsDrawer:
			
			//close the shared part browser
			[[PartBrowserPanelController sharedPartBrowserPanel] close];
			
			// open the browser drawer on each document
			for(counter = 0; counter < documentCount; counter++)
			{
				[[[documents objectAtIndex:counter] partBrowserDrawer] open];
			}
			
			break;
			
		case PartBrowserShowAsPanel:
			
			//close the browser drawer on each document
			for(counter = 0; counter < documentCount; counter++)
			{
				[[[documents objectAtIndex:counter] partBrowserDrawer] close];
			}
			
			//open the shared part browser.
			[[[PartBrowserPanelController sharedPartBrowserPanel] window] makeKeyAndOrderFront:self];
			
			break;
	} 
	
}//end partBrowserStyleDidChange:


#pragma mark -
#pragma mark UTILITIES
#pragma mark -

//========== openHelpAnchor: ===================================================
//
// Purpose:		Provides much-needed API layering to open the specified help 
//				anchor token. DO NOT USE NSHelpManager DIRECTLY! 
//
// Rant:		Apple's automatic help registration is worthless. I've tried the 
//				program on numerous Macs; it refuses to load until the OS 
//				finally realizes a new program is there, which takes either 
//				a) 2 million years or b) voodoo/ritualistic sacrifice. So 
//				I'm bypassing what it does for something much less magical.
//
// Note:		I did manage to do *something* on two computers that got it 
//				working automatically (touching, copying, I don't know). But 
//				it never just happened when the application was first installed.
//
// Addendum:	I think the files need to be run through some help 
//				utility/indexer in the Developer Tools. But Help Viewer in 
//				Leopard is so abominable that I'm just going to launch a 
//				browser. On my  PowerBook G4, the Leopard Help Viewer takes 
//				2 minutes 42 seconds to launch and become responsive to events. 
//				That is shockingly unacceptible. 
//
//==============================================================================
- (void) openHelpAnchor:(NSString *)helpAnchor
{
	NSBundle	*applicationBundle	= [NSBundle mainBundle];
	NSString	*fileName			= helpAnchor; // help anchor is the filename by my convention
	NSString	*helpPath			= [applicationBundle pathForResource:fileName
																  ofType:@"html"
															 inDirectory:@"Help"];
	NSURL		*helpURL			= [NSURL fileURLWithPath:helpPath];
	
//	[[NSWorkspace sharedWorkspace] openFile:helpRoot withApplication:@"Help Viewer.app"];
	[[NSWorkspace sharedWorkspace] openURL:helpURL];
		
}//end openHelpAnchor:


//========== findLDrawPath =====================================================
//
// Purpose:		Search for an LDraw folder and display failure UI if it's not 
//				found. 
//
//==============================================================================
- (void) findLDrawPath
{
	NSUserDefaults  *userDefaults   = [NSUserDefaults standardUserDefaults];
	LDrawPaths      *paths          = [LDrawPaths sharedPaths];
	NSString        *ldrawPath      = nil;
	
	// Search
	ldrawPath = [paths findLDrawPath];
	
	//We found one.
	if(ldrawPath != nil)
	{
		[paths setPreferredLDrawPath:ldrawPath];
		[userDefaults setObject:ldrawPath forKey:LDRAW_PATH_KEY];
	}
	else
	{
		[self->partLibraryController validateLDrawFolderWithMessage:nil];
		ldrawPath = nil;
	}
	
}//end findLDrawPath


//========== populateLSynthModelMenus ==========================================
//
// Purpose:		Populate the LSynth Model menus dynamically from configuration
//				file.
//
//==============================================================================
- (void) populateLSynthModelMenus
{
    LDrawApplication	*appDelegate    = [NSApp delegate];
    NSMenu				*mainMenu       = [NSApp mainMenu];
    NSMenu				*modelMenu      = [[mainMenu itemWithTag:modelsMenuTag] submenu];
	NSMenu				*lsynthMenu     = [[modelMenu itemWithTag:lsynthMenuTag] submenu];
    NSUserDefaults	    *userDefaults   = [NSUserDefaults standardUserDefaults];

	// A declarative encoding of our LSynth menus
	// We process this, along with associated LSynthConfiguration data to generate our Model LSynth menu
	NSArray *menus = [NSArray arrayWithObjects:
					  
					  [NSDictionary dictionaryWithObjectsAndKeys:
							   [NSNumber numberWithInt:lsynthPartMenuTag], @"tag",
							   @"getParts", @"getter",
							   @"title", @"entry_key",
							   NSStringFromSelector(@selector(insertSynthesizableDirective:)), @"action",
                               @YES, @"shouldFilter",
							   nil],
					  
					  [NSDictionary dictionaryWithObjectsAndKeys:
							   [NSNumber numberWithInt:lsynthHoseMenuTag], @"tag",
							   @"getHoseTypes", @"getter",
							   @"title", @"entry_key",
							   NSStringFromSelector(@selector(insertSynthesizableDirective:)), @"action",
                               @YES, @"shouldFilter",
                               nil],
					  
					  [NSDictionary dictionaryWithObjectsAndKeys:
							   [NSNumber numberWithInt:lsynthHoseConstraintMenuTag], @"tag",
							   @"getHoseConstraints", @"getter",
							   @"description", @"entry_key",
							   NSStringFromSelector(@selector(insertLSynthConstraint:)), @"action",
                               @NO, @"shouldFilter",
							   nil],
					  
					  [NSDictionary dictionaryWithObjectsAndKeys:
							   [NSNumber numberWithInt:lsynthBandMenuTag], @"tag",
							   @"getBandTypes", @"getter",
							   @"title", @"entry_key",
							   NSStringFromSelector(@selector(insertSynthesizableDirective:)), @"action",
                               @YES, @"shouldFilter",
							   nil],
					  
					  [NSDictionary dictionaryWithObjectsAndKeys:
							   [NSNumber numberWithInt:lsynthBandConstraintMenuTag], @"tag",
							   @"getBandConstraints", @"getter",
							   @"description", @"entry_key",
							   NSStringFromSelector(@selector(insertLSynthConstraint:)), @"action",
                               @NO, @"shouldFilter",
							   nil],
					  
					  nil];
	
	for (NSDictionary *menuSpec in menus)
	{
        NSInteger	tag				= [[menuSpec objectForKey:@"tag"] integerValue];
		NSMenu		*elementMenu	= [[lsynthMenu itemWithTag:tag] submenu]; // one for each of part, constraint, hose, band etc.
		
        [elementMenu removeAllItems];
        
		// Retrieve the appropriate data for each menu entry, based on the getter given above

        NSArray *lsynthMLCADDefaults = [[MLCadIni iniFile] lsynthVisibleTypes];

        for (NSDictionary *entry in [[appDelegate lsynthConfiguration] performSelector:NSSelectorFromString([menuSpec objectForKey:@"getter"])])
		{
			// The MLCad.ini file contains a list of semi-official LSynth types.  The lsynth.mpd file also contains legacy entries
			// for backward compatibility.  We want to filter out non-semi-official synth parts unless the user has turned this off
			// in the preferences.  Parts get filtered, constraints don't.
            if (([[menuSpec valueForKey:@"shouldFilter"] boolValue]
                    && [lsynthMLCADDefaults indexOfObject:[entry valueForKey:@"LSYNTH_TYPE"]] != NSNotFound)
                    ||
                    // This menu should not be filtered
                    ![[menuSpec valueForKey:@"shouldFilter"] boolValue]
                    ||
                    // User has turned off filtering in prefs
                    ![userDefaults boolForKey:LSYNTH_SHOW_BASIC_PARTS_LIST_KEY])
            {
                NSMenuItem *entryMenuItem = [[[NSMenuItem alloc] init] autorelease];
                [entryMenuItem setTitle:[entry objectForKey:[menuSpec objectForKey:@"entry_key"]]];
                [entryMenuItem setRepresentedObject:entry];
                [entryMenuItem setAction:NSSelectorFromString([menuSpec objectForKey:@"action"])];
                [entryMenuItem setTarget:nil]; // direct to responder chain, e.g. foremost LDrawDocument
                [entryMenuItem setTag:tag]; // give all items the same tag for validation purposes
                [elementMenu addItem:entryMenuItem];
            }
		}

		[elementMenu setAutoenablesItems:YES];
	}
	
	//
	// Add INSIDE/OUTSIDE menus
	//
	
	NSMenu *insideOutsideMenu = [[lsynthMenu itemWithTag:lsynthInsideOutsideMenuTag] submenu];
	
	// TODO: Add these in later
//  NSMenuItem *surroundSelectionItem = [[[NSMenuItem alloc] init] autorelease];
//  [surroundSelectionItem setTitle:@"Surround Selection"];
//  [surroundSelectionItem setTarget:self];
//  [surroundSelectionItem setAction:@selector(surroundLSynthConstraints:)];
//  [surroundSelectionItem setTag:lsynthSurroundINSIDEOUTSIDETag];
//  [insideOutsideMenu addItem:surroundSelectionItem];
//
//  NSMenuItem *invertSelectionItem = [[[NSMenuItem alloc] init] autorelease];
//  [invertSelectionItem setTitle:@"Invert Selection"];
//  [invertSelectionItem setTarget:self];
//  [invertSelectionItem setAction:@selector(invertLSynthConstraintSelection:)];
//  [invertSelectionItem setTag:lsynthInvertINSIDEOUTSIDETag];
//  [insideOutsideMenu addItem:invertSelectionItem];
	
	NSMenuItem *addInsideItem = [[[NSMenuItem alloc] init] autorelease];
	[addInsideItem setTitle:@"Insert INSIDE"];
	[addInsideItem setTarget:nil];
	[addInsideItem setAction:@selector(insertINSIDEOUTSIDELSynthDirective:)];
	[addInsideItem setTag:lsynthInsertINSIDETag];
	[insideOutsideMenu addItem:addInsideItem];
	
	NSMenuItem *addOutsideItem = [[[NSMenuItem alloc] init] autorelease];
	[addOutsideItem setTitle:@"Insert OUTSIDE"];
	[addOutsideItem setTarget:nil];
	[addOutsideItem setAction:@selector(insertINSIDEOUTSIDELSynthDirective:)];
	[addOutsideItem setTag:lsynthInsertOUTSIDETag];
	[insideOutsideMenu addItem:addOutsideItem];
	
	NSMenuItem *addCrossItem = [[[NSMenuItem alloc] init] autorelease];
	[addCrossItem setTitle:@"Insert CROSS"];
	[addCrossItem setTarget:nil];
	[addCrossItem setAction:@selector(insertINSIDEOUTSIDELSynthDirective:)];
	[addCrossItem setTag:lsynthInsertCROSSTag];
	[insideOutsideMenu addItem:addCrossItem];
	
}//end populateLSynthModelMenus


//========== userName ==========================================================
//
// Purpose:		Returns the name of the current user of the computer.
//
//==============================================================================
- (NSString *) userName
{
	NSString    *fullName   = NSFullUserName();
	
	// 10.8 presents a frightening warning when an application tries to access 
	// the address book. So just use the username.
//	ABPerson    *userInfo   = [[ABAddressBook sharedAddressBook] me];
//	NSString    *firstName  = [userInfo valueForProperty:kABFirstNameProperty];
//	NSString    *lastName   = [userInfo valueForProperty:kABLastNameProperty];
	
	return fullName;
}


#pragma mark -
#pragma mark DESTRUCTOR
#pragma mark -

//========== dealloc ===========================================================
//
// Purpose:		The curtain falls.
//
//==============================================================================
- (void) dealloc
{
	[partLibraryController	release];
	[inspector				release];
	[sharedGLContext		release];

	[super dealloc];
	
}//end dealloc


@end
