//==============================================================================
//
// File:		LDrawModel.swift
//
// Purpose:		Represents a collection of Lego bricks that form a single model.
//
//				Bricksmith imposes an arbitrary requirement that a model be
//				composed of a series of steps. Each model must have at least one
//				step in it, and only LDrawSteps can be put into the model's
//				subdirective array. Each LDraw model contains at least one step
//				even if it contains no 0 STEP commands, since the final step in
//				the model is not required to have step marker.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//
//  Ported to Swift in P6b. The superclass (LDrawContainer) is still ObjC.
//  Not final: LDrawMPDModel (Swift, P6a) subclasses it.
//
//  Swift API notes: -steps and -draggingDirectives hand ObjC callers the live
//  array, as before; Swift callers keep the imported [Any] spelling
//  (steps(), draggingDirectives()), as LDrawFile's -submodels does (P6a).
//
//  Where the ObjC raised (and a caller's @try or AppKit swallowed it), the
//  port has a guard that abandons the operation at the same point, marked
//  "P6b: ObjC raised here"; see KNOWN-BUGS BUG-P6B-containers-*. The one
//  exception is -setMaximumStepIndexForStepDisplay:, whose deliberate
//  NSRangeException is part of its contract (the steps golden records it).
//==============================================================================

import Foundation

// This disables culling and box approximations for small bricks.  Normally
// we want this on, but for the purpose of measuring heads-up video card
// performance we don't want small bricks to get lost...if we do, the exact
// window size is going to change the rendering load, making it difficult to
// get good metrics on laptops with small screens.
// (If we zoom in to avoid culling by size, the large model will be offscreen
// and the off-screen bricks are culled!
// (ObjC: #define NO_CULL_SMALL_BRICKS 0; the culling code is compiled in.)


/// The undo proxy, seen through the three setters LDrawModel registers (LEARNINGS L103: send the selectors
/// dynamically; never ask the proxy responds(to:)).
@objc private protocol LDrawModelUndoTarget {
	@objc(setAuthor:)
	func setAuthor(_ newAuthor: String!)
	@objc(setFileName:)
	func setFileName(_ newName: String!)
	@objc(setModelDescription:)
	func setModelDescription(_ newDescription: String!)
}


@objc(LDrawModel)
class LDrawModel: LDrawContainer {

	// Coder keys over 15 ASCII bytes would bridge to a new NSString per call (L102).
	private static let modelDescriptionKey = NSString(string: "modelDescription") as String

	// Stored defaults are trivial: -[LDrawDirective initWithLines:...] re-enters
	// init() on the half-built object.
	private var modelDescriptionValue: String?	= nil
	private var fileNameValue: String?			= nil
	private var authorValue: String?			= nil
	@exclusivity(unchecked) private var rotationCenterValue: Point3 = Point3()

	@exclusivity(unchecked) private var colorLibraryValue: ColorLibrary? = nil	// in-scope !COLOURS local to the model
	@exclusivity(unchecked) private var stepDisplayActive: Bool = false		// YES if we are only display steps 1-currentStepDisplayed
	@exclusivity(unchecked) private var currentStepDisplayed: UInt = 0		// display up to and including this step index

	@exclusivity(unchecked) private var cachedBounds: Box3 = Box3()		// bounds of the model - only covers steps that are showing

	//steps are stored in the superclass.

	// Drag and Drop
	@exclusivity(unchecked) private var draggingStep: LDrawStep? = nil

	@exclusivity(unchecked) private var isOptimized: Bool = false			// Were we ever structure-optimized - used to optimize out
																			// some drawing on library parts.
	@exclusivity(unchecked) private var dl: LDrawDLHandle? = nil			// Cached DL if we have one.
	@exclusivity(unchecked) private var dlDtor: LDrawDLCleanup_f? = nil


	// MARK: - INITIALIZATION

	//---------- model ---------------------------------------------------[static]--
	//
	// Purpose:		Creates a new model ready to be edited.
	//
	//------------------------------------------------------------------------------
	@objc(model)
	class func model() -> Any! {
		// [[[self class] alloc] init]: the receiving class's -init.
		let newModel = (self as NSObject.Type).init() as! LDrawModel

		//Then fill it up with useful initial attributes
		newModel.setModelDescription(NSLocalizedString("UntitledModel", comment: ""))
		newModel.setFileName("")

		newModel.setAuthor(LDrawUtilities.defaultAuthor())

		//Need to create a blank step.
		newModel.addStep()

		return newModel

	}//end model


	//========== init ==============================================================
	//
	// Purpose:		Creates a new, completely blank model file.
	//
	//==============================================================================
	@objc(init)
	override init() {
		super.init()

		self.colorLibraryValue	= ColorLibrary()
		self.cachedBounds		= InvalidBox
		setModelDescription("")
		setFileName("")
		setAuthor("")

		setStepDisplay(false)

	}//end init


	//========== initWithLines:inRange: ============================================
	//
	// Purpose:		-[LDrawDirective initWithLines:inRange:] (no parent group),
	//				which sends -initWithLines:inRange:parentGroup: to self.
	//				Designated, not convenience, so LDrawMPDModel can override it.
	//
	//==============================================================================
	@objc(initWithLines:inRange:)
	override init!(lines: [NSObject]!, in range: NSRange) {
		super.init(lines: lines, in: range)
	}


	//========== initWithLines:inRange:parentGroup: ================================
	//
	// Purpose:		Creates a new model file based on the lines from a file.
	//				These lines of strings should only describe one model, not
	//				multiple ones.
	//
	//				This method divides the model into steps. A step may be ended
	//				by:
	//					* a 0 STEP line
	//					* a 0 ROTSTEP line
	//					* the end of the file
	//
	//				A STEP or ROTSTEP command is part of the step they end, so they
	//				are the last line IN the step.
	//
	//				The final step marker is optional. Thus a file that has no step
	//				markers still has one step.
	//
	// Notes:		Index arithmetic is NSUInteger as in ObjC (wrapping operators).
	//
	//==============================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override init!(lines: [NSObject]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		let rangeLocation			= UInt(bitPattern: range.location)
		let rangeMax				= rangeLocation &+ UInt(bitPattern: range.length)	// NSMaxRange(range)
		var contentStartIndex: UInt	= 0
		var stepRange				= range
		var maxLineIndex: UInt		= 0
		// (ObjC: a calloc'd buffer of range.length slots.)
		var substeps: [LDrawStep]	= []

		//Start with a nice blank model.
		// (No lines at all: super answers nil. The ObjC then wrote an ivar
		// through nil and crashed; see KNOWN-BUGS BUG-P6B-containers-1.)
		super.init(lines: lines, in: range, parentGroup: parentGroup)
		self.cachedBounds = InvalidBox

		//Try and get the header out of the file. If it's there, the lines returned
		// will not contain it.
		contentStartIndex	= parseHeader(fromLines: lines, beginningAt: rangeLocation)
		maxLineIndex		= rangeMax &- 1

		let modelDispatchGroup: dispatch_group_t? = nil
		// Parse out steps. Each time we run into a new 0 STEP command, we finish
		// the current step.
		repeat {
			stepRange = LDrawStep.rangeOfDirectiveBeginning(at: contentStartIndex, inLines: lines, maxIndex: maxLineIndex)
			guard let newStep = LDrawStep(lines: lines, in: stepRange, parentGroup: modelDispatchGroup) else {
				// The step could not be parsed (malformed ROTSTEP): fail the model.
				// Stop here, as the exception this replaces did, so later steps are
				// never parsed.
				return nil
			}
			substeps.append(newStep)

			contentStartIndex = UInt(bitPattern: stepRange.location) &+ UInt(bitPattern: stepRange.length)

		}
		while contentStartIndex < rangeMax

		for step in substeps {
			addStep(step)
		}

		// Degenerate case: utterly empty file. Create one empty step, because it is
		// illegal to have a 0-step model in Bricksmith.
		if (stepsArray()?.count ?? 0) == 0 {
			addStep()
		}

	}//end initWithLines:inRange:


	//========== initWithCoder: ====================================================
	//
	// Purpose:		Reads a representation of this object from the given coder,
	//				which is assumed to always be a keyed decoder. This allows us to
	//				read and write LDraw objects as NSData.
	//
	// Notes:		-init never runs here, so there is no colour library.
	//
	//==============================================================================
	@objc(initWithCoder:)
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)
		self.cachedBounds = InvalidBox
		invalCache(.CacheFlagBounds)

		modelDescriptionValue	= decoder.decodeObject(forKey: LDrawModel.modelDescriptionKey) as? String
		fileNameValue			= decoder.decodeObject(forKey: "fileName") as? String
		authorValue				= decoder.decodeObject(forKey: "author") as? String

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

		encoder.encode(modelDescriptionValue, forKey: LDrawModel.modelDescriptionKey)
		encoder.encode(fileNameValue, forKey: "fileName")
		encoder.encode(authorValue, forKey: "author")

	}//end encodeWithCoder:


	//========== copyWithZone: =====================================================
	//
	// Purpose:		Returns a duplicate of this file.
	//
	//==============================================================================
	@objc(copyWithZone:)
	override func copy(with zone: NSZone? = nil) -> Any {
		let copied = (super.copy(with: zone) as AnyObject) as! LDrawModel	// (a class cast: `as!` from Any is a slow existential cast)
		copied.cachedBounds = cachedBounds

		copied.setModelDescription(modelDescription())
		copied.setFileName(fileName())
		copied.setAuthor(author())

		copied.setStepDisplay(stepDisplay())
		// P6b: -setMaximumStepIndexForStepDisplay: raised here when the step
		// index was past the copy's last step (an index set while the model had
		// no steps); the copy is returned as it stands, since -copy can't fail;
		// see KNOWN-BUGS BUG-P6B-containers-6
		let maximumStepIndex = maximumStepIndexForStepDisplay()
		guard maximumStepIndex <= UInt(bitPattern: (copied.stepsArray()?.count ?? 0) - 1) else {
			return copied
		}
		copied.setMaximumStepIndexForStepDisplay(maximumStepIndex)

		//I don't think we care about the cached bounds.

		return copied

	}//end copyWithZone:


	// MARK: - DIRECTIVES

	//---------- stepsToOutput -------------------------------------------[private]--
	//
	// Purpose:		The steps array and -maxStepIndexToOutput for the loops over
	//				the visible steps, or nil where those loops raised: a model
	//				with no steps (the maximum index wraps to NSUIntegerMax, and
	//				-objectAtIndex:0 raised).
	//
	//------------------------------------------------------------------------------
	@inline(__always)
	private func stepsToOutput() -> (steps: NSMutableArray, maxIndex: Int)? {
		guard let steps = subdirectives() else {
			return nil
		}
		let maxIndex = maxStepIndexToOutput()
		// P6b: ObjC raised here (-objectAtIndex: past the last step; a model with
		// no steps); see KNOWN-BUGS BUG-P6B-containers-6
		guard maxIndex < UInt(steps.count) else {
			return nil
		}
		return (steps, Int(maxIndex))
	}


	//========== draw:viewScale:parentColor: =======================================
	//
	// Purpose:		Simply draw all the steps; they will worry about drawing all
	//				their constituents.
	//
	//==============================================================================
	@objc(draw:viewScale:parentColor:)
	override func draw(_ optionsMask: UInt, viewScale scaleFactor: Float, parentColor: LDrawColor!) {
		guard let output = stepsToOutput() else {
			return
		}

		// Draw all the steps in the model
		for counter in 0...output.maxIndex {
			withLDrawDirective(at: counter, in: output.steps) { $0.draw(optionsMask, viewScale: scaleFactor, parentColor: parentColor) }
		}

		// Draw Drag-and-Drop pieces if we've got 'em.
		if let draggingStep = self.draggingStep {
			draggingStep.draw(optionsMask, viewScale: scaleFactor, parentColor: parentColor)
		}

	}//end draw:viewScale:parentColor:


	//========== drawSelf: ===========================================================
	//
	// Purpose:		Draw this directive and its subdirectives by calling APIs on
	//				the passed in renderer, then calling drawSelf on children.
	//
	// Notes:		The LDrawModel serves as the display-list holder for all
	//				primitives directly "underneath" it.  Thus when we hit drawSelf
	//				We revalidate our DL and then just draw it.
	//
	//				"Our" DL is a DL containing only the mesh primtiives DIRECTLY
	//				underneath us.  Triangles that are part of a model that is
	//				referenced by a PART underneath us are not collected - that is,
	//				collection is not recursive.  We count on the library being
	//				flattened to ensure one VBO per library part.
	//
	//				Per frame: no heap allocation on the cached-DL path.
	//
	//================================================================================
	@objc(drawSelf:)
	override func drawSelf(_ renderer: (any LDrawRenderer)!) {
		// First: cull check!  In my last perf look, draw time was bottlenecked
		// on the GPU not eating data fast enough, _not_ on CPU.  So burning a
		// tiny bit of CPU time per part to cull draw calls is a win!

		// (-boundingBox3, minus the dispatch; nil where it raised.)
		guard let my_bounds = checkedBoundingBox3() else {
			return
		}
		var minxyz: (Float, Float, Float) = (my_bounds.min.x, my_bounds.min.y, my_bounds.min.z)
		var maxxyz: (Float, Float, Float) = (my_bounds.max.x, my_bounds.max.y, my_bounds.max.z)

		let cull_result = withUnsafeMutablePointer(to: &minxyz) { minTuple in
			withUnsafeMutablePointer(to: &maxxyz) { maxTuple in
				minTuple.withMemoryRebound(to: Float.self, capacity: 3) { minPtr in
					maxTuple.withMemoryRebound(to: Float.self, capacity: 3) { maxPtr in
						renderer.checkCull(minPtr, to: maxPtr)
					}
				}
			}
		}

		// (NO_CULL_SMALL_BRICKS is 0.)
		if Int(cull_result) == cull_skip {
			return
		}

		if Int(cull_result) == cull_box {
			withUnsafeMutablePointer(to: &minxyz) { minTuple in
				withUnsafeMutablePointer(to: &maxxyz) { maxTuple in
					minTuple.withMemoryRebound(to: Float.self, capacity: 3) { minPtr in
						maxTuple.withMemoryRebound(to: Float.self, capacity: 3) { maxPtr in
							renderer.drawBox(from: minPtr, to: maxPtr)
						}
					}
				}
			}
			return
		}

		// DL cache control: we may have to throw out our old DL if it has gone
		// stale. EITHER WAY we mark our DL bit as validated per the rules of
		// the observable protocol.
		if let staleDL = dl {
			if revalCache(.DisplayList) == .DisplayList {
				// (A NULL cleanup function crashed the ObjC too.)
				dlDtor!(staleDL)
				dlDtor = nil
				dl = nil
			}
		}
		else {
			_ = revalCache(.DisplayList)
		}

		// Now: if we do not have a DL (no DL or we threw it out because it
		// was invalid) build one now: get a collector and call "collect" on
		// ourselves, which will walk our tree picking up primitives.
		if dl == nil {
			let collector = renderer.beginDL()
			// (-collectSelf:, minus the dispatch.)
			// P6b: ObjC raised inside -collectSelf: (a model with no steps),
			// leaving the DL open; see KNOWN-BUGS BUG-P6B-containers-6
			guard collectSteps(collector) else {
				return
			}
			var newDL: LDrawDLHandle?			= nil
			var newDtor: LDrawDLCleanup_f?		= nil
			renderer.endDL(&newDL, cleanupFunc: &newDtor)
			dl		= newDL
			dlDtor	= newDtor
		}

		// Finally: if we have a DL (cached or brand new, draw it!!)
		if let dl {
			renderer.drawDL(dl)
		}

		if !isOptimized {
			// Slow stuff part 1, skipped on library parts for speed.

			// First: recurse the 'drawSelf message.  This is needed for:
			// - Parts, which draw, not collect and
			// - Drag handles for selected primitives.
			// Library parts are guaranteed to be only steps of primitives,
			// so there is no need for this.

			guard let output = stepsToOutput() else {
				return
			}

			for counter in 0...output.maxIndex {
				withLDrawDirective(at: counter, in: output.steps) { $0.drawSelf(renderer) }
			}

			// And: if we are currently dragging directives, those
			// directives were skipped in the cases above.  So we
			// do something a little scary.  We build a temporary
			// DL for those directives, draw the DL and nuke them.
			// We ALSO pass drawSelf message.
			//
			// This isn't terrible unless we are dragging a huge
			// number of raw primitives.

			if let draggingStep = self.draggingStep {
				var drag_dl: LDrawDLHandle?				= nil
				var drag_dl_dtor: LDrawDLCleanup_f?		= nil

				let collector = renderer.beginDL()
				draggingStep.collectSelf(collector)
				renderer.endDL(&drag_dl, cleanupFunc: &drag_dl_dtor)

				if let drag_dl {
					renderer.drawDL(drag_dl)
					drag_dl_dtor!(drag_dl)
				}

				draggingStep.drawSelf(renderer)
			}

		}
	}//drawSelf:


	//========== collectSelf: ========================================================
	//
	// Purpose:		Collect self is called on each directive by its parents to
	//				accumulate _mesh_ data into a display list for later drawing.
	//				The collector protocol passed in is some object capable of
	//				remembering the collectable data.
	//
	//				Models simply recurse to their steps.
	//
	// Notes:		We do NOT revalidate our display list, because we do not expect
	//				to hit this case from a 'parent'.  Rather, we expect a part to
	//				call "draw" on us (a model) and then we bulid our OWN DL.
	//
	//				See drawSelf: implementation above for cached DL handling!
	//
	//================================================================================
	@objc(collectSelf:)
	override func collectSelf(_ renderer: (any LDrawCollector)!) {
		_ = collectSteps(renderer)

	}//end collectSelf:


	//---------- collectSteps: -------------------------------------------[private]--
	//
	// Purpose:		The body of -collectSelf:. Returns false where the ObjC raised.
	//
	//------------------------------------------------------------------------------
	private func collectSteps(_ renderer: (any LDrawCollector)!) -> Bool {
		guard let output = stepsToOutput() else {
			return false
		}

		// Draw all the steps in the model
		for counter in 0...output.maxIndex {
			withLDrawDirective(at: counter, in: output.steps) { $0.collectSelf(renderer) }
		}
		return true
	}


	//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =======
	//
	// Purpose:		Hit-test the geometry.
	//
	//==============================================================================
	@objc(hitTest:transform:viewScale:boundsOnly:creditObject:hits:)
	override func hitTest(_ pickRay: Ray3, transform: Matrix4, viewScale scaleFactor: Float, boundsOnly: Bool, creditObject: Any!, hits: NSMutableDictionary!) {
		let credit = creditObject as AnyObject?	// (once, not per child: LDrawDirectiveSends)
		guard let output = stepsToOutput() else {
			return
		}

		// Draw all the steps in the model
		for counter in 0...output.maxIndex {
			withLDrawDirective(at: counter, in: output.steps) { $0.hitTest(pickRay, transform: transform, viewScale: scaleFactor, boundsOnly: boundsOnly, creditObject: credit, hits: hits) }
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
		// (-boundingBox3, minus the dispatch; nil where it raised.)
		guard let myBounds = checkedBoundingBox3() else {
			return false
		}
		if !VolumeCanIntersectBox(myBounds, transform, bounds) {
			return false
		}

		guard let output = stepsToOutput() else {
			return false
		}

		// Draw all the steps in the model
		for counter in 0...output.maxIndex {
			if withLDrawDirective(at: counter, in: output.steps, { $0.boxTest(bounds, transform: transform, boundsOnly: boundsOnly, creditObject: credit, hits: hits) }) {
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
		// (-boundingBox3, minus the dispatch; nil where it raised.)
		guard let myBounds = checkedBoundingBox3() else {
			return
		}
		if !VolumeCanIntersectPoint(myBounds, transform, bounds, bestDepth.pointee) {
			return
		}

		guard let output = stepsToOutput() else {
			return
		}

		// Draw all the steps in the model
		for counter in 0...output.maxIndex {
			withLDrawDirective(at: counter, in: output.steps) { $0.depthTest(pt, inBox: bounds, transform: transform, creditObject: credit, bestObject: bestObject, bestDepth: bestDepth) }
		}

	}//end depthTest:inBox:transform:creditObject:bestObject:bestDepth:


	//========== write =============================================================
	//
	// Purpose:		Writes out the MPD submodel, wrapped in the MPD file commands.
	//
	//==============================================================================
	@objc(write)
	override func write() -> String! {
		let CRLF			= NSString.crlf() as NSString	//we need a DOS line-end marker, because
															//LDraw is predominantly DOS-based.
		let CRLFString		= CRLF as String	// bridged once, not per step
		let written			= NSMutableString()
		let steps			= subdirectives()
		let numberSteps		= steps?.count ?? 0

		//Write out the file header in all of its irritating glory.
		// ("%@": a nil string printed "(null)".)
		written.append(String(format: "0 %@%@", modelDescription() ?? "(null)", CRLF))
		written.append(String(format: "0 %@ %@%@", LDRAW_HEADER_NAME, fileName() ?? "(null)", CRLF))
		written.append(String(format: "0 %@ %@%@", LDRAW_HEADER_AUTHOR, author() ?? "(null)", CRLF))

		//Write out all the steps in the file.
		if let steps {
			for counter in 0..<numberSteps {
				let currentStep = ldrawDirective(at: counter, in: steps)
				let stepOutput: String?

				// Omit the 0 STEP command for 1-step models, which probably aren't
				// being built with steps in mind anyway.
				if numberSteps == 1 {
					// P6b: ObjC raised here (-writeWithStepCommand: sent to a child
					// that isn't a step); see KNOWN-BUGS BUG-P6B-containers-7
					guard let step = currentStep as? LDrawStep else {
						return nil
					}
					stepOutput = step.write(withStepCommand: false)
				}
				else {
					stepOutput = currentStep.write()
				}

				written.append(stepOutput ?? "(null)")
				written.append(CRLFString)
			}
		}

		//Now remove that last CRLF.
		written.deleteCharacters(in: NSMakeRange(written.length - CRLF.length, CRLF.length))

		return written as String

	}//end write


	// MARK: - DISPLAY

	//========== browsingDescription ===============================================
	//
	// Purpose:		Returns a representation of the directive as a short string
	//				which can be presented to the user.
	//
	//==============================================================================
	@objc(browsingDescription)
	override func browsingDescription() -> String! {
		modelDescription()

	}//end browsingDescription


	//========== iconName ==========================================================
	//
	// Purpose:		Returns the name of image file used to display this kind of
	//				object, or nil if there is no icon.
	//
	//==============================================================================
	@objc(iconName)
	override func iconName() -> String! {
		"Document"

	}//end iconName


	// MARK: - ACCESSORS

	//========== boundingBox3 ======================================================
	//
	// Purpose:		Returns the minimum and maximum points of the box which
	//				perfectly contains this object.
	//
	//				We optimize this calculation on models whose dimensions are
	//				known to be constant--parts from the library, for instance.
	//
	//==============================================================================
	@objc(boundingBox3)
	override func boundingBox3() -> Box3 {
		// (Where the ObjC raised, the cache is already revalidated and empty.)
		checkedBoundingBox3() ?? InvalidBox

	}//end boundingBox3


	//---------- checkedBoundingBox3 -------------------------------------[private]--
	//
	// Purpose:		The body of -boundingBox3. Answers nil where the ObjC raised:
	//				rebuilding the bounds of a model with no steps.
	//
	//------------------------------------------------------------------------------
	private func checkedBoundingBox3() -> Box3? {
		var totalBounds		= InvalidBox
		var draggingBounds	= InvalidBox

		if revalCache(.CacheFlagBounds) == .CacheFlagBounds {
			cachedBounds = InvalidBox

			guard let output = stepsToOutput() else {
				return nil
			}
			// Draw all the steps in the model
			for counter in 0...output.maxIndex {
				cachedBounds = V3UnionBox(cachedBounds, withLDrawDirective(at: counter, in: output.steps) { $0.boundingBox3() })
			}
		}
		totalBounds = cachedBounds

		// If drag-and-drop objects are present, add them into the bounds.
		if let draggingStep = self.draggingStep {
			draggingBounds	= ldrawBoundingBox3(forDirectives: draggingStep.subdirectives())
			totalBounds		= V3UnionBox(draggingBounds, totalBounds)
		}

		return totalBounds
	}


	//========== category ==========================================================
	//
	// Purpose:		Returns the category to which this model belongs. This is
	//				determined from the description field, which is the first line
	//				of the file for non-MPD documents. For instance:
	//
	//				0 Brick  2 x  4
	//
	//				This part would be in the category "Brick", and has the
	//				description "Brick  2 x  4".
	//
	//==============================================================================
	@objc(category)
	func category() -> String! {
		// (Messaging a nil description answered a zero range, then nil.)
		guard let modelDescription = self.modelDescriptionValue as NSString? else {
			return nil
		}
		var category: NSString

		//The category name is the first word in the description.
		let firstSpace = modelDescription.range(of: " ")	//range of the category string in the first line.
		if firstSpace.location != NSNotFound {
			category = modelDescription.substring(to: firstSpace.location) as NSString
		}
		else {
			category = NSString(string: modelDescription as String)
		}

		//Clean category name of any weird notational marks
		if category.hasPrefix("_") || category.hasPrefix("~") {
			category = category.substring(from: 1) as NSString
		}

		return category as String

	}//end category


	//========== colorLibrary ======================================================
	//
	// Purpose:		Returns the color library object which accumulates the !COLOURS
	//				defined locally within the model.
	//
	// Notes:		According to the LDraw color spec, local colors having scoping:
	//				they become active at the point of definition and fall out of
	//				scope at the end of the model. As a convenience in Bricksmith,
	//				the color library will still contain all the local model colors
	//				after a draw is complete--the library will not be purged just
	//				for scoping's sake. It may be purged at the beginning of
	//				drawing, however.
	//
	//==============================================================================
	@objc(colorLibrary)
	func colorLibrary() -> ColorLibrary! {
		self.colorLibraryValue

	}//end colorLibrary


	//========== draggingDirectives ================================================
	//
	// Purpose:		Returns the objects that are currently being displayed as part
	//				of drag-and-drop.
	//
	// Notes:		ObjC callers get the drag step's live array, as before (or nil).
	//				Swift callers keep the imported [Any] spelling.
	//
	//==============================================================================
	@objc(draggingDirectives)
	func draggingDirectivesArray() -> NSArray! {
		self.draggingStep?.subdirectives()

	}//end draggingDirectives

	@nonobjc
	func draggingDirectives() -> [Any]! {
		(draggingDirectivesArray() as NSArray?) as? [Any]
	}


	//========== enclosingFile =====================================================
	//
	// Purpose:		Returns the file in which this model is stored.
	//
	// Notes:		The ObjC cast without checking: whatever container encloses
	//				the model is returned, as before.
	//
	//==============================================================================
	@objc(enclosingFile)
	override func enclosingFile() -> LDrawFile! {
		unsafeBitCast(enclosingDirective() as LDrawContainer?, to: LDrawFile?.self)

	}//end enclosingFile


	//========== modelDescription ==================================================
	//
	// Purpose:		Returns the model description, which is the first line of the
	//				model. (i.e., Brick 2 x 4)
	//
	//==============================================================================
	@objc(modelDescription)
	func modelDescription() -> String! {
		modelDescriptionValue

	}//end modelDescription


	//========== fileName ==========================================================
	//
	// Purpose:		Returns the name the model is ostensibly saved under in the
	//				file system.
	//
	//==============================================================================
	@objc(fileName)
	func fileName() -> String! {
		fileNameValue

	}//end fileName


	//========== author ============================================================
	//
	// Purpose:		Returns the person who created the document.
	//
	//==============================================================================
	@objc(author)
	func author() -> String! {
		authorValue

	}//end author


	//========== maximumStepIndexDisplayed =========================================
	//
	// Purpose:		Returns the index of the last step which will be drawn. The
	//				value only has meaning if the model is in step-display mode.
	//
	//==============================================================================
	@objc(maximumStepIndexForStepDisplay)
	func maximumStepIndexForStepDisplay() -> UInt {
		self.currentStepDisplayed

	}//end maximumStepIndexDisplayed


	//========== rotationAngleForStepAtIndex: ======================================
	//
	// Purpose:		Returns the viewing angle which should be used when displaying
	//				the given step in Step Display mode.
	//
	// Notes:		Rotations are NOT built up in a stack. One would think End
	//				Rotation removes an item from the stack, but actually it
	//				restores the default view. Each step rotation completely
	//				replaces the previous rotation, although computing the new value
	//				may require consulting the value about to be replaced.
	//
	//				The actual rotation to use is whatever we get by calculating all
	//				the rotations up to and including the specified step.
	//
	//				Neither the step, the model, nor any other data-level class is
	//				responsible for enforcing this angle when drawing. It is up to
	//				the document to enforce or ignore the step rotation angle. In
	//				Bricksmith, the document only sets the step rotation when in
	//				Step Display mode, when the step being viewed is changed.
	//
	//==============================================================================
	@objc(rotationAngleForStepAtIndex:)
	func rotationAngleForStep(at stepNumber: UInt) -> Tuple3 {
		let steps								= stepsArray()
		let stepCount							= UInt(steps?.count ?? 0)
		var rotationType: LDrawStepRotationT	= .none
		var stepRotationAngle					= ZeroPoint3
		var previousRotation					= ZeroPoint3
		var newRotation							= ZeroPoint3
		var totalRotation						= ZeroPoint3
		var rotationMatrix						= IdentityMatrix4
		var counter: UInt						= 0

		// Start with the default 3D angle onto the stack. If no rotation is ever
		// specified, that is the one we use.
		newRotation		= LDrawUtilities.angle(forViewOrientation: .orientation3D)
		totalRotation	= newRotation

		// Build the rotation stack
		while counter <= stepNumber && counter < stepCount {
			// P6b: ObjC raised here (-stepRotationType sent to a child that isn't
			// a step); see KNOWN-BUGS BUG-P6B-containers-7
			guard let currentStep = steps?.object(at: Int(counter)) as? LDrawStep else {
				return totalRotation
			}
			rotationType		= currentStep.stepRotationType()
			stepRotationAngle	= currentStep.rotationAngle()

			switch rotationType {
				case .none:
					// Nothing to do here. This means "use whatever was on the stack
					// last."
					newRotation = totalRotation

				case .relative:

					// Start with the default 3D rotation
					previousRotation	= LDrawUtilities.angle(forViewOrientation: .orientation3D)

					// Add the new value to it.
					rotationMatrix	= Matrix4Rotate(IdentityMatrix4, stepRotationAngle)
					rotationMatrix	= Matrix4Rotate(rotationMatrix, previousRotation)
					newRotation		= Matrix4DecomposeXYZRotation(rotationMatrix)

					// convert from radians to degrees
					newRotation.x	= LDrawModel.degrees(newRotation.x)
					newRotation.y	= LDrawModel.degrees(newRotation.y)
					newRotation.z	= LDrawModel.degrees(newRotation.z)

				case .absolute:

					// Use the step's angle directly
					newRotation		= stepRotationAngle

				case .additive:

					// Peek at the previous rotation on the stack
					previousRotation = totalRotation

					// Add the new value to it.
					rotationMatrix	= Matrix4Rotate(IdentityMatrix4, stepRotationAngle)
					rotationMatrix	= Matrix4Rotate(rotationMatrix, previousRotation)
					newRotation		= Matrix4DecomposeXYZRotation(rotationMatrix)

					// convert from radians to degrees
					newRotation.x	= LDrawModel.degrees(newRotation.x)
					newRotation.y	= LDrawModel.degrees(newRotation.y)
					newRotation.z	= LDrawModel.degrees(newRotation.z)

				case .end:

					// This means end all rotations and restore the default angle.
					// It's not a stack. Bizarre.
					newRotation		= LDrawUtilities.angle(forViewOrientation: .orientation3D)

				@unknown default:
					// (An out-of-range type matched no case: newRotation stays.)
					break
			}

			// Replace the cumulative rotation with the newly-computed one
			totalRotation	= newRotation
			counter += 1
		}

		// Return the final calculated angle. This is the absolute rotation to which
		// we are to set the view.

		return totalRotation

	}//end rotationAngleForStepAtIndex:


	//========== rotationCenter ====================================================
	//==============================================================================
	@objc(rotationCenter)
	func rotationCenter() -> Point3 {
		self.rotationCenterValue
	}


	//========== stepDisplay =======================================================
	//
	// Purpose:		Returns YES if the receiver only displays the steps through
	//				the index of the currentStepDisplayed instance variable.
	//
	//==============================================================================
	@objc(stepDisplay)
	func stepDisplay() -> Bool {
		self.stepDisplayActive

	}//end stepDisplay


	//========== steps =============================================================
	//
	// Purpose:		Returns the steps which constitute this model.
	//
	// Notes:		ObjC callers get the live array, as before. Swift callers keep
	//				the imported [Any] spelling.
	//
	//==============================================================================
	@objc(steps)
	func stepsArray() -> NSArray! {
		subdirectives()

	}//end steps

	@nonobjc
	func steps() -> [Any]! {
		(stepsArray() as NSArray?) as? [Any]
	}


	//========== visibleStep =======================================================
	//
	// Purpose:		Returns the last step which would be drawn if this model were
	//				drawn right now.
	//
	//==============================================================================
	@objc(visibleStep)
	func visibleStep() -> LDrawStep! {
		let steps					= stepsArray()
		var lastStep: AnyObject?	= nil

		if stepDisplay() == true {
			let maxIndex = maxStepIndexToOutput()
			// P6b: ObjC raised here (-objectAtIndex: past the last step; a model
			// with no steps); see KNOWN-BUGS BUG-P6B-containers-6
			guard let steps, maxIndex < UInt(steps.count) else {
				return nil
			}
			lastStep = steps.object(at: Int(maxIndex)) as AnyObject
		}
		else {
			lastStep = steps?.lastObject as AnyObject?
		}

		// (The ObjC returned the object unchecked.)
		return unsafeBitCast(lastStep, to: LDrawStep?.self)

	}//end visibleStep


	//========== setDraggingDirectives: ============================================
	//
	// Purpose:		Sets the parts which are being manipulated in the model via
	//			    drag-and-drop.
	//
	//==============================================================================
	@objc(setDraggingDirectives:)
	func setDraggingDirectives(_ directives: [Any]!) {
		var dragStep: LDrawStep? = nil

		// Remove primitives from the previous dragging directives from the
		// optimized vertexes
		if let previousDragStep = self.draggingStep {
			let lines			= NSMutableArray()
			let triangles		= NSMutableArray()
			let quadrilaterals	= NSMutableArray()

			previousDragStep.flatten(intoLines: lines,
									 triangles: triangles,
									 quadrilaterals: quadrilaterals,
									 other: nil,
									 currentColor: ColorLibrary.shared()?.color(forCode: LDrawCurrentColor),
									 currentTransform: IdentityMatrix4,
									 normalTransform: IdentityMatrix3,
									 recursive: false)
		}

		// When we get sent nil directives, nil out the drag step.
		if let directives {
			let newDragStep = LDrawStep.empty() as! LDrawStep

			// The law of Bricksmith is that all parts in a model must be enclosed in a
			// step. Resistance is futile.
			for counter in 0..<directives.count {
				let currentDirective = unsafeBitCast(directives[counter] as AnyObject, to: LDrawDirective.self)
				newDragStep.add(currentDirective)
			}

			// Tell the element that it lives in us now. This is important for
			// submodel references being dragged; without it, they have no way of
			// resolving their part reference, and thus can't draw during their
			// drag.
			newDragStep.setEnclosing(self)


			//---------- Optimize primitives ---------------------------------------

			let lines			= NSMutableArray()
			let triangles		= NSMutableArray()
			let quadrilaterals	= NSMutableArray()

			newDragStep.flatten(intoLines: lines,
								triangles: triangles,
								quadrilaterals: quadrilaterals,
								other: nil,
								currentColor: ColorLibrary.shared()?.color(forCode: LDrawCurrentColor),
								currentTransform: IdentityMatrix4,
								normalTransform: IdentityMatrix3,
								recursive: false)

			dragStep = newDragStep
		}


		self.draggingStep = dragStep

	}//end setDraggingDirectives:


	//========== setModelDescription: ==============================================
	//
	// Purpose:		Sets a new model description.
	//
	//==============================================================================
	@objc(setModelDescription:)
	func setModelDescription(_ newDescription: String!) {
		modelDescriptionValue = newDescription

	}//end setModelDescription:


	//========== setFileName: ======================================================
	//
	// Purpose:		Sets the name the model is ostensibly saved under in the
	//				file system. This may take on a rather different meaning in
	//				multi-part documents. It also has no real connection with the
	//				actual filesystem name.
	//
	//==============================================================================
	@objc(setFileName:)
	func setFileName(_ newName: String!) {
		fileNameValue = newName

	}//end setFileName:


	//========== setAuthor: ========================================================
	//
	// Purpose:		Changes the name of the person who created the model.
	//
	//==============================================================================
	@objc(setAuthor:)
	func setAuthor(_ newAuthor: String!) {
		// LLW - Don't allow author to be set to nil, as this causes funky
		// behavior in the inspector
		authorValue = newAuthor ?? ""

	}//end setAuthor:


	//========== setMaximumStepIndexForStepDisplay: ================================
	//
	// Purpose:		Sets the index of the last step drawn. If the model is not
	//				currently in step-display mode, this call will NOT cause it to
	//				enter step display.
	//
	// Notes:		The bounds check compares unsigned, as in ObjC: with no steps
	//				the maximum index wraps and nothing is out of range.
	//
	//				The NSRangeException is this method's contract (its message is
	//				in the steps golden), so it is raised as before. It starts in
	//				this frame and unwinds straight to the caller; Swift callers in
	//				this class check first.
	//
	//==============================================================================
	@objc(setMaximumStepIndexForStepDisplay:)
	func setMaximumStepIndexForStepDisplay(_ stepIndex: UInt) {
		//Need to check and make sure this step number is not overflowing the bounds.
		let maximumIndex: Int = (stepsArray()?.count ?? 0) &- 1

		if stepIndex > UInt(bitPattern: maximumIndex) {
			NSException(name: .rangeException,
						reason: String(format: "index (%ld) beyond maximum step index %ld", Int(bitPattern: stepIndex), maximumIndex),
						userInfo: nil).raise()
		}
		else {
			invalCache([.CacheFlagBounds, .DisplayList])
			self.currentStepDisplayed = stepIndex
		}

	}//end setMaximumStepIndexForStepDisplay:


	//========== setRotationCenter: ================================================
	//
	// Purpose:		Returns the point around which the model should be spun while
	//				being viewed.
	//
	//==============================================================================
	@objc(setRotationCenter:)
	func setRotationCenter(_ newPoint: Point3) {
		var oldPoint = self.rotationCenterValue

		self.rotationCenterValue = newPoint

		// @encode(Point3)
		let oldValue = NSValue(bytes: &oldPoint, objCType: "{Point3Struct=fff}")
		NotificationCenter.default.post(name: NSNotification.Name(LDrawModelRotationCenterDidChangeNotification),
										object: enclosingFile(),
										userInfo: ["oldRotationCenter": oldValue])
	}


	//========== setStepDisplay ====================================================
	//
	// Purpose:		Sets whether the receiver only displays the steps through
	//				the index of the currentStepDisplayed instance variable.
	//
	//==============================================================================
	@objc(setStepDisplay:)
	func setStepDisplay(_ flag: Bool) {
		invalCache([.CacheFlagBounds, .DisplayList])
		self.stepDisplayActive = flag

	}//end setStepDisplay:


	// MARK: - ACTIONS

	//========== addStep ===========================================================
	//
	// Purpose:		Creates a new blank step at the end of the model. Returns the
	//				new step created.
	//
	//==============================================================================
	@objc(addStep)
	@discardableResult
	func addStep() -> LDrawStep! {
		let newStep = LDrawStep.empty() as! LDrawStep

		add(newStep as LDrawDirective) //adds the step and tells it who it belongs to.

		return newStep

	}//end addStep


	//========== addStep: ==========================================================
	//
	// Purpose:		Adds newStep at the end of the model.
	//
	//==============================================================================
	@objc(addStep:)
	func addStep(_ newStep: LDrawStep!) {
		add(newStep as LDrawDirective)

	}//end addStep:


	//========== makeStepVisible: ==================================================
	//
	// Purpose:		Guarantees that the given step is visible in this model.
	//
	//==============================================================================
	@objc(makeStepVisible:)
	func makeStepVisible(_ step: LDrawStep!) {
		let stepIndex = UInt(bitPattern: index(of: step))

		// If we're in step display, but below this step, make it visible.
		// (A step in the model is never past its last index, so no raise.)
		if		stepIndex != UInt(bitPattern: NSNotFound)
			&&	stepIndex > maxStepIndexToOutput() {
			setMaximumStepIndexForStepDisplay(stepIndex)
		}
		// Otherwise, we see everything, so by definition this step is visible.

	}//end makeStepVisible


	//========== removeDirectiveAtIndex: ===========================================
	//
	// Purpose:		Removes one directive from our container.  We override this
	//				to find out our directive index _before_ the removal so we can
	//				keep our current step in sync!
	//
	//==============================================================================
	@objc(removeDirectiveAtIndex:)
	override func removeDirective(at idx: Int) {
		invalCache([.CacheFlagBounds, .DisplayList])
		if UInt(bitPattern: idx) <= currentStepDisplayed && currentStepDisplayed > 0 {
			currentStepDisplayed -= 1
		}

		// P6b: ObjC raised here (-objectAtIndex: in LDrawContainer for an index
		// past the end, after the bookkeeping above); see KNOWN-BUGS
		// BUG-P6B-containers-5
		guard idx >= 0, idx < (subdirectives()?.count ?? 0) else {
			return
		}
		super.removeDirective(at: idx)
	}


	@objc(insertDirective:atIndex:)
	override func insert(_ directive: LDrawDirective!, at index: Int) {
		invalCache([.CacheFlagBounds, .DisplayList])
		// P6b: ObjC raised here (-[NSMutableArray insertObject:atIndex:] in
		// LDrawContainer, for a nil directive or an index past the end, before
		// the insert); see KNOWN-BUGS BUG-P6B-containers-5
		guard directive != nil, index >= 0, index <= (subdirectives()?.count ?? 0) else {
			return
		}
		super.insert(directive, at: index)
	}


	// MARK: - UTILITIES

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
			let referenceName						= part.referenceName()
			var enclosingModelName: NSString?		= ""
			if let enclosingModel = self.enclosingModel(),
			   enclosingModel.responds(to: #selector(LDrawMPDModel.modelName)) {
				// (A getter: its result is not owned.)
				enclosingModelName = enclosingModel.perform(#selector(LDrawMPDModel.modelName))?.takeUnretainedValue() as? NSString
			}

			if let enclosingModelName, let referenceName, enclosingModelName.isEqual(to: referenceName) {
				return false
			}
		}

		return true
	}


	//========== maxStepIndexToOutput ==============================================
	//
	// Purpose:		Returns the index of the last step which should be displayed.
	//
	// Notes:		This is always supposed to return an index >= 0, simply because
	//				it is illegal for a model to have no steps in Bricksmith.
	//				(With no steps, count - 1 wraps to NSUIntegerMax, as in ObjC.)
	//
	//==============================================================================
	@objc(maxStepIndexToOutput)
	func maxStepIndexToOutput() -> UInt {
		let stepCount		= UInt(subdirectives()?.count ?? 0)
		var maxStep: UInt	= 0

		// If step display is active, we want to display only as far as the
		// specified step, or the maximum step if the one specified exceeds the
		// number of steps.
		if self.stepDisplayActive == true {
			maxStep = min(stepCount &- 1, //subtract one to get last step index in model.
						  self.currentStepDisplayed)
		}
		else {
			maxStep = stepCount &- 1
		}

		return maxStep

	}//end maxStepIndexToOutput


	//========== numberElements ====================================================
	//
	// Purpose:		Returns the number of elements found in this model. Currently
	//				this does not recurse into MPD submodels which have been
	//				included.
	//
	//==============================================================================
	@objc(numberElements)
	func numberElements() -> UInt {
		let steps					= stepsArray()
		var numberElements: UInt	= 0

		for counter in 0..<(steps?.count ?? 0) {
			// P6b: ObjC raised here (-subdirectives sent to a child that isn't a
			// container); see KNOWN-BUGS BUG-P6B-containers-7
			guard let currentStep = steps?.object(at: counter) as? LDrawContainer else {
				return numberElements
			}
			numberElements += UInt(currentStep.subdirectives()?.count ?? 0)
		}

		return numberElements

	}//end numberElements


	//========== optimizeStructure =================================================
	//
	// Purpose:		Arranges the directives in such a way that the file will be
	//				drawn faster. This method should *never* be called on files
	//				which the user has created himself, since it reorganizes the
	//				file contents. It is intended only for parts read from the part
	//				library.
	//
	//				To optimize, we flatten all the primitives referenced by a part
	//				into a non-nested structure, then separate all the directives
	//				out by the type: all triangles go in a step, all quadrilaterals
	//				go in their own step, etc.
	//
	//				Then when drawing, we need not call glBegin() each time. The
	//				result is a speed increase of over 1000%.
	//
	//				1000%. That is not a typo.
	//
	//==============================================================================
	@objc(optimizeStructure)
	func optimizeStructure() {
		let steps				= subdirectives()

		let lines				= NSMutableArray()
		let triangles			= NSMutableArray()
		let quadrilaterals		= NSMutableArray()
		let everythingElse		= NSMutableArray()

		let linesStep			= LDrawStep.empty(withFlavor: .lines) as! LDrawStep
		let trianglesStep		= LDrawStep.empty(withFlavor: .triangles) as! LDrawStep
		let quadrilateralsStep	= LDrawStep.empty(withFlavor: .quadrilaterals) as! LDrawStep
		let everythingElseStep	= LDrawStep.empty(withFlavor: .anyDirectives) as! LDrawStep

		var directiveCount		= 0
		var counter				= 0

		// Traverse the entire hiearchy of part references and sort out each
		// primitive type into a flat list. This allows staggering speed increases.
		//
		// If we were to only sort without flattening, we would get a 100% speed
		// increase. But flattening and sorting yields over 1000%.
		flatten(intoLines: lines,
				triangles: triangles,
				quadrilaterals: quadrilaterals,
				other: everythingElse,
				currentColor: ColorLibrary.shared()?.color(forCode: LDrawCurrentColor),
				currentTransform: IdentityMatrix4,
				normalTransform: IdentityMatrix3,
				recursive: true)

		// Now that we have everything separated, remove the main step (it's the one
		// that has the entire model in it) and .
		directiveCount = steps?.count ?? 0
		counter = directiveCount - 1
		while counter >= 0 {
			removeDirective(at: counter)
			counter -= 1
		}

		// Replace the original directives with the categorized steps we've created
		if lines.count > 0 {
			for index in 0..<lines.count {
				linesStep.add(ldrawDirective(at: index, in: lines))
			}
			add(linesStep as LDrawDirective)
		}

		if triangles.count > 0 {
			for index in 0..<triangles.count {
				trianglesStep.add(ldrawDirective(at: index, in: triangles))
			}
			add(trianglesStep as LDrawDirective)
		}
		if quadrilaterals.count > 0 {
			for index in 0..<quadrilaterals.count {
				quadrilateralsStep.add(ldrawDirective(at: index, in: quadrilaterals))
			}
			add(quadrilateralsStep as LDrawDirective)
		}
		if everythingElse.count > 0 || (subdirectives()?.count ?? 0) == 0 {
			// Make sure there is at least one step in the model!
			for index in 0..<everythingElse.count {
				everythingElseStep.add(ldrawDirective(at: index, in: everythingElse))
			}
			add(everythingElseStep as LDrawDirective)
		}

		isOptimized = true

	}//end optimizeStructure


	//========== parseHeaderFromLines:beginningAtIndex: ============================
	//
	// Purpose:		Given lines from an LDraw document, fill in the model header
	//				info. It should be of the following format:
	//
	//				0 7140 X-Wing Fighter
	//				0 Name: main.ldr
	//				0 Author: Tim Courtney <tim@zacktron.com>
	//				0 LDraw.org Official Model Repository
	//				0 http://www.ldraw.org/repository/official/
	//
	//				Note, however, that this information is *not* required, so it
	//				may not be there. Consequently, the code below is a nightmarish
	//				unmaintainable mess.
	//
	//				Returns the line index of the first non-header line.
	//
	//==============================================================================
	@objc(parseHeaderFromLines:beginningAtIndex:)
	func parseHeader(fromLines lines: [NSObject]!, beginningAt index: UInt) -> UInt {
		let lineArray						= lines as NSArray?
		var currentLine: String?			= nil
		var counter: UInt					= 0
		var lineValidForHeader				= false
		var firstNonHeaderIndex: UInt		= index
		var payload: NSString?				= nil
		let lineCount						= UInt(lineArray?.count ?? 0)

		// Stop at the end of the lines. (Not at the end of the model's range: the
		// header scan has always been free to read on into the following lines.)
		if let lineArray, index < lineCount {
			//First line. Should be a description of the model.
			currentLine = lineArray.object(at: Int(index)) as? String
			if line(currentLine, isValidForHeader: "", info: &payload) {
				setModelDescription(payload as String?)
				firstNonHeaderIndex += 1
			}

			//There are at least three more lines in a valid header.
			// Read the first four lines, and try to get the model info out of
			// them.
			lineValidForHeader	= true
			counter				= firstNonHeaderIndex
			while counter < firstNonHeaderIndex + 3 && lineValidForHeader == true {
				//Ran out of lines in the file. Oh well. We got what we got.
				if counter >= lineCount {
					break
				}

				currentLine			= lineArray.object(at: Int(counter)) as? String
				lineValidForHeader	= false // assume not, then disprove
				payload				= nil

				//Second line. Should be file name.
				if line(currentLine, isValidForHeader: LDRAW_HEADER_NAME, info: &payload) {
					setFileName(payload as String?)
					lineValidForHeader = true
				}
				//Third line. Should be author name.
				else if line(currentLine, isValidForHeader: LDRAW_HEADER_AUTHOR, info: &payload) {
					setAuthor(payload as String?)
					lineValidForHeader = true
				}
				//Fourth line. MLCad used it as a nonstandard way of indicating
				//official status. Since it was nonstandard, nobody used it.
				else if line(currentLine, isValidForHeader: "", info: &payload) {
					if		payload?.isEqual(to: "LDraw.org Official Model Repository") == true
						||	payload?.isEqual(to: "Unofficial Model") == true {
						// Bricksmith followed MLCad spewing out this garbage for
						// years. It is unnecessary. Now I am just stripping it out
						// of any file I encounter.
						lineValidForHeader = true
					}
				}

				if lineValidForHeader == true {
					firstNonHeaderIndex += 1
				}
				counter += 1
			}
		}

		return firstNonHeaderIndex

	}//end parseHeaderFromLines


	//========== line:isValidForHeader: ============================================
	//
	// Purpose:		Determines if the given line of LDraw is formatted to be the
	//				the specified field in a model header.
	//
	//				Fields compare with NSString's isEqual(to:) (isEqualToString:),
	//				not Swift ==.
	//
	//==============================================================================
	@objc(line:isValidForHeader:info:)
	func line(_ line: String!, isValidForHeader headerKey: String!, info infoPtr: AutoreleasingUnsafeMutablePointer<NSString?>!) -> Bool {
		var workingLine: NSString?	= line as NSString?
		var isValid					= false

		var parsedField = LDrawUtilities.readNextField(line, remainder: &workingLine) as NSString?
		if parsedField?.isEqual(to: "0") == true {
			if ((headerKey as NSString?)?.length ?? 0) > 0 {
				let partial = workingLine as String?
				parsedField = LDrawUtilities.readNextField(partial, remainder: &workingLine) as NSString?
				isValid = parsedField?.isEqual(to: headerKey) == true
			}
			else {
				isValid = true
			}


			if isValid {
				if let infoPtr {
					infoPtr.pointee = workingLine?.trimmingCharacters(in: .whitespaces) as NSString?
				}
			}
		}

		return isValid

	}//end line:isValidForHeader:


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

		unsafeBitCast(undoManager.prepare(withInvocationTarget: self) as AnyObject, to: LDrawModelUndoTarget.self).setAuthor(author())
		unsafeBitCast(undoManager.prepare(withInvocationTarget: self) as AnyObject, to: LDrawModelUndoTarget.self).setFileName(fileName())
		unsafeBitCast(undoManager.prepare(withInvocationTarget: self) as AnyObject, to: LDrawModelUndoTarget.self).setModelDescription(modelDescription())

		undoManager.setActionName(NSLocalizedString("UndoAttributesModel", comment: ""))

	}//end registerUndoActions:


	// MARK: - DESTRUCTOR

	// (No deinit: -dealloc released the ivars and never ran the DL cleanup, so
	// the last display list is not cleaned up here either. ModelDisplayListTests
	// pins that.)


	// MARK: - Helpers

	/// MatrixMath.h's degrees(): `(radians) * 180/PI`, a float product divided in double.
	@inline(__always)
	private static func degrees(_ radians: Float) -> Float {
		Float(Double(radians * 180) / Double.pi)
	}
}
