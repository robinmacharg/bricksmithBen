//==============================================================================
//
// File:		PartBrowserDataSource.h
//
// Purpose:		Provides a standarized data source for part browser interface.
//
//  Created by Allen Smith on 2/17/05.
//  Copyright 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "LDrawGLView.h"
#import "MacLDraw.h"

@class LDrawViewerContainer;
@class PartLibrary;

////////////////////////////////////////////////////////////////////////////////
//
// class PartBrowserDataSource
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface PartBrowserDataSource : NSObject <NSOutlineViewDelegate, NSOutlineViewDataSource>
{
	IBOutlet NSButton		*searchAllCategoriesButton;
	IBOutlet NSButton		*searchSelectedCategoryButton;
	IBOutlet NSSearchField	*searchField;
	
	IBOutlet NSOutlineView	*categoryTable;
	IBOutlet NSTableView	*partsTable;
	IBOutlet LDrawGLView	*partPreview;
	IBOutlet LDrawViewerContainer	*partPreviewViewport;
	IBOutlet NSButton		*zoomInButton;
	IBOutlet NSButton		*zoomOutButton;
	IBOutlet NSButton		*addRemoveFavoriteButton;
	IBOutlet NSButton		*insertButton;
	IBOutlet NSMenu			*contextualMenu;

	PartLibrary     *partLibrary; //weak reference to the shared part catalog.
	NSString		*selectedCategory;
	NSArray         *categoryList;
	NSMutableArray  *tableDataSource;
	SearchModeT		searchMode;

}

//Accessors
- (null_unspecified NSString *) category;
- (null_unspecified NSString *) selectedPartName;

- (void) setPartLibrary:(null_unspecified PartLibrary *)partLibraryIn;
- (BOOL) loadCategory:(null_unspecified NSString *)newCategory;
- (void) setCategoryList:(null_unspecified NSArray *)categoryList;
- (void) setTableDataSource:(null_unspecified NSMutableArray *) partsInCategory;

//Actions
- (IBAction) searchAllCategoriesButtonClicked:(null_unspecified id)sender;
- (IBAction) searchSelectedCategoryButtonClicked:(null_unspecified id)sender;
- (IBAction) addPartClicked:(null_unspecified id)sender;
- (IBAction) addFavoriteClicked:(null_unspecified id)sender;
- (void) doubleClickedInPartTable:(null_unspecified id)sender;
- (IBAction) removeFavoriteClicked:(null_unspecified id)sender;
- (IBAction) searchFieldChanged:(null_unspecified id)sender;

//Notifications
- (void) sharedPartCatalogDidChange:(null_unspecified NSNotification *)notification;

//Utilities
- (null_unspecified NSMutableArray *) filterPartRecords:(null_unspecified NSArray *)partRecords bySearchString:(null_unspecified NSString *)searchString excludeParts:(null_unspecified NSSet *)excludedParts;
- (NSUInteger) indexOfPartNamed:(null_unspecified NSString *)searchName;
- (void) performSearch;
- (void) setConstraints;
- (void) scrollSelectedCategoryToCenter;
- (void) syncSelectionAndCategoryDisplayed;
- (void) syncSelectionAndPartDisplayed;
- (BOOL) writeSelectedPartToPasteboard:(null_unspecified NSPasteboard *)pasteboard;

@end

NS_ASSUME_NONNULL_END
