//==============================================================================
//
// File:		MLCadIni.swift
//
// Purpose:		Parses the contents of LDraw/MLCad.ini, the file which defines
//				settings for the minifigure generator.
//
//				MLCad.ini  has the following basic syntax:
//
//				; comment
//
//				[SECTION]
//				; (section-dependent syntax)
//
//				The file is maintained independently of this project at
//				www.holly-wood.it/mlcad-en.html. It was originally designed for
//				the Windows-based LDraw tool MLCad; I simply appropriated it.
//
//  Created by Allen Smith on 7/2/06.
//  Copyright 2006. All rights reserved.
//  Ported to Swift in P5: same selectors, same parsing (NSScanner) and quirks.
//==============================================================================

import Foundation

//---------- Section Headers ---------------------------------------------------
// a section header in MLCad.ini is enclosed in brackets (i.e., [HATS])

private let MLCAD_SECTION_LSYNTH						= "LSYNTH"
private let MLCAD_SECTION_MINIFIGURE_HATS				= "HATS"
private let MLCAD_SECTION_MINIFIGURE_HEAD				= "HEAD"
private let MLCAD_SECTION_MINIFIGURE_TORSO				= "BODY"
private let MLCAD_SECTION_MINIFIGURE_PELVIS				= "BODY2"
private let MLCAD_SECTION_MINIFIGURE_NECK				= "NECK"
private let MLCAD_SECTION_MINIFIGURE_ARM_LEFT			= "RARM"
private let MLCAD_SECTION_MINIFIGURE_ARM_RIGHT			= "LARM"
private let MLCAD_SECTION_MINIFIGURE_HAND_LEFT			= "RHAND"   //MLCad's left is the minifigure's right!
private let MLCAD_SECTION_MINIFIGURE_HAND_LEFT_ACCESSORY	= "RHANDA"
private let MLCAD_SECTION_MINIFIGURE_HAND_RIGHT			= "LHAND"
private let MLCAD_SECTION_MINIFIGURE_HAND_RIGHT_ACCESSORY	= "LHANDA"
private let MLCAD_SECTION_MINIFIGURE_LEG_LEFT			= "RLEG"
private let MLCAD_SECTION_MINIFIGURE_LEG_LEFT_ACCESSORY	= "RLEGA"
private let MLCAD_SECTION_MINIFIGURE_LEG_RIGHT			= "LLEG"
private let MLCAD_SECTION_MINIFIGURE_LEG_RIGHT_ACCESSORY	= "LLEGA"

@objc(MLCadIni)
class MLCadIni: NSObject {

	// The shared instance. Only touched from the main thread, as in the ObjC original.
	nonisolated(unsafe) private static var sharedIniFile: MLCadIni?

	private var lsynthVisibleTypesList: NSArray?

	//Minifigure Generator
	//these are mutable simply so I can fill them easier. Their mutability is
	// not exposed via the accessors.
	private let minifigureHatsList					= NSMutableArray()
	private let minifigureHeadsList					= NSMutableArray()
	private let minifigureNecksList					= NSMutableArray()
	private let minifigureTorsosList				= NSMutableArray()
	private let minifigureHipsList					= NSMutableArray()
	private let minifigureArmsLeftList				= NSMutableArray()
	private let minifigureArmsRightList				= NSMutableArray()
	private let minifigureHandsLeftList				= NSMutableArray()
	private let minifigureHandsLeftAccessoriesList	= NSMutableArray()
	private let minifigureHandsRightList			= NSMutableArray()
	private let minifigureHandsRightAccessoriesList	= NSMutableArray()
	private let minifigureLegsLeftList				= NSMutableArray()
	private let minifigureLegsLeftAcessoriesList	= NSMutableArray()
	private let minifigureLegsRightList				= NSMutableArray()
	private let minifigureLegsRightAccessoriesList	= NSMutableArray()

	// MARK: - INITIALIZATION

	//---------- iniFile -------------------------------------------------[static]--
	//
	// Purpose:		Parses the MLCad.ini file at the standard location (installing
	//				it if necessary) and returns an object containing all the known
	//				information therein.
	//
	//------------------------------------------------------------------------------
	@objc(iniFile)
	class func iniFile() -> MLCadIni! {
		//only parse MLCad.ini once; future invocations will just reuse the shared
		// object.
		if let shared = sharedIniFile {
			return shared
		}
		let mlcadini = MLCadIni()
		let filePath = LDrawPaths.shared().mlCadIniPath()

		mlcadini.parse(fromPath: filePath)

		sharedIniFile = mlcadini
		return mlcadini
	}//end iniFile


	//---------- resetForTesting -----------------------------------------[static]--
	//
	// Purpose:		TEST SUPPORT ONLY. Discards the shared instance so the next
	//				access rebuilds it (e.g. from a test fixture library).
	//
	//------------------------------------------------------------------------------
	@objc(resetForTesting)
	class func resetForTesting() {
		sharedIniFile = nil
	}//end resetForTesting


	//========== init ==============================================================
	//
	// Purpose:		Creates an empty, unparsed MLCad.ini database.
	//
	//==============================================================================
	override init() {
		super.init()
	}//end init


	// MARK: - ACCESSORS
	// Read through KVC by MinifigureGenerator.xib (selection.iniFile.minifigure…),
	// hence @objc dynamic.

	//========== lsynthVisibleTypes ================================================
	//
	// Purpose:		Returns the type names of LSynth elements which we should show
	//				in the UI. The LSynth.mpd configuration file includes
	//				definitions for a number of deprecated names that we don't want
	//				to show, so this list should be the authoritative filter.
	//				nil until the first parse.
	//
	//==============================================================================
	@objc dynamic func lsynthVisibleTypes() -> [Any]! {
		return lsynthVisibleTypesList.map { $0 as [AnyObject] }
	}

	//========== minifigure lists ==================================================
	//
	// Purpose:		Returns the specified list of parts for the minifigure
	//				generator.
	//
	//==============================================================================
	@objc dynamic func minifigureHats() -> [Any]! { return minifigureHatsList as [AnyObject] }
	@objc dynamic func minifigureHeads() -> [Any]! { return minifigureHeadsList as [AnyObject] }
	@objc dynamic func minifigureNecks() -> [Any]! { return minifigureNecksList as [AnyObject] }
	@objc dynamic func minifigureTorsos() -> [Any]! { return minifigureTorsosList as [AnyObject] }
	@objc dynamic func minifigureHips() -> [Any]! { return minifigureHipsList as [AnyObject] }
	@objc dynamic func minifigureArmsLeft() -> [Any]! { return minifigureArmsLeftList as [AnyObject] }
	@objc dynamic func minifigureArmsRight() -> [Any]! { return minifigureArmsRightList as [AnyObject] }
	@objc dynamic func minifigureHandsLeft() -> [Any]! { return minifigureHandsLeftList as [AnyObject] }
	@objc dynamic func minifigureHandsLeftAccessories() -> [Any]! { return minifigureHandsLeftAccessoriesList as [AnyObject] }
	@objc dynamic func minifigureHandsRight() -> [Any]! { return minifigureHandsRightList as [AnyObject] }
	@objc dynamic func minifigureHandsRightAccessories() -> [Any]! { return minifigureHandsRightAccessoriesList as [AnyObject] }
	@objc dynamic func minifigureLegsLeft() -> [Any]! { return minifigureLegsLeftList as [AnyObject] }
	@objc dynamic func minifigureLegsLeftAcessories() -> [Any]! { return minifigureLegsLeftAcessoriesList as [AnyObject] }
	@objc dynamic func minifigureLegsRight() -> [Any]! { return minifigureLegsRightList as [AnyObject] }
	@objc dynamic func minifigureLegsRightAccessories() -> [Any]! { return minifigureLegsRightAccessoriesList as [AnyObject] }


	//========== armAngleForTorsoName: =============================================
	//
	// Purpose:		Returns the absolute value of the angle at which arms should be
	//				rotated in order to fit on the torso.
	//
	// Notes:		If I had my way, this information would be part of MLCad.ini so
	//				I didn't need to do this cheezy hard-coding.
	//
	//==============================================================================
	@objc(armAngleForTorsoName:)
	func armAngle(forTorsoName torsoName: String!) -> Float {
		// Mechanical torso. No arm rotation
		if torsoName == "30375.dat" || torsoName == "54275.dat" {
			return 0.0
		}
		else {
			// Regular torso.
			//		-- this value is derived from a little trig on the torso surface.
			return 9.791
		}
	}//end armAngleForTorsoName:


	//========== setParts:intoMinifigurePartList: ==================================
	//
	// Purpose:		Assigns the partList variable to the new list of parts.
	//
	//==============================================================================
	private func setParts(_ parts: NSArray, intoMinifigurePartList partList: NSMutableArray) {
		partList.removeAllObjects()
		partList.addObjects(from: parts as [AnyObject])
	}//end setParts:intoMinifigurePartList:


	// MARK: - PARSING

	//========== parseFromPath: ====================================================
	//
	// Purpose:		Reads the MLCad.ini file at the given path.
	//
	//==============================================================================
	@objc(parseFromPath:)
	func parse(fromPath path: String!) {
		let fileString	= LDrawUtilities.string(fromFile: path) as NSString?
		let rawLines	= fileString?.separateByLine() as NSArray?

		//---------- cull out all the comments and blank lines ---------------------

		let sections = sectionsFromLines(rawLines)

		//---------- Parse Minifigure Sections -------------------------------------

		//this associates the key for each section with the list into which its
		// parts should be stored.
		let listsForSections: [(String, NSMutableArray)] = [
			(MLCAD_SECTION_MINIFIGURE_HATS,					minifigureHatsList),
			(MLCAD_SECTION_MINIFIGURE_HEAD,					minifigureHeadsList),
			(MLCAD_SECTION_MINIFIGURE_TORSO,				minifigureTorsosList),
			(MLCAD_SECTION_MINIFIGURE_PELVIS,				minifigureHipsList),
			(MLCAD_SECTION_MINIFIGURE_NECK,					minifigureNecksList),
			(MLCAD_SECTION_MINIFIGURE_ARM_LEFT,				minifigureArmsLeftList),
			(MLCAD_SECTION_MINIFIGURE_ARM_RIGHT,			minifigureArmsRightList),
			(MLCAD_SECTION_MINIFIGURE_HAND_LEFT,			minifigureHandsLeftList),
			(MLCAD_SECTION_MINIFIGURE_HAND_LEFT_ACCESSORY,	minifigureHandsLeftAccessoriesList),
			(MLCAD_SECTION_MINIFIGURE_HAND_RIGHT,			minifigureHandsRightList),
			(MLCAD_SECTION_MINIFIGURE_HAND_RIGHT_ACCESSORY,	minifigureHandsRightAccessoriesList),
			(MLCAD_SECTION_MINIFIGURE_LEG_LEFT,				minifigureLegsLeftList),
			(MLCAD_SECTION_MINIFIGURE_LEG_LEFT_ACCESSORY,	minifigureLegsLeftAcessoriesList),
			(MLCAD_SECTION_MINIFIGURE_LEG_RIGHT,			minifigureLegsRightList),
			(MLCAD_SECTION_MINIFIGURE_LEG_RIGHT_ACCESSORY,	minifigureLegsRightAccessoriesList),
		]

		for (currentSectionKey, partList) in listsForSections {
			let sectionLines = sections.object(forKey: currentSectionKey) as? NSArray
			let sectionParts = partsFromMinifigureLines(sectionLines)

			setParts(sectionParts, intoMinifigurePartList: partList)
		}

		//---------- Parse LSynth Section ------------------------------------------

		let lsynthLines = sections.object(forKey: MLCAD_SECTION_LSYNTH) as? NSArray
		lsynthVisibleTypesList = lsynthTypesFromLines(lsynthLines)
	}//end parseFromPath:


	//========== sectionsFromLines: ================================================
	//
	// Purpose:		Returns a dictionary with each section name as a keys, and lines
	//				as values.
	//
	//==============================================================================
	private func sectionsFromLines(_ lines: NSArray?) -> NSDictionary {
		let whitespaceCharacterSet	= CharacterSet.whitespacesAndNewlines
		var currentSectionName: String? = nil
		var currentSectionLines: NSMutableArray? = nil
		let sections = NSMutableDictionary()

		for case let rawLine as NSString in lines ?? [] {
			// cull out all the comments and blank lines
			let currentLine = rawLine.trimmingCharacters(in: whitespaceCharacterSet) as NSString
			if currentLine.length > 0 && currentLine.hasPrefix(";") == false {
				//once we pass the start of the section, start including lines.
				if currentLine.hasPrefix("[") {
					// Finish previous section
					if let name = currentSectionName {
						sections.setObject(currentSectionLines as Any, forKey: name as NSString)
					}

					// Start new section
					// (a failed scan leaves the name unchanged, as NSScanner's
					// out-parameter did: "[]" continues the previous section's name)
					let scanner = Scanner(string: currentLine as String)
					_ = scanner.scanString("[")
					if let name = scanner.scanUpToString("]") {
						currentSectionName = name
					}
					currentSectionLines = NSMutableArray()
				}
				else {
					currentSectionLines?.add(currentLine)
				}
			}
		}

		// Finish last section
		if let name = currentSectionName {
			sections.setObject(currentSectionLines as Any, forKey: name as NSString)
		}

		return sections
	}


	//========== lsynthTypesFromLines: =============================================
	//
	// Purpose:		Reads LSynth types out of the LSynth info block. Lines have the
	//				following format:
	//				02 - ELECTRIC_NXT_CABLE = SYNTH BEGIN ELECTRIC_NXT_CABLE 16
	//
	//				We return the type name after SYNTH BEGIN.
	//
	// Notes:		There are a few other things in the MLCad.ini [LSYNTH] section
	//				that we don't care about. This method current returns only those
	//				lines which start with a number, denoting supported synthesis
	//				types.
	//
	//				BUG-036: a line with nothing after SYNTH BEGIN repeats the
	//				previous type name (NSScanner left its out-parameter alone). If
	//				there is no previous name, the ObjC code inserted nil and
	//				Foundation raised; Swift can't raise, so it traps instead.
	//
	//==============================================================================
	private func lsynthTypesFromLines(_ lines: NSArray?) -> NSArray {
		let namesInList		= NSMutableArray(capacity: lines?.count ?? 0)
		let whitespaceSet	= CharacterSet.whitespaces
		var actualName: String? = nil

		for case let currentLine as String in lines ?? [] {
			let scanner = Scanner(string: currentLine)

			if scanner.scanInt() != nil {
				_ = scanner.scanString("-")
				_ = scanner.scanUpToCharacters(from: whitespaceSet)		// display name
				if scanner.scanString("= SYNTH BEGIN") != nil {			// ignore 00 - VERSION 3.1 line
					if let name = scanner.scanUpToCharacters(from: whitespaceSet) {
						actualName = name
					}
					guard let name = actualName else {
						fatalError("MLCad.ini [LSYNTH]: \"\(currentLine)\" has no type name after SYNTH BEGIN (BUG-036)")
					}
					namesInList.add(name)
				}
			}
		}

		return namesInList
	}//end lsynthTypesFromLines:


	//========== partsFromMinifigureLines: =========================================
	//
	// Purpose:		Reads LDrawParts out of an array of strings specifying elements
	//				for MLCad's minifigure generator.
	//
	//				Each line has the following format:
	//				"<Display name>" "<DAT/LDR file name>" <Flags> <Matrix> <Offset>
	//
	//				<Display name>		The name of the element as it is displayed
	//									in the element list. Bricksmith ignores this
	//									name!
	//				<DAT/LDR file name>	The file name of the element or "" for
	//									hidden element
	//				<Flags>				always 0 reserved for future use
	//				<Matrix>			a rotation matrix a11 a12 a13 ... a33 for
	//									optimal appearance at 0 degree rotation angle
	//				<Offset>			The offset of the part to be in place
	//
	// Note:		The position of the matrix and the offset is reversed from the
	//				standard order of a type 1 part line.
	//
	//				The matrix is carried over from line to line: a value that fails
	//				to scan keeps the previous line's value.
	//
	//==============================================================================
	private func partsFromMinifigureLines(_ lines: NSArray?) -> NSArray {
		let lineCount		= lines?.count ?? 0
		let parts			= NSMutableArray(capacity: lineCount)
		let namesInList		= NSMutableArray(capacity: lineCount)

		var partName: String?	= nil
		var transformation		= IdentityMatrix4

		let quoteSet		= CharacterSet(charactersIn: "\"")
		let whitespaceSet	= CharacterSet.whitespaces

		func scanFloat(_ scanner: Scanner, into value: inout Float) {
			if let scanned = scanner.scanFloat() {
				value = scanned
			}
		}

		for case let currentLine as String in lines ?? [] {
			//---------- Extract the textual part info -----------------------------

			let scanner = Scanner(string: currentLine)

			//skip the display name. We just don't care.
			_ = scanner.scanUpToCharacters(from: quoteSet)
			_ = scanner.scanString("\"")
			_ = scanner.scanUpToCharacters(from: quoteSet)
			_ = scanner.scanString("\"") //so we scan "" as two separate characters

			//scan the part name, skipping the first quote.
			_ = scanner.scanUpToCharacters(from: quoteSet)
			_ = scanner.scanString("\"")
			let scannedName = scanner.scanUpToCharacters(from: quoteSet)
			let gotName = scannedName != nil
			if let scannedName {
				partName = scannedName
			}
			_ = scanner.scanString("\"")

			//skip the flags; they don't mean anything yet anyway
			_ = scanner.scanUpToCharacters(from: whitespaceSet)

			//the rest is the transformation matrix, but in a different order from
			// an LDraw type 1 part line.
			scanFloat(scanner, into: &transformation.element.0.0)
			scanFloat(scanner, into: &transformation.element.1.0)
			scanFloat(scanner, into: &transformation.element.2.0)
			scanFloat(scanner, into: &transformation.element.0.1)
			scanFloat(scanner, into: &transformation.element.1.1)
			scanFloat(scanner, into: &transformation.element.2.1)
			scanFloat(scanner, into: &transformation.element.0.2)
			scanFloat(scanner, into: &transformation.element.1.2)
			scanFloat(scanner, into: &transformation.element.2.2)

			scanFloat(scanner, into: &transformation.element.3.0)
			scanFloat(scanner, into: &transformation.element.3.1)
			scanFloat(scanner, into: &transformation.element.3.2)


			//---------- Create an LDrawPart for the line --------------------------

			// Some entries have an empty string for a part name. NSScanner only
			// indicates this by failing the scan through "". In any event, we
			// want to discard these non-entries.
			if gotName {
				let currentPart = LDrawPart()

				currentPart.setTransformationMatrix(&transformation)
				currentPart.setDisplayName(partName, parse: false, in: nil)

				//add the part-- but don't allow duplicate names, even if they
				// are specified in the ini file. Not only is it bad form, but
				// it seriously messes up binding the array to an NSPopUpButton,
				// which filters out identically-named menu items.
				let referenceName: String = currentPart.referenceName()
				if namesInList.contains(referenceName) == false {
					parts.add(currentPart)
					namesInList.add(referenceName)
				}
				else {
					NSLog("%@ %@ is already in the list", referenceName as NSString,
						  (currentPart.browsingDescription() ?? "(null)") as NSString)
				}
			}
		}

		//---------- Sort list by part name ----------------------------------------

		let sortDescriptor = NSSortDescriptor(key: "browsingDescription", ascending: true)
		parts.sort(using: [sortDescriptor])

		return parts
	}//end partsFromMinifigureLines:

}
