//==============================================================================
//
// File:		LDrawStep.swift
//
// Purpose:		Represents a collection of Lego bricks which compose a single
//				step when constructing a model.
//
//				A step, of course, corresponds to a step in a set of Lego set
//				instructions.
//
//				The subdirectives which make up a step are a list of
//				LDrawDirectives including parts, primitives, and meta-commands.
//
//				Steps may have rotations associated with them. A step rotation
//				defines the viewing angle at which the step is intended to be
//				displayed (for instance, upside-down). However, since steps are
//				drawn in a pipeline, they can't actually draw their own
//				rotations. It is the responsibility of the controller object to
//				enforce the rotation defined by the step. In Bricksmith, step
//				rotations are only honored when the model is being drawn in Step
//				Display mode.
//
//				The step rotation functionality was originally defined by MLCad.
//
//  Created by Allen Smith on 2/20/05.
//  Copyright (c) 2005. All rights reserved.
//
//  Ported to Swift in P6b. The superclass (LDrawContainer) is still ObjC.
//  LDrawStep.h survives as a types-only header for
//  LDrawStepDidChangeNotification, LDrawStepRotationT and LDrawStepFlavorT.
//
//  Where the ObjC raised (and a caller's @try or AppKit swallowed it), the
//  port has a guard that abandons the operation at the same point, marked
//  "P6b: ObjC raised here"; see KNOWN-BUGS BUG-049..055.
//==============================================================================

import Foundation


//---------- ldrawDirective(at:in:) ----------------------------------[private]--
//
// Purpose:		The child at index of a container's (NSMutableArray) children,
//				without bridging the array. The ObjC assumed every child is an
//				LDrawDirective; messages to it still go through objc_msgSend.
//
//------------------------------------------------------------------------------
@inline(__always)
func ldrawDirective(at index: Int, in array: NSArray) -> LDrawDirective {
	unsafeDowncast(array.object(at: index) as AnyObject, to: LDrawDirective.self)
}


//---------- LDrawDirectiveSends ---------------------------------------------
//
// Purpose:		The hit-test messages a container's per-child loops send, with
//				the same selectors as LDrawDirective's but with the `id`
//				credit object typed AnyObject? rather than Any!. Passing an
//				Any! on builds an existential for every child; an AnyObject?
//				goes through objc_msgSend as is, as in the ObjC. Nothing
//				conforms: a child is reinterpreted as this protocol
//				(withLDrawDirectiveSends(at:in:_:)), and every LDrawDirective
//				implements these selectors. The other per-child messages are
//				direct calls through LDrawDirective (withLDrawDirective).
//
//------------------------------------------------------------------------------
@objc protocol LDrawDirectiveSends {
	@objc(hitTest:transform:viewScale:boundsOnly:creditObject:hits:)
	func hitTest(_ pickRay: Ray3, transform: Matrix4, viewScale scaleFactor: Float, boundsOnly: Bool,
				 creditObject: AnyObject?, hits: NSMutableDictionary?)
	@objc(boxTest:transform:boundsOnly:creditObject:hits:)
	func boxTest(_ bounds: Box2, transform: Matrix4, boundsOnly: Bool, creditObject: AnyObject?, hits: NSMutableSet?) -> Bool
	@objc(depthTest:inBox:transform:creditObject:bestObject:bestDepth:)
	func depthTest(_ pt: Point2, inBox bounds: Box2, transform: Matrix4, creditObject: AnyObject?,
				   bestObject: AutoreleasingUnsafeMutablePointer<AnyObject?>?, bestDepth: UnsafeMutablePointer<Float>?)
}


//---------- withLDrawDirective(at:in:_:) ------------------------------------
//
// Purpose:		Calls body with the child at index of a container's children.
//				The child is read with CFArrayGetValueAtIndex and used
//				unretained (the array holds it, as in the ObjC's fast
//				enumeration), so a loop costs no retain/release and no checked
//				cast per child; LDrawDirective's methods are then called
//				through the class (vtable dispatch: every subclass is Swift and
//				overrides in its class body). Out of range raises, as
//				-objectAtIndex: did.
//
//------------------------------------------------------------------------------
@inline(__always)
func withLDrawDirective<Result>(at index: Int, in array: NSArray, _ body: (LDrawDirective) -> Result) -> Result {
	withUnretainedChild(at: index, in: array) {
		body(unsafeDowncast($0, to: LDrawDirective.self))
	}
}


//---------- withLDrawDirectiveSends(at:in:_:) -------------------------------
//
// Purpose:		As withLDrawDirective(at:in:_:), for sending the child one of
//				LDrawDirectiveSends.
//
//------------------------------------------------------------------------------
@inline(__always)
func withLDrawDirectiveSends<Result>(at index: Int, in array: NSArray, _ body: (LDrawDirectiveSends) -> Result) -> Result {
	withUnretainedChild(at: index, in: array) {
		body(unsafeBitCast($0, to: LDrawDirectiveSends.self))
	}
}


//---------- withUnretainedChild(at:in:_:) -----------------------------------
//
// Purpose:		The child at index, read with CFArrayGetValueAtIndex and lent
//				to body without a retain (see withLDrawDirective(at:in:_:)).
//
//------------------------------------------------------------------------------
@inline(__always)
func withUnretainedChild<Result>(at index: Int, in array: NSArray, _ body: (AnyObject) -> Result) -> Result {
	let child = CFArrayGetValueAtIndex(unsafeBitCast(array, to: CFArray.self), index)!
	return Unmanaged<AnyObject>.fromOpaque(child)._withUnsafeGuaranteedRef(body)
}


//---------- SwiftPrimitiveClasses ---------------------------------------------
//
// Purpose:		Picks out a child of exactly LDrawLine, LDrawConditionalLine,
//				LDrawTriangle or LDrawQuadrilateral, so that a step's collect,
//				box-test and depth-test loops can call the primitive's body
//				directly (collectPrimitive(_:), boxTestPrimitive(...),
//				depthTestPrimitive(...)). Entering a
//				Swift method through its @objc entry costs a retain/release of
//				the receiver and of each object argument (and boxes an `id` as
//				Any), per primitive; the ObjC primitives never paid that. Any
//				other class, a subclass included, is .other and is messaged as
//				before. A KVO-observed primitive is not .other: Swift's
//				type(of:) skips KVO's artificial subclass (LEARNINGS L111), and
//				KVO overrides only setters, so the direct call is still right
//				(StepDirectCollectTests). The same body runs either way.
//
//------------------------------------------------------------------------------
struct SwiftPrimitiveClasses {
	enum Kind { case line, triangle, quadrilateral, other }

	private let line			= ObjectIdentifier(LDrawLine.self)
	private let conditionalLine	= ObjectIdentifier(LDrawConditionalLine.self)
	private let triangle		= ObjectIdentifier(LDrawTriangle.self)
	private let quadrilateral	= ObjectIdentifier(LDrawQuadrilateral.self)

	@inline(__always)
	func kind(of child: AnyObject) -> Kind {
		let childClass = ObjectIdentifier(type(of: child))
		if childClass == triangle { return .triangle }
		if childClass == quadrilateral { return .quadrilateral }
		if childClass == line || childClass == conditionalLine { return .line }
		return .other
	}
}


//---------- ldrawBoundingBox3(forDirectives:) ---------------------------------
//
// Purpose:		+[LDrawUtilities boundingBox3ForDirectives:], inlined so that a
//				container's NSMutableArray isn't bridged to [Any] (a copy) on
//				every bounds rebuild. Same calls, same order.
//
//------------------------------------------------------------------------------
func ldrawBoundingBox3(forDirectives directives: NSArray?) -> Box3 {
	var bounds					= InvalidBox
	let numberOfDirectives		= directives?.count ?? 0

	if let directives {
		for counter in 0..<numberOfDirectives {
			let partBounds = withLDrawDirective(at: counter, in: directives) { $0.boundingBox3() }
			bounds = V3UnionBox(bounds, partBounds)
		}
	}

	return bounds
}


/// The undo proxy, seen through the two setters LDrawStep registers (LEARNINGS L103: send the selectors
/// dynamically; never ask the proxy responds(to:)).
@objc private protocol LDrawStepUndoTarget {
	@objc(setRotationAngle:)
	func setRotationAngle(_ newAngle: Tuple3)
	@objc(setStepRotationType:)
	func setStepRotationType(_ newValue: LDrawStepRotationT)
}


@objc(LDrawStep)
final class LDrawStep: LDrawContainer {

	// Coder keys over 15 ASCII bytes would bridge to a new NSString per call (L102).
	private static let stepRotationTypeKey = NSString(string: "stepRotationType") as String

	// Stored defaults are trivial: -[LDrawDirective initWithLines:...] re-enters
	// init() on the half-built object.
	@exclusivity(unchecked) private var stepRotationTypeValue: LDrawStepRotationT = .none
	@exclusivity(unchecked) private var rotationAngleValue: Tuple3 = Tuple3()		// in degrees
	@exclusivity(unchecked) private var cachedBounds: Box3 = Box3()					// cached bounds of the step
	//Optimization variables
	@exclusivity(unchecked) private var stepFlavorValue: LDrawStepFlavorT = .anyDirectives	//defaults to LDrawStepAnyDirectives
	// (The ObjC ivar colorOfAllDirectives was never read or written; dropped.)

	//Inherited from the superclasses:
	//NSMutableArray	*containedObjects; //the commands that make up the step.
	//LDrawContainer	*enclosingDirective; //weak link to enclosing model.


	// MARK: - INITIALIZATION

	//---------- emptyStep -----------------------------------------------[static]--
	//
	// Purpose:		Creates a new step ready to be edited, with nothing inside it.
	//
	//------------------------------------------------------------------------------
	@objc(emptyStep)
	class func empty() -> Any! {
		let newStep = LDrawStep()

		return newStep

	}//end emptyStep


	//---------- emptyStepWithFlavor: ------------------------------------[static]--
	//
	// Purpose:		Creates a new step ready to be edited, and prespecifies that
	//				only directives of the flavorType will be added.
	//
	//------------------------------------------------------------------------------
	@objc(emptyStepWithFlavor:)
	class func empty(withFlavor flavorType: LDrawStepFlavorT) -> Any! {
		let newStep = LDrawStep.empty() as! LDrawStep
		newStep.setStepFlavor(flavorType)

		return newStep

	}//end emptyStepWithFlavor:


	//========== init ==============================================================
	//
	// Purpose:		Creates a new step ready to be edited, with nothing inside it.
	//
	//==============================================================================
	@objc(init)
	override init() {
		super.init()

		stepRotationTypeValue	= .none
		rotationAngleValue		= ZeroPoint3
		stepFlavorValue			= .anyDirectives
		cachedBounds			= InvalidBox

	}//end init


	//========== initWithLines:inRange: ============================================
	//
	// Purpose:		As -[LDrawDirective initWithLines:inRange:]: no parent group.
	//				(Overridden so the inherited ObjC entry point isn't a trap.)
	//
	//==============================================================================
	@objc(initWithLines:inRange:)
	override convenience init!(lines: [NSObject]!, in range: NSRange) {
		self.init(lines: lines, in: range, parentGroup: nil)
	}


	//========== initWithLines:inRange:parentGroup: ================================
	//
	// Purpose:		Parses a step beginning at the specified line of LDraw code.
	//
	// Notes:		Index arithmetic is NSUInteger as in ObjC (wrapping operators).
	//
	//==============================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override init!(lines: [NSObject]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		let rangeLocation						= UInt(bitPattern: range.location)
		var rangeLength							= UInt(bitPattern: range.length)
		var lineIndex: UInt						= 0
		var insertIndex							= 0

		// (No lines at all: super answers nil. The ObjC then wrote an ivar
		// through nil and crashed; see KNOWN-BUGS BUG-049.)
		super.init(lines: lines, in: range, parentGroup: parentGroup)

		cachedBounds = InvalidBox

		// (A nil array has no lines, so super already answered nil.)
		guard let lineArray = lines as NSArray? else {
			return nil
		}
		let lineCount = UInt(lineArray.count)

		// Parse but disallow multithreading for subparsing. (ObjC:
		// stepDispatchGroup, always NULL.)
		let stepDispatchGroup: dispatch_group_t? = nil

		// Parse out the STEP command
		if rangeLength > 0 {
			// P6b: ObjC raised here (-objectAtIndex: past the end of the lines,
			// before anything was parsed); see KNOWN-BUGS BUG-050
			guard rangeLocation < lineCount, rangeLength <= lineCount - rangeLocation else {
				return nil
			}
			let currentLine = lineArray.object(at: Int(bitPattern: rangeLocation &+ rangeLength &- 1)) as? String

			// See if the line is a step delimiter. If the delimiter doesn't exist,
			// it's implied (such as in a 1-step model). Otherwise, it marks the end
			// of the step.
			if LDrawStep.lineIsStepTerminator(currentLine) {
				// Nothing more to parse. Stop.
				rangeLength -= 1
			}
			else if LDrawStep.lineIsRotationStepTerminator(currentLine) {
				// Parse the rotation step. A malformed one fails the whole step, and
				// with it the model and file being parsed (it used to throw; BUG-007).
				// Nothing has been parsed into the step yet.
				if parseRotationStep(fromLine: currentLine) == false {
					return nil
				}

				rangeLength -= 1
			}
		}

		// (ObjC: calloc'd range.length slots before the range was checked; the
		// slots past the end were never checked: BUG-001. Allocated here, once
		// range.length is known to be a real line count.)
		var directives = [LDrawDirective?](repeating: nil, count: range.length)

		// Convert each non-step-delimiter line into a directive, and add it to this
		// step.
		let maxRange = rangeLocation &+ rangeLength	// NSMaxRange(range)
		lineIndex = rangeLocation
		while lineIndex < maxRange {
			let currentLine = lineArray.object(at: Int(bitPattern: lineIndex)) as? NSString
			if (currentLine?.length ?? 0) > 0 {
				// (Messaging Nil, for an unknown line type, answered a zero range
				// and a nil directive: BUG-001.)
				let CommandClass	= LDrawUtilities.classForDirectiveBeginning(withLine: currentLine as String?) as? LDrawDirective.Type
				var commandRange	= NSRange(location: 0, length: 0)
				var newDirective: LDrawDirective? = nil
				if let CommandClass {
					commandRange = CommandClass.rangeOfDirectiveBeginning(at: lineIndex,
																		  inLines: lines,
																		  maxIndex: maxRange &- 1)
					// Parse but disallow multithreading for subparsing. LDraw
					// objects be be deeply recursive, which means we would pile
					// up a lot of dispatch_group_wait calls, resulting in so
					// many threads we run out of stack space.
					newDirective = CommandClass.directive(lines: lines, in: commandRange, parentGroup: stepDispatchGroup)
				}

				// BUG-001: an unknown line type never advances lineIndex, and the
				// ObjC wrote past the end of its buffer until it crashed. The
				// array subscript traps at that point instead.
				directives[insertIndex] = newDirective
				lineIndex	= UInt(bitPattern: commandRange.location) &+ UInt(bitPattern: commandRange.length)
				insertIndex += 1
			}
			else {
				lineIndex += 1
			}
		}

		// Add the accumulated directives *in order*
		for counter in 0..<insertIndex {
			// P6b: ObjC raised here (-addDirective:nil, when a directive's init
			// answered nil, e.g. a part whose library file fails to parse); the
			// step fails, as the exception failed the whole parse; see KNOWN-BUGS
			// BUG-051
			guard let currentDirective = directives[counter] else {
				return nil
			}

			add(currentDirective)
			directives[counter] = nil
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
		super.init(coder: decoder)
		cachedBounds = InvalidBox
		invalCache(.CacheFlagBounds)

		// (A missing key gave NULL, and memcpy crashed, as here.)
		memcpy(&rotationAngleValue, decoder.decodeBytes(forKey: "rotationAngle", returnedLength: nil), MemoryLayout<Tuple3>.size)

		// (An imported NS_ENUM keeps any raw value.)
		stepRotationTypeValue = LDrawStepRotationT(rawValue: decoder.decodeCInt(forKey: LDrawStep.stepRotationTypeKey)) ?? .none

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

		withUnsafeBytes(of: rotationAngleValue) {
			encoder.encodeBytes($0.bindMemory(to: UInt8.self).baseAddress, length: MemoryLayout<Tuple3>.size, forKey: "rotationAngle")
		}
		encoder.encodeCInt(stepRotationTypeValue.rawValue, forKey: LDrawStep.stepRotationTypeKey)

	}//end encodeWithCoder:


	//========== copyWithZone: =====================================================
	//
	// Purpose:		Returns a duplicate of this file.
	//
	//==============================================================================
	@objc(copyWithZone:)
	override func copy(with zone: NSZone? = nil) -> Any {
		let copied = (super.copy(with: zone) as AnyObject) as! LDrawStep	// (a class cast: `as!` from Any is a slow existential cast)

		copied.setStepFlavor(self.stepFlavorValue)
		copied.setStepRotationType(self.stepRotationTypeValue)
		copied.setRotationAngle(self.rotationAngleValue)
		copied.cachedBounds = cachedBounds

		return copied

	}//end copyWithZone:


	//---------- rangeOfDirectiveBeginningAtIndex:inLines:maxIndex: ------[static]--
	//
	// Purpose:		Returns the range from the beginning to the end of the step.
	//
	// Notes:		Index arithmetic is NSUInteger as in ObjC (wrapping operators).
	//
	//------------------------------------------------------------------------------
	@objc(rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:)
	override class func rangeOfDirectiveBeginning(at index: UInt, inLines lines: [NSObject]!, maxIndex: UInt) -> NSRange {
		let lineArray			= lines as NSArray?
		let testLength: UInt	= maxIndex &- index &+ 1
		let testMax: UInt		= index &+ testLength	// NSMaxRange(testRange)
		var counter: UInt		= index
		var stepLength: UInt	= 0

		// Find the last line in the step. Steps either end with the step delimiter,
		// or they simply go all the way to the end of the file.
		while counter < testMax {
			// (Messaging a nil array answered nil lines.)
			var currentLine: String? = nil
			if let lineArray {
				// P6b: ObjC raised here (-objectAtIndex: past the end of the lines);
				// the untrimmed range goes back, and the step parse then fails at
				// its own guard; see KNOWN-BUGS BUG-050
				guard counter < UInt(lineArray.count) else {
					return NSMakeRange(Int(bitPattern: index), Int(bitPattern: testLength))
				}
				currentLine = lineArray.object(at: Int(bitPattern: counter)) as? String
			}
			stepLength &+= 1

			// See if the line is a step delimiter. If the delimiter doesn't exist,
			// it's implied (such as in a 1-step model). Otherwise, it marks the end
			// of the step.
			if		self.lineIsStepTerminator(currentLine)
				||	self.lineIsRotationStepTerminator(currentLine) {
				// Nothing more to parse. Stop.
				break
			}
			counter &+= 1
		}

		return NSMakeRange(Int(bitPattern: index), Int(bitPattern: stepLength))

	}//end rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:


	// MARK: - DIRECTIVES

	//========== draw:viewScale:parentColor: =======================================
	//
	// Purpose:		Draw all the commands in the step.
	//
	//==============================================================================
	@objc(draw:viewScale:parentColor:)
	override func draw(_ optionsMask: UInt, viewScale scaleFactor: Float, parentColor: LDrawColor!) {
		guard let commandsInStep = subdirectives() else {
			return
		}

		//Draw each element in the step.
		for counter in 0..<commandsInStep.count {
			withLDrawDirective(at: counter, in: commandsInStep) { $0.draw(optionsMask, viewScale: scaleFactor, parentColor: parentColor) }
		}

	}//end draw:viewScale:parentColor:


	//========== drawSelf: ===========================================================
	//
	// Purpose:		Draw this directive and its subdirectives by calling APIs on
	//				the passed in renderer, then calling drawSelf on children.
	//
	// Notes:		Steps, like most collections, simply pass down the drawSelf
	//				message.  This is needed because parts "draw" themselves; they do
	//				not "collect" themselves.
	//
	//================================================================================
	@objc(drawSelf:)
	override func drawSelf(_ renderer: (any LDrawRenderer)!) {
		guard let commandsInStep = subdirectives() else {
			return
		}

		//Draw each element in the step.
		for counter in 0..<commandsInStep.count {
			withLDrawDirective(at: counter, in: commandsInStep) { $0.drawSelf(renderer) }
		}

	}//end drawSelf:


	//========== collectSelf: ========================================================
	//
	// Purpose:		Collect self is called on each directive by its parents to
	//				accumulate _mesh_ data into a display list for later drawing.
	//				The collector protocol passed in is some object capable of
	//				remembering the collectable data.
	//
	//				The step does this by recursively collecting its directives.
	//
	//================================================================================
	@objc(collectSelf:)
	override func collectSelf(_ renderer: (any LDrawCollector)!) {
		if let commandsInStep = subdirectives() {
			let primitives = SwiftPrimitiveClasses()

			//Draw each element in the step.
			for counter in 0..<commandsInStep.count {
				withUnretainedChild(at: counter, in: commandsInStep) { child in
					switch primitives.kind(of: child) {
					case .triangle:			unsafeDowncast(child, to: LDrawTriangle.self).collectPrimitive(renderer)
					case .quadrilateral:	unsafeDowncast(child, to: LDrawQuadrilateral.self).collectPrimitive(renderer)
					case .line:				unsafeDowncast(child, to: LDrawLine.self).collectPrimitive(renderer)
					case .other:			unsafeDowncast(child, to: LDrawDirective.self).collectSelf(renderer)
					}
				}
			}
		}
		_ = revalCache(.DisplayList)

	}//end collectSelf:


	//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =======
	//
	// Purpose:		Hit-test the geometry.
	//
	//==============================================================================
	@objc(hitTest:transform:viewScale:boundsOnly:creditObject:hits:)
	override func hitTest(_ pickRay: Ray3, transform: Matrix4, viewScale scaleFactor: Float, boundsOnly: Bool, creditObject: Any!, hits: NSMutableDictionary!) {
		let credit = creditObject as AnyObject?	// (once, not per child: LDrawDirectiveSends)
		guard let commandsInStep = subdirectives() else {
			return
		}
		let commandCount = commandsInStep.count

		// Draw all the steps in the model
		for counter in 0..<commandCount {
			withLDrawDirectiveSends(at: counter, in: commandsInStep) { $0.hitTest(pickRay, transform: transform, viewScale: scaleFactor, boundsOnly: boundsOnly, creditObject: credit, hits: hits) }
		}

	}//end hitTest:transform:viewScale:boundsOnly:creditObject:hits:


	//========== boxTest:transform:boundsOnly:creditObject:hits: ===================
	//
	// Purpose:		Check for intersections with screen-space geometry.
	//
	//==============================================================================
	@objc(boxTest:transform:boundsOnly:creditObject:hits:)
	override func boxTest(_ bounds: Box2, transform: Matrix4, boundsOnly: Bool, creditObject: Any!, hits: NSMutableSet!) -> Bool {
		let credit = creditObject as AnyObject?	// (once, not per child: LDrawDirectiveSends)
		if !VolumeCanIntersectBox(boundingBox3(), transform, bounds) {
			return false
		}

		guard let commandsInStep = subdirectives() else {
			return false
		}
		let commandCount = commandsInStep.count

		let primitives = SwiftPrimitiveClasses()

		// Draw all the steps in the model
		for counter in 0..<commandCount {
			let hit = withUnretainedChild(at: counter, in: commandsInStep) { child -> Bool in
				switch primitives.kind(of: child) {
				case .triangle:
					return unsafeDowncast(child, to: LDrawTriangle.self).boxTestPrimitive(bounds, transform: transform, boundsOnly: boundsOnly, creditObject: creditObject, hits: hits)
				case .quadrilateral:
					return unsafeDowncast(child, to: LDrawQuadrilateral.self).boxTestPrimitive(bounds, transform: transform, boundsOnly: boundsOnly, creditObject: creditObject, hits: hits)
				case .line:
					return unsafeDowncast(child, to: LDrawLine.self).boxTestPrimitive(bounds, transform: transform, boundsOnly: boundsOnly, creditObject: creditObject, hits: hits)
				case .other:
					return unsafeBitCast(child, to: LDrawDirectiveSends.self).boxTest(bounds, transform: transform, boundsOnly: boundsOnly, creditObject: credit, hits: hits)
				}
			}
			if hit {
				if creditObject != nil {
					return true
				}
			}
		}
		return false

	}//end boxTest:transform:boundsOnly:creditObject:hits:


	//========== depthTest:inBox:transform:creditObject:bestObject:bestDepth:=======
	//
	// Purpose:		depthTest finds the closest primitive (in screen space)
	//				overlapping a given point, as well as its device coordinate
	//				depth.
	//
	//==============================================================================
	@objc(depthTest:inBox:transform:creditObject:bestObject:bestDepth:)
	override func depthTest(_ pt: Point2, inBox bounds: Box2, transform: Matrix4, creditObject: Any!, bestObject: AutoreleasingUnsafeMutablePointer<AnyObject?>!, bestDepth: UnsafeMutablePointer<Float>!) {
		let credit = creditObject as AnyObject?	// (once, not per child: LDrawDirectiveSends)
		if !VolumeCanIntersectPoint(boundingBox3(), transform, bounds, bestDepth.pointee) {
			return
		}

		guard let commandsInStep = subdirectives() else {
			return
		}
		let commandCount = commandsInStep.count

		let primitives = SwiftPrimitiveClasses()

		// Draw all the steps in the model
		for counter in 0..<commandCount {
			withUnretainedChild(at: counter, in: commandsInStep) { child in
				switch primitives.kind(of: child) {
				case .triangle:
					unsafeDowncast(child, to: LDrawTriangle.self).depthTestPrimitive(pt, inBox: bounds, transform: transform, creditObject: creditObject, bestObject: bestObject, bestDepth: bestDepth)
				case .quadrilateral:
					unsafeDowncast(child, to: LDrawQuadrilateral.self).depthTestPrimitive(pt, inBox: bounds, transform: transform, creditObject: creditObject, bestObject: bestObject, bestDepth: bestDepth)
				case .line:
					unsafeDowncast(child, to: LDrawLine.self).depthTestPrimitive(pt, inBox: bounds, transform: transform, creditObject: creditObject, bestObject: bestObject, bestDepth: bestDepth)
				case .other:
					unsafeBitCast(child, to: LDrawDirectiveSends.self).depthTest(pt, inBox: bounds, transform: transform, creditObject: credit, bestObject: bestObject, bestDepth: bestDepth)
				}
			}
		}

	}//end depthTest:inBox:transform:creditObject:bestObject:bestDepth:


	//========== write =============================================================
	//
	// Purpose:		Write out all the commands in the step, prefaced by the line
	//				0 STEP
	//
	//==============================================================================
	@objc(write)
	override func write() -> String! {
		write(withStepCommand: true)

	}//end write


	//========== writeWithStepCommand: =============================================
	//
	// Purpose:		Write out all the commands in the step. The output will be
	//				postfaced by the line 0 STEP if explicitStep is true.
	//				The reason this method exists is that we do not want to write
	//				the step command for the last step in the file. That step
	//				is inferred rather than explicit.
	//
	// Note:		flag is ignored if this is a rotation step. In that case, you
	//				get the step command no matter what.
	//
	//==============================================================================
	@objc(writeWithStepCommand:)
	func write(withStepCommand flag: Bool) -> String! {
		let written					= NSMutableString()
		let CRLF					= NSString.crlf() as NSString
		let CRLFString				= CRLF as String	// bridged once, not per child
		let angleZYX				= rotationAngleZYX()

		let commandsInStep			= subdirectives()
		let numberCommands			= commandsInStep?.count ?? 0

		// Write all the step's subdirectives
		// ("%@%@": a nil string printed "(null)".)
		if let commandsInStep {
			for counter in 0..<numberCommands {
				let currentCommand = ldrawDirective(at: counter, in: commandsInStep)
				written.append(currentCommand.write() ?? "(null)")
				written.append(CRLFString)
			}
		}

		// End with 0 STEP or 0 ROTSTEP
		if		flag == true
			||	self.stepRotationTypeValue != .none {
			switch self.stepRotationTypeValue {
				case .none:
					written.append(String(format: "0 %@", LDRAW_STEP_TERMINATOR))

				case .relative:
					written.append(String(format: "0 %@ %.3f %.3f %.3f %@", LDRAW_ROTATION_STEP_TERMINATOR,
										  Double(angleZYX.x),
										  Double(angleZYX.y),
										  Double(angleZYX.z),
										  LDRAW_ROTATION_RELATIVE))

				case .absolute:
					written.append(String(format: "0 %@ %.3f %.3f %.3f %@", LDRAW_ROTATION_STEP_TERMINATOR,
										  Double(angleZYX.x),
										  Double(angleZYX.y),
										  Double(angleZYX.z),
										  LDRAW_ROTATION_ABSOLUTE))

				case .additive:
					written.append(String(format: "0 %@ %.3f %.3f %.3f %@", LDRAW_ROTATION_STEP_TERMINATOR,
										  Double(angleZYX.x),
										  Double(angleZYX.y),
										  Double(angleZYX.z),
										  LDRAW_ROTATION_ADDITIVE))

				case .end:
					written.append(String(format: "0 %@ %@", LDRAW_ROTATION_STEP_TERMINATOR, LDRAW_ROTATION_END))

				@unknown default:
					// (An out-of-range type matched no case and wrote nothing.)
					break
			}
		}

		//Now remove that last CRLF, if it's there.
		if written.hasSuffix(CRLF as String) {
			let lastNewline = NSMakeRange(written.length - CRLF.length, CRLF.length)
			written.deleteCharacters(in: lastNewline)
		}

		return written as String

	}//end writeWithStepCommand:


	// MARK: - DISPLAY

	//========== browsingDescription ===============================================
	//
	// Purpose:		Returns a representation of the directive as a short string
	//				which can be presented to the user.
	//
	//==============================================================================
	@objc(browsingDescription)
	override func browsingDescription() -> String! {
		let enclosingModel			= enclosingDirective()
		var description: String?	= nil

		//If there is no parent model, just display the word step. This situtation
		// would be highly irregular.
		if enclosingModel == nil {
			description = NSLocalizedString("Step", comment: "")
		}
		else {
			// P6b: ObjC raised here (-steps sent to an enclosing container that
			// isn't a model); see KNOWN-BUGS BUG-052
			guard let model = enclosingModel as? LDrawModel else {
				return nil
			}
			//Return the step number.
			// (-[LDrawModel steps] answers -subdirectives.)
			let modelSteps	= model.subdirectives()
			let stepIndex	= modelSteps?.indexOfObjectIdentical(to: self) ?? 0

			description = String(format: NSLocalizedString("StepDisplayWithNumber", comment: ""),
								 Int(bitPattern: UInt(stepIndex)) &+ 1)
		}

		return description

	}//end browsingDescription


	//========== iconName ==========================================================
	//
	// Purpose:		Returns the name of image file used to display this kind of
	//				object, or nil if there is no icon.
	//
	//==============================================================================
	@objc(iconName)
	override func iconName() -> String! {
		var iconName: String? = nil

		switch self.stepRotationTypeValue {
			case .none:
				// no image.
				break

			case .end:
				iconName = "RotationStepEnd"

			default:
				iconName = "RotationStep"
		}

		return iconName

	}//end iconName


	//========== inspectorClassName ================================================
	//
	// Purpose:		Returns the name of the class used to inspect this one.
	//
	//==============================================================================
	@objc(inspectorClassName)
	override func inspectorClassName() -> String! {
		"InspectionStep"

	}//end inspectorClassName


	// MARK: - ACCESSORS

	//========== boundingBox3 ======================================================
	//==============================================================================
	@objc(boundingBox3)
	override func boundingBox3() -> Box3 {
		if revalCache(.CacheFlagBounds) == .CacheFlagBounds {
			cachedBounds = ldrawBoundingBox3(forDirectives: subdirectives())
		}
		return cachedBounds

	}//end boundingBox3


	//========== enclosingModel ====================================================
	//
	// Purpose:		Returns the model of which this step is a part.
	//
	// Notes:		The ObjC cast without checking: whatever container encloses
	//				the step is returned, as before.
	//
	//==============================================================================
	@objc(enclosingModel)
	override func enclosingModel() -> LDrawModel! {
		unsafeBitCast(enclosingDirective() as LDrawContainer?, to: LDrawModel?.self)

	}//end enclosingModel


	//========== rotationAngle =====================================================
	//
	// Purpose:		Returns the xyz angle in degrees of the rotation. The value must
	//				be interpreted according to the step rotation type.
	//
	//==============================================================================
	@objc(rotationAngle)
	func rotationAngle() -> Tuple3 {
		self.rotationAngleValue

	}//end rotationAngle


	//========== rotationAngleZYX ==================================================
	//
	// Purpose:		Returns the zyx angle in degrees of the rotation.
	//
	// Notes:		Of of Bricksmith's matrix math functions expect angles to be in
	//				x-y-z order, so this value is not useful internally. However,
	//				the ROTSTEP directive (and the rest of MLCad) uses a z-y-x
	//				angle, so we have to save to the file in this format.
	//
	//==============================================================================
	@objc(rotationAngleZYX)
	func rotationAngleZYX() -> Tuple3 {
		//---------- Convert XYZ to ZYX --------------------------------------------

		// Translate our internal XYZ angle to ZYX by creating a rotation matrix and
		// decomposing it in a different order.

		let rotationMatrix	= Matrix4Rotate(IdentityMatrix4, self.rotationAngleValue)
		var angleZYX		= Matrix4DecomposeZYXRotation(rotationMatrix)

		// convert from radians to degrees
		angleZYX.x	= LDrawStep.degrees(angleZYX.x)
		angleZYX.y	= LDrawStep.degrees(angleZYX.y)
		angleZYX.z	= LDrawStep.degrees(angleZYX.z)


		//---------- Fix weird float values ----------------------------------------

		// Sometimes these get decomposed with a -180 rotation, which is the same as
		// a 180 rotation. Fix it for display purposes.
		if FloatsApproximatelyEqual(angleZYX.x, -180.0) {
			angleZYX.x = 180
		}

		if FloatsApproximatelyEqual(angleZYX.y, -180.0) {
			angleZYX.y = 180
		}

		if FloatsApproximatelyEqual(angleZYX.z, -180.0) {
			angleZYX.z = 180
		}

		// Sometimes we wind up with a -0 rotation, which ought to be plain old 0.
		// Fix it for display purposes.
		if FloatsApproximatelyEqual(angleZYX.x, -0.0) {
			angleZYX.x = 0
		}

		if FloatsApproximatelyEqual(angleZYX.y, -0.0) {
			angleZYX.y = 0
		}

		if FloatsApproximatelyEqual(angleZYX.z, -0.0) {
			angleZYX.z = 0
		}

		return angleZYX

	}//end rotationAngleZYX


	//========== stepFlavor ========================================================
	//
	// Purpose:		Returns the kind of step this is (optimized parts group like
	//				directives into a single step).
	//
	//==============================================================================
	@objc(stepFlavor)
	func stepFlavor() -> LDrawStepFlavorT {
		self.stepFlavorValue

	}//end stepFlavor


	//========== stepRotationType ==================================================
	//
	// Purpose:		Returns what kind of rotation is attached to this step.
	//
	//==============================================================================
	@objc(stepRotationType)
	func stepRotationType() -> LDrawStepRotationT {
		self.stepRotationTypeValue

	}//end stepRotationType


	//========== setModel: =========================================================
	//
	// Purpose:		Sets a reference to the model of which this step is a part.
	//				Called automatically by -addStep:
	//
	//==============================================================================
	@objc(setModel:)
	func setModel(_ enclosingModel: LDrawModel!) {
		setEnclosing(enclosingModel)

	}//end setModel:


	//========== setRotationAngle: =================================================
	//
	// Purpose:		Sets the xyz angle (in degrees) of the receiver's rotation. The
	//				meaning of the value is determined by the step rotation type.
	//
	// Notes:		The angle stored in the LDraw file is in zyx order, so it is
	//				unsuitable for feeding directly to this method.
	//
	//==============================================================================
	@objc(setRotationAngle:)
	func setRotationAngle(_ newAngle: Tuple3) {
		self.rotationAngleValue = newAngle

		if self.postsNotifications {
			NotificationCenter.default.post(name: NSNotification.Name(LDrawStepDidChangeNotification), object: self)
		}

	}//end setRotationAngle:


	//========== setRotationAngleZYX: ==============================================
	//
	// Purpose:		Sets the rotation angle (in degrees) such the the z angle is
	//				applied first, then y, and lastly x.
	//
	// Notes:		This is the format in which ROTSTEP angles are saved in the
	//				file, but Bricksmith's matrix functions expect XYZ angles. This
	//				translates the ZYX angle so that it can be used by the rest of
	//				Bricksmith.
	//
	//==============================================================================
	@objc(setRotationAngleZYX:)
	func setRotationAngleZYX(_ newAngleZYX: Tuple3) {
		var rotationMatrix	= IdentityMatrix4
		var newAngleXYZ		= ZeroPoint3

		rotationMatrix = Matrix4Rotate(rotationMatrix, V3Make(0, 0, newAngleZYX.z))
		rotationMatrix = Matrix4Rotate(rotationMatrix, V3Make(0, newAngleZYX.y, 0))
		rotationMatrix = Matrix4Rotate(rotationMatrix, V3Make(newAngleZYX.x, 0, 0))

		newAngleXYZ = Matrix4DecomposeXYZRotation(rotationMatrix)

		// convert from radians to degrees
		newAngleXYZ.x	= LDrawStep.degrees(newAngleXYZ.x)
		newAngleXYZ.y	= LDrawStep.degrees(newAngleXYZ.y)
		newAngleXYZ.z	= LDrawStep.degrees(newAngleXYZ.z)

		// Sometimes these get decomposed with a -180 rotation, which is the same as
		// a 180 rotation. Fix it for display purposes.
		if FloatsApproximatelyEqual(newAngleXYZ.x, -180.0) {
			newAngleXYZ.x = 180
		}

		if FloatsApproximatelyEqual(newAngleXYZ.y, -180.0) {
			newAngleXYZ.y = 180
		}

		if FloatsApproximatelyEqual(newAngleXYZ.z, -180.0) {
			newAngleXYZ.z = 180
		}

		setRotationAngle(newAngleXYZ)

	}//end setRotationAngleZYX:


	//========== setStepFlavor: ====================================================
	//
	// Purpose:		Sets the step flavor, which identifies the types of
	//				LDrawDirectives the step contains. Setting the flavor to a
	//				specific directive type will cause the step to draw its
	//				subdirectives inside one set of glBegin()/glEnd(), rather than
	//				starting a new group for each directive encountered.
	//
	//==============================================================================
	@objc(setStepFlavor:)
	func setStepFlavor(_ newFlavor: LDrawStepFlavorT) {
		self.stepFlavorValue = newFlavor

		if self.postsNotifications {
			NotificationCenter.default.post(name: NSNotification.Name(LDrawStepDidChangeNotification), object: self)
		}

	}//end setStepFlavor:


	//========== setStepRotationType: ==============================================
	//
	// Purpose:		Sets the kind of rotation attached to this step.
	//
	// Notes:		Honoring a step rotation is the responsibility of the object
	//				drawing the model, not the step itself.
	//
	//==============================================================================
	@objc(setStepRotationType:)
	func setStepRotationType(_ newValue: LDrawStepRotationT) {
		self.stepRotationTypeValue = newValue

		if self.postsNotifications {
			NotificationCenter.default.post(name: NSNotification.Name(LDrawStepDidChangeNotification), object: self)
		}

	}//end setStepRotationType:


	//========== insertDirective:atIndex: ==========================================
	//
	// Purpose:		Inserts the new directive into the step.
	//
	//==============================================================================
	@objc(insertDirective:atIndex:)
	override func insert(_ directive: LDrawDirective!, at index: Int) {
		invalCache([.CacheFlagBounds, .DisplayList])
		// P6b: ObjC raised here (-[NSMutableArray insertObject:atIndex:] in
		// LDrawContainer, for a nil directive or an index past the end, before
		// the insert); see KNOWN-BUGS BUG-053
		guard directive != nil, index >= 0, index <= (subdirectives()?.count ?? 0) else {
			return
		}
		super.insert(directive, at: index)

	}//end insertDirective:atIndex:


	//========== removeDirectiveAtIndex: ===========================================
	//
	// Purpose:		Removes the directive from the step.
	//
	//==============================================================================
	@objc(removeDirectiveAtIndex:)
	override func removeDirective(at index: Int) {
		invalCache([.CacheFlagBounds, .DisplayList])
		// P6b: ObjC raised here (-objectAtIndex: past the end, before the
		// remove); see KNOWN-BUGS BUG-053
		guard let steps = subdirectives(), index >= 0, index < steps.count else {
			return
		}
		// Keep the directive alive while super removes it (was retain ... release under MRC).
		let directive = steps.object(at: index) as AnyObject

		withExtendedLifetime(directive) {
			super.removeDirective(at: index)
		}

	}//end removeDirectiveAtIndex:


	// MARK: - UTILITIES

	//========== lineIsStepTerminator: =============================================
	//
	// Purpose:		Returns if line is a 0 STEP
	//
	//				Fields compare with NSString's isEqual(to:) (isEqualToString:),
	//				not Swift ==.
	//
	//==============================================================================
	@objc(lineIsStepTerminator:)
	class func lineIsStepTerminator(_ line: String!) -> Bool {
		var workingLine: NSString?	= line as NSString?
		var isStep					= false

		var parsedField = LDrawUtilities.readNextField(line, remainder: &workingLine) as NSString?
		if parsedField?.isEqual(to: "0") == true {
			let partial = workingLine as String?
			parsedField = LDrawUtilities.readNextField(partial, remainder: &workingLine) as NSString?

			if parsedField?.isEqual(to: LDRAW_STEP_TERMINATOR) == true {
				isStep = true
			}
		}

		return isStep
	}


	//========== acceptsDroppedDirective: ==========================================
	//
	// Purpose:		Returns YES if this container will accept a directive dropped on
	//              it.  Explicitly excludes LDrawLSynthDirectives such as INSIDE/OUTSIDE
	//              and self-referencing model "parts"
	//
	//==============================================================================
	@objc(acceptsDroppedDirective:)
	override func acceptsDroppedDirective(_ directive: LDrawDirective!) -> Bool {
		// explicitly disregard LSynth directives
		if directive is LDrawLSynthDirective {
			return false
		}

		// explicitly disregard self-references if the dropped directive is a model "part"
		else if let part = directive as? LDrawPart {
			// ((LDrawMPDModel *)[self enclosingModel]) modelName: messaging nil
			// answered nil.
			var modelName: String? = nil
			if let enclosingModel = enclosingDirective() {
				// P6b: ObjC raised here (-modelName sent to an enclosing container
				// that isn't an MPD model); the drop is refused; see KNOWN-BUGS
				// BUG-052
				guard enclosingModel.responds(to: #selector(LDrawMPDModel.modelName)) else {
					return false
				}
				modelName = enclosingModel.perform(#selector(LDrawMPDModel.modelName))?.takeUnretainedValue() as? String
			}
			if let referenceName = part.referenceName() as NSString?,
			   let modelName,
			   referenceName.isEqual(to: modelName) {
				return false
			}
		}

		return true
	}


	//========== lineIsRotationStepTerminator: =====================================
	//
	// Purpose:		Returns if line is a 0 ROTSTEP
	//
	//==============================================================================
	@objc(lineIsRotationStepTerminator:)
	class func lineIsRotationStepTerminator(_ line: String!) -> Bool {
		var workingLine: NSString?	= line as NSString?
		var isRotationStep			= false

		var parsedField = LDrawUtilities.readNextField(line, remainder: &workingLine) as NSString?
		if parsedField?.isEqual(to: "0") == true {
			let partial = workingLine as String?
			parsedField = LDrawUtilities.readNextField(partial, remainder: &workingLine) as NSString?

			if parsedField?.isEqual(to: LDRAW_ROTATION_STEP_TERMINATOR) == true {
				isRotationStep = true
			}
		}

		return isRotationStep
	}


	//========== parseRotationStepFromLine: ========================================
	//
	// Purpose:		Parses out the rotation step values from the given line.
	//
	//				Rotation steps can have the following forms:
	//
	//					0 ROTSTEP angleX angleY angleZ		// implied REL
	//					0 ROTSTEP angleX angleY angleZ REL
	//					0 ROTSTEP angleX angleY angleZ ABS
	//					0 ROTSTEP angleX angleY angleZ ADD
	//					0 ROTSTEP END
	//
	// Notes:		The angle in ROTSTEPs is in z-y-x order, which is backwards from
	//				how Bricksmith expects the world to be.
	//
	//				Scans with NSScanner's own (UTF-16) methods (L101).
	//
	// Returns:		YES on success.
	//
	//==============================================================================
	@objc(parseRotationStepFromLine:)
	func parseRotationStep(fromLine rotstep: String!) -> Bool {
		let scanner	= Scanner(string: rotstep ?? "")
		let scan	= scanner.utf16
		var angles	= ZeroPoint3

		if scan.scanString("0", into: nil) == false {
			return false
		}

		if scan.scanString(LDRAW_ROTATION_STEP_TERMINATOR, into: nil) == false {
			return false
		}

		// Is it an end rotation?
		if scan.scanString(LDRAW_ROTATION_END, into: nil) == true {
			setStepRotationType(.end)
		}
		else {
			//---------- Angles ------------------------------------------------

			if scan.scanFloat(&angles.x) == false {
				return false
			}

			if scan.scanFloat(&angles.y) == false {
				return false
			}

			if scan.scanFloat(&angles.z) == false {
				return false
			}


			//---------- Rotation Type -----------------------------------------

			if scan.scanString(LDRAW_ROTATION_ABSOLUTE, into: nil) == true {
				setStepRotationType(.absolute)
			}
			else if scan.scanString(LDRAW_ROTATION_ADDITIVE, into: nil) == true {
				setStepRotationType(.additive)
			}
			else if scan.scanString(LDRAW_ROTATION_RELATIVE, into: nil) == true {
				setStepRotationType(.relative)
			}
			// if no type is explicitly specified, it is a relative rotation.
			else if scanner.isAtEnd == true {
				setStepRotationType(.relative)
			}
			// there is some syntax we don't recognize. Abort parsing attempt.
			else {
				return false
			}

			// Set the parsed angles if we successfully got the type.
			setRotationAngleZYX(angles)
		}

		return true

	}//end parseRotationStepFromLine:


	//========== registerUndoActions ===============================================
	//
	// Purpose:		Registers the undo actions that are unique to this subclass,
	//				not to any superclass.
	//
	//==============================================================================
	@objc(registerUndoActions:)
	override func registerUndoActions(_ undoManager: UndoManager!) {
		super.registerUndoActions(undoManager)

		// (Messaging a nil undo manager did nothing.)
		guard let undoManager else {
			return
		}

		unsafeBitCast(undoManager.prepare(withInvocationTarget: self) as AnyObject, to: LDrawStepUndoTarget.self).setRotationAngle(rotationAngle())
		unsafeBitCast(undoManager.prepare(withInvocationTarget: self) as AnyObject, to: LDrawStepUndoTarget.self).setStepRotationType(stepRotationType())

		undoManager.setActionName(NSLocalizedString("UndoAttributesStep", comment: ""))

	}//end registerUndoActions:


	// MARK: - Helpers

	/// MatrixMath.h's degrees(): `(radians) * 180/PI`, a float product divided in double.
	@inline(__always)
	private static func degrees(_ radians: Float) -> Float {
		Float(Double(radians * 180) / Double.pi)
	}
}
