//==============================================================================
//
// File:		LDrawMetaCommand.swift
//
// Purpose:		Meta-command holder.
//				Could do just about anything, but only in subclasses!
//
//				Line format:
//				0 command...
//
//				where
//
//				* command is a string; it could mean anything. We have specific
//				subclasses to deal with recognized meta-commands. This class is
//				the fallback class for unrecognized commands.
//
//  Created by Allen Smith on 2/21/05.
//  Copyright (c) 2005. All rights reserved.
//
//  Ported to Swift in P6b. Not final: LDrawComment, LDrawColor and
//  LDrawLSynthDirective (Swift, P6a) subclass it.
//==============================================================================

import Foundation

//---------- LogFatallyInvalidMetaCommand ---------------------------[static]--
//
// Purpose:		Logs a meta-command line that could not be parsed. (These are
//				the messages the parser logged when it used exceptions.)
//
//------------------------------------------------------------------------------
private func LogFatallyInvalidMetaCommand(_ line: Any?) {
	// (%@ printed the line's -description, or "(null)".)
	NSLog("the meta-command %@ was fatally invalid", (line as AnyObject?)?.description ?? "(null)")
	NSLog(" raised exception %@", "BricksmithParseException")
}


@objc(LDrawMetaCommand)
class LDrawMetaCommand: LDrawDirective {

	/// The command text (everything after "0 "). nil only if set so.
	private var commandString: String? = nil


	// MARK: - Initialization

	//========== init ==============================================================
	//
	// Purpose:		Initialize an empty command.
	//
	//==============================================================================
	@objc(init)
	override init() {
		super.init()
		setStringValue("")

	}//end init


	//========== initWithLines:inRange: ============================================
	//
	// Purpose:		As -[LDrawDirective initWithLines:inRange:]: no parent group.
	//				(Overridden so the inherited ObjC entry point isn't a trap, and
	//				so the Swift subclasses can keep overriding it.)
	//
	//==============================================================================
	@objc(initWithLines:inRange:)
	override init!(lines: [Any]!, in range: NSRange) {
		super.init(lines: lines, in: range)

	}//end initWithLines:inRange:


	//========== initWithLines:inRange:parentGroup: ================================
	//
	// Purpose:		LDrawDirective's version: -init, then nil when there are no
	//				lines. Meta commands are parsed through
	//				+directiveWithLines:inRange:parentGroup:; this only keeps a
	//				direct call working.
	//
	//==============================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override init!(lines: [Any]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		super.init(lines: lines, in: range, parentGroup: parentGroup)

	}//end initWithLines:inRange:parentGroup:


	//---------- directiveWithLines:inRange:parentGroup: ----------------[static]--
	//
	// Purpose:		Returns the LDraw directive based on lineFromFile, a single line
	//				of LDraw code from a file.
	//
	//				directive should have the format:
	//
	//				0 command...
	//
	//				This method determines and returns a subclass instance for known
	//				meta-commands (LDrawComment, LDrawColor). Anything else becomes
	//				a generic instance of the receiving class that records the text.
	//
	// Notes:		This replaces -initWithLines:inRange:parentGroup:, which used to
	//				return a substitute object.
	//
	//------------------------------------------------------------------------------
	@objc(directiveWithLines:inRange:parentGroup:)
	override class func directive(lines: [Any]!, in range: NSRange, parentGroup: dispatch_group_t?) -> LDrawDirective? {
		let lineArray						= lines as NSArray?
		var directive: LDrawMetaCommand?	= nil
		var parsedField: NSString?			= nil
		var lineCode: Int32					= 0
		var gotLineCode						= false
		var metaLineStart					= 0

		// P6b: ObjC raised here (-objectAtIndex: past the end of the lines); see
		// KNOWN-BUGS BUG-P6B-meta-1. (A nil array answered a nil line, which
		// scans as an empty string, as below.)
		if let lineArray, range.location < 0 || range.location >= lineArray.count {
			return nil
		}
		let firstLine	= lineArray?.object(at: range.location) as? String
		let scanner		= Scanner(string: firstLine ?? "")
		let utf16		= scanner.utf16

		scanner.charactersToBeSkipped = nil

		// skip leading whitespace
		_ = utf16.scanCharacters(from: .whitespaces, into: nil)

		//Read in the line code and advance past it.
		gotLineCode = utf16.scanInt(&lineCode)

		if gotLineCode == true && lineCode == 0 {
			// The first word of a meta-command should indicate the command
			// itself, and thus the syntax of the rest of the line. However, the
			// first word might not be a recognized command. It might not even
			// be anything. "0\n" is perfectly valid LDraw.
			_ = utf16.scanCharacters(from: .whitespaces, into: nil)
			metaLineStart = utf16.location()

			_ = utf16.scanUpToCharacters(from: .whitespaces, into: &parsedField)

			// isEqualToString: compares UTF-16 units (NSString's isEqual(to:)); nil matches nothing.
			// Comment?
			if		parsedField?.isEqual(to: LDRAW_COMMENT_SLASH) == true
				||	parsedField?.isEqual(to: LDRAW_COMMENT_WRITE) == true
				||	parsedField?.isEqual(to: LDRAW_COMMENT_PRINT) == true {
				directive = LDrawComment()
			}
			// Color Definition?
			else if parsedField?.isEqual(to: LDRAW_COLOR_DEFINITION) == true {
				directive = LDrawColor()
			}

			// If we recognized the metacommand, use the subclass to finish
			// parsing.
			if let recognized = directive {
				// On a syntax error the partly-parsed directive is still returned
				// (KNOWN-BUGS S1); only the log reports the failure.
				if recognized.finishParsing(scanner) == false {
					LogFatallyInvalidMetaCommand(firstLine)
				}
			}
			else {
				// Didn't specifically recognize this metacommand. Create a
				// non-functional generic command to record its existence.
				let generic = (self as NSObject.Type).init() as! LDrawMetaCommand
				let command = (scanner.string as NSString).substring(from: metaLineStart)

				generic.setStringValue(command)
				directive = generic
			}
		}
		else if gotLineCode == false {
			// This is presumably an empty line, and the following will
			// incorrectly add a 0 linetype to it.
			let generic = (self as NSObject.Type).init() as! LDrawMetaCommand
			let command = scanner.string

			generic.setStringValue(command)
			directive = generic
		}
		else {
			// nonzero linetype! No directive is returned (KNOWN-BUGS S6).
			LogFatallyInvalidMetaCommand(firstLine)
		}

		return directive

	}//end directiveWithLines:inRange:parentGroup:


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

		commandString = decoder.decodeObject(forKey: "commandString") as? String

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

		encoder.encode(commandString as NSString?, forKey: "commandString")

	}//end encodeWithCoder:


	//========== copyWithZone: =====================================================
	//
	// Purpose:		Returns a duplicate of this file.
	//
	//==============================================================================
	@objc(copyWithZone:)
	override func copy(with zone: NSZone? = nil) -> Any {
		let copied = super.copy(with: zone)

		(copied as? LDrawMetaCommand)?.setStringValue(stringValue())

		return copied

	}//end copyWithZone:


	//========== finishParsing: ====================================================
	//
	// Purpose:		Subclasses override this method to finish parsing their specific
	//				syntax once +[LDrawMetaCommand directiveWithLines:inRange:parentGroup:]
	//				has determined which subclass to instantiate.
	//
	// Returns:		YES on success; NO on a syntax error.
	//
	//==============================================================================
	@objc(finishParsing:)
	func finishParsing(_ scanner: Scanner!) -> Bool {
		// LDrawMetaCommand itself doesn't have any special syntax, so we shouldn't
		// be getting any in this method.
		return false

	}//end finishParsing:


	// MARK: - Directives

	//========== draw:viewScale:parentColor: =======================================
	//
	// Purpose:		Draws the part.
	//
	//==============================================================================
	@objc(draw:viewScale:parentColor:)
	override func draw(_ optionsMask: UInt, viewScale scaleFactor: Float, parentColor: LDrawColor!) {
		// Nothing to do here.

	}//end draw:viewScale:parentColor:


	//========== write =============================================================
	//
	// Purpose:		Returns a line that can be written out to a file.
	//				Line format:
	//				0 command...
	//
	//==============================================================================
	@objc(write)
	override func write() -> String! {
		// "%@" printed a nil string as "(null)"; keep that.
		"0 \(stringValue() ?? "(null)")"

	}//end write


	// MARK: - Display

	//========== browsingDescription ===============================================
	//
	// Purpose:		Returns a representation of the directive as a short string
	//				which can be presented to the user.
	//
	//==============================================================================
	@objc(browsingDescription)
	override func browsingDescription() -> String! {
//		return NSLocalizedString(@"Unknown Metacommand", nil);
		commandString

	}//end browsingDescription


	//========== iconName ==========================================================
	//
	// Purpose:		Returns the name of image file used to display this kind of
	//				object, or nil if there is no icon.
	//
	//==============================================================================
	@objc(iconName)
	override func iconName() -> String! {
		"Unknown"

	}//end iconName


	//========== inspectorClassName ================================================
	//
	// Purpose:		Returns the name of the class used to inspect this one.
	//
	//==============================================================================
	@objc(inspectorClassName)
	override func inspectorClassName() -> String! {
		"InspectionUnknownCommand"

	}//end inspectorClassName


	// MARK: - Accessors

	//========== setStringValue: ===================================================
	//
	// Purpose:		updates the basic command string.
	//
	//==============================================================================
	@objc(setStringValue:)
	func setStringValue(_ newString: String!) {
		commandString = newString

	}//end setStringValue:


	//========== stringValue =======================================================
	//
	// Purpose:
	//
	//==============================================================================
	@objc(stringValue)
	func stringValue() -> String! {
		commandString

	}//end stringValue


	// MARK: - Utilities

	//========== registerUndoActions ===============================================
	//
	// Purpose:		Registers the undo actions that are unique to this subclass,
	//				not to any superclass.
	//
	//==============================================================================
	@objc(registerUndoActions:)
	override func registerUndoActions(_ undoManager: UndoManager!) {
		super.registerUndoActions(undoManager)

		// The proxy forwards the message as an invocation: send it dynamically (L103).
		(undoManager.prepare(withInvocationTarget: self) as AnyObject).setStringValue(stringValue())

		//[undoManager setActionName:NSLocalizedString(@"UndoAttributesLine", nil)];
		// (unused for this class; a plain "Undo" will probably be less confusing.)

	}//end registerUndoActions:
}
