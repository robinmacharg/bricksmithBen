//==============================================================================
//
// File:		LDrawLSynthDirective.swift
//
// Purpose:		Represent LSynth meta-directives such as
//              SHOW/HIDE/INSIDE/OUTSIDE/CROSS.
//
// Created by: Robin Macharg 30/09/2012.
//
//  Ported to Swift in P6a. The superclass (LDrawMetaCommand) is still ObjC.
//==============================================================================

import Foundation

@objc(LDrawLSynthDirective)
final class LDrawLSynthDirective: LDrawMetaCommand {

	// MARK: - Accessors

	//========== setSelected: ======================================================
	//
	// Purpose:		Inform the directive that it's been (de)selected.
	//
	//==============================================================================
	@objc(setSelected:)
	override func setSelected(_ flag: Bool) {
		super.setSelected(flag)

		// would like LDrawContainer to be a protocol.  In its absence, respondsToSelector: works
		// (A nil parent answered NO in ObjC.)
		if let parent = enclosingDirective(),
		   parent.responds(to: #selector(LDrawContainer.setSubdirectiveSelected(_:))) {
			parent.setSubdirectiveSelected(flag)
		}

	}//end setSelected:

	// MARK: - Display

	//========== browsingDescription ===============================================
	//
	// Purpose:		Returns a representation of the directive as a short string
	//				which can be presented to the user.
	//
	//==============================================================================
	@objc(browsingDescription)
	override func browsingDescription() -> String! {
		// isEqualToString: compares UTF-16 code units; NSString's isEqual(to:) keeps
		// that (Swift == uses canonical equivalence). A nil value matches nothing.
		let value = stringValue() as NSString?
		if value?.isEqual(to: "INSIDE") == true {
			return "Inside"
		}
		else if value?.isEqual(to: "OUTSIDE") == true {
			return "Outside"
		}
		else if value?.isEqual(to: "CROSS") == true {
			return "Cross"
		}

		return "Unknown LSynth Direction"
	}//end browsingDescription

	//========== iconName ==========================================================
	//
	// Purpose:		Returns the name of image file used to display this kind of
	//				object, or nil if there is no icon.
	//
	//==============================================================================
	@objc(iconName)
	override func iconName() -> String! {
		"LSynthDirection"
	}//end iconName

	// MARK: - Directives

	//========== write =============================================================
	//
	// Purpose:		Returns a line that can be written out to a file.
	//				Line format:
	//				0 SYNTH [INSIDE|OUTSIDE]
	//
	//==============================================================================
	@objc(write)
	override func write() -> String! {
		// "%@" printed a nil string as "(null)"; keep that.
		"0 SYNTH \(stringValue() ?? "(null)")"
	}//end write
}
