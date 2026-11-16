//
//  SearchPanel.h
//  Bricksmith
//
//  Created by Robin Macharg on 06/02/2014.
//

#import <Cocoa/Cocoa.h>
#import "LDrawColorWell.h"

// UI radio buttons are tagged:
// Where to search
typedef NS_ENUM(int, ScopeT){
    ScopeFile  = 1,
    ScopeModel = 2,
    ScopeStep  = 3,
    ScopeSelection = 4
};

// How to search for colors
typedef NS_ENUM(int, ColorFilterT){
    ColorNoFilter = 1,
    ColorSelectionFilter = 2,
    ColorFilter = 3
};

// What to search for
typedef NS_ENUM(int, SearchPartCriteriaT){
    SearchAllParts = 1,
    SearchSpecificPart = 2,
    SearchSelectedParts = 3
};

@interface SearchPanelController : NSWindowController <NSWindowDelegate, NSDraggingDestination>
{
	IBOutlet __unsafe_unretained NSMatrix		*scopeMatrix;
	IBOutlet __unsafe_unretained NSMatrix		*colorMatrix;
	IBOutlet __unsafe_unretained LDrawColorWell *colorWell;
	IBOutlet __unsafe_unretained NSMatrix		*findTypeMatrix;
	IBOutlet __unsafe_unretained NSButton		*searchInsideLSynthContainers;
	IBOutlet __unsafe_unretained NSButton		*searchHiddenParts;
	IBOutlet __unsafe_unretained NSTextField	*partName;
	IBOutlet __unsafe_unretained NSTextField	*warningText;
}

//Initialization
+ (SearchPanelController *) searchPanel;

// Accessors
+ (BOOL) isVisible;

// Actions
- (IBAction)doSearchAndSelect:(id)sender;
- (IBAction)scopeChanged:(id)sender;
- (IBAction)colorOptionChanged:(id)sender;
- (IBAction)findTypeOptionChanged:(id)sender;

// Utility
- (void) updateInterfaceForSelection:(NSArray *)selectedObjects;

@end
