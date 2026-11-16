//==============================================================================
//
// File:		LDrawMPDModel.swift
//
// Purpose:		LDraw MPD (Multi-Part Document) models are the basic components
//				of an LDrawFile. An MPD model is a discreet collection of parts
//				(such as a car or a minifigure); each file can be composed of
//				multiple models.
//
//				An MPD model is an extension of a basic LDraw model, with the
//				addition of a name which can be used to refer to the entire
//				model as a single part. (This is used, for instance, to insert
//				the entire minifigure driver into his car.)
//
//				While the LDraw file format accommodates documents with only one
//				(non-MPD) model, Bricksmith does not make such a distinction
//				until the file is actually written to disk. For the sake of
//				simplicity, all logical models within an LDrawFile *must* be
//				MPD models.
//
//  Created by Allen Smith on 2/19/05.
//  Copyright 2005. All rights reserved.
//
//  Ported to Swift in P6a. The superclass (LDrawModel) is still ObjC.
//
//  Swift API note: Swift imported -writeModel as LDrawMPDModel.write(), which
//  can't coexist with the override of -write; it is writeModel() here.
//==============================================================================

import Foundation

@objc(LDrawMPDModel)
final class LDrawMPDModel: LDrawModel {

	// MPD submodels have a name to identify them.
	// it gets written out as 0 FILE modelName at the beginning.
	// (Defaults to nil: -[LDrawDirective initWithLines:...] re-enters init()
	// on the half-built object, so stored defaults stay trivial.)
	private var storedModelName: String?


	// MARK: - Initialization

	//---------- model ---------------------------------------------------[static]--
	//
	// Purpose:		Creates a new model ready to be edited.
	//
	//------------------------------------------------------------------------------
	@objc(model)
	override class func model() -> Any! {
		let newModel = super.model() as? LDrawMPDModel

		// Set the spec-compliant model name with extension
		let name = NSLocalizedString("UntitledModel", comment: "")
		newModel?.setModelDisplayName(name)

		return newModel

	}//end model


	//========== init ==============================================================
	//
	// Purpose:		Creates a blank submodel.
	//
	//==============================================================================
	@objc(init)
	override init() {
		super.init()

		storedModelName = ""

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
	// Purpose:		Creates a new model file based on the lines from a file.
	//				These lines of strings should only describe one model, not
	//				multiple ones.
	//
	//				The first line does not need to be an MPD file delimiter. If
	//				you pass in a non-mpd submodel, this method simply wraps it in
	//				an MPD submodel object.
	//
	//==============================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override init!(lines: [NSObject]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		let lineArray						= lines as NSArray?
		var mpdSubmodelName: NSString?		= ""
		var isMPDModel						= false
		var hasSubmodelEnd					= false
		var nonMPDRange						= range

		// (Messaging a nil array answered nil, which is not an MPD line.)
		if let lineArray {
			// P6a: ObjC raised here (-objectAtIndex: past the end of the lines, before
			// any parsing); see KNOWN-BUGS BUG-038
			guard range.location >= 0, range.location < lineArray.count else {
				return nil
			}

			// The first line should be 0 FILE modelName
			let mpdFileCommand = lineArray.object(at: range.location) as? String
			isMPDModel = LDrawMPDModel.lineIsMPDModelStart(mpdFileCommand, modelName: &mpdSubmodelName)

			// Strip out the MPD commands for model parsing, and read in the model name.
			if isMPDModel == true {
				// Strip out the first line and the NOFILE command, if there is one.
				// P6a: ObjC raised here (-objectAtIndex: past the end of the lines; an
				// empty range wrapped and raised later, in the parse); see KNOWN-BUGS
				// BUG-038
				guard range.length >= 1, NSMaxRange(range) <= lineArray.count else {
					return nil
				}
				let lastLine = lineArray.object(at: NSMaxRange(range) - 1) as? String

				hasSubmodelEnd = LDrawMPDModel.lineIsMPDModelEnd(lastLine)
				if hasSubmodelEnd {
					// strip out 0 FILE and 0 NOFILE
					nonMPDRange = NSMakeRange(range.location + 1, range.length - 2)
				}
				else {
					// strip out 0 FILE only
					nonMPDRange = NSMakeRange(range.location + 1, range.length - 1)
				}
			}
			else {
				nonMPDRange = range
			}
		}

		// Create a basic model.
		// (A nil from super, e.g. a step that could not be parsed, fails this init.)
		super.init(lines: lines, in: nonMPDRange, parentGroup: parentGroup) //parses model into header and steps.

		// If it wasn't MPD, we still need a model name. We can get that via the
		// parsed model.
		if isMPDModel == false {
			mpdSubmodelName = modelDescription() as NSString?
		}

		// And now set the MPD-specific attributes.
		setModelName(mpdSubmodelName as String?)

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

		storedModelName = decoder.decodeObject(forKey: "modelName") as? String

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

		encoder.encode(storedModelName, forKey: "modelName")

	}//end encodeWithCoder:


	//========== copyWithZone: =====================================================
	//
	// Purpose:		Returns a duplicate of this file.
	//
	//==============================================================================
	@objc(copyWithZone:)
	override func copy(with zone: NSZone? = nil) -> Any {
		let copied = super.copy(with: zone)

		(copied as? LDrawMPDModel)?.setModelName(modelName())

		return copied

	}//end copyWithZone:


	//---------- rangeOfDirectiveBeginningAtIndex:inLines:maxIndex: ------[static]--
	//
	// Purpose:		Returns the range from the beginning to the end of the model.
	//
	// Notes:		Index arithmetic is NSUInteger as in ObjC (wrapping operators).
	//
	//------------------------------------------------------------------------------
	@objc(rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:)
	override class func rangeOfDirectiveBeginning(at index: UInt, inLines lines: [NSObject]!, maxIndex: UInt) -> NSRange {
		let lineArray					= lines as NSArray?
		var isMPDModel					= false
		let testLocation: UInt			= index
		let testLength: UInt			= maxIndex &- index &+ 1
		let testMax: UInt				= testLocation &+ testLength	// NSMaxRange(testRange)
		let testRange					= NSMakeRange(Int(bitPattern: testLocation), Int(bitPattern: testLength))
		var modelRange					= testRange
		var counter: UInt				= 0
		var modelEndIndex: UInt			= 0

		if testLength > 1, let lineArray {
			// P6a: ObjC raised here (-objectAtIndex: past the end of the lines while
			// looking for the model's end); see KNOWN-BUGS BUG-039
			guard testLocation < testMax, testMax <= UInt(lineArray.count) else {
				return modelRange
			}

			// See if we have to look for MPD syntax.
			let firstLine = lineArray.object(at: Int(bitPattern: testLocation)) as? String
			isMPDModel = LDrawMPDModel.lineIsMPDModelStart(firstLine, modelName: nil)

			// Find the end of the MPD model. MPD models can end with 0 NOFILE, or
			// they can just stop where the next model starts.
			if isMPDModel == true {
				// Assume the model extends for the rest of the file unless proven
				// otherwise.
				modelEndIndex = testMax &- 1

				counter = testLocation &+ 1
				while counter < testMax {
					let currentLine = lineArray.object(at: Int(bitPattern: counter)) as? String

					if LDrawMPDModel.lineIsMPDModelEnd(currentLine) {
						modelEndIndex = counter
						break
					}
					else if LDrawMPDModel.lineIsMPDModelStart(currentLine, modelName: nil) {
						modelEndIndex = counter &- 1
						break
					}
					counter &+= 1
				}
				modelRange = NSMakeRange(Int(bitPattern: testLocation),
										 Int(bitPattern: modelEndIndex &- testLocation &+ 1))
			}
			else {
				// Non-MPD models just go to the end of the file.
				modelRange = testRange
			}
		}
		// (A nil array: every line was nil, so not MPD; the range stays testRange.)

		return modelRange

	}//end rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:


	// MARK: - Directives

	//========== write =============================================================
	//
	// Purpose:		Writes out the MPD submodel, wrapped in the MPD file commands.
	//
	//==============================================================================
	@objc(write)
	override func write() -> String! {
		let CRLF: String = NSString.crlf() //we need a DOS line-end marker, because
										   //LDraw is predominantly DOS-based.

		//Write it out as:
		//		0 FILE model_name
		//			....
		//		   model text
		//			....
		//		0 NOFILE
		// ("%@" printed nil as "(null)"; keep that.)
		return String(format: "0 %@ %@%@%@%@0 %@",
					  LDRAW_MPD_SUBMODEL_START,
					  modelName() ?? "(null)",
					  CRLF,
					  super.write() ?? "(null)",
					  CRLF,
					  LDRAW_MPD_SUBMODEL_END)

	}//end write


	//========== writeModel =============================================================
	//
	// Purpose:		Writes out the submodel, without the MPD file commands.
	//
	//==============================================================================
	@objc(writeModel)
	func writeModel() -> String! {
		super.write()

	}//end writeModel


	// MARK: - Display

	//========== browsingDescription ===============================================
	//
	// Purpose:		Returns a representation of the directive as a short string
	//				which can be presented to the user.
	//
	//==============================================================================
	@objc(browsingDescription)
	override func browsingDescription() -> String! {
		modelDisplayName()

	}//end browsingDescription


	//========== inspectorClassName ================================================
	//
	// Purpose:		Returns the name of the class used to inspect this one.
	//
	//==============================================================================
	@objc(inspectorClassName)
	override func inspectorClassName() -> String! {
		"InspectionMPDModel"

	}//end inspectorClassName


	@objc(setEnclosingDirective:)
	override func setEnclosing(_ newParent: LDrawContainer!) {
		super.setEnclosing(newParent)
		sendMessage(toObservers: .scopeChanged)
	}


	// MARK: - Accessors

	//========== modelDisplayName ==================================================
	//
	// Purpose:		Chop off that hideous un-Maclike .ldr extension that the LDraw
	//				File Specification forces us to add.
	//
	//==============================================================================
	@objc(modelDisplayName)
	func modelDisplayName() -> String! {
		(modelName() as NSString?)?.deletingPathExtension

	}//end modelDisplayName


	//========== modelName =========================================================
	//
	// Purpose:		Retuns the name for this MPD file. The MPD name functions as
	//				the part name to describe the entire submodel.
	//
	//==============================================================================
	@objc(modelName)
	func modelName() -> String! {
		storedModelName

	}//end modelName


	//========== setModelName: =====================================================
	//
	// Purpose:		Updates the name for this MPD file. The MPD name functions as
	//				the part name to describe the entire submodel.
	//
	//==============================================================================
	@objc(setModelName:)
	func setModelName(_ newModelName: String!) {
		storedModelName = newModelName

		sendMessage(toObservers: .nameChanged)

	}//end setModelName:


	//========== setModelDisplayName: ==============================================
	//
	// Purpose:		Unfortunately, we can't accept any old input for model names.
	//				This method accepts a user-entered string with arbitrary
	//				characters, and sets the model name to the closest
	//				representation thereof which is still LDraw-compliant.
	//
	//				After calling this method, -browsingDescription will return a
	//				value as close to newDisplayName as possible.
	//
	//==============================================================================
	@objc(setModelDisplayName:)
	func setModelDisplayName(_ newDisplayName: String!) {
		let acceptableName = LDrawMPDModel.ldrawCompliantName(forName: newDisplayName)

		setModelName(acceptableName)

	}//end setModelDisplayName:


	// MARK: - Utilities

	//---------- ldrawCompliantNameForName: ------------------------------[static]--
	//
	// Purpose:		Unfortunately, we can't accept any old input for model names.
	//				This method accepts a user-entered string with arbitrary
	//				characters, and returns the model name or the closest
	//				representation thereof which is still LDraw-compliant.
	//
	//------------------------------------------------------------------------------
	@objc(ldrawCompliantNameForName:)
	class func ldrawCompliantName(forName newDisplayName: String!) -> String! {
		// Messaging nil answered nil all the way through.
		guard let displayName = newDisplayName as NSString? else {
			return nil
		}

		// Since LDraw is space-delimited, we can't have whitespace at the beginning
		// of the name. We'll chop of ending whitespace for good measure.
		var acceptableName = displayName.trimmingCharacters(in: .whitespacesAndNewlines) as NSString

		// The LDraw spec demands that the model name end with a valid LDraw
		// extension. Yuck!
		if LDrawUtilities.isLDrawFilenameValid(acceptableName as String) == false {
			acceptableName = acceptableName.appending(".ldr") as NSString
		}

		return acceptableName as String

	}//end ldrawCompliantNameForName:


	//========== lineIsMPDModelStart:modelName: ====================================
	//
	// Purpose:		Returns if the line is a 0 FILE submodelName line.
	//
	//				If it is, optionally returns the submodelName
	//
	// Note:		Any line can have leading whitespace, which is why this is not
	//				as simple as [line hasPrefix:@"0 FILE"]
	//
	//				Fields compare with NSString's isEqual(to:) (isEqualToString:),
	//				not Swift ==.
	//
	//==============================================================================
	@objc(lineIsMPDModelStart:modelName:)
	class func lineIsMPDModelStart(_ line: String!, modelName modelNamePtr: AutoreleasingUnsafeMutablePointer<NSString?>!) -> Bool {
		var workingLine: NSString?	= line as NSString?
		var isMPDModel				= false

		var parsedField = LDrawUtilities.readNextField(line, remainder: &workingLine) as NSString?
		if parsedField?.isEqual(to: "0") == true {
			let partial = workingLine as String?
			parsedField = LDrawUtilities.readNextField(partial, remainder: &workingLine) as NSString?

			if parsedField?.isEqual(to: LDRAW_MPD_SUBMODEL_START) == true {
				isMPDModel = true
			}
		}

		//Strip out the MPD commands for model parsing, and read in the model name.
		if isMPDModel == true, let modelNamePtr {
			// Extract MPD-specific data: the submodel name.
			// Leading and trailing whitespace is ignored, in keeping with the rules
			// for parsing file references (type 1 lines)
			modelNamePtr.pointee = workingLine?.trimmingCharacters(in: .whitespaces) as NSString?
		}

		return isMPDModel
	}


	//========== lineIsMPDModelEnd: ================================================
	//
	// Purpose:		Returns if the line is a 0 NOFILE line.
	//
	//==============================================================================
	@objc(lineIsMPDModelEnd:)
	class func lineIsMPDModelEnd(_ line: String!) -> Bool {
		var workingLine: NSString?	= line as NSString?
		var isMPDModelEnd			= false

		var parsedField = LDrawUtilities.readNextField(line, remainder: &workingLine) as NSString?
		if parsedField?.isEqual(to: "0") == true {
			let partial = workingLine as String?
			parsedField = LDrawUtilities.readNextField(partial, remainder: &workingLine) as NSString?

			if parsedField?.isEqual(to: LDRAW_MPD_SUBMODEL_END) == true {
				isMPDModelEnd = true
			}
		}

		return isMPDModelEnd
	}


	//========== registerUndoActions ===============================================
	//
	// Purpose:		Registers the undo actions that are unique to this subclass,
	//				not to any superclass.
	//
	// Notes:		prepareWithInvocationTarget: returns the undo manager itself,
	//				which records the next message it can't handle; perform(_:with:)
	//				sends that message through ordinary dispatch, as the ObjC did.
	//
	//==============================================================================
	@objc(registerUndoActions:)
	override func registerUndoActions(_ undoManager: UndoManager!) {
		let enclosingFile	= self.enclosingFile()
		let oldName			= modelName()

		super.registerUndoActions(undoManager)

		// (Messaging a nil undo manager did nothing.)
		guard let undoManager else {
			return
		}

		// Changing the name of the model in an undo-aware way is pretty bothersome,
		// because we have to track down any references to the model and change
		// their names too. That operation is the responsibility of the LDrawFile,
		// not us.
		if let enclosingFile {
			let proxy = undoManager.prepare(withInvocationTarget: enclosingFile) as! NSObject
			_ = proxy.perform(#selector(LDrawFile.renameModel(_:toName:)), with: self, with: oldName)
		}
		else {
			let proxy = undoManager.prepare(withInvocationTarget: self) as! NSObject
			_ = proxy.perform(#selector(LDrawMPDModel.setModelName(_:)), with: oldName)
		}

	}//end registerUndoActions:
}
