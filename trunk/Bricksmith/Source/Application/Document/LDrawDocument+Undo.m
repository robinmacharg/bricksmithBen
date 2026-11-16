//==============================================================================
//
// File:		LDrawDocument+Undo.m
//
// Purpose:		The undoable activities: every edit of the document goes through
//				these, which register their inverses with the undo manager.
//
//				A category of LDrawDocument, split out of LDrawDocument.m (P4) so
//				that P10 can port it on its own. Shared declarations and the
//				instance variables are in LDrawDocument+Private.h.
//
//  Created by Allen Smith on 2/14/05.
//  Copyright (c) 2005. All rights reserved.
//==============================================================================
#import "LDrawDocument+Private.h"

@implementation LDrawDocument (Undo)

#pragma mark -
#pragma mark UNDOABLE ACTIVITIES
#pragma mark -

//these are *low-level* calls which provide support for the Undo architecture.
// all of these are wrapped by high-level calls, which are all application-level 
// code should ever need to use.


//========== addDirective:toParent: ============================================
//
// Purpose:		Undo-aware call to add a directive to the specified parent.
//
//==============================================================================
- (void) addDirective:(LDrawDirective *)newDirective
			 toParent:(LDrawContainer * )parent
{
	NSInteger index = [[parent subdirectives] count];
	
	[self addDirective:newDirective
			  toParent:parent
			   atIndex:index];
			   
}//end addDirective:toParent:


//========== addDirective:toParent:atIndex: ====================================
//
// Purpose:		Undo-aware call to add a directive to the specified parent.
//
//==============================================================================
- (void) addDirective:(LDrawDirective *)newDirective
			 toParent:(LDrawContainer * )parent
			  atIndex:(NSInteger)index
{
	NSUndoManager	*undoManager	= [self undoManager];
	
	{
		[[undoManager prepareWithInvocationTarget:self]
			deleteDirective:newDirective ];
	
		[parent insertDirective:newDirective atIndex:index];
	}
	CGLLockContext([[LDrawApplication sharedOpenGLContext] CGLContextObj]);
	{
		[[LDrawApplication sharedOpenGLContext] makeCurrentContext];
	}
	CGLUnlockContext([[LDrawApplication sharedOpenGLContext] CGLContextObj]);
	
}//end addDirective:toParent:atIndex:


//========== deleteDirective: ==================================================
//
// Purpose:		Removes the specified doomedDirective from its enclosing 
//				container.
//
// Notes:		If the doomed directive is selected, chaos breaks out.  (The
//				act of removing the directive triggers a rebuilding of the 
//				outliner.  The outliner rebuild triggers a push of the cached
//				selection back to the outliner.  The cached selection will have
//				doomedDirective and the outliner won't, causing the push of the
//				selection to fail with an ObjC exception.
///
//==============================================================================
- (void) deleteDirective:(LDrawDirective *)doomedDirective
{
	NSUndoManager   *undoManager    = [self undoManager];
	LDrawContainer  *parent         = [doomedDirective enclosingDirective];
	NSInteger       index           = [[parent subdirectives] indexOfObject:doomedDirective];
	
	{
		[[undoManager prepareWithInvocationTarget:self]
				addDirective:doomedDirective
					toParent:parent
					 atIndex:index ];
		
		[parent removeDirective:doomedDirective];
	}

	// After a directive is deleted, we need to resynchronize our step field - maybe the current step changed.
	// There may be other places where we need this too.
	[self->stepField setIntegerValue:[[[self documentContents] activeModel] maximumStepIndexForStepDisplay] + 1];

}//end deleteDirective:


//========== moveDirective:inDirection: ========================================
//
// Purpose:		Undo-aware call to move the object in the direction indicated. 
//				The vector here should indicate the exact amount to move. It 
//				should be adjusted to the grid mode already).
//
//==============================================================================
- (void) moveDirective:(LDrawDrawableElement *)object
		   inDirection:(Vector3)moveVector
{
	NSUndoManager	*undoManager	= [self undoManager];
	Vector3			 opposite		= {0};
	
	//Prepare the undo.
	
	opposite.x = -(moveVector.x);
	opposite.y = -(moveVector.y);
	opposite.z = -(moveVector.z);
	
	{
			[[undoManager prepareWithInvocationTarget:self]
				moveDirective: object
				  inDirection: opposite ];
		[undoManager setActionName:NSLocalizedString(@"UndoMove", nil)];
		
		//Do the move.
		[object moveBy:moveVector];
	}
	
	//our part changed; notify!
	[object noteNeedsDisplay];
								  
}//end moveDirective:inDirection:


//========== preserveDirectiveState: ===========================================
//
// Purpose:		Records the entire state of the object with the undo manager. 
//
// Note:		Undo operations are stored on a *stack*, so the order of undo 
//				registration in the code is the opposite from the order in 
//				which the undo operations are executed.
//
//==============================================================================
- (void) preserveDirectiveState:(LDrawDirective *)directive
{
	NSUndoManager	*undoManager	= [self undoManager];

	{
		// ** Read code bottom-to-top ** //

		[[undoManager prepareWithInvocationTarget:directive] noteNeedsDisplay];
		[directive registerUndoActions:undoManager];
		
		[[undoManager prepareWithInvocationTarget:self]
								preserveDirectiveState:directive ];
	}
	
}//end preserveDirectiveState:


//========== rotatePart:onAxis:byDegrees: ======================================
//
// Purpose:		Undo-aware call to rotate the object in the direction indicated. 
//
// Notes:		This gets a little tricky because there is more than one way 
//				to represent a single rotation when using three rotation angles. 
//				Since we don't really know which one was intended, we can't just 
//				blithely manipulate the rotation components.
//
//				Instead, we must generate a new transformation matrix that 
//				rotates by degreesToRotate in the desired direction. Then we 
//				multiply that matrix by the part's current transformation. This 
//				way, we can rest assured that we rotated the part exactly the 
//				direction the user intended, no matter what goofy representation
//				the components came up with.
//
//				Caveat: We have to zero out the translation components of the 
//				part's transformation before we append our new rotation. Thus 
//				the part will be rotated in place.
//
//==============================================================================
- (void) rotatePart:(LDrawPart *)part
		  byDegrees:(Tuple3)rotationDegrees
		aroundPoint:(Point3)rotationCenter
{

	NSUndoManager	*undoManager		= [self undoManager];
	Tuple3			 oppositeRotation	= V3AntiEuler(rotationDegrees);
	
	[[undoManager prepareWithInvocationTarget:self]
			rotatePart: part
			 byDegrees: oppositeRotation
		   aroundPoint: rotationCenter  ]; //undo: rotate backwards
	[undoManager setActionName:NSLocalizedString(@"UndoRotate", nil)];
	
	
	{
		[part rotateByDegrees:rotationDegrees centerPoint:rotationCenter];
	}
	
	[part noteNeedsDisplay];
	
} //rotatePart:onAxis:byDegrees:


//========== setElement:toHidden: ==============================================
//
// Purpose:		Undo-aware call to change the visibility attribute of an element.
//
//==============================================================================
- (void) setElement:(LDrawDrawableElement *)element toHidden:(BOOL)hideFlag
{
	NSUndoManager	*undoManager	= [self undoManager];
	NSString		*actionName		= nil;
	
	if(hideFlag == YES)
		actionName = NSLocalizedString(@"UndoHidePart", nil);
	else
		actionName = NSLocalizedString(@"UndoShowPart", nil);
	
	{
			[[undoManager prepareWithInvocationTarget:self]
			setElement:element
			  toHidden:(!hideFlag) ];
		[undoManager setActionName:actionName];
		
		[element setHidden:hideFlag];
	}
	[element noteNeedsDisplay];

}//end setElement:toHidden:


//========== setObject:toColor: ================================================
//
// Purpose:		Undo-aware call to change the color of an object.
//
//==============================================================================
- (void) setObject:(LDrawDirective <LDrawColorable>* )object toColor:(LDrawColor *)newColor
{
	NSUndoManager *undoManager = [self undoManager];
	
	[[undoManager prepareWithInvocationTarget:self]
												setObject:object
												  toColor:[object LDrawColor] ];
	[undoManager setActionName:NSLocalizedString(@"UndoColor", nil)];
	
	{
		[object setLDrawColor:newColor];
	}
	[object noteNeedsDisplay];

}//end setObject:toColor:


//========== setTransformation:forPart: ========================================
//
// Purpose:		Undo-aware call to set the entire transformation for a part. 
//				This is an important step in snapping a part to the grid.
//
//==============================================================================
- (void) setTransformation:(TransformComponents)newComponents
				   forPart:(LDrawPart *)part
{
	NSUndoManager		*undoManager		= [self undoManager];
	TransformComponents	 currentComponents	= [part transformComponents];
	
	{
		[part setTransformComponents:newComponents];
		
		//Be ready to restore the old components.
		[[undoManager prepareWithInvocationTarget:self]
				setTransformation:currentComponents
						  forPart:part ];
		
		[undoManager setActionName:NSLocalizedString(@"UndoSnapToGrid", nil)];
	}
	[part noteNeedsDisplay];
	
}//end setTransformation:forPart:

@end
