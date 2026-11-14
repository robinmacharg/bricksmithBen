//==============================================================================
//
// File:		MacLDraw.h
//
// Purpose:		Keys, enumerations, and constants used in the Bricksmith 
//				project. 
//
// Notes:		Bricksmith was originally titled "Mac LDraw"; hence the name of 
//				this file. That name was dropped shortly before the 1.0 release 
//				because Tim Courtney said the LDraw name should be reserved for 
//				the Library itself, and I thought "Mac LDraw" was kinda boring. 
//
// Modified:	2/14/05 Allen Smith.
//
//==============================================================================


#import <Foundation/Foundation.h>


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Preferences Keys
//
////////////////////////////////////////////////////////////////////////////////

FOUNDATION_EXPORT NSString * const COLUMNIZE_OUTPUT_KEY; // @"ColumnizeOutput"
FOUNDATION_EXPORT NSString * const DOCUMENT_WINDOW_SIZE; // @"Document Window Size"
FOUNDATION_EXPORT NSString * const DONATION_SCREEN_LAST_VERSION_DISPLAYED; // @"DonationRequestLastVersion"
FOUNDATION_EXPORT NSString * const DONATION_SCREEN_SUPPRESS_THIS_VERSION; // @"DonationRequestSuppressThisVersion"
FOUNDATION_EXPORT NSString * const FAVORITE_PARTS_KEY; // @"FavoriteParts"
FOUNDATION_EXPORT NSString * const FILE_CONTENTS_DRAWER_STATE; // @"File Contents Drawer State"  //obsolete
FOUNDATION_EXPORT NSString * const GRID_SPACING_COARSE; // @"Grid Spacing: Coarse"
FOUNDATION_EXPORT NSString * const GRID_SPACING_FINE; // @"Grid Spacing: Fine"
FOUNDATION_EXPORT NSString * const GRID_SPACING_MEDIUM; // @"Grid Spacing: Medium"
FOUNDATION_EXPORT NSString * const LDRAW_GL_VIEW_ANGLE; // @"LDrawGLView Viewing Angle"
FOUNDATION_EXPORT NSString * const LDRAW_GL_VIEW_PROJECTION; // @"LDrawGLView Viewing Projection"
FOUNDATION_EXPORT NSString * const LDRAW_PATH_KEY; // @"LDraw Path"
FOUNDATION_EXPORT NSString * const LDRAW_VIEWER_BACKGROUND_COLOR_KEY; // @"LDraw Viewer Background Color"
FOUNDATION_EXPORT NSString * const MOUSE_DRAGGING_BEHAVIOR_KEY; // @"Mouse Dragging Behavior"
FOUNDATION_EXPORT NSString * const RIGHT_BUTTON_BEHAVIOR_KEY; // @"Right Button Behavior"
FOUNDATION_EXPORT NSString * const ROTATE_MODE_KEY; // @"Rotate Mode"
FOUNDATION_EXPORT NSString * const MOUSE_WHEEL_BEHAVIOR_KEY; // @"Mouse Wheel Behavior"
FOUNDATION_EXPORT NSString * const PART_BROWSER_DRAWER_STATE; // @"Part Browser Drawer State"
FOUNDATION_EXPORT NSString * const PART_BROWSER_PANEL_SHOW_AT_LAUNCH; // @"Part Browser Panel Show at Launch"
FOUNDATION_EXPORT NSString * const PART_BROWSER_PREVIOUS_CATEGORY; // @"Part Browser Previous Category"
FOUNDATION_EXPORT NSString * const PART_BROWSER_PREVIOUS_SELECTED_ROW; // @"Part Browser Previous Selected Row"
FOUNDATION_EXPORT NSString * const PART_BROWSER_SEARCH_MODE; // @"Part Browser Search Mode"
FOUNDATION_EXPORT NSString * const PART_BROWSER_STYLE_KEY; // @"Part Browser Style"
FOUNDATION_EXPORT NSString * const PREFERENCES_LAST_TAB_DISPLAYED; // @"Preferences Tab"
FOUNDATION_EXPORT NSString * const SYNTAX_COLOR_COLORS_KEY; // @"Syntak Color Colors"
FOUNDATION_EXPORT NSString * const SYNTAX_COLOR_COMMENTS_KEY; // @"Syntax Color Comments"
FOUNDATION_EXPORT NSString * const SYNTAX_COLOR_MODELS_KEY; // @"Syntax Color Models"
FOUNDATION_EXPORT NSString * const SYNTAX_COLOR_PARTS_KEY; // @"Syntax Color Parts"
FOUNDATION_EXPORT NSString * const SYNTAX_COLOR_PRIMITIVES_KEY; // @"Syntax Color Primitives"
FOUNDATION_EXPORT NSString * const SYNTAX_COLOR_STEPS_KEY; // @"Syntax Color Steps"
FOUNDATION_EXPORT NSString * const SYNTAX_COLOR_UNKNOWN_KEY; // @"Syntax Color Unknown"
FOUNDATION_EXPORT NSString * const TOOL_PALETTE_HIDDEN; // @"Tool Palette Hidden"
FOUNDATION_EXPORT NSString * const VIEWPORTS_EXPAND_TO_AVAILABLE_SIZE; // @"ViewportsExpandToAvailableSize"

// LSynth
FOUNDATION_EXPORT NSString * const LSYNTH_EXECUTABLE_PATH_KEY; // @"LSynth Executable Path"
FOUNDATION_EXPORT NSString * const LSYNTH_CONFIGURATION_PATH_KEY; // @"LSynth Configuration Path"
FOUNDATION_EXPORT NSString * const LSYNTH_SELECTION_TRANSPARENCY_KEY; // @"LSynth Selection Transparency"
FOUNDATION_EXPORT NSString * const LSYNTH_SELECTION_COLOR_KEY; // @"LSynth Selection Color"
FOUNDATION_EXPORT NSString * const LSYNTH_SELECTION_MODE_KEY; // @"LSynth Selection Mode"
FOUNDATION_EXPORT NSString * const LSYNTH_SAVE_SYNTHESIZED_PARTS_KEY; // @"LSynth Save Synthesized Parts"
FOUNDATION_EXPORT NSString * const LSYNTH_SHOW_BASIC_PARTS_LIST_KEY; // @"LSynth Show Basic Parts List"

FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_HAT; // @"Minifigure Has Hat"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_HEAD; // @"Minifigure Has Head"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_NECK; // @"Minifigure Has Neck"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_TORSO; // @"Minifigure Has Torso"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_ARM_RIGHT; // @"Minifigure Has Arm Right"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_ARM_LEFT; // @"Minifigure Has Arm Left"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_HAND_RIGHT; // @"Minifigure Has Hand Right"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_HAND_RIGHT_ACCESSORY; // @"Minifigure Has Hand Right Accessory"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_HAND_LEFT; // @"Minifigure Has Hand Left"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_HAND_LEFT_ACCESSORY; // @"Minifigure Has Hand Left Accessory"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_HIPS; // @"Minifigure Has Hips"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_LEG_RIGHT; // @"Minifigure Has Leg Right"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_LEG_RIGHT_ACCESSORY; // @"Minifigure Has Leg Right Accessory"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_LEG_LEFT; // @"Minifigure Has Leg Left"
FOUNDATION_EXPORT NSString * const MINIFIGURE_HAS_LEG_LEFT_ACCESSORY; // @"Minifigure Has Leg Left Accessory"

FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_HAT; // @"Minifigure Partname Hat"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_HEAD; // @"Minifigure Partname Head"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_NECK; // @"Minifigure Partname Neck"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_TORSO; // @"Minifigure Partname Torso"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_ARM_RIGHT; // @"Minifigure Partname Arm Right"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_ARM_LEFT; // @"Minifigure Partname Arm Left"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_HAND_RIGHT; // @"Minifigure Partname Hand Right"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_HAND_RIGHT_ACCESSORY; // @"Minifigure Partname Hand Right Accessory"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_HAND_LEFT; // @"Minifigure Partname Hand Left"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_HAND_LEFT_ACCESSORY; // @"Minifigure Partname Hand Left Accessory"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_HIPS; // @"Minifigure Partname Hips"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_LEG_RIGHT; // @"Minifigure Partname Leg Right"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_LEG_RIGHT_ACCESSORY; // @"Minifigure Partname Leg Right Accessory"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_LEG_LEFT; // @"Minifigure Partname Leg Left"
FOUNDATION_EXPORT NSString * const MINIFIGURE_PARTNAME_LEG_LEFT_ACCESSORY; // @"Minifigure Partname Leg Left Accessory"

FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_HAT; // @"Minifigure Angle Hat"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_HEAD; // @"Minifigure Angle Head"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_NECK; // @"Minifigure Angle Neck"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_TORSO; // @"Minifigure Angle Torso"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_ARM_RIGHT; // @"Minifigure Angle Arm Right"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_ARM_LEFT; // @"Minifigure Angle Arm Left"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_HAND_RIGHT; // @"Minifigure Angle Hand Right"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_HAND_RIGHT_ACCESSORY; // @"Minifigure Angle Hand Right Accessory"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_HAND_LEFT; // @"Minifigure Angle Hand Left"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_HAND_LEFT_ACCESSORY; // @"Minifigure Angle Hand Left Accessory"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_HIPS; // @"Minifigure Angle Hips"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_LEG_RIGHT; // @"Minifigure Angle Leg Right"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_LEG_RIGHT_ACCESSORY; // @"Minifigure Angle Leg Right Accessory"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_LEG_LEFT; // @"Minifigure Angle Leg Left"
FOUNDATION_EXPORT NSString * const MINIFIGURE_ANGLE_LEG_LEFT_ACCESSORY; // @"Minifigure Angle Leg Left Accessory"

FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_HAT; // @"Minifigure Color Hat"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_HEAD; // @"Minifigure Color Head"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_NECK; // @"Minifigure Color Neck"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_TORSO; // @"Minifigure Color Torso"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_ARM_RIGHT; // @"Minifigure Color Arm Right"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_ARM_LEFT; // @"Minifigure Color Arm Left"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_HAND_RIGHT; // @"Minifigure Color Hand Right"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_HAND_RIGHT_ACCESSORY; // @"Minifigure Color Hand Right Accessory"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_HAND_LEFT; // @"Minifigure Color Hand Left"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_HAND_LEFT_ACCESSORY; // @"Minifigure Color Hand Left Accessory"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_HIPS; // @"Minifigure Color Hips"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_LEG_RIGHT; // @"Minifigure Color Leg Right"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_LEG_RIGHT_ACCESSORY; // @"Minifigure Color Leg Right Accessory"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_LEG_LEFT; // @"Minifigure Color Leg Left"
FOUNDATION_EXPORT NSString * const MINIFIGURE_COLOR_LEG_LEFT_ACCESSORY; // @"Minifigure Color Leg Left Accessory"

FOUNDATION_EXPORT NSString * const MINIFIGURE_HEAD_ELEVATION; // @"Minifigure Head Elevation"


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Drawing Mask bits and Constants
//
////////////////////////////////////////////////////////////////////////////////
#define DRAW_NO_OPTIONS							0
#define DRAW_BOUNDS_ONLY						1 << 3

//Number of degrees to rotate in each grid mode.
#define GRID_ROTATION_FINE						15
#define GRID_ROTATION_MEDIUM					45
#define GRID_ROTATION_COARSE					90


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Notifications
//
////////////////////////////////////////////////////////////////////////////////

//The color which will be assigned to new parts has changed.
// Object is the new LDrawColorT, as an NSNumber. No userInfo.
FOUNDATION_EXPORT NSNotificationName const LDrawColorDidChangeNotification; // @"LDrawColorDidChangeNotification"

//the keys on the keyboard which were depressed just changed.
// Object is an NSEvent: keyUp, keyDown, or flagsChanged.
FOUNDATION_EXPORT NSNotificationName const LDrawKeyboardDidChangeNotification; // @"LDrawKeyboardDidChangeNotification"

//tool mode changed.
// Object is an NSNumber containing the new ToolModeT.
FOUNDATION_EXPORT NSNotificationName const LDrawMouseToolDidChangeNotification; // @"LDrawMouseToolDidChangeNotification"

//tablet pointing device changed.
// Object is an NSEvent: NSTabletProximity.
FOUNDATION_EXPORT NSNotificationName const LDrawPointingDeviceDidChangeNotification; // @"LDrawPointingDeviceDidChangeNotification"

//Part Browser should be shown a different way.
// Object is NSNumber of new style. No userInfo.
FOUNDATION_EXPORT NSNotificationName const LDrawPartBrowserStyleDidChangeNotification; // @"LDrawPartBrowserStyleDidChangeNotification"

//Syntax coloring changed in preferences.
// Object is the application. No userInfo.
FOUNDATION_EXPORT NSNotificationName const LDrawSyntaxColorsDidChangeNotification; // @"LDrawSyntaxColorsDidChangeNotification"

//Syntax coloring changed in preferences.
// Object is the new color. No userInfo.
FOUNDATION_EXPORT NSNotificationName const LDrawViewBackgroundColorDidChangeNotification; // @"LDrawViewBackgroundColorDidChangeNotification"

//A model was added to a document.  Note that the object
// for this notification is the LDrawFile that was edited!
FOUNDATION_EXPORT NSString * const LDrawMPDSubModelAdded; // @"LDrawMPDSubModelAdded"

//The library was reloaded.  Documents need to tell their parts
// to re-resolve their references.
FOUNDATION_EXPORT NSString * const LDrawPartLibraryReloaded; // @"LDrawPartLibraryReloaded"

// The LSynth selection appearance changed.  Selected LSynth
// parts need to update to reflect this
FOUNDATION_EXPORT NSNotificationName const LSynthSelectionDisplayDidChangeNotification; // @"LSynthSelectionDisplayDidChangeNotification"

// The LSynth parts need to resynthesize for some reason - maybe config or exe changes
FOUNDATION_EXPORT NSNotificationName const LSynthResynthesisRequiredNotification; // @"LSynthResynthesisRequiredNotification"

////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Menu Tags
//
// Tags to look up menus with.
//
////////////////////////////////////////////////////////////////////////////////

typedef enum MenuTags
{
	// Application Menu
	applicationMenuTag				= 0,
	
	// File Menu
	fileMenuTag						= 1,
    revealInFinderTag               = 101,
	
	// Edit Menu
	editMenuTag						= 2,
	cutMenuTag						= 202,
	copyMenuTag						= 203,
	pasteMenuTag					= 204,
	deleteMenuTag					= 205,
	selectAllMenuTag				= 206,
	duplicateMenuTag				= 207,
	splitStepMenuTag				= 208,
	changeOriginMenuTag				= 209,
	splitModelMenuTag				= 210,
	rotatePositiveXTag				= 220,
	rotateNegativeXTag				= 221,
	rotatePositiveYTag				= 222,
	rotateNegativeYTag				= 223,
	rotatePositiveZTag				= 224,
	rotateNegativeZTag				= 225,
	
	// Tools Menu
	toolsMenuTag					= 3,
	fileContentsMenuTag				= 302,
	showMouseToolsMenuTag			= 303,
	hideMouseToolsMenuTag			= 304,
	gridFineMenuTag					= 305,
	gridMediumMenuTag				= 306,
	gridCoarseMenuTag				= 307,
	coordModelMenuTag				= 308,
	coordPartMenuTag				= 309,	
	
	// Views Menu
	viewsMenuTag					= 4,
	stepDisplayMenuTag				= 404,
	nextStepMenuTag					= 405,
	previousStepMenuTag				= 406,
	orientationMenuTag				= 407,
	useSelectionForSpinCenterMenuTag= 408,
	resetSpinCenterMenuTag			= 409,
	
	// Piece Menu
	pieceMenuTag					= 5,
	hidePieceMenuTag				= 501,
	showPieceMenuTag				= 502,
	snapToGridMenuTag				= 503,
	gotoModelMenuTag				= 504,
	
	// Models Menu
	modelsMenuTag					= 6,
	addModelMenuTag					= 601,
	modelsSeparatorMenuTag			= 602,
	insertReferenceMenuTag			= 603,
	submodelReferenceMenuTag		= 604, //used for all items in the Insert Reference menu.
	rawCommandMenuTag               = 605,
	addModelSelectionMenuTag		= 606,
	relatedPartMenuTag				= 610, //used to add related parts dynamically.
	
    lsynthMenuTag                   = 630,
    lsynthPartMenuTag               = 631, // LSynth parts
    lsynthHoseMenuTag				= 632, // LSynth synthesizable part: hose
    lsynthHoseConstraintMenuTag     = 633, // LSynth constraint items: hose
	lsynthBandMenuTag				= 634, // LSynth synthesizable part: band
	lsynthBandConstraintMenuTag		= 635, // LSynth constraint items: band
	lsynthInsideOutsideMenuTag		= 636,
    lsynthSurroundINSIDEOUTSIDETag  = 637,
    lsynthInvertINSIDEOUTSIDETag    = 638,
    lsynthInsertINSIDETag           = 639,
    lsynthInsertOUTSIDETag          = 640,
    lsynthInsertCROSSTag            = 641,

	// Window Menu
	windowMenuTag					= 7,
	
	// Contextual Menus
	partBrowserAddFavoriteTag		= 4001,
	partBrowserRemoveFavoriteTag	= 4002
	
} menuTagsT;


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Shared Datatypes
//
// Data types which would otherwise be homeless
//
////////////////////////////////////////////////////////////////////////////////

typedef NS_ENUM(int, MouseDragBehaviorT)
{
	MouseDraggingOff									= 0,
	MouseDraggingBeginImmediately						= 1,
	MouseDraggingBeginAfterDelay						= 2,
	MouseDraggingImmediatelyInOrthoNeverInPerspective	= 3
	

};

typedef NS_ENUM(int, RightButtonBehaviorT)
{
	RightButtonContextual								= 0,
	RightButtonRotates									= 1

};

typedef NS_ENUM(int, RotateModeT) {
	RotateModeTrackball									= 0,
	RotateModeTurntable									= 1

};

typedef NS_ENUM(int, MouseWheelBeahviorT) {
	MouseWheelScrolls									= 0,
	MouseWheelZooms										= 1

};

typedef NS_ENUM(int, PartBrowserStyleT)
{
	PartBrowserShowAsDrawer	= 0,
	PartBrowserShowAsPanel	= 1

};


typedef NS_ENUM(int, SearchModeT)
{
	SearchModeAllCategories	= 0,
	SearchModeSelectedCategory = 1

};


typedef NS_ENUM(int, SelectionModeT) {
	
	SelectionReplace		= 0,			// Normal drag - take new
	SelectionExtend			= 1,			// Shift drag - take old | new
	SelectionSubtract		= 2,			// Option drag - take old - new
	SelectionIntersection	= 3				// Option-shift drag - take old & new
	
};


////////////////////////////////////////////////////////////////////////////////
//
#pragma mark		Pasteboards
//
// Names of pasteboard types that Bricksmith uses to transfer data internally.
//
////////////////////////////////////////////////////////////////////////////////

//Used for dragging within the File Contents outline. Contains an array of 
// LDrawDirectives stored as NSData objects. There should be no duplication of 
// objects.
FOUNDATION_EXPORT NSString * const LDrawDirectivePboardType; // @"LDrawDirectivePboardType"

//Used for dragging parts around in or between viewports. Contains an array of 
// LDrawDirectives stored as NSData objects. There should be no duplication of 
// objects.
FOUNDATION_EXPORT NSString * const LDrawDraggingPboardType; // @"LDrawDraggingPboardType"

// Contains a Vector3 as NSData indicating the offset between the click location 
// which originated the drag and the position of the first dragged directive. 
FOUNDATION_EXPORT NSString * const LDrawDraggingInitialOffsetPboardType; // @"LDrawDraggingInitialOffsetPboardType"

// Contains a BOOL indicating the dragging directive has never been part of a 
// model before.  
FOUNDATION_EXPORT NSString * const LDrawDraggingIsUninitializedPboardType; // @"LDrawDraggingIsUninitializedPboardType"

//Contains an array of indexes for the original objects being drug.
// Since the objects are converted to data when placed on the 
// LDrawDirectivePboardType (effectively copying them), these source indexes 
// must be used to delete the original objects after the copies have been 
// deposited in their new destination.
FOUNDATION_EXPORT NSString * const LDrawDragSourceRowsPboardType; // @"LDrawDragSourceRowsPboardType"

FOUNDATION_EXPORT NSString * const LDrawDisallowDragToSourcePboardType; // @"LDrawDisallowDragToSourcePboardType"

