//==============================================================================
//
// File:		LDrawDocument.h
//
// Purpose:		Document controller for an LDraw document.
//
//				Opens the document and manages its editor and viewer.
//
//              To use elsewhere, do something like:
//
//                   #import "LDrawDocument.h"
//                   NSDocumentController *documentController = [NSDocumentController sharedDocumentController];
//                   LDrawDocument *currentDocument = [documentController currentDocument];
//
//  Created by Allen Smith on 2/14/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import <Cocoa/Cocoa.h>

#import "BricksmithUtilities.h"
#import "ColorLibrary.h"
#import "LDrawUtilities.h"
#import "MatrixMath.h"
#import "RotationPanelController.h"
#import "ViewportArranger.h"

@class DocumentToolbarController;
@class ExtendedSplitView;
@class LDrawContainer;
@class LDrawDirective;
@class LDrawDrawableElement;
@class LDrawFile;
@class LDrawFileOutlineView;
@class LDrawGLView;
@class LDrawModel;
@class LDrawMPDModel;
@class LDrawStep;
@class LDrawPart;
@class PartBrowserDataSource;


////////////////////////////////////////////////////////////////////////////////
//
// class LDrawDocument
//
////////////////////////////////////////////////////////////////////////////////
NS_ASSUME_NONNULL_BEGIN

@interface LDrawDocument : NSDocument <ViewportArrangerDelegate>

// Outlets and internal state are properties (P4) so that P10's Swift extensions can reach them; Swift can't see
// ivars. Each keeps its ivar name (@synthesize name = name) and the ivar's ownership. Bare outlets are
// unsafe_unretained, as under MRC (LEARNINGS L79). Other classes should not use the internal state.
// documentContents, the one remaining ivar, is reached through -documentContents / -setDocumentContents:.

@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet DocumentToolbarController	*toolbarController;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSObjectController			*bindingsController;

// Window satellites
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSDrawer					*partBrowserDrawer;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet PartBrowserDataSource		*partsBrowser;

// Scope bar
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSButton					*viewAllButton;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSButton					*viewStepsButton;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSPopUpButton				*submodelPopUpMenu;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSView						*scopeStepControlsContainer;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSTextField				*stepField;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSSegmentedControl			*stepNavigator;

// Window contents
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet ExtendedSplitView			*fileContentsSplitView;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet LDrawFileOutlineView		*fileContentsOutline;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSPopUpButton				*addReferenceButton;

// LDraw graphic view
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet ViewportArranger			*viewportArranger;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSTextField				*coordinateLabelX;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSTextField				*coordinateLabelY;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSTextField				*coordinateLabelZ;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSTextField				*coordinateFieldX;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSTextField				*coordinateFieldY;
@property (nonatomic, unsafe_unretained, null_unspecified) IBOutlet NSTextField				*coordinateFieldZ;

// Internal state (was @private)
@property (nonatomic, strong, null_unspecified) LDrawPart		*lastSelectedPart;		// the part in the file which was most recently selected in the contents. Set with the hand-written -setLastSelectedPart:.
@property (nonatomic, strong, null_unspecified) NSArray		*selectedDirectives;	// mirrors the selection of the file contents outline.
@property (nonatomic, strong, null_unspecified) NSArray		*selectedDirectivesBeforeCopyDrag;
@property (nonatomic, assign) gridSpacingModeT				gridMode;				// raw storage; -gridSpacingMode / -setGridSpacingMode: are the accessors (the setter updates the UI)
@property (nonatomic, assign) gridOrientationModeT			gridOrientation;		// raw storage; -gridOrientationMode / -setGridOrientationMode: are the accessors (the setter updates the UI)
@property (nonatomic, weak, null_unspecified) LDrawGLView		*mostRecentLDrawView;	// file graphic view which most recently had focus. Set with the hand-written -setMostRecentLDrawView:. Bound in LDrawDocument.xib (selection.mostRecentLDrawView.zoomPercentage).
@property (nonatomic, strong, null_unspecified) NSArray		*markedSelection;		// if we are mid-marquee selection, the previously selected directives before the drag started


// Random source for Randomize Colors (-randomizeLDrawColors:). Returns a
// non-negative int, as rand() does. nil (the default) means rand(); tests set
// a seeded source to make the action deterministic.
@property (nonatomic, copy, nullable) int (^randomSource)(void);

// Accessors
- (null_unspecified LDrawFile *) documentContents;
- (null_unspecified NSWindow *)foremostWindow;
- (gridSpacingModeT) gridSpacingMode;
- (gridOrientationModeT) gridOrientationMode;
- (Tuple3) viewingAngle;

- (void) setActiveModel:(null_unspecified LDrawMPDModel *)newActiveModel;
- (void) setCurrentStep:(NSInteger)requestedStep;
- (void) setDocumentContents:(null_unspecified LDrawFile *)newContents;
- (void) setGridSpacingMode:(gridSpacingModeT)newMode;
- (void) setGridOrientationMode:(gridOrientationModeT)newMode;
- (void) setStepDisplay:(BOOL)showStepsFlag;

//Notifications
- (void)partChanged:(null_unspecified NSNotification *)notification;
- (void)docChanged:(null_unspecified NSNotification *)notification;
- (void)stepChanged:(null_unspecified NSNotification *)notification;
- (void)syntaxColorChanged:(null_unspecified NSNotification *)notification;

@end


@interface LDrawDocument (FileIO)
// LDrawDocument+FileIO.m

// Activities
- (void) exportStepsToURL:(NSURL *)saveURL;

// - miscellaneous
- (void) doMissingModelnameExtensionCheck:(null_unspecified id)sender;
- (void) doMissingPiecesCheck:(null_unspecified id)sender;
- (void) doMovedPiecesCheck:(null_unspecified id)sender;

// - File menu
- (IBAction) exportSteps:(null_unspecified id)sender;
- (IBAction) revealInFinder:(null_unspecified id)sender;

@end


@interface LDrawDocument (Editing)
// LDrawDocument+Editing.m

// Activities
- (void) moveSelectionBy:(Vector3) movementVector;
- (void) nudgeSelectionBy:(Vector3) nudgeVector;
- (void) rotateSelectionAround:(Vector3)rotationAxis;
- (void) rotateSelection:(Tuple3)rotation mode:(RotationModeT)mode fixedCenter:(null_unspecified Point3 *)fixedCenter;
- (void) selectDirective:(null_unspecified LDrawDirective *)directiveToSelect byExtendingSelection:(BOOL)shouldExtend;
- (void) selectDirectives:(null_unspecified NSArray *)directivesToSelect;
- (void) setSelectionToHidden:(BOOL)hideFlag;
- (void) setZoomPercentage:(CGFloat)newPercentage;

// Actions
- (void) changeLDrawColor:(null_unspecified id)sender;
- (void) insertLDrawPart:(null_unspecified id)sender;
- (void) panelMoveParts:(null_unspecified id)sender;
- (void) panelRotateParts:(null_unspecified id)sender;

// - Edit menu
- (IBAction) copy:(null_unspecified id)sender;
- (IBAction) paste:(null_unspecified id)sender;
- (IBAction) delete:(null_unspecified id)sender;
- (IBAction) duplicate:(null_unspecified id)sender;
- (IBAction) splitStep:(null_unspecified id)sender;
- (IBAction) splitModel:(null_unspecified id)sender;
- (IBAction) orderFrontRotationPanel:(null_unspecified id)sender;
- (IBAction) quickRotateClicked:(null_unspecified id)sender;
- (IBAction) randomizeLDrawColors:(null_unspecified id)sender;
- (IBAction) find:(null_unspecified id)sender;
- (IBAction) changeOrigin:(null_unspecified id)sender;

// - Tools menu
- (IBAction) showInspector:(null_unspecified id)sender;
- (IBAction) toggleFileContentsDrawer:(null_unspecified id)sender;
- (IBAction) gridGranularityMenuChanged:(null_unspecified id)sender;
- (IBAction) gridOrientationModeChanged:(null_unspecified id)sender;
- (IBAction) showDimensions:(null_unspecified id)sender;
- (IBAction) showPieceCount:(null_unspecified id)sender;

// - Piece menu
- (IBAction) showParts:(null_unspecified id)sender;
- (IBAction) hideParts:(null_unspecified id)sender;
- (IBAction) showAllParts:(null_unspecified id)sender;
- (IBAction) gotoModel:(null_unspecified id)sender;
- (void) snapSelectionToGrid:(null_unspecified id)sender;

@end


@interface LDrawDocument (ModelsMenu)
// LDrawDocument+ModelsMenu.m

// - Models menu
- (IBAction) addModelClicked:(null_unspecified id)sender;
- (IBAction) addStepClicked:(null_unspecified id)sender;
- (IBAction) addPartClicked:(null_unspecified id)sender;
- (void) addSubmodelReferenceClicked:(null_unspecified id)sender;
- (IBAction) addLineClicked:(null_unspecified id)sender;
- (IBAction) addTriangleClicked:(null_unspecified id)sender;
- (IBAction) addQuadrilateralClicked:(null_unspecified id)sender;
- (IBAction) addConditionalClicked:(null_unspecified id)sender;
- (IBAction) addCommentClicked:(null_unspecified id)sender;
- (IBAction) addRawCommandClicked:(null_unspecified id)sender;
- (IBAction) addRelatedPartClicked:(null_unspecified id)sender;
- (void) modelSelected:(null_unspecified id)sender;

@end


@interface LDrawDocument (Undo)
// LDrawDocument+Undo.m

// Undoable Activities
- (void) addDirective:(null_unspecified LDrawDirective *)newDirective toParent:(null_unspecified LDrawContainer *)parent;
- (void) addDirective:(null_unspecified LDrawDirective *)newDirective toParent:(null_unspecified LDrawContainer *)parent atIndex:(NSInteger)index;
- (void) deleteDirective:(null_unspecified LDrawDirective *)doomedDirective;
- (void) moveDirective:(null_unspecified LDrawDrawableElement *)object inDirection:(Vector3)moveVector;
- (void) preserveDirectiveState:(null_unspecified LDrawDirective *)directive;
- (void) rotatePart:(null_unspecified LDrawPart *)part byDegrees:(Tuple3)rotationDegrees aroundPoint:(Point3)rotationCenter;
- (void) setElement:(null_unspecified LDrawDrawableElement *)element toHidden:(BOOL)hideFlag;
- (void) setObject:(null_unspecified LDrawDirective <LDrawColorable>*)object toColor:(null_unspecified LDrawColor *)newColor;
- (void) setTransformation:(TransformComponents)newComponents forPart:(null_unspecified LDrawPart *)part;

@end


@interface LDrawDocument (Viewers)
// LDrawDocument+Viewers.m

// Viewport Management
- (void) connectLDrawGLView:(null_unspecified LDrawGLView *)glView;
- (null_unspecified LDrawGLView *) main3DViewport;
- (void) updateViewportAutosaveNamesAndRestore:(BOOL)shouldRestore;

@end


@interface LDrawDocument (Menus)
// LDrawDocument+Menus.m

// - Scope bar
- (IBAction) viewAll:(null_unspecified id)sender;
- (IBAction) viewSteps:(null_unspecified id)sender;
- (IBAction) stepFieldChanged:(null_unspecified id)sender;
- (IBAction) stepNavigatorClicked:(null_unspecified id)sender;

// - View menu
- (IBAction) zoomActual:(null_unspecified id)sender;
- (IBAction) zoomIn:(null_unspecified id)sender;
- (IBAction) zoomOut:(null_unspecified id)sender;
- (IBAction) toggleStepDisplay:(null_unspecified id)sender;
- (IBAction) advanceOneStep:(null_unspecified id)sender;
- (IBAction) backOneStep:(null_unspecified id)sender;
- (IBAction) useSelectionForRotationCenter:(null_unspecified id)sender;
- (IBAction) clearRotationCenter:(null_unspecified id)sender;

//Menus
- (void) addModelsToMenus;
- (void) clearModelMenus;
- (void) buildRelatedPartsMenus;

@end


@interface LDrawDocument (Utilities)
// LDrawDocument+Utilities.m

// Utilities
- (void) addModel:(null_unspecified LDrawMPDModel *)newModel atIndex:(NSInteger)insertAtIndex preventNameCollisions:(BOOL)renameModels;
- (void) addStep:(null_unspecified LDrawStep *)newStep parent:(null_unspecified LDrawMPDModel*)selectedModel index:(NSInteger)insertAtIndex;
- (void) addPartNamed:(null_unspecified NSString *)partName;
- (void) addStepComponent:(null_unspecified LDrawDirective *)newDirective parent:(null_unspecified LDrawContainer*)parent index:(NSInteger)insertAtIndex;
- (BOOL) canDeleteDirective:(null_unspecified LDrawDirective *)directive displayErrors:(BOOL)errorFlag;
- (BOOL) elementsAreSelectedOfVisibility:(BOOL)visibleFlag;
- (null_unspecified NSAttributedString *) formatDirective:(null_unspecified LDrawDirective *)item withStringRepresentation:(null_unspecified NSString *)representation;
- (void) loadDataIntoDocumentUI;
- (null_unspecified LDrawContainer *) selectedContainer;
- (null_unspecified NSArray *) selectedObjects;
- (null_unspecified LDrawMPDModel *) selectedModel;
- (null_unspecified LDrawStep *) selectedStep;
- (null_unspecified LDrawDirective *) selectedStepComponent;
- (null_unspecified LDrawPart *) selectedPart;
- (void) updateInspector;
- (void) updateViewingAngleToMatchStep;
- (void) writeDirectives:(null_unspecified NSArray *)directives toPasteboard:(null_unspecified NSPasteboard *)pasteboard;
- (null_unspecified NSArray *) pasteFromPasteboard:(null_unspecified NSPasteboard *) pasteboard preventNameCollisions:(BOOL)renameModels parent:(null_unspecified LDrawContainer*)parent index:(NSInteger)insertAtIndex;
- (void) flushDocChangesAndSelect:(null_unspecified NSArray*)directives;

@end

NS_ASSUME_NONNULL_END
