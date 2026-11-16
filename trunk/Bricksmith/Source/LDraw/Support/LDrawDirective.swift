//==============================================================================
//
// File:		LDrawDirective.swift
//
// Purpose:		Base class for all LDraw objects provides a few basic utilities.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//
//  Ported to Swift in P6c. LDrawDirective.h survives as a types-only header
//  (CacheFlagsT, MessageT, the LDrawObserver/LDrawObservable protocols, the
//  notification and DRAW_* macros, LDrawPartVisitor) plus the three
//  initializer shims this file uses (see "Initializer shims" below).
//
//  The observer set is the port of LDrawFastSet.h (NEW_SET was hard-coded to
//  1; the NSMutableSet-only branch is gone): see "OBSERVER SET".
//==============================================================================

import Foundation


@objc(LDrawDirective)
class LDrawDirective: NSObject, NSCoding, NSCopying, LDrawObservable {

	// Coder keys over 15 ASCII bytes would bridge to a new NSString per call (L102).
	private static let enclosingDirectiveKey = NSString(string: "enclosingDirective") as String

	// Stored defaults are trivial: the parse initializers re-enter init() on
	// the half-built object (as -[LDrawDirective initWithLines:...] sent
	// [self init]), which initializes them again without releasing them.
	//
	// The parent: unretained, as the ObjC's __unsafe_unretained ivar (never
	// weak: zeroing would change behaviour and cost).
	@exclusivity(unchecked) private unowned(unsafe) var enclosingDirectiveRef: LDrawContainer? = nil

	// The observer set (LDrawFastSet), observers unretained:
	//	observerP1	observerP2	meaning
	//	nil			nil			empty
	//	a			nil			{a}
	//	a			b			{a, b}, told in that order
	//	nil			set			3 or more: set is an NSMutableSet of
	//							NSValue(pointer:), owned +1 (Unmanaged)
	@exclusivity(unchecked) private var observerP1: UnsafeMutableRawPointer? = nil
	@exclusivity(unchecked) private var observerP2: UnsafeMutableRawPointer? = nil

	@exclusivity(unchecked) private var invalFlags: CacheFlagsT = CacheFlagsT(rawValue: 0)
	@exclusivity(unchecked) private var selected: Bool = false
	// nil after decoding (initWithCoder: never set it); -iconName answers "".
	private var iconNameStorage: String? = nil


	//========== defaultIconName ===================================================
	//
	// Purpose:		Return the base icon name for this type of LDraw directive
	//
	//==============================================================================
	@objc(defaultIconName)
	class func defaultIconName() -> String! {
		return nil
	}


	// MARK: - INITIALIZATION

	//========== init ==============================================================
	//
	// Purpose:		Start me up. This should be called before any other subclass
	//				initialization code.
	//
	//==============================================================================
	@objc(init)
	override init() {
		super.init()

		enclosingDirectiveRef	= nil
		iconNameStorage			= ""

		// (LDrawFastSetInit)
		observerP1 = nil
		observerP2 = nil

	}//end init


	//---------- directiveWithLines:inRange:parentGroup: ----------------[static]--
	//
	// Purpose:		Returns a directive parsed from the given lines.
	//
	//				Subclasses whose syntax decides the class of the result (such
	//				as LDrawMetaCommand) override this method; inits always return
	//				an instance of the class they were sent to.
	//
	// Notes:		[[self alloc] initWithLines:inRange:parentGroup:] through the
	//				header shim: see LDrawDirectiveAllocInitWithLines.
	//
	//------------------------------------------------------------------------------
	@objc(directiveWithLines:inRange:parentGroup:)
	class func directive(lines: [NSObject]!, in range: NSRange, parentGroup: dispatch_group_t?) -> LDrawDirective? {
		guard let directive = LDrawDirectiveAllocInitWithLines(self, lines, range, parentGroup) else {
			return nil
		}
		return unsafeDowncast(directive, to: LDrawDirective.self)

	}//end directiveWithLines:inRange:parentGroup:


	//========== initWithLines:inRange: ============================================
	//
	// Purpose:		Convenience method to perform a blocking parse operation
	//
	// Notes:		Designated, not convenience: the Swift subclasses override it
	//				(some with convenience initializers, which Swift allows only
	//				over a designated one). The ObjC sent
	//				[self initWithLines:inRange:parentGroup:NULL], reaching the
	//				subclass's parse initializer; a designated initializer can't
	//				delegate to self, so that message goes through the header shim
	//				after NSObject's init.
	//
	//==============================================================================
	@objc(initWithLines:inRange:)
	init!(lines: [NSObject]!, in range: NSRange) {
		super.init()

		guard LDrawDirectiveSendInitWithLines(self, lines, range, nil) != nil else {
			return nil
		}

	}//end initWithLines:inRange:


	//========== initWithLines:inRange:parentGroup: ================================
	//
	// Purpose:		Returns the LDraw directive based on lineFromFile, a single line
	//				of LDraw code from a file.
	//
	//				This method is intended to be overridden by subclasses.
	//				LDrawDirective's implementation simply returns a useless empty
	//				directive.
	//
	//				A subclass implementation would look something like:
	//				---------------------------------------------------------------
	//
	//				Class LineTypeClass = [LDrawUtilities classForDirectiveBeginningWithLine:lineFromFile];
	//				// Then initialize whatever subclass we came up with for this line.
	//
	// Notes:		The ObjC's first statement was [self init] ("call basic
	//				initializer"), which runs the subclass's -init: subclasses
	//				rely on it (LDrawContainer's children array, LDrawModel's
	//				colour library, LDrawPart's icon and transform). Sent through
	//				the header shim after NSObject's init, as a designated
	//				initializer can't delegate to self.
	//
	//==============================================================================
	@objc(initWithLines:inRange:parentGroup:)
	init!(lines: [NSObject]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		super.init()

		_ = LDrawDirectiveSendInit(self) // call basic initializer

		if (lines?.count ?? 0) == 0 {
			return nil
		}

	}//end initWithLines:inRange:


	//========== initWithCoder: ====================================================
	//
	// Purpose:		Reads a representation of this object from the given coder,
	//				which is assumed to always be a keyed decoder. This allows us to
	//				read and write LDraw objects as NSData.
	//
	//==============================================================================
	@objc(initWithCoder:)
	required init?(coder decoder: NSCoder) {
		//The superclass doesn't support NSCoding. So we just call the default init.
		super.init()

		// (LDrawFastSetInit: the stored defaults.)

		// Passed on unchecked, as the ObjC did: a malformed archive's object of
		// another class is stored as is, not turned into nil.
		let parent = decoder.decodeObject(forKey: LDrawDirective.enclosingDirectiveKey) as AnyObject?
		self.setEnclosing(unsafeBitCast(parent, to: LDrawContainer?.self))

	}//end initWithCoder:


	//========== encodeWithCoder: ==================================================
	//
	// Purpose:		Writes a representation of this object to the given coder,
	//				which is assumed to always be a keyed decoder. This allows us to
	//				read and write LDraw objects as NSData.
	//
	//==============================================================================
	@objc(encodeWithCoder:)
	func encode(with encoder: NSCoder) {
		//self = [super encodeWithCoder:encoder]; //super doesn't implement this method.

		//We encode the parent conditionally--it won't actually get encoded unless
		// someone else encodes the parent unconditionally.
		encoder.encodeConditionalObject(enclosingDirectiveRef, forKey: LDrawDirective.enclosingDirectiveKey)

	}//end encodeWithCoder:


	//========== copyWithZone: =====================================================
	//
	// Purpose:		Returns a duplicate of this object.
	//				This thing has issues. Note caveats in LDrawContainer.
	//
	//==============================================================================
	@objc(copyWithZone:)
	func copy(with zone: NSZone? = nil) -> Any {
		//Allocate a new instance because we don't inherit -copy: from anybody.
		// Note the code to ensure that the correct subclass is allocated!
		// Since LDrawDirective is the root LDraw class, all [subclass copy]
		// messages wind up here. ([[[self class] allocWithZone:zone] init]:
		// the zone was ignored; type(of:) is [self class], KVO included, L111.)
		let copied = unsafeDowncast((type(of: self) as NSObject.Type).init(), to: LDrawDirective.self)

		copied.setEnclosing(nil) //if that is to be copied, then it should be assigned via accessors.
		copied.setSelected(self.selected)	// the stored flag, not -isSelected (overridden)

		return copied

	}//end copyWithZone:


	// MARK: -

	//---------- rangeOfDirectiveBeginningAtIndex:inLines:maxIndex: ------[static]--
	//
	// Purpose:		Returns the range from the first to the last LDraw line of the
	//				directive which starts at index.
	//
	//				This is a core method of the LDraw parser. It allows supporting
	//				multiline directives and parallelization in parsing.
	//
	// Parameters:	index	- Index of first line to be considered for the directive
	//				lines	- (Potentially) All the lines of the enclosing file. The
	//						  directive is represented by a subset of the lines in
	//						  the range between index and maxIndex.
	//				maxIndex- Index of the last line which could possibly be part of
	//						  the directive.
	//
	// Notes:		Subclasses of LDrawDirective override this method. You should
	//				ALWAYS call this method on a subclass. Find the subclass using
	//				+[LDrawUtilities classForDirectiveBeginningWithLine:].
	//
	//------------------------------------------------------------------------------
	@objc(rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:)
	class func rangeOfDirectiveBeginning(at index: UInt, inLines lines: [NSObject]!, maxIndex: UInt) -> NSRange {
		// Most LDraw directives are only one line. For those that aren't the
		// subclass should override this method and perform its own parsing.
		return NSMakeRange(Int(bitPattern: index), 1)

	}//end rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:


	// MARK: - DIRECTIVES

	//========== draw:viewScale:parentColor: =======================================
	//
	// Purpose:		Issues the OpenGL code necessary to draw this element.
	//
	//				This method is intended to be overridden by subclasses.
	//				LDrawDirective's implementation does nothing.
	//
	//==============================================================================
	@objc(draw:viewScale:parentColor:)
	func draw(_ optionsMask: UInt, viewScale scaleFactor: Float, parentColor: LDrawColor!) {
		//subclasses should override this with OpenGL code to draw the line.

	}//end draw:viewScale:parentColor:


	//========== boundingBox3 ======================================================
	//
	// Purpose:		return the bounds (in model space) of the directive.
	//
	// Notes:		This routine is cached - the observers have a flag for whether
	//				bounding box is invalidated.  Thus implementations that have a
	//				sane bounding box should call revalCache before returning a
	//				value.
	//
	//				Directives that don't have spatial meaning (e.g. hidden
	//				directives and comments) can return InvalidBox.
	//
	//==============================================================================
	@objc(boundingBox3)
	func boundingBox3() -> Box3 {
		return InvalidBox
	}//end boundingBox3


	//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =======
	//
	// Purpose:		Tests the directive and any of its children for intersections
	//				between the pickRay and the directive's drawn content.
	//
	// Parameters:	pickRay - in world coordinates
	//				transform - transformation to apply to directive points to get
	//						to world coordinates
	//				scaleFactor - the window zoom level (1.0 == 100%)
	//				boundsOnly - test the bounding box, rather than the
	//						fully-detailed geometry
	//				creditObject - object which should get credit if the
	//						current object has been hit. (Used to credit nested
	//						geometry to its parent.) If nil, the hit object credits
	//						itself.
	//				hits - keys are hit objects. Values are NSNumbers of hit depths.
	//
	//==============================================================================
	@objc(hitTest:transform:viewScale:boundsOnly:creditObject:hits:)
	func hitTest(_ pickRay: Ray3, transform: Matrix4, viewScale scaleFactor: Float, boundsOnly: Bool,
				 creditObject: Any!, hits: NSMutableDictionary!) {
		//subclasses should override this with hit-detection code

	}//end hitTest:transform:viewScale:boundsOnly:creditObject:hits:


	//========== boxTest:transform:boundsOnly:creditObject:hits: ===================
	//
	// Purpose:		Tests the directive and any of its children for intersections
	//				between the directive's drawn form and the bounding box in the
	//				XY plane, after perspective divide.
	//
	// Parameters:	bounds - the box to test against, in post-projection (clip)
	//						coordinates
	//				transform - transformation to apply to directive points to get
	//						to clip coordinates - perspective divide is required!
	//				creditObject - object which should get credit if the
	//						current object has been hit. (Used to credit nested
	//						geometry to its parent.) If nil, the hit object credits
	//						itself.
	//				hits - a set of hit directives that we have accumulated so far
	//						this routine adds more as found.
	//
	// Return:		This function returns true if the _credit object_ was added to
	//				the set.  This allows hierarchies below the credit object to
	//				early-exit.
	//
	// Notes:		This test is used to do marquee selection - the marquee is
	//				converted back from viewport to clip coordinates, and then
	//				the primitive is forward-transformed to clip coordinates, for a
	//				simple 2-d screen-space test.
	//
	//==============================================================================
	// (@discardableResult: LDrawGLRenderer.m ignores the result, which the ObjC
	// declaration allowed; without it Bricksmith-Swift.h warns there.)
	@discardableResult
	@objc(boxTest:transform:boundsOnly:creditObject:hits:)
	func boxTest(_ bounds: Box2, transform: Matrix4, boundsOnly: Bool, creditObject: Any!, hits: NSMutableSet!) -> Bool {
		//subclasses should override this with hit-detection code
		return false

	}//end boxTest:transform:boundsOnly:creditObject:hits:


	//========== depthTest:inBox:transform:creditObject:bestObject:bestDepth:=======
	//
	// Purpose:		depthTest finds the closest primitive (in screen space)
	//				overlapping a given point, as well as its device coordinate
	//				depth.
	//
	// Parameters:	pt - the 2-d location (in screen space) to intersect.
	//				inBox - a bounding box in XY (in screen space) surrounding the
	//						test point.  The size of the box (e.g. how much bigger
	//						it is than the point) defines the "slop" for testing
	//						infinitely thin primitives like lines and drag handles.
	//				transform - a model view and projection matrix to transform from
	//						the directive's model coordinates to screen space.
	//				creditObject - if not nil, we credit this object with the hit;
	//						otherwise we use self.
	//				bestObject - a ptr to an object that is rewritten with the new
	//						best object if one is found.
	//				depth - a ptr to a depth (in normalized device coordinates: -1
	//						is max near, 1 is max far) of that best object.  If a
	//						hit is recorded, depth is updated.
	//
	// Notes:		Depth testing uses "replace if closer" semantics to provide
	//				return results; thus bestDepth should be initialized to point
	//				to 1.0f (the far clip plane) before being called.
	//
	//==============================================================================
	@objc(depthTest:inBox:transform:creditObject:bestObject:bestDepth:)
	func depthTest(_ testPt: Point2, inBox bounds: Box2, transform: Matrix4, creditObject: Any!,
				   bestObject: AutoreleasingUnsafeMutablePointer<AnyObject?>!, bestDepth: UnsafeMutablePointer<Float>!) {
		// subclasses should override this.

	}//end depthTest:inBox:transform: creditObject:bestObject:bestDepth:


	//========== write =============================================================
	//
	// Purpose:		Returns the LDraw code for this directive, which can then be
	//				written out to a LDraw file and read by any LDraw interpreter.
	//
	//				This method is intended to be overridden by subclasses.
	//				LDrawDirective's implementation does nothing.
	//
	//==============================================================================
	@objc(write)
	func write() -> String! {
		//Returns a representation of the line which can be written out to a file.
		return "" //empty string; subclasses should override this method.

	}//end write


	// MARK: - DISPLAY

	//========== browsingDescription ===============================================
	//
	// Purpose:		Returns a representation of the directive as a short string
	//				which can be presented to the user.
	//
	//==============================================================================
	@objc(browsingDescription)
	func browsingDescription() -> String! {
		return NSStringFromClass(type(of: self))	// ("%@" of [self class])

	}//end browsingDescription


	//========== iconName ==========================================================
	//
	// Purpose:		Returns the name of image file used to display this kind of
	//				object.
	//
	//==============================================================================
	@objc(iconName)
	func iconName() -> String! {
		if let iconNameStorage {
			return iconNameStorage
		}
		return "" //Nothing.

	}//end iconName


	//========== inspectorClassName ================================================
	//
	// Purpose:		Returns the name of the class used to inspect this one.
	//
	//==============================================================================
	@objc(inspectorClassName)
	func inspectorClassName() -> String! {
		return ""

	}//end inspectorClassName


	// MARK: - ACCESSORS

	//========== ancestors =========================================================
	//
	// Purpose:		Returns the ancestors enclosing this directive (as well as the
	//				directive itself), with the oldest ancestor (highest node) at
	//				the first index.
	//
	//==============================================================================
	@objc(ancestors)
	final func ancestors() -> [Any]! {
		let ancestors						= NSMutableArray(capacity: 3)
		var currentAncestor: LDrawDirective?	= self

		while let ancestor = currentAncestor {
			ancestors.insert(ancestor, at: 0)
			currentAncestor = ancestor.enclosingDirective()
		}

		return ancestors as? [Any]

	}//end ancestors


	//========== enclosingDirective ================================================
	//
	// Purpose:		Bricksmith imposes a rigid hierarchy on the data in a file:
	//
	//				LDrawFile
	//					|
	//					|-----> LDrawMPDModels
	//								|
	//								|-----> LDrawSteps
	//											|
	//											|-----> LDrawParts
	//											|
	//											|-----> LDraw Primitives
	//											|
	//											|-----> LDrawMetaCommands
	//
	//				With the exception of LDrawFile at the root, all directives
	//				must be enclosed within another directive. This method returns
	//				the directive in which this one is stored.
	//
	// Notes:		LDrawFiles return nil.
	//
	//==============================================================================
	@objc(enclosingDirective)
	final func enclosingDirective() -> LDrawContainer! {
		return enclosingDirectiveRef

	}//end enclosingDirective


	//========== enclosingFile =====================================================
	//
	// Purpose:		Returns the highest LDrawFile which contains this directive, or
	//				nil if the directive is not in the hierarchy of an LDrawFile.
	//
	// Notes:		(It returns the nearest one, self included.)
	//
	//==============================================================================
	@objc(enclosingFile)
	func enclosingFile() -> LDrawFile! {
		var currentAncestor: LDrawDirective? = self

		while let ancestor = currentAncestor {
			if ancestor is LDrawFile {
				return unsafeDowncast(ancestor, to: LDrawFile.self)
			}
			currentAncestor = ancestor.enclosingDirective()
		}

		return nil

	}//end enclosingFile


	//========== enclosingModel ====================================================
	//
	// Purpose:		Returns the highest LDrawModel which contains this directive, or
	//				nil if the directive is not in the hierarchy of an LDrawModel.
	//
	// Notes:		(It returns the nearest one, self included.)
	//
	//==============================================================================
	@objc(enclosingModel)
	func enclosingModel() -> LDrawModel! {
		var currentAncestor: LDrawDirective? = self

		while let ancestor = currentAncestor {
			if ancestor is LDrawModel {
				return unsafeDowncast(ancestor, to: LDrawModel.self)
			}
			currentAncestor = ancestor.enclosingDirective()
		}

		return nil

	}//end enclosingModel


	//========== enclosingStep =====================================================
	//
	// Purpose:		Returns the highest LDrawStep which contains this directive, or
	//				nil if the directive is not in the hierarchy of an LDrawStep.
	//
	// Notes:		(It returns the nearest one, self included.)
	//
	//==============================================================================
	@objc(enclosingStep)
	final func enclosingStep() -> LDrawStep! {
		var currentAncestor: LDrawDirective? = self

		while let ancestor = currentAncestor {
			if ancestor is LDrawStep {
				return unsafeDowncast(ancestor, to: LDrawStep.self)
			}
			currentAncestor = ancestor.enclosingDirective()
		}

		return nil

	}//end enclosingStep


	//========== isSelected ========================================================
	//
	// Purpose:		Returns whether this directive thinks it's selected.
	//
	//==============================================================================
	@objc(isSelected)
	func isSelected() -> Bool {
		return selected

	}//end isSelected


	// MARK: -

	//========== setEnclosingDirective: ============================================
	//
	// Purpose:		Just about all directives can be nested inside another one, so
	//				this is where this method landed.
	//
	//==============================================================================
	@objc(setEnclosingDirective:)
	func setEnclosing(_ newParent: LDrawContainer!) {
		enclosingDirectiveRef = newParent

	}//end setEnclosingDirective:


	//========== setSelected: ======================================================
	//
	// Purpose:		Somebody make this a protocol method.
	//
	//==============================================================================
	@objc(setSelected:)
	func setSelected(_ flag: Bool) {
		selected = flag

	}//end setSelected:


	//========== setIconName: ======================================================
	//
	// Purpose:		Set the icon name
	//
	//==============================================================================
	@objc(setIconName:)
	final func setIconName(_ icon: String!) {
		iconNameStorage = icon
	}//end setIconName:


	// MARK: - UTILITIES
	//This is stuff that didn't really go anywhere else.

	//========== containsReferenceTo: ==============================================
	//
	// Purpose:		Overridden by subclasses to indicate if the object (or any of
	//				its potential children) references a model with the given name.
	//
	//==============================================================================
	@objc(containsReferenceTo:)
	func containsReference(to name: String!) -> Bool {
		return false
	}


	//========== description =======================================================
	//
	// Purpose:		Overrides NSObject method to get a more meaningful description
	//				suitable for printing to the console.
	//
	//==============================================================================
	override var description: String {
		return "\(NSStringFromClass(type(of: self)))\n\(self.write() ?? "(null)")"

	}//end description


	//========== flattenIntoLines:triangles:quadrilaterals:other:currentColor: =====
	//
	// Purpose:		Appends the directive (or a copy of the directive) into the
	//				appropriate container.
	//
	// Notes:		This is used to flatten a complicated hiearchy of primitives and
	//				part references to files containing yet more primitives into a
	//				single flat list, which may be drawn to produce a shape visually
	//				identical to the original structure. The flattened structure,
	//				however, has the advantage that it is much faster to traverse
	//				during drawing.
	//
	//				This is the core of -[LDrawModel optimizeStructure].
	//
	//==============================================================================
	@objc(flattenIntoLines:triangles:quadrilaterals:other:currentColor:currentTransform:normalTransform:recursive:)
	func flatten(intoLines lines: NSMutableArray!, triangles: NSMutableArray!, quadrilaterals: NSMutableArray!,
				 other everythingElse: NSMutableArray!, currentColor parentColor: LDrawColor!,
				 currentTransform transform: Matrix4, normalTransform: Matrix3, recursive: Bool) {
		// By default, a directive does not add itself to the list, an indication
		// that it is not drawn. Subclasses override this routine to add themselves
		// to the appropriate list.

	}//end flattenIntoLines:triangles:quadrilaterals:other:currentColor:


	//========== isAncestorInList: =================================================
	//
	// Purpose:		Given a list of LDrawContainers, returns YES if any of the
	//				containers is a direct ancestor of the receiver. An ancestor is
	//				specified by enclosingDirective; each enclosingDirective can
	//				also have an ancestor. This method searchs the whole chain.
	//
	// Note:		I think this method is potentially buggy. Shouldn't we be doing
	//				pointer equality tests?
	//
	//==============================================================================
	@objc(isAncestorInList:)
	final func isAncestor(inList containers: [Any]!) -> Bool {
		guard let containers else {
			return false	// (a message to a nil array answered NO)
		}
		let list						= containers as NSArray
		var ancestor: LDrawDirective?	= self
		var foundInList					= false

		repeat {
			ancestor = ancestor?.enclosingDirective()
			// (-containsObject:nil answered NO; a Swift nil would bridge to NSNull.)
			foundInList = ancestor.map { list.contains($0) } ?? false

		} while ancestor != nil && foundInList == false

		return foundInList

	}//end isAncestorInList:


	//========== noteNeedsDisplay ==================================================
	//
	// Purpose:		An object can certainly be displayed in multiple views, and we
	//				don't really care to find out which ones here. So we just post
	//				a notification, and anyone can pick that up.
	//
	//==============================================================================
	@objc(noteNeedsDisplay)
	final func noteNeedsDisplay() {
		NotificationCenter.default.post(name: NSNotification.Name(LDrawDirectiveDidChangeNotification),
										object: self)
	}//end setNeedsDisplay


	//========== registerUndoActions: ==============================================
	//
	// Purpose:		Registers the undo actions that are unique to this subclass,
	//				not to any superclass.
	//
	//==============================================================================
	@objc(registerUndoActions:)
	func registerUndoActions(_ undoManager: UndoManager!) {
		//LDrawDirectives are fairly abstract, so all undoable attributes come
		// from subclasses.

	}//end registerUndoActions:


	//========== addObserver: ========================================================
	//
	// Purpose:		Adds a directive as an observer of _this_ directive.  Implements
	//				the observable protocol.
	//
	//================================================================================
	@objc(addObserver:)
	final func add(_ observer: (any LDrawObserver)!) {
		observerSetInsert(observer.map { Unmanaged.passUnretained($0 as AnyObject).toOpaque() })
	}//end addObserver:


	//========== removeObserver: =====================================================
	//
	// Purpose:		Removes an observer that was watching us for notifications.
	//				Implements the observable protocol.
	//
	//================================================================================
	@objc(removeObserver:)
	final func remove(_ observer: (any LDrawObserver)!) {
		observerSetRemove(observer.map { Unmanaged.passUnretained($0 as AnyObject).toOpaque() })
	}//end removeObserver


	//========== drawSelf: ===========================================================
	//
	// Purpose:		Draw this directive and its subdirectives by calling APIs on
	//				the passed in renderer, then calling drawSelf on children.
	//
	// Notes:		The drawSelf API draws existing DLs and changes GL state; some
	//				directives will, as part of drawing, (re)build their DLs on the
	//				fly.  Thus VBO build-up is a by-product of drawing a frame where
	//				the DL is needed.  So we don't actually build VBOs for all models
	//				on document-open - only the ones we can see!
	//
	//================================================================================
	@objc(drawSelf:)
	func drawSelf(_ renderer: (any LDrawRenderer)!) {
		// Default implementation does ... nothing.
	}//end drawSelf:


	//========== collectSelf: ========================================================
	//
	// Purpose:		Collect self is called on each directive by its parents to
	//				accumulate _mesh_ data into a display list for later drawing.
	//				The collector protocol passed in is some object capable of
	//				remembering the collectable data.
	//
	// Notes:		As a general rule, directives that participate in display lists
	//				need to re-validate their display list cache bit when this is
	//				called so that the next data edit can move the DL state to
	//				invalid.  (Once data is invalid, further invalidations are
	//				ignored.)
	//
	//				This requirement falls on both real mesh-participants like
	//				LDrawTriangle but also their direct containers like LDrawSteps
	//				and LDrawTextures.
	//
	//================================================================================
	@objc(collectSelf:)
	func collectSelf(_ renderer: (any LDrawCollector)!) {
		// Default implementation collects...nothing.
	}//end collectSelf:


	// MARK: - OBSERVATION

	//============ deinit ==========================================================
	//
	// Purpose:		Gone daddy gone, the love has gone awaaaaay...
	//
	// Notes:		When an observable dies, it has to notify its observers to drop
	//				their weak references.  Since directives implement the observable
	//				protocol, we have to notify.
	//
	//				An observer may use the dying directive during the goodbye
	//				(LDrawPart removes itself from it) but must not keep it: a
	//				reference that outlives deinit crashes.
	//
	//==============================================================================
	deinit {
		forEachObserver { $0.observableSaysGoodbyeCruelWorld(self) }

		// (LDrawFastSetDealloc)
		if observerP1 == nil, let set = observerP2 {
			Unmanaged<NSMutableSet>.fromOpaque(set).release()
			observerP2 = nil
		}
	}


	//============ sendMessageToObservers ==========================================
	//
	// Purpose:		This is a utility to send a message to every observer.
	//				Subclasses use it to reach observers since the observer
	//				set is private.
	//
	//==============================================================================
	@objc(sendMessageToObservers:)
	final func sendMessage(toObservers msg: MessageT) {
		forEachObserver { $0.receiveMessage(msg, who: self) }
	}


	//============ invalCache ======================================================
	//
	// Purpose:		This is a utility that marks the cache flags as invalid for a
	//				given subset of flags.  If the flags were not already dirty,
	//				observers are notified.
	//
	// Usage:		Observables should call invalCache with the flag for a bit of
	//				data EVERY TIME that data changes.  Most of the time this will
	//				result in a no-op or a small quantity of messages.  The
	//				internals take care of tracking cached state.
	//
	//==============================================================================
	@objc(invalCache:)
	final func invalCache(_ flags: CacheFlagsT) {
		let newFlags = CacheFlagsT(rawValue: flags.rawValue & ~invalFlags.rawValue)
		if newFlags.rawValue != 0 {
			invalFlags = CacheFlagsT(rawValue: invalFlags.rawValue | newFlags.rawValue)

			forEachObserver { $0.statusInvalidated(newFlags, who: self) }
		}
	}


	//============== revalCache ====================================================
	//
	// Purpose:		This is a utility that clears out cache flags.  Clients call
	//				this when they rebuild their own cached data as it is queried
	//				by clients.
	//
	// Return:		The function returns the flags that were previously dirty from
	//				among the set specified.
	//
	// Usage 1:		For an observable that does not need to cache its internals:
	//				The observable should call this with the flag for the data when
	//				the accessor is called.  This "re-arms" inval notifications for
	//				observers.
	//
	// Usage 2:		For an observable that uses a cache with lazy rebuilding for a
	//				property:
	//				The observer should call revalCache with the flag for the
	//				property.  Then IF the return is the flag passed in, it should
	//				rebuild the cache.  finally, it should return the cache.
	//
	//				In case 2, the cache is being lazily rebuilt when needed and
	//				notifications rearmed at the same time.
	//
	//==============================================================================
	@objc(revalCache:)
	final func revalCache(_ flags: CacheFlagsT) -> CacheFlagsT {
		let wereDirty = CacheFlagsT(rawValue: flags.rawValue & invalFlags.rawValue)
		invalFlags = CacheFlagsT(rawValue: invalFlags.rawValue & ~flags.rawValue)
		return wereDirty
	}


	// MARK: - OBSERVER SET (LDrawFastSet)

	//---------- observerSet --------------------------------------------[private]--
	//
	// Purpose:		The overflow set (3 or more observers), or nil while the
	//				observers fit in the two pointers.
	//
	//------------------------------------------------------------------------------
	@inline(__always)
	private var observerSet: NSMutableSet? {
		guard observerP1 == nil, let set = observerP2 else {
			return nil
		}
		return Unmanaged<NSMutableSet>.fromOpaque(set).takeUnretainedValue()
	}


	//---------- observerSetContains(_:) ---------------------------------[private]--
	//
	// Purpose:		LDrawFastSetContains.
	//
	//------------------------------------------------------------------------------
	@inline(__always)
	private func observerSetContains(_ p: UnsafeMutableRawPointer?) -> Bool {
		if let set = observerSet {
			return set.contains(NSValue(pointer: p))
		}
		return observerP1 == p || observerP2 == p
	}


	//---------- observerSetInsert(_:) -----------------------------------[private]--
	//
	// Purpose:		LDrawFastSetInsert: a duplicate is ignored.
	//
	//------------------------------------------------------------------------------
	private func observerSetInsert(_ p: UnsafeMutableRawPointer?) {
		if observerP1 != nil {
			if observerP2 != nil {
				if p != observerP1 && p != observerP2 {
					let newSet = NSMutableSet(capacity: 3)
					newSet.add(NSValue(pointer: observerP1))
					newSet.add(NSValue(pointer: observerP2))
					newSet.add(NSValue(pointer: p))
					observerP1 = nil
					observerP2 = Unmanaged.passRetained(newSet).toOpaque()
				}
			}
			else {
				if p != observerP1 {
					observerP2 = p
				}
			}
		}
		else {
			if let set = observerSet {
				set.add(NSValue(pointer: p))
			}
			else {
				observerP1 = p
			}
		}
	}


	//---------- observerSetRemove(_:) -----------------------------------[private]--
	//
	// Purpose:		LDrawFastSetRemove. Removing an observer that isn't in the set
	//				asserts (Debug); in Release it does nothing.
	//
	//------------------------------------------------------------------------------
	private func observerSetRemove(_ p: UnsafeMutableRawPointer?) {
		if let set = observerSet {
			let me = NSValue(pointer: p)
			assert(set.contains(me))
			set.remove(me)
			assert(set.count >= 2)
			if set.count == 2 {
				// Back to two pointers, in the set's order.
				let dead = Unmanaged<NSMutableSet>.fromOpaque(observerP2!).takeRetainedValue()
				let values = dead.objectEnumerator()
				observerP1 = (values.nextObject() as! NSValue).pointerValue
				observerP2 = (values.nextObject() as! NSValue).pointerValue
			}
		}
		else {
			if observerP1 == p {
				observerP1 = observerP2
				observerP2 = nil
			}
			else if observerP2 == p {
				observerP2 = nil
			}
			else {
				assertionFailure("Removal of an unknown object.")
			}
		}
	}


	//---------- forEachObserver(_:) -------------------------------------[private]--
	//
	// Purpose:		MESSAGE_FOR_SET: messages each observer, from a snapshot of
	//				the set taken first, skipping any that are no longer in the
	//				live set when their turn comes (observers add and remove
	//				observers, themselves included, while being told). The first of
	//				two pointers is always told; with 3 or more the order is the
	//				set's.
	//
	//				The snapshot of the overflow set is -copy, never NSSet(set:):
	//				that overload takes a Swift Set, so the set would be bridged
	//				and reordered.
	//
	//------------------------------------------------------------------------------
	@inline(__always)
	private func forEachObserver(_ body: (any LDrawObserver) -> Void) {
		if let p1 = observerP1 {
			let p2 = observerP2
			body(LDrawDirective.observer(p1))
			if let p2, observerSetContains(p2) {
				body(LDrawDirective.observer(p2))
			}
		}
		else if let set = observerSet {
			let orig = set.copy() as! NSSet
			for case let value as NSValue in orig {
				let oo = value.pointerValue
				if observerSetContains(oo), let oo {
					body(LDrawDirective.observer(oo))
				}
			}
		}
	}


	//---------- observer(_:) -------------------------------------[private static]--
	//
	// Purpose:		An observer from its stored pointer: a strong reference for
	//				the message, as the ObjC's local was.
	//
	//------------------------------------------------------------------------------
	@inline(__always)
	private static func observer(_ p: UnsafeMutableRawPointer) -> any LDrawObserver {
		unsafeBitCast(Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue(), to: (any LDrawObserver).self)
	}
}
