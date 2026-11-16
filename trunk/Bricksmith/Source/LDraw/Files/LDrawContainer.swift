//==============================================================================
//
// File:		LDrawContainer.swift
//
// Purpose:		Abstract subclass for LDrawDirectives which represent a
//				collection of related directives.
//
//				Subclasses: LDrawFile, LDrawModel, LDrawStep
//
//  Created by Allen Smith on 3/31/05.
//  Copyright (c) 2005. All rights reserved.
//
//  Ported to Swift in P6c. The superclass (LDrawDirective) is still ObjC.
//  LDrawContainer.h survives as a forward-declaration stub.
//
//  The children stay in an NSMutableArray, which -subdirectives returns live
//  (the subclasses iterate and edit it). Per-child loops read the children
//  unretained (withUnretainedChild(at:in:_:), LDrawStep.swift) and message
//  them through LDrawContainerChildSends, so every send stays dynamic, as in
//  the ObjC.
//
//  Where the ObjC raised, the port has a guard that stops at the same point,
//  marked "P6c: ObjC raised here"; see KNOWN-BUGS BUG-069.
//==============================================================================

import Foundation


//---------- LDrawContainerChildSends --------------------------------[private]--
//
// Purpose:		The messages LDrawContainer sends its children, typed so that
//				nothing is bridged per child (NSString, NSArray, blocks as
//				blocks). Nothing conforms: a child is reinterpreted as this
//				protocol, and each message goes through objc_msgSend; the ones
//				not every directive implements are sent only after
//				-respondsToSelector:, as in the ObjC.
//
//------------------------------------------------------------------------------
@objc private protocol LDrawContainerChildSends: NSObjectProtocol {
	@objc(allEnclosedElements)
	func allEnclosedElements() -> NSArray?
	@objc(projectedBoundingBoxWithModelView:projection:view:)
	func projectedBoundingBox(withModelView modelView: Matrix4, projection: Matrix4, view viewport: Box2) -> Box3
	@objc(postsNotifications)
	func postsNotifications() -> Bool
	@objc(setPostsNotifications:)
	func setPostsNotifications(_ flag: Bool)
	@objc(collectPartReport:)
	func collectPartReport(_ report: PartReport?)
	@objc(applyToAllParts:)
	func applyToAllParts(_ visitor: (@convention(block) (LDrawPart) -> Void)?)
	@objc(containsReferenceTo:)
	func containsReference(to name: NSString?) -> Bool
	@objc(flattenIntoLines:triangles:quadrilaterals:other:currentColor:currentTransform:normalTransform:recursive:)
	func flatten(intoLines lines: NSMutableArray?, triangles: NSMutableArray?, quadrilaterals: NSMutableArray?,
				 other everythingElse: NSMutableArray?, currentColor parentColor: LDrawColor?,
				 currentTransform transform: Matrix4, normalTransform: Matrix3, recursive: Bool)
	@objc(setEnclosingDirective:)
	func setEnclosingDirective(_ newParent: LDrawContainer?)
	@objc(addObserver:)
	func addObserver(_ observer: (any LDrawObserver)?)
	@objc(removeObserver:)
	func removeObserver(_ observer: (any LDrawObserver)?)
}


//---------- childSends(_:) ------------------------------------------[private]--
//
// Purpose:		A child (an element of the children array) as
//				LDrawContainerChildSends: a reinterpretation, no cast or retain.
//
//------------------------------------------------------------------------------
@inline(__always)
private func childSends(_ child: AnyObject) -> LDrawContainerChildSends {
	unsafeBitCast(child, to: LDrawContainerChildSends.self)
}


@objc(LDrawContainer)
class LDrawContainer: LDrawDirective, LDrawObserver {

	// Coder keys over 15 ASCII bytes would bridge to a new NSString per call (L102).
	private static let containedObjectsKey = NSString(string: "containedObjects") as String

	private static let allEnclosedElementsSelector	= #selector(LDrawContainerChildSends.allEnclosedElements)
	private static let projectedBoundsSelector		= #selector(LDrawContainerChildSends.projectedBoundingBox(withModelView:projection:view:))
	private static let setPostsNotificationsSelector	= #selector(LDrawContainerChildSends.setPostsNotifications(_:))
	private static let collectPartReportSelector	= #selector(LDrawContainerChildSends.collectPartReport(_:))
	private static let applyToAllPartsSelector		= #selector(LDrawContainerChildSends.applyToAllParts(_:))

	// Stored defaults are trivial: -[LDrawDirective initWithLines:...] re-enters
	// init() on the half-built object. Both are written only by init, decode
	// and -setPostsNotifications:.
	//
	// The children. nil only after decoding an archive without the key; every
	// use below then behaves as the ObjC's messages to nil did.
	@exclusivity(unchecked) private var containedObjects: NSMutableArray? = nil
	@exclusivity(unchecked) private var postsNotificationsFlag: Bool = false


	// MARK: - INITIALIZATION

	//========== init ==============================================================
	//
	// Purpose:		Creates a new container with absolutely nothing in it, but
	//				ready to receive objects.
	//
	//==============================================================================
	@objc(init)
	override init() {
		super.init()

		containedObjects	= NSMutableArray()
		postsNotificationsFlag	= false

	}//end init


	//========== initWithLines:inRange: ============================================
	//
	// Purpose:		Not overridden in the ObjC; declared so the Swift subclasses
	//				keep inheriting and overriding it (L107).
	//
	//==============================================================================
	@objc(initWithLines:inRange:)
	override init!(lines: [NSObject]!, in range: NSRange) {
		super.init(lines: lines, in: range)

	}//end initWithLines:inRange:


	//========== initWithLines:inRange:parentGroup: ================================
	//
	// Purpose:		Not overridden in the ObjC: -[LDrawDirective
	//				initWithLines:inRange:parentGroup:] sends -init, which
	//				creates the children array.
	//
	//==============================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override init!(lines: [NSObject]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		super.init(lines: lines, in: range, parentGroup: parentGroup)

	}//end initWithLines:inRange:parentGroup:


	//========== initWithCoder: ====================================================
	//
	// Purpose:		Reads a representation of this object from the given coder,
	//				which is assumed to always be a keyed decoder. This allows us to
	//				read and write LDraw objects as NSData.
	//
	//==============================================================================
	@objc(initWithCoder:)
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)

		// Stored as decoded, unchecked, as the ObjC ivar was.
		containedObjects = unsafeBitCast(decoder.decodeObject(forKey: LDrawContainer.containedObjectsKey) as AnyObject?,
										 to: NSMutableArray?.self)

		if let containedObjects {
			for counter in 0..<containedObjects.count {
				withUnretainedChild(at: counter, in: containedObjects) { childSends($0).addObserver(self) }
			}
		}

	}//end initWithCoder:


	//========== encodeWithCoder: ==================================================
	//
	// Purpose:		Writes a representation of this object to the given coder,
	//				which is assumed to always be a keyed decoder. This allows us to
	//				read and write LDraw objects as NSData.
	//
	//==============================================================================
	@objc(encodeWithCoder:)
	override func encode(with encoder: NSCoder) {
		super.encode(with: encoder)

		encoder.encode(containedObjects, forKey: LDrawContainer.containedObjectsKey)

	}//end encodeWithCoder:


	//========== copyWithZone: =====================================================
	//
	// Purpose:		Returns a duplicate of this object. Each contained directive is
	//				copied, so the returned object is a complete duplicate of the
	//				receiver.
	//
	//==============================================================================
	@objc(copyWithZone:)
	override func copy(with zone: NSZone? = nil) -> Any {
		let copiedContainer	= (super.copy(with: zone) as AnyObject) as! LDrawContainer	// (a class cast: `as!` from Any is a slow existential cast)
		let counter			= 0	// never incremented, as in the ObjC: the copies come out reversed (BUG-011)

		// Copy each subdirective and transfer it into the copied container.
		if let containedObjects {
			for index in 0..<containedObjects.count {
				let copiedObject = withUnretainedChild(at: index, in: containedObjects) {
					unsafeBitCast($0, to: NSObject.self).copy() as AnyObject
				}
				copiedContainer.insert(unsafeDowncast(copiedObject, to: LDrawDirective.self), at: counter)
			}
		}

		return copiedContainer

	}//end copyWithZone:


	// MARK: - ACCESSORS

	//========== allEnclosedElements ===============================================
	//
	// Purpose:		Returns all of the terminal (leaf-node) subdirectives contained
	//				within this object and all enclosed containers. Does not return
	//				the enclosed containers themselves.
	//
	//==============================================================================
	@objc(allEnclosedElements)
	func allEnclosedElements() -> [Any]! {
		let subelements = NSMutableArray()

		if let containedObjects {
			for counter in 0..<containedObjects.count {
				withUnretainedChild(at: counter, in: containedObjects) { currentDirective in
					let child = childSends(currentDirective)
					if child.responds(to: LDrawContainer.allEnclosedElementsSelector) {
						if let elements = child.allEnclosedElements() {
							subelements.addObjects(from: elements as! [Any])
						}
					}
					else {
						subelements.add(currentDirective)
					}
				}
			}
		}

		return subelements as? [Any]

	}//end allEnclosedElements


	//========== postsNotifications ================================================
	//
	// Purpose:		Whether the container posts notifications when its contents
	//				change (see -setPostsNotifications:). Final: a direct load
	//				for the Swift subclasses, which read it on every edit.
	//
	//==============================================================================
	@objc(postsNotifications)
	final var postsNotifications: Bool {
		return postsNotificationsFlag
	}


	//========== projectedBoundingBoxWithModelView:projection:view: ================
	//
	// Purpose:		Returns the 2D projection (you should ignore the z) of the
	//				object's bounds.
	//
	//==============================================================================
	@objc(projectedBoundingBoxWithModelView:projection:view:)
	func projectedBoundingBox(withModelView modelView: Matrix4, projection: Matrix4, view viewport: Box2) -> Box3 {
		var bounds				= InvalidBox
		var partBounds			= InvalidBox
		let numberOfDirectives	= containedObjects?.count ?? 0

		if let containedObjects {
			for counter in 0..<numberOfDirectives {
				withUnretainedChild(at: counter, in: containedObjects) { currentDirective in
					let child = childSends(currentDirective)
					if child.responds(to: LDrawContainer.projectedBoundsSelector) {
						partBounds	= child.projectedBoundingBox(withModelView: modelView,
																 projection: projection,
																 view: viewport)
						bounds		= V3UnionBox(bounds, partBounds)
					}
				}
			}
		}

		return bounds

	}//end projectedBoundingBoxWithModelView:projection:view:


	//========== indexOfDirective: =================================================
	//
	// Purpose:		Returns the index of the directive (by identity), or
	//				NSNotFound.
	//
	//==============================================================================
	@objc(indexOfDirective:)
	func index(of directive: LDrawDirective!) -> Int {
		guard let containedObjects else {
			return 0	// (a message to a nil array answered 0)
		}
		guard let directive else {
			return NSNotFound
		}
		return containedObjects.indexOfObjectIdentical(to: directive)

	}//end indexOfDirective:


	//========== subdirectives =====================================================
	//
	// Purpose:		Returns the LDraw directives stored in this collection: the
	//				live array, not a copy.
	//
	//==============================================================================
	@objc(subdirectives)
	func subdirectives() -> NSMutableArray! {
		return containedObjects

	}//end subdirectives


	//========== setPostsNotifications: ============================================
	//
	// Purpose:		Sets whether the container posts
	//				LDrawDirectiveDidChangeNotifications when its contents change.
	//
	// Notes:		Posting notifications is extremely time-consuming and only
	//				needed for editable containers. Given the huge number of
	//				container changes which occur during parsing, you generally want
	//				this flag off except in parseable directives.
	//
	//==============================================================================
	@objc(setPostsNotifications:)
	func setPostsNotifications(_ flag: Bool) {
		postsNotificationsFlag = flag

		// Apply new setting to children
		if let containedObjects {
			for counter in 0..<containedObjects.count {
				withUnretainedChild(at: counter, in: containedObjects) { childDirective in
					let child = childSends(childDirective)
					if child.responds(to: LDrawContainer.setPostsNotificationsSelector) == true {
						child.setPostsNotifications(flag)
					}
				}
			}
		}
	}//end setPostsNotifications:


	// MARK: - ACTIONS

	//========== addDirective: =====================================================
	//
	// Purpose:		Adds directive into the collection at the end of the list.
	//
	//==============================================================================
	@objc(addDirective:)
	func add(_ directive: LDrawDirective!) {
		let index = containedObjects?.count ?? 0
		self.insert(directive, at: index)

	}//end addDirective:


	//========== collectPartReport: ================================================
	//
	// Purpose:		Collects a report on all the parts in this container, no matter
	//				how deeply they may be contained.
	//
	//==============================================================================
	@objc(collectPartReport:)
	func collect(_ report: PartReport!) {
		guard let containedObjects else {
			return
		}
		var counter = 0

		while counter < containedObjects.count {
			withUnretainedChild(at: counter, in: containedObjects) { currentDirective in
				let child = childSends(currentDirective)
				if child.responds(to: LDrawContainer.collectPartReportSelector) {
					child.collectPartReport(report)
				}
			}
			counter += 1
		}

	}//end collectPartReport:


	//========== applyToAllParts: ==================================================
	//
	// Purpose:		This is part of a visitor API that applies a block to all parts.
	//				Introspect our sub-directives and recurse where we can.
	//
	// Notes:		The visitor stays a block (@convention(block)), so it is
	//				passed on to each child as is rather than rewrapped.
	//
	//==============================================================================
	@objc(applyToAllParts:)
	func apply(toAllParts visitor: (@convention(block) (LDrawPart) -> Void)!) {
		guard let containedObjects else {
			return
		}
		var counter = 0

		while counter < containedObjects.count {
			withUnretainedChild(at: counter, in: containedObjects) { currentDirective in
				let child = childSends(currentDirective)
				if child.responds(to: LDrawContainer.applyToAllPartsSelector) {
					child.applyToAllParts(visitor)
				}
			}
			counter += 1
		}
	}//end applyToAllParts:


	//========== removeDirective: ==================================================
	//
	// Purpose:		Removes the specified LDraw directive stored in this collection.
	//
	//				If it isn't in the collection, well, that's that.
	//
	//==============================================================================
	@objc(removeDirective:)
	func remove(_ doomedDirective: LDrawDirective!) {
		//First, find the object (making sure it's actually there in the process)
		let indexOfObject = self.index(of: doomedDirective)

		if indexOfObject != NSNotFound {
			//We found it; kill it!
			self.removeDirective(at: indexOfObject)
		}
	}//end removeDirective:


	//========== insertDirective:atIndex: ==========================================
	//
	// Purpose:		Adds directive into the collection at position index.
	//
	//==============================================================================
	@objc(insertDirective:atIndex:)
	func insert(_ directive: LDrawDirective!, at index: Int) {
		// Insert
		if let containedObjects {
			// P6c: ObjC raised here (-insertObject:atIndex: with a nil directive
			// or an index outside 0...count, before anything changed); see
			// KNOWN-BUGS BUG-069
			guard let directive, index >= 0, index <= containedObjects.count else {
				return
			}
			containedObjects.insert(directive, at: index)
		}
		guard let directive else {
			// (Only with no children array: the ObjC's messages to nil did nothing.)
			if postsNotificationsFlag == true {
				noteNeedsDisplay()
			}
			return
		}
		directive.setEnclosing(self)

		// Apply notification policy to new children
		let child = childSends(directive)
		if child.responds(to: LDrawContainer.setPostsNotificationsSelector) == true {
			if child.postsNotifications() != postsNotificationsFlag {
				child.setPostsNotifications(postsNotificationsFlag)
			}
		}

		// We have to do this FIRST - otherwise, our cache gets rebuilt by the notification handlers before the view hierarchy is fully wired
		// up and things go pretty sideways from there.
		child.addObserver(self)

		if postsNotificationsFlag == true {
			noteNeedsDisplay()
		}

	}//end insertDirective:atIndex:


	//========== removeDirectiveAtIndex: ===========================================
	//
	// Purpose:		Removes the LDraw directive stored at index in this collection.
	//
	//==============================================================================
	@objc(removeDirectiveAtIndex:)
	func removeDirective(at index: Int) {
		var doomedDirective: AnyObject? = nil

		if let containedObjects {
			// P6c: ObjC raised here (-objectAtIndex: with an index outside
			// 0..<count, before anything changed); see KNOWN-BUGS
			// BUG-069
			guard index >= 0, index < containedObjects.count else {
				return
			}
			doomedDirective = containedObjects.object(at: index) as AnyObject	// strong, as the ObjC local was
		}

		if let doomedDirective {
			let doomed = childSends(doomedDirective)
			if unsafeDowncast(doomedDirective, to: LDrawDirective.self).enclosingDirective() === self {
				doomed.setEnclosingDirective(nil) //no parent anymore; it's an orphan now.
			}

			// Do this first...the actual remove may drop the directive's ref count.  In that
			// case we'll puke.
			doomed.removeObserver(self)
		}

		containedObjects?.removeObject(at: index) //or disowned at least.

		if postsNotificationsFlag == true {
			noteNeedsDisplay()
		}

	}//end removeDirectiveAtIndex:


	//========== setSubdirectiveSelected: ==========================================
	//
	// Purpose: Called by a subdirective when it's been selected.  This allows
	//          container directives to act on child selection.  Override in
	//          subclasses.
	//
	//==============================================================================
	@objc(setSubdirectiveSelected:)
	func setSubdirectiveSelected(_ flag: Bool) {
		// stub
	}


	// MARK: - UTILITES

	//========== containsReferenceTo: ==============================================
	//
	// Purpose:		Returns if this object (or any of its children) references a
	//				model with the given name.
	//
	//==============================================================================
	@objc(containsReferenceTo:)
	override func containsReference(to name: String!) -> Bool {
		let nameObject			= name as NSString?
		var containsReference	= false

		guard let subdirectives = self.subdirectives() else {
			return false
		}

		for counter in 0..<subdirectives.count {
			containsReference = withUnretainedChild(at: counter, in: subdirectives) {
				childSends($0).containsReference(to: nameObject)
			}

			if containsReference {
				break
			}
		}

		return containsReference
	}


	//========== acceptsDroppedDirective: ==========================================
	//
	// Purpose:		Returns YES if this container will accept a directive dropped on
	//              it.  Intended to be overridden by subclasses
	//
	//==============================================================================
	@objc(acceptsDroppedDirective:)
	func acceptsDroppedDirective(_ directive: LDrawDirective!) -> Bool {
		return true
	}//end acceptsDroppedDirective:


	//========== flattenIntoLines:triangles:quadrilaterals:other:currentColor: =====
	//
	// Purpose:		Appends the directive into the appropriate container.
	//
	//==============================================================================
	@objc(flattenIntoLines:triangles:quadrilaterals:other:currentColor:currentTransform:normalTransform:recursive:)
	override func flatten(intoLines lines: NSMutableArray!, triangles: NSMutableArray!, quadrilaterals: NSMutableArray!,
						  other everythingElse: NSMutableArray!, currentColor parentColor: LDrawColor!,
						  currentTransform transform: Matrix4, normalTransform: Matrix3, recursive: Bool) {
		guard let subdirectives = self.subdirectives() else {
			return
		}

		for counter in 0..<subdirectives.count {
			withUnretainedChild(at: counter, in: subdirectives) {
				childSends($0).flatten(intoLines: lines,
									   triangles: triangles,
									   quadrilaterals: quadrilaterals,
									   other: everythingElse,
									   currentColor: parentColor,
									   currentTransform: transform,
									   normalTransform: normalTransform,
									   recursive: recursive)
			}
		}

	}//end flattenIntoLines:triangles:quadrilaterals:other:currentColor:


	// MARK: - DESTRUCTOR

	//========== deinit ============================================================
	//
	// Purpose:		IT'S THE END OF THE WORLD AS WE KNOW IT!!!
	//
	//				As the ObjC -dealloc: runs before -[LDrawDirective dealloc]
	//				(the goodbye to our observers); the children array is
	//				released after both.
	//
	//==============================================================================
	deinit {
		if let containedObjects {
			for counter in 0..<containedObjects.count {
				withUnretainedChild(at: counter, in: containedObjects) { childSends($0).removeObserver(self) }
			}
			//the children must not be allowed to remember us. Crashes could result otherwise.
			for counter in 0..<containedObjects.count {
				withUnretainedChild(at: counter, in: containedObjects) { childSends($0).setEnclosingDirective(nil) }
			}
		}
	}//end deinit


	// MARK: - OBSERVABLE/OBSERVER

	//========== observableSaysGoodbyeCruelWorld====================================
	//
	// Purpose:		this is the message receiving method for observers when their
	//				observable is yanked out from under them.  Observation is a weak
	//				reference so the thing you are observing may be nuked.
	//
	//				In the case of the container, we only observe the directives
	//				we contain and we are supposed to remove all directives before
	//				they die (and containing them is a strong reference).  So...
	//				If any dying directives call out to us, it's a programming error.
	//				Just log it out for now?
	//
	//==============================================================================
	@objc(observableSaysGoodbyeCruelWorld:)
	func observableSaysGoodbyeCruelWorld(_ doomedObservable: (any LDrawObservable)!) {
		let index: Int
		if let containedObjects {
			// (-indexOfObject:nil answered NSNotFound.)
			index = doomedObservable.map { containedObjects.index(of: $0) } ?? NSNotFound
		}
		else {
			index = 0	// (a message to a nil array answered 0)
		}

		if index != NSNotFound {
			NSLog("Observer's observable is dying but we have no idea who it is...")
		}
	}


	//========== statusInvalidated =================================================
	//
	// Purpose:		The things we watch call this when one of their states that we
	//				might have cached is no longer valid.  This tells us to not rely
	//				on that data.
	//
	//==============================================================================
	@objc(statusInvalidated:who:)
	func statusInvalidated(_ flags: CacheFlagsT, who observable: (any LDrawObservable)!) {
		invalCache(flags)
	}


	//========== receiveMessage ====================================================
	//
	// Purpose:		The things we observe call this when something one-time and
	//				eventful happens - we can respond if desired.
	//
	//==============================================================================
	@objc(receiveMessage:who:)
	func receiveMessage(_ msg: MessageT, who observable: (any LDrawObservable)!) {
	}
}
