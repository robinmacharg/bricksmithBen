//==============================================================================
//
// File:		LDrawFile.swift
//
// Purpose:		Represents an LDraw file, composed of one or more models.
//				In Bricksmith, each file is interpreted as a Multi-Part Document
//				having multiple submodels. Only LDrawMPDModels can be contained
//				in the file's subdirective array. However, when the document is
//				written out, the MPD commands are stripped if there is only
//				one model in the file.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright (c) 2005. All rights reserved.
//
//  Ported to Swift in P6a. The superclass (LDrawContainer) is still ObjC.
//  LDrawFile.h survives as a types-only header for
//  LDrawFileActiveModelDidChangeNotification.
//
//  Where the ObjC raised (and a caller's @try or AppKit swallowed it), the
//  port has a guard that abandons the operation at the same point, marked
//  "P6a: ObjC raised here"; see KNOWN-BUGS BUG-P6A-files-n.
//==============================================================================

import Foundation

@objc(LDrawFile)
final class LDrawFile: LDrawContainer {

	// Stored defaults are nil: -[LDrawDirective initWithLines:...] re-enters
	// init() on the half-built object.
	private var nameModelDict: NSDictionary?	// lower-cased model name -> model
	private var activeModelRef: LDrawMPDModel?
	private var filePath: String?				//where this file came from on disk.
	// Set when the last lookup-table rebuild hit a place where the ObjC raised
	// (BUG-P6A-files-6), so Swift callers further up stop as the raise did.
	private var lookupRebuildAbandoned = false


	// MARK: - Initialization

	//---------- file ----------------------------------------------------[static]--
	//
	// Purpose:		Creates a new LDraw document ready for editing. It should
	//				include one submodel with one step inside it.
	//
	//------------------------------------------------------------------------------
	@objc(file)
	class func file() -> LDrawFile! {
		let newFile		= LDrawFile()
		let firstModel	= LDrawMPDModel.model() as? LDrawMPDModel

		//Fill it with one empty model.
		newFile.addSubmodel(firstModel)
		newFile.setActiveModel(firstModel)

		return newFile

	}//end file


	//---------- fileFromContentsAtPath: ---------------------------------[static]--
	//
	// Purpose:		Reads a file from the specified path.
	//
	// Notes:		The ObjC entry point. Swift imported it as
	//				init!(fromContentsAtPath:), which is kept below (L98).
	//
	//------------------------------------------------------------------------------
	@objc(fileFromContentsAtPath:)
	class func file(fromContentsAtPath path: String!) -> LDrawFile! {
		let fileContents				= LDrawUtilities.string(fromFile: path)
		var parsedFile: LDrawFile?		= nil

		if fileContents != nil {
			parsedFile = LDrawFile.parse(fromFileContents: fileContents)
			parsedFile?.setPath(path)
		}

		return parsedFile

	}//end fileFromContentsAtPath:


	//---------- init(fromContentsAtPath:) ---------------------------------------
	//
	// Purpose:		The Swift spelling of +fileFromContentsAtPath: (Swift-only).
	//				Parses exactly as +parseFromFileContents: does.
	//
	//------------------------------------------------------------------------------
	@nonobjc
	convenience init!(fromContentsAtPath path: String!) {
		guard let fileContents = LDrawUtilities.string(fromFile: path) else {
			return nil
		}
		let lines = (fileContents as NSString).separateByLine()

		self.init(lines: lines, in: NSMakeRange(0, lines?.count ?? 0))

		setPath(path)
	}


	//---------- parseFromFileContents: ----------------------------------[static]--
	//
	// Purpose:		Reads a file out of the raw file contents.
	//
	//------------------------------------------------------------------------------
	@objc(parseFromFileContents:)
	class func parse(fromFileContents fileContents: String!) -> LDrawFile? {
		parse(fromFileContents: fileContents, parseFailed: nil)

	}//end parseFromFileContents:


	//---------- parseFromFileContents:parseFailed: ----------------------[static]--
	//
	// Purpose:		Reads a file out of the raw file contents.
	//
	//				Returns nil both for text with no lines and for text that could
	//				not be parsed; *parseFailed (if given) says which. (The parse used
	//				to throw in the second case; BUG-007.)
	//
	//------------------------------------------------------------------------------
	@objc(parseFromFileContents:parseFailed:)
	class func parse(fromFileContents fileContents: String!, parseFailed: UnsafeMutablePointer<ObjCBool>?) -> LDrawFile? {
		let lines		= (fileContents as NSString?)?.separateByLine()
		let lineCount	= lines?.count ?? 0

		let newFile: LDrawFile? = LDrawFile(lines: lines, in: NSMakeRange(0, lineCount))

		if let parseFailed {
			parseFailed.pointee = ObjCBool(newFile == nil && lineCount > 0)
		}

		return newFile

	}//end parseFromFileContents:parseFailed:


	//========== init ==============================================================
	//
	// Purpose:		Creates a new file with absolutely nothing in it.
	//
	//==============================================================================
	@objc(init)
	override init() {
		super.init() //initializes an empty list of subdirectives--in this
		// case, the models in the file.

		activeModelRef = nil

	}//end init


	//========== initWithLines:inRange: ============================================
	//
	// Purpose:		As -[LDrawDirective initWithLines:inRange:]: no parent group.
	//				(Overridden so the inherited ObjC entry point isn't a trap.)
	//
	//==============================================================================
	@objc(initWithLines:inRange:)
	override convenience init!(lines: [Any]!, in range: NSRange) {
		self.init(lines: lines, in: range, parentGroup: nil)
	}


	//========== initWithLines:inRange:parentGroup: ================================
	//
	// Purpose:		Parses the MPD models out of the lines. If lines contains a
	//				single non-MPD model, it will be wrapped in an MPD model.
	//
	//==============================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override init!(lines: [Any]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		super.init(lines: lines, in: range, parentGroup: parentGroup)

		let maxIndex					= UInt(bitPattern: NSMaxRange(range) &- 1)
		var modelStartIndex				= range.location
		var submodels: [LDrawMPDModel]	= []

		// Search through all the lines in the file, and separate them out into
		// submodels.
		repeat {
			let modelRange = LDrawMPDModel.rangeOfDirectiveBeginning(at: UInt(bitPattern: modelStartIndex),
																	 inLines: lines,
																	 maxIndex: maxIndex)
			// Parse
			guard let newModel = LDrawMPDModel(lines: lines, in: modelRange, parentGroup: nil) else {
				// A model could not be parsed (malformed ROTSTEP): fail the file,
				// stopping here as the exception this replaces did.
				return nil
			}
			submodels.append(newModel)

			modelStartIndex = NSMaxRange(modelRange)
		}
		while modelStartIndex < NSMaxRange(range)

		// Add all the models in order
		for currentModel in submodels {
			addSubmodel(currentModel)
			// P6a: ObjC raised inside (see updateModelLookupTable), out of the
			// init; see KNOWN-BUGS BUG-P6A-files-6
			if lookupRebuildAbandoned {
				return nil
			}
		}

		if let models = subdirectives(), models.count > 0 {
			setActiveModel(models.object(at: 0) as? LDrawMPDModel)
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

		//We don't encode the active model; it is just assumed to be the first
		// model each time the file is created.
		// (A missing array answered nil, so no active model.)
		let models = subdirectives()
		// P6a: ObjC raised here (-objectAtIndex:0 on a file archived with no
		// models); see KNOWN-BUGS BUG-P6A-files-3
		if let models, models.count == 0 {
			return nil
		}
		let firstModel = models?.object(at: 0) as? LDrawMPDModel
		setActiveModel(firstModel)

		// P6a: ObjC raised inside (see updateModelLookupTable); see KNOWN-BUGS
		// BUG-P6A-files-6
		guard updateModelLookupTable() else {
			return nil
		}

	}//end initWithCoder:


	//========== copyWithZone: =====================================================
	//
	// Purpose:		Returns a duplicate of this file.
	//
	//==============================================================================
	@objc(copyWithZone:)
	override func copy(with zone: NSZone? = nil) -> Any {
		let copied				= super.copy(with: zone)
		let indexOfActiveModel	= index(of: activeModelRef)

		guard let copiedFile = copied as? LDrawFile else {
			return copied
		}
		// P6a: ObjC raised here (-objectAtIndex:NSNotFound when the active model
		// is nil or no longer in the file); the copy is returned without an active
		// model; see KNOWN-BUGS BUG-P6A-files-4
		guard let copiedModels = copiedFile.subdirectives(),
			  indexOfActiveModel >= 0, indexOfActiveModel < copiedModels.count else {
			return copiedFile
		}
		let copiedActiveModel = copiedModels.object(at: indexOfActiveModel)

		copiedFile.setActiveModel(copiedActiveModel as? LDrawMPDModel)

		return copiedFile

	}//end copyWithZone:


	// MARK: - Directives

	//========== draw:viewScale:parentColor: =======================================
	//
	// Purpose:		Draw only the active model. The other submodels in an MPD file
	//				are only meant to be seen when they are are referenced from the
	//				active submodel.
	//
	//==============================================================================
	@objc(draw:viewScale:parentColor:)
	override func draw(_ optionsMask: UInt, viewScale scaleFactor: Float, parentColor: LDrawColor!) {
		//
		// Draw!
		//	(only the active model.)
		//
		activeModelRef?.draw(optionsMask, viewScale: scaleFactor, parentColor: parentColor)

	}//end draw:viewScale:parentColor:


	//========== drawSelf: ===========================================================
	//
	// Purpose:		Draw this directive and its subdirectives by calling APIs on
	//				the passed in renderer, then calling drawSelf on children.
	//
	//================================================================================
	@objc(drawSelf:)
	override func drawSelf(_ renderer: (any LDrawRenderer)!) {
		activeModelRef?.drawSelf(renderer)

	}//end drawSelf:


	//========== collectSelf: ========================================================
	//
	// Purpose:		Collect self is called on each directive by its parents to
	//				accumulate _mesh_ data into a display list for later drawing.
	//
	// Notes:		The file should never be 'collected', because parts do not
	//				reference files - rather they reference the models WITHIN
	//				files.  So while we have a release implementation of passing
	//				the message on, we have an assert to catch this case.
	//				(assert() was compiled out by NDEBUG in Release and Perf;
	//				assertionFailure is likewise a no-op in optimised builds.)
	//
	//================================================================================
	@objc(collectSelf:)
	override func collectSelf(_ renderer: (any LDrawCollector)!) {
		assertionFailure("Why are we here?")
		activeModelRef?.collectSelf(renderer)

	}//end collectSelf:


	//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =======
	//
	// Purpose:		Hit-test the geometry.
	//
	//==============================================================================
	@objc(hitTest:transform:viewScale:boundsOnly:creditObject:hits:)
	override func hitTest(_ pickRay: Ray3, transform: Matrix4, viewScale scaleFactor: Float, boundsOnly: Bool,
						  creditObject: Any!, hits: NSMutableDictionary!) {
		activeModelRef?.hitTest(pickRay, transform: transform, viewScale: scaleFactor, boundsOnly: boundsOnly,
								creditObject: creditObject, hits: hits)

	}//end hitTest:transform:viewScale:boundsOnly:creditObject:hits:


	//========== boxTest:transform:boundsOnly:creditObject:hits: ===================
	//
	// Purpose:		Check for intersections with screen-space geometry.
	//
	//==============================================================================
	@objc(boxTest:transform:boundsOnly:creditObject:hits:)
	override func boxTest(_ bounds: Box2, transform: Matrix4, boundsOnly: Bool, creditObject: Any!,
						  hits: NSMutableSet!) -> Bool {
		activeModelRef?.boxTest(bounds, transform: transform, boundsOnly: boundsOnly,
								creditObject: creditObject, hits: hits) ?? false

	}//end boxTest:transform:boundsOnly:creditObject:hits:


	//========== depthTest:inBox:transform:creditObject:bestObject:bestDepth:=======
	//
	// Purpose:		depthTest finds the closest primitive (in screen space)
	//				overlapping a given point, as well as its device coordinate
	//				depth.
	//
	//==============================================================================
	@objc(depthTest:inBox:transform:creditObject:bestObject:bestDepth:)
	override func depthTest(_ testPt: Point2, inBox bounds: Box2, transform: Matrix4, creditObject: Any!,
							bestObject: AutoreleasingUnsafeMutablePointer<AnyObject?>!,
							bestDepth: UnsafeMutablePointer<Float>!) {
		activeModelRef?.depthTest(testPt, inBox: bounds, transform: transform, creditObject: creditObject,
								  bestObject: bestObject, bestDepth: bestDepth)

	}//end depthTest:inBox:transform:creditObject:bestObject:bestDepth:


	//========== write =============================================================
	//
	// Purpose:		Write out all the submodels sequentially.
	//
	//==============================================================================
	@objc(write)
	override func write() -> String! {
		let written			= NSMutableString()
		let CRLF: String	= NSString.crlf()
		let modelsInFile	= subdirectives()
		let numberModels	= modelsInFile?.count ?? 0

		//If there is only one submodel, this hardly qualifies as an MPD document.
		// So write out the single model without the MPD FILE/NOFILE wrapper.
		if numberModels == 1 {
			// P6a: ObjC raised here (-writeModel sent to a non-MPD child, or a nil
			// string appended); see KNOWN-BUGS BUG-P6A-files-7
			guard let currentModel = modelsInFile?.object(at: 0) as? LDrawMPDModel,
				  let text = currentModel.writeModel() else {
				return nil
			}
			//Write out the model, without MPD wrappers.
			written.append(text)
		}
		else {
			//Write out each MPD submodel, one after another.
			for counter in 0 ..< numberModels {
				// P6a: ObjC raised here (a nil string appended); see KNOWN-BUGS
				// BUG-P6A-files-7
				guard let currentModel = modelsInFile?.object(at: counter) as? LDrawDirective,
					  let text = currentModel.write() else {
					return nil
				}
				written.append(text)
				written.append(CRLF)
			}
		}

		//Trim off any final newline characters.
		return written.trimmingCharacters(in: .whitespacesAndNewlines)

	}//end write


	// MARK: - Accessors

	//========== activeModel =======================================================
	//
	// Purpose:		Returns the name of the currently-active model in the file.
	//
	//==============================================================================
	@objc(activeModel)
	func activeModel() -> LDrawMPDModel! {
		activeModelRef

	}//end activeModel


	//========== firstModel =======================================================
	//
	// Purpose:		Returns the first model in the file, which is the one to use
	//				when referred to from a separate peer file.
	//
	//==============================================================================
	@objc(firstModel)
	func firstModel() -> LDrawMPDModel! {
		// (A missing array answered nil.)
		guard let models = subdirectives() else {
			return nil
		}
		// P6a: ObjC raised here (-objectAtIndex:0 on a file with no models); see
		// KNOWN-BUGS BUG-P6A-files-5
		guard models.count > 0 else {
			return nil
		}
		return models.object(at: 0) as? LDrawMPDModel

	}//end firstModel


	//========== draggingDirectives ================================================
	//
	// Purpose:		Returns the objects that are currently being displayed as part
	//			    of drag-and-drop.
	//
	//==============================================================================
	@objc(draggingDirectives)
	func draggingDirectives() -> [Any]! {
		activeModel()?.draggingDirectives()

	}//end draggingDirectives


	//========== modelNames ========================================================
	//
	// Purpose:		Returns the the names of all the submodels in the file.
	//
	//==============================================================================
	@objc(modelNames)
	func modelNames() -> [Any]! {
		let submodels		= subdirectives()
		let numberModels	= submodels?.count ?? 0
		let modelNames		= NSMutableArray()

		for counter in 0 ..< numberModels {
			// P6a: ObjC raised here (a nil model name, or -modelName sent to a
			// non-MPD child); see KNOWN-BUGS BUG-P6A-files-6
			guard let currentModel = submodels?.object(at: counter) as? LDrawMPDModel,
				  let name = currentModel.modelName() else {
				return nil
			}
			modelNames.add(name)
		}

		return modelNames as? [Any]

	}//end modelNames


	//========== modelWithName: ====================================================
	//
	// Purpose:		Returns the submodel with the given name, or nil if one couldn't
	//				be found.
	//
	//==============================================================================
	@objc(modelWithName:)
	func model(withName soughtName: String!) -> LDrawMPDModel! {
		// (Messaging nil answered nil.)
		guard let soughtName else {
			return nil
		}
		let referenceName	= (soughtName as NSString).lowercased // we standardized on lower-case names for searching.
		let foundModel		= nameModelDict?.object(forKey: referenceName) as? LDrawMPDModel

		return foundModel

	}//end modelWithName:


	//========== path ==============================================================
	//
	// Purpose:		Returns the filesystem path at which this file was resides, or
	//				nil if that information is undetermined. Only files that are
	//				read by the user will have their paths set; parts from the
	//				library disregard this information.
	//
	//==============================================================================
	@objc(path)
	func path() -> String! {
		filePath

	}//end path


	//========== submodels =========================================================
	//
	// Purpose:		Returns an array of the LDrawModels (or more likely, the
	//				LDrawMPDModels) which constitute this file.
	//
	// Notes:		ObjC callers (the outline data source, per row; the
	//				Dimensions/Piece Count bindings) get the live array, as before.
	//				Swift callers keep the imported [Any] spelling.
	//
	//==============================================================================
	@objc(submodels)
	func submodelsArray() -> NSArray! {
		subdirectives()

	}//end submodels

	@nonobjc
	func submodels() -> [Any]! {
		(subdirectives() as NSArray?) as? [Any]
	}


	//========== setActiveModel: ===================================================
	//
	// Purpose:		Sets newModel to be the currently-active model in the file.
	//				The active model is the only one drawn.
	//
	//==============================================================================
	@objc(setActiveModel:)
	func setActiveModel(_ newModel: LDrawMPDModel!) {
		let notificationCenter = NotificationCenter.default

		if let newModel, subdirectives()?.contains(newModel) == true {
			//Don't bother doing anything if we aren't really changing models.
			if newModel !== activeModelRef {

				//Update the active model and note that something happened.
				activeModelRef = newModel
				if postsNotifications {
					notificationCenter.post(name: NSNotification.Name(LDrawFileActiveModelDidChangeNotification),
											object: self)
				}
			}
		}
		else if newModel == nil {
			//why are we retaining?!
			activeModelRef = nil
		}
		else {
			NSLog("Attempted to set the active model to one which is not in the file!")
		}

	}//end setActiveModel:


	//========== setDraggingDirectives: ============================================
	//
	// Purpose:		Sets the parts which are being manipulated in the model via
	//			    drag-and-drop.
	//
	// Notes:		This is a convenience method for LDrawGLView, which might not
	//			    care to wonder whether it's displaying a model or a file. In
	//			    either event, we just want to drag-and-drop, and that's defined
	//			    in the model.
	//
	//==============================================================================
	@objc(setDraggingDirectives:)
	func setDraggingDirectives(_ directives: [Any]!) {
		activeModel()?.setDraggingDirectives(directives)

	}//end setDraggingDirectives:


	//========== setEnclosingDirective: ============================================
	//
	// Purpose:		In other containers, this method would set the object which
	//				encloses this one. LDrawFiles, however, are intended to be at
	//				the root of the LDraw container hierarchy, and thus calling this
	//				method should have no effect.
	//
	//==============================================================================
	@objc(setEnclosingDirective:)
	override func setEnclosing(_ newParent: LDrawContainer!) {
		// Do Nothing.

	}//end setEnclosingDirective:


	//========== setPath: ==========================================================
	//
	// Purpose:		Sets the filesystem path at which this file was resides. Only
	//				files that are read by the user will have their paths set; parts
	//				from the library disregard this information.
	//
	//==============================================================================
	@objc(setPath:)
	func setPath(_ newPath: String!) {
		filePath = newPath

	}//end setPath:


	//========== removeDirective: ==================================================
	//
	// Purpose:		Removes the directive; if it was the active model, the first
	//				remaining model becomes active.
	//
	//==============================================================================
	@objc(removeDirective:)
	override func remove(_ doomedDirective: LDrawDirective!) {
		var removedActiveModel = false

		if doomedDirective === activeModelRef {
			removedActiveModel = true
		}

		super.remove(doomedDirective)

		// P6a: ObjC raised inside (see updateModelLookupTable), before the active
		// model was reset; see KNOWN-BUGS BUG-P6A-files-6
		if lookupRebuildAbandoned {
			return
		}

		if removedActiveModel == true {
			if let models = subdirectives(), models.count > 0 {
				setActiveModel(models.object(at: 0) as? LDrawMPDModel)
			}
			else {
				setActiveModel(nil) //this is probably not a good thing.
			}
		}

	}//end removeDirective:


	// MARK: - Actions

	//========== addSubmodel: ======================================================
	//
	// Purpose:		Adds a new submodel to the file. This method only accepts MPD
	//				models, because adding additional submodels is meaningless
	//				outside of MPD models.
	//
	//==============================================================================
	@objc(addSubmodel:)
	func addSubmodel(_ newSubmodel: LDrawMPDModel!) {
		insert(newSubmodel, at: subdirectives()?.count ?? 0)

	}//end addSubmodel:


	//========== insertDirective:atIndex: ==========================================
	//
	// Purpose:		Adds directive into the collection at position index.
	//
	//==============================================================================
	@objc(insertDirective:atIndex:)
	override func insert(_ directive: LDrawDirective!, at index: Int) {
		// P6a: ObjC raised here (-[NSMutableArray insertObject:atIndex:] in
		// LDrawContainer, for a nil directive or an index past the end, before
		// anything changed); see KNOWN-BUGS BUG-P6A-files-8
		guard directive != nil, index >= 0, index <= (subdirectives()?.count ?? 0) else {
			return
		}

		super.insert(directive, at: index)
		// P6a: ObjC raised inside (see updateModelLookupTable): the model stays
		// inserted, nothing is posted; see KNOWN-BUGS BUG-P6A-files-6
		guard updateModelLookupTable() else {
			return
		}

		// Post a notification on ourself that a model was added - missing parts need
		// to know this to re-check whether they match this model.
		NotificationCenter.default.post(name: NSNotification.Name(LDrawMPDSubModelAdded), object: self)

	}//end insertDirective:atIndex:


	//========== removeDirectiveAtIndex: ===========================================
	//
	// Purpose:		Removes the LDraw directive stored at index in this collection.
	//
	//==============================================================================
	@objc(removeDirectiveAtIndex:)
	override func removeDirective(at index: Int) {
		// P6a: ObjC raised here (-objectAtIndex: in LDrawContainer for an index
		// past the end, before anything changed); see KNOWN-BUGS BUG-P6A-files-8
		guard index >= 0, index < (subdirectives()?.count ?? 0) else {
			return
		}

		super.removeDirective(at: index)
		// P6a: a raise inside left the table stale; see KNOWN-BUGS BUG-P6A-files-6
		updateModelLookupTable()

	}//end removeDirectiveAtIndex:


	// MARK: - Utilities

	//========== acceptsDroppedDirective: ==========================================
	//
	// Purpose:		Returns YES if this container will accept a directive dropped on
	//              it.  Explicitly excludes LDrawLSynthDirectives such as INSIDE/OUTSIDE
	//
	//==============================================================================
	@objc(acceptsDroppedDirective:)
	override func acceptsDroppedDirective(_ directive: LDrawDirective!) -> Bool {
		// explicitly disregard LSynth directives
		if directive is LDrawLSynthDirective {
			return false
		}
		return true
	}


	//========== boundingBox3 ======================================================
	//
	// Purpose:		Returns the minimum and maximum points of the box which
	//				perfectly contains the part of this file being displayed.
	//				(No active model: messaging nil gave a zeroed box.)
	//
	//==============================================================================
	@objc(boundingBox3)
	override func boundingBox3() -> Box3 {
		_ = revalCache(.CacheFlagBounds)
		let ret = activeModel()?.boundingBox3() ?? Box3()
		return ret

	}//end boundingBox3


	//========== projectedBoundingBoxWithModelView:projection:view: ================
	//
	// Purpose:		Returns the 2D projection (you should ignore the z) of the
	//				object's bounds.
	//
	//==============================================================================
	@objc(projectedBoundingBoxWithModelView:projection:view:)
	override func projectedBoundingBox(withModelView modelView: Matrix4, projection: Matrix4, view viewport: Box2) -> Box3 {
		activeModel()?.projectedBoundingBox(withModelView: modelView, projection: projection, view: viewport) ?? Box3()

	}//end projectedBoundingBoxWithModelView:projection:view:


	//========== optimizeStructure =================================================
	//
	// Purpose:		Arranges the directives in such a way that the file will be
	//				drawn faster. This method should *never* be called on files
	//				which the user has created himself, since it reorganizes the
	//				file contents. It is intended only for parts read from the part
	//				library.
	//
	//==============================================================================
	@objc(optimizeStructure)
	func optimizeStructure() {
		let modelsInFile	= subdirectives()
		let numberModels	= modelsInFile?.count ?? 0

		//Write out each MPD submodel, one after another.
		for counter in 0 ..< numberModels {
			// P6a: ObjC raised here (-optimizeStructure sent to a non-model child);
			// see KNOWN-BUGS BUG-P6A-files-7
			guard let currentModel = modelsInFile?.object(at: counter) as? LDrawModel else {
				return
			}
			currentModel.optimizeStructure()
		}

	}//end optimizeStructure


	//========== renameModel:toName: ===============================================
	//
	// Purpose:		Sets the name of the given member submodel to the new name, and
	//				updates all internal references to the submodel to use the new
	//				name as well.
	//
	//==============================================================================
	@objc(renameModel:toName:)
	func renameModel(_ submodel: LDrawMPDModel!, toName newName: String!) {
		let submodels			= subdirectives()
		let containsSubmodel	= (submodels?.indexOfObjectIdentical(to: submodel as Any) ?? NSNotFound) != NSNotFound
		let oldName				= submodel?.modelName() as NSString?

		// [oldName isEqualToString:newName]: NO when either is nil.
		var sameName = false
		if let oldName, let newName {
			sameName = oldName.isEqual(to: newName)
		}

		if containsSubmodel == true && sameName == false {
			// Update the model name itself
			submodel.setModelName(newName)

			// Update all references to the old name
			let partReport	= PartReport(for: self)
			let allParts	= partReport?.allParts() as NSArray?

			for counter in 0 ..< (allParts?.count ?? 0) {
				let currentPart = allParts?.object(at: counter) as? LDrawPart

				// If the part points to the old name, change it to the new one.
				// Since the user can enter these values and Bricksmith is
				// case-insensitive, make sure to ignore case.
				// ([nil caseInsensitiveCompare:] answered NSOrderedSame; comparing
				// with a nil name answered NSOrderedDescending.)
				var matches = true
				if let referenceName = currentPart?.referenceName() as NSString? {
					if let oldName {
						matches = referenceName.caseInsensitiveCompare(oldName as String) == .orderedSame
					}
					else {
						matches = false
					}
				}
				if matches {
					currentPart?.setDisplayName(newName)
				}
			}
		}

	}//end renameModel:toName:


	//========== updateModelLookupTable ============================================
	//
	// Purpose:		Rebuilds the optimized lookup table for models.  This is now
	//				an internal method, run when we add or remove a directive,
	//				after coder init, and any time one of our children renames
	//				itself.
	//
	// Notes:		Keys are NSString -lowercaseString; the table is built with
	//				-initWithObjects:forKeys:, so of two equal names the earlier
	//				model wins, as before.
	//
	//				Returns false where the ObjC raised; the table is then left as
	//				it was and the caller abandons the rest of its work.
	//
	//==============================================================================
	@discardableResult
	private func updateModelLookupTable() -> Bool {
		let submodels	= subdirectives() ?? NSMutableArray()
		let names		= NSMutableArray(capacity: submodels.count)

		lookupRebuildAbandoned = false
		for model in submodels {
			// always use lowercase for comparison
			// P6a: ObjC raised here (-addObject:nil for a nil model name, or
			// -modelName sent to a non-MPD child); see KNOWN-BUGS BUG-P6A-files-6
			guard let name = (model as? LDrawMPDModel)?.modelName() as NSString? else {
				lookupRebuildAbandoned = true
				return false
			}
			names.add(name.lowercased)
		}

		nameModelDict = NSDictionary(objects: submodels as! [Any], forKeys: names as! [NSCopying])
		return true
	}


	// MARK: - Observation

	//========== receiveMessage:who: ===============================================
	//
	// Purpose:		LDrawFile overrides the message handler to get access to name
	//				change announcements from its contained MDP models.  In this
	//				way it can rebuild the lookup table.
	//
	//==============================================================================
	@objc(receiveMessage:who:)
	override func receiveMessage(_ msg: MessageT, who observable: (any LDrawObservable)!) {
		if msg == .nameChanged {
			// P6a: ObjC raised inside (see updateModelLookupTable), before super;
			// see KNOWN-BUGS BUG-P6A-files-6
			guard updateModelLookupTable() else {
				return
			}
		}

		super.receiveMessage(msg, who: observable)
	}
}
