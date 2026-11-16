//==============================================================================
//
// File:		LDrawDocument+Private.h
//
// Purpose:		What LDrawDocument's own files share and nothing else may use:
//				the imports, the instance variables behind the properties, and
//				the internal methods one category calls in another.
//
//				Imported only by LDrawDocument.m and its LDrawDocument+*.m
//				categories (P4 split). Not in the bridging header.
//
//==============================================================================
#import "LDrawDocument.h"

#import <AMSProgressBar/AMSProgressBar.h>

#import "DimensionsPanel.h"
#import "DocumentToolbarController.h"
#import "ExtendedSplitView.h"
#import "IconTextCell.h"
#import "Inspector.h"
#import "LDrawApplication.h"
#import "LDrawColor.h"
#import "LDrawColorPanelController.h"
#import "LDrawComment.h"
#import "LDrawConditionalLine.h"
#import "LDrawContainer.h"
#import "LDrawDirective.h"
#import "LDrawDocumentWindow.h"
#import "LDrawDragHandle.h"
#import "LDrawDrawableElement.h"
#import "LDrawFile.h"
#import "LDrawFileOutlineView.h"
#import "LDrawGLView.h"
#import "LDrawLine.h"
#import "LDrawLSynth.h"
#import "LDrawLSynthDirective.h"
#import "LDrawModel.h"
#import "LDrawMPDModel.h"
#import "LDrawPart.h"
#import "LDrawQuadrilateral.h"
#import "LDrawStep.h"
#import "LDrawTriangle.h"
#import "LDrawUtilities.h"
#import "LDrawViewerContainer.h"
#import "LSynthConfiguration.h"
#import "MacLDraw.h"
#import "MinifigureDialogController.h"
#import "ModelManager.h"
#import "MovePanel.h"
#import "PartBrowserDataSource.h"
#import "PartBrowserPanelController.h"
#import "PartReport.h"
#import "PieceCountPanel.h"
#import "RotationPanelController.h"
#import "SearchPanelController.h"
#import "StringUtilities.h"
#import "UserDefaultsCategory.h"
#import "ViewportArranger.h"
#import "WindowCategory.h"
#if WANT_RELATED_PARTS
#import "RelatedParts.h"
#endif


@interface LDrawDocument ()
{
	// Storage of the properties declared in LDrawDocument.h (@synthesize name = name in
	// LDrawDocument.m). Declared here, not synthesized, so the categories can use them.
	LDrawFile		*documentContents;	// use -documentContents / -setDocumentContents: (the setter turns on notifications)
	__unsafe_unretained DocumentToolbarController	*toolbarController;
	__unsafe_unretained NSObjectController	*bindingsController;
	__unsafe_unretained NSDrawer	*partBrowserDrawer;
	__unsafe_unretained PartBrowserDataSource	*partsBrowser;
	__unsafe_unretained NSButton	*viewAllButton;
	__unsafe_unretained NSButton	*viewStepsButton;
	__unsafe_unretained NSPopUpButton	*submodelPopUpMenu;
	__unsafe_unretained NSView	*scopeStepControlsContainer;
	__unsafe_unretained NSTextField	*stepField;
	__unsafe_unretained NSSegmentedControl	*stepNavigator;
	__unsafe_unretained ExtendedSplitView	*fileContentsSplitView;
	__unsafe_unretained LDrawFileOutlineView	*fileContentsOutline;
	__unsafe_unretained NSPopUpButton	*addReferenceButton;
	__unsafe_unretained ViewportArranger	*viewportArranger;
	__unsafe_unretained NSTextField	*coordinateLabelX;
	__unsafe_unretained NSTextField	*coordinateLabelY;
	__unsafe_unretained NSTextField	*coordinateLabelZ;
	__unsafe_unretained NSTextField	*coordinateFieldX;
	__unsafe_unretained NSTextField	*coordinateFieldY;
	__unsafe_unretained NSTextField	*coordinateFieldZ;
	LDrawPart	*lastSelectedPart;
	NSArray	*selectedDirectives;
	NSArray	*selectedDirectivesBeforeCopyDrag;
	gridSpacingModeT	gridMode;
	gridOrientationModeT	gridOrientation;
	__weak LDrawGLView	*mostRecentLDrawView;
	NSArray	*markedSelection;
}
@end
