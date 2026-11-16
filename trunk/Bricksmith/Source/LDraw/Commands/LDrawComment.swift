//==============================================================================
//
// File:		LDrawComment.swift
//
// Purpose:		A comment. It serves only as explanatory text in the model.
//
//  Created by Allen Smith on 3/12/05.
//  Copyright (c) 2005. All rights reserved.
//
//  Ported to Swift in P6a. The superclass (LDrawMetaCommand) is still ObjC.
//==============================================================================

import Foundation

@objc(LDrawComment)
final class LDrawComment: LDrawMetaCommand {

	// MARK: - Initialization

	//========== finishParsing: ===================================================
	//
	// Purpose:		lineWithDirectiveText: is a dispatching method; this is where
	//				the comment text (everything after the "//") is captured.
	//
	//==============================================================================
	@objc(finishParsing:)
	override func finishParsing(_ scanner: Scanner!) -> Bool {
		_ = scanner.scanCharacters(from: .whitespaces)
		setStringValue(String(scanner.string[scanner.currentIndex...]))
		return true
	}

	// MARK: - Directives

	//========== write =============================================================
	//
	// Purpose:		Returns a line that can be written out to a file.
	//				Line format:
	//				0 // comment-text
	//
	//==============================================================================
	@objc(write)
	override func write() -> String! {
		// "%@" printed a nil string as "(null)"; keep that.
		"0 \(LDRAW_COMMENT_SLASH) \(stringValue() ?? "(null)")"
	}

	// MARK: - Display

	@objc(browsingDescription)
	override func browsingDescription() -> String! {
		stringValue()
	}

	@objc(iconName)
	override func iconName() -> String! {
		"Comment"
	}

	@objc(inspectorClassName)
	override func inspectorClassName() -> String! {
		"InspectionComment"
	}
}
