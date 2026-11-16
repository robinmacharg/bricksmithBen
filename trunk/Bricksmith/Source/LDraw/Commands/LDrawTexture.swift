//==============================================================================
//
// File:		LDrawTexture.swift
//
// Purpose:		Support for projecting images onto LDraw geometry.
//
// Modified:	04/10/2012 Allen Smith. Creation Date.
//
//				Ported to Swift in P6b. The superclass (LDrawContainer) is
//				still ObjC.
//
//==============================================================================

import Foundation
import OpenGL.GL

/// Coder keys longer than 15 ASCII bytes bridge to a new NSString on every call as Swift literals (L102).
private enum CoderKey {
	static let imageDisplayName = NSString(string: "imageDisplayName") as String
}

/// The double-quote set scanQuotableToken: uses.
private let doubleQuoteSet = CharacterSet(charactersIn: "\"")


//---------- QuotableTokenIsMissing() --------------------------------[static]--
//
// Purpose:		Returns YES if +[LDrawUtilities scanQuotableToken:] would raise
//				on this scanner: that is, when its first scan finds no token
//				and it appends nil. Makes the same scanner calls, then puts the
//				scan location back, so the scanner is left unchanged.
//
//------------------------------------------------------------------------------
private func QuotableTokenIsMissing(_ scanner: Scanner) -> Bool {
	let utf16			= scanner.utf16
	let startLocation	= utf16.location()
	var foundToken		= false

	if utf16.scanCharacters(from: doubleQuoteSet, into: nil) == true {
		foundToken = utf16.scanUpToCharacters(from: doubleQuoteSet, into: nil)
	}
	else {
		foundToken = utf16.scanUpToCharacters(from: .whitespaces, into: nil)
	}

	utf16.setLocation(startLocation)

	return (foundToken == false)

}//end QuotableTokenIsMissing


/// -[LDrawUtilities readNextField:remainder:], keeping the fields as NSString.
private func readNextField(_ line: NSString?, remainder: inout NSString?) -> NSString? {
	return LDrawUtilities.readNextField(line as String?, remainder: &remainder) as NSString?
}

/// -isEqualToString: (UTF-16 units; a nil receiver answers NO).
@inline(__always)
private func fieldIs(_ field: NSString?, _ keyword: String) -> Bool {
	return field?.isEqual(to: keyword) == true
}


@objc(LDrawTexture)
final class LDrawTexture: LDrawContainer {

	// Stored defaults are the ObjC zero-initialized ivars (-init isn't overridden;
	// -[LDrawDirective initWithLines:...] re-sends -init mid-parse, L104).
	private var fallback: NSArray?				= nil
	private var displayName: String?			= nil
	private var referenceName: String?			= nil
	private var glossmap: String?				= nil

	private var planePoint1: Point3				= ZeroPoint3
	private var planePoint2: Point3				= ZeroPoint3
	private var planePoint3: Point3				= ZeroPoint3

	private var dragHandles: NSArray?			= nil
	private var cachedBounds: Box3				= Box3()	// cached bounds of the enclosed directives

	private var textureTag: GLuint				= 0


	// MARK: - Initialization

	//========== init ==============================================================
	//
	// Purpose:		LDrawContainer's -init. (Overridden so it stays inherited by
	//				ObjC: copy uses [[[self class] alloc] init].)
	//
	//==============================================================================
	@objc(init)
	override init() {
		super.init()

	}//end init


	//========== initWithLines:inRange: ============================================
	//
	// Purpose:		As -[LDrawDirective initWithLines:inRange:]: no parent group.
	//
	//==============================================================================
	@objc(initWithLines:inRange:)
	override convenience init!(lines: [Any]!, in range: NSRange) {
		self.init(lines: lines, in: range, parentGroup: nil)

	}//end initWithLines:inRange:


	//========== initWithLines:inRange:parentGroup: ================================
	//
	// Purpose:		Initializes the texture with the lines.
	//
	// Notes:		Index arithmetic is NSUInteger as in ObjC (wrapping operators).
	//
	//==============================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override init!(lines: [Any]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		// NSRange's fields are NSUInteger in ObjC: unsigned, wrapping arithmetic.
		let rangeLocation				= UInt(bitPattern: range.location)
		var rangeLength					= UInt(bitPattern: range.length)
		var currentLine: NSString?		= nil
		var fallbackRange				= NSMakeRange(NSNotFound, 0)
		var lineIndex: UInt				= 0
		let strippedLines				= NSMutableArray()

		// (nil when there are no lines)
		super.init(lines: lines, in: range, parentGroup: parentGroup)

		let lineArray	= lines! as NSArray
		let lineCount	= UInt(lineArray.count)

		cachedBounds = InvalidBox

		// P6b: ObjC raised here (-objectAtIndex: past the end of the lines);
		// see KNOWN-BUGS BUG-P6B-meta-2
		guard rangeLocation < lineCount else {
			return nil
		}
		currentLine = lineArray.object(at: Int(rangeLocation)) as? NSString
		_ = parsePlanarTexture(fromLine: currentLine as String?, parentGroup: parentGroup)

		// Parse out the END command
		if rangeLength > 0 {
			// P6b: ObjC raised here (-objectAtIndex: past the end of the lines);
			// see KNOWN-BUGS BUG-P6B-meta-2
			let lastIndex = rangeLocation &+ rangeLength &- 1
			guard lastIndex < lineCount, lastIndex >= rangeLocation else {
				return nil
			}
			currentLine = lineArray.object(at: Int(lastIndex)) as? NSString

			if LDrawTexture.lineIsTextureTerminator(currentLine as String?) {
				rangeLength -= 1
			}
		}
		let rangeMax = rangeLocation &+ rangeLength	// NSMaxRange(range), within the lines (checked above)

		//---------- Textured geometry -----------------------------------------

		// Strip the !: from the beginning of any geometry lines
		lineIndex = rangeLocation &+ 1
		while lineIndex < rangeMax {
			currentLine = lineArray.object(at: Int(lineIndex)) as? NSString
			lineIndex += 1

			var strippedLine: NSString?	= nil
			var field					= readNextField(currentLine, remainder: &strippedLine)
			var handled					= false

			if fieldIs(field, "0") {
				field = readNextField(strippedLine, remainder: &strippedLine)
				if fieldIs(field, LDRAW_TEXTURE_GEOMETRY) {
					// (readNextField gives a remainder for every string line.)
					strippedLines.add(strippedLine ?? "")
					handled = true
				}
				else if fieldIs(field, LDRAW_TEXTURE) {
					field = readNextField(strippedLine, remainder: &strippedLine)
					if fieldIs(field, LDRAW_TEXTURE_FALLBACK) {
						fallbackRange.location = Int(lineIndex)
						fallbackRange.length = Int(rangeMax - lineIndex)
						handled = true
						break
					}
				}
			}

			if handled == false {
				// Line did not have a protective meta prefix. Keep the
				// original line intact.
				strippedLines.add(lineArray.object(at: Int(lineIndex - 1)))
			}
		}

		// Interpret geometry
		// (Bridged once to an immutable array: each child parse gets this same
		// NSArray back, O(1), as the ObjC passed strippedLines itself.)
		let parsedLines		= strippedLines.copy() as! [Any]
		let strippedCount	= UInt(strippedLines.count)
		lineIndex = 0
		while lineIndex < strippedCount {
			currentLine = strippedLines.object(at: Int(lineIndex)) as? NSString

			// (A Nil class, for an unknown line type, answered a zero range and a
			// nil directive: messaging Nil.)
			let CommandClass = LDrawUtilities.classForDirectiveBeginning(withLine: currentLine as String?) as? LDrawDirective.Type
			let commandRange = CommandClass?.rangeOfDirectiveBeginning(at: lineIndex,
																	   inLines: parsedLines,
																	   maxIndex: strippedCount &- 1)
				?? NSMakeRange(0, 0)
			let newDirective = CommandClass?.directive(lines: parsedLines, in: commandRange, parentGroup: parentGroup)

			// P6b: ObjC raised here (-addDirective:nil inserts nil: a child that
			// failed to parse, such as a part whose library file fails to load,
			// or an unknown line type); see KNOWN-BUGS BUG-P6B-meta-3
			guard let newDirective else {
				return nil
			}
			add(newDirective)

			lineIndex = UInt(bitPattern: commandRange.location) &+ UInt(bitPattern: commandRange.length)
		}

		//---------- Fallback geometry -----------------------------------------

		if fallbackRange.location != NSNotFound {
			// not even going to bother parsing this.
			fallback = NSArray(array: lineArray.subarray(with: fallbackRange))
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

		setImageDisplayName(decoder.decodeObject(forKey: CoderKey.imageDisplayName) as? String)
		setGlossmapName(decoder.decodeObject(forKey: "glossmapName") as? String)

		//Decoding structures is a bit messy. memcpy: the bytes have no alignment promise.
		memcpy(&planePoint1, decoder.decodeBytes(forKey: "planePoint1", returnedLength: nil), MemoryLayout<Point3>.size)
		memcpy(&planePoint2, decoder.decodeBytes(forKey: "planePoint2", returnedLength: nil), MemoryLayout<Point3>.size)
		memcpy(&planePoint3, decoder.decodeBytes(forKey: "planePoint3", returnedLength: nil), MemoryLayout<Point3>.size)

		fallback = decoder.decodeObject(forKey: "fallback") as? NSArray

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

		encoder.encode(fallback,						forKey: "fallback")
		encoder.encode(displayName as NSString?,		forKey: CoderKey.imageDisplayName)
		encoder.encode(glossmap as NSString?,			forKey: "glossmapName")

		encodeBytes(of: planePoint1, encoder, "planePoint1")
		encodeBytes(of: planePoint2, encoder, "planePoint2")
		encodeBytes(of: planePoint3, encoder, "planePoint3")

	}//end encodeWithCoder:

	/// [encoder encodeBytes:&value length:sizeof(Point3) forKey:key]
	private func encodeBytes(of value: Point3, _ encoder: NSCoder, _ key: String) {
		withUnsafeBytes(of: value) {
			encoder.encodeBytes($0.bindMemory(to: UInt8.self).baseAddress, length: MemoryLayout<Point3>.size, forKey: key)
		}
	}


	//========== copyWithZone: =====================================================
	//
	// Purpose:		Returns a duplicate of this file.
	//
	//==============================================================================
	@objc(copyWithZone:)
	override func copy(with zone: NSZone? = nil) -> Any {
		let copied = super.copy(with: zone) as! LDrawTexture

		copied.fallback = fallback?.copy() as? NSArray
		copied.setImageDisplayName(imageDisplayName())
		copied.setGlossmapName(glossmapName())
		copied.planePoint1 = planePoint1
		copied.planePoint2 = planePoint2
		copied.planePoint3 = planePoint3
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
	override class func rangeOfDirectiveBeginning(at index: UInt, inLines lines: [Any]!, maxIndex: UInt) -> NSRange {
		var ranPastEnd = false
		return textureRange(at: index, inLines: lines, maxIndex: maxIndex, ranPastEnd: &ranPastEnd)

	}//end rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:


	//---------- textureRange(at:inLines:maxIndex:ranPastEnd:) ----------[static]--
	//
	// Purpose:		+rangeOfDirectiveBeginningAtIndex:inLines:maxIndex:, with the
	//				nesting made explicit.
	//
	// Notes:		The ObjC asked for a nested texture's range with
	//				maxIndex:NSMaxRange(testRange), one past its own last line, so a
	//				nested START with no END running to the end of the lines read
	//				one past them and raised (KNOWN-BUGS BUG-P6B-meta-4). Where it
	//				raised, every level now answers "to the end of the lines", as
	//				the spec has it for a texture with no END. (Answering the count
	//				so far instead leaves the inner START as the last line of the
	//				outer texture; its range is then empty, and the outer texture's
	//				parse loop never advances: the zero-length range of
	//				BUG-P6B-meta-13.)
	//
	//------------------------------------------------------------------------------
	private class func textureRange(at index: UInt, inLines lines: [Any]!, maxIndex: UInt, ranPastEnd: inout Bool) -> NSRange {
		let lineArray					= lines as NSArray?
		var counter: UInt				= 0
		let testLocation: UInt			= index
		let testMax: UInt				= testLocation &+ (maxIndex &- index &+ 1)	// NSMaxRange(testRange)
		var textureLength: Int			= 0

		var parsedField: NSString?		= nil
		var currentLine: NSString?		= nil
		var workingLine: NSString?		= nil

		// (Messaging a nil array answered nil, which is not a texture line.)
		if let lineArray {
			let lineCount = UInt(lineArray.count)

			// P6b: ObjC raised here (-objectAtIndex: past the end of the lines;
			// not reachable: the first line is always inside them); see
			// KNOWN-BUGS BUG-P6B-meta-4
			guard testLocation < lineCount else {
				return NSMakeRange(Int(bitPattern: index), textureLength)
			}

			// Regretfully, we have a NEXT directive which saves a whole whopping ONE
			// LINE of LDraw code. SWEETNESS! And for this INCREDIBLE, STUPENDOUS
			// SAVINGS, we have to do much more complicated parsing.
			currentLine = lineArray.object(at: Int(bitPattern: index)) as? NSString
			parsedField = readNextField(currentLine, remainder: &currentLine)
			if fieldIs(parsedField, "0") {
				parsedField = readNextField(currentLine, remainder: &currentLine)

				if fieldIs(parsedField, LDRAW_TEXTURE) {
					// (workingLine is nil here: this read gives nil.)
					parsedField = readNextField(workingLine, remainder: &workingLine)
//					if([parsedField isEqualToString:LDRAW_TEXTURE_NEXT] )
//					{
//						// 0 !TEXMAP NEXT
//						// <a single-line directive, we hope>
//
//						textureLength = 2; // the header and the next line
//					}
//					else
					do {
						// 0 !TEXMAP START
						// .....
						// 0 !TEXMAP END
						//
						// Find the last line in the texture.
						counter = testLocation &+ 1
						while counter < testMax {
							// P6b: ObjC raised here (-objectAtIndex: past the end of
							// the lines: a nested START with no END, whose range is
							// asked for one line past the outer one); see KNOWN-BUGS
							// BUG-P6B-meta-4
							guard counter < lineCount else {
								ranPastEnd = true
								return NSMakeRange(Int(bitPattern: index), Int(lineCount &- index))
							}
							currentLine = lineArray.object(at: Int(bitPattern: counter)) as? NSString

							if lineIsTextureBeginning(currentLine as String?) {
								// Get length of nested texture using a recursive call. This handles
								// any level of texture nesting.
								// This is only necessary at all if nested textures are permitted to
								// be added without a leading "0 !:".
								let nestedTextureRange = textureRange(at: counter, inLines: lines, maxIndex: testMax, ranPastEnd: &ranPastEnd)
								if ranPastEnd {
									return NSMakeRange(Int(bitPattern: index), Int(lineCount &- index))
								}
								textureLength += nestedTextureRange.length
							}
							else {
								textureLength += 1
							}

							if lineIsTextureTerminator(currentLine as String?) {
								// Nothing more to parse. Stop.
								textureLength += 1
								break
							}
							counter &+= 1
						}
					}
				}
			}
		}

		return NSMakeRange(Int(bitPattern: index), textureLength)

	}//end textureRange(at:inLines:maxIndex:ranPastEnd:)


	// MARK: - Directives

	//========== planarSpec ========================================================
	//
	// Purpose:		The texture spec drawSelf: and collectSelf: push: planar
	//				projection through the three plane points.
	//
	//==============================================================================
	@inline(__always)
	private func planarSpec() -> LDrawTextureSpec {
		var normal: Vector3	= ZeroPoint3
		var length: Float	= 0
		var spec			= LDrawTextureSpec()

		normal = V3Sub(planePoint2, planePoint1)
		length = V3Length(normal)//128./80;//
		normal = V3Normalize(normal)

		spec.plane_s.0 = normal.x / length
		spec.plane_s.1 = normal.y / length
		spec.plane_s.2 = normal.z / length
		spec.plane_s.3 = V3DistanceFromPointToPlane(ZeroPoint3, normal, planePoint1) / length

		normal = V3Sub(planePoint3, planePoint1)
		length = V3Length(normal)//128./80;//
		normal = V3Normalize(normal)

		spec.plane_t.0 = normal.x / length
		spec.plane_t.1 = normal.y / length
		spec.plane_t.2 = normal.z / length
		spec.plane_t.3 = V3DistanceFromPointToPlane(ZeroPoint3, normal, planePoint1) / length

		spec.projection = Int32(tex_proj_planar)
		spec.tex_obj = textureTag

		return spec
	}


	//========== drawSelf: ===========================================================
	//
	// Purpose:		Draw this directive and its subdirectives by calling APIs on
	//				the passed in renderer, then calling drawSelf on children.
	//
	// Notes:		The texture is a container, so it passes drawSelf to give child
	//				parts time to draw.  It first pushes its own texture state onto
	//				the stack.  This means that an untextured part inside a texture
	//				will pick up the projected texture, which is what the LDraw spec
	//				calls for.
	//
	//================================================================================
	@objc(drawSelf:)
	override func drawSelf(_ renderer: (any LDrawRenderer)!) {
		// (Messages to a nil renderer or array did nothing; a nil renderer answered tag 0.)
		if textureTag == 0 {
			textureTag = renderer?.textureTag(for: self) ?? 0
		}

		var spec = planarSpec()

		renderer?.pushTexture(&spec)
		if let commands = subdirectives() {
			for case let currentDirective as LDrawDirective in commands {
				currentDirective.drawSelf(renderer)
			}
		}
		renderer?.popTexture()

	}//end drawSelf:


	//========== collectSelf: ========================================================
	//
	// Purpose:		Collect self is called on each directive by its parents to
	//				accumulate _mesh_ data into a display list for later drawing.
	//				The collector protocol passed in is some object capable of
	//				remembering the collectable data.
	//
	// Notes:		LDrawTexture is a collection of sub-directives that all receive
	//				projective texturing.  So we first push our texture state to the
	//				collector and then recurse.
	//
	//================================================================================
	@objc(collectSelf:)
	override func collectSelf(_ renderer: (any LDrawCollector)!) {
		// (Messages to a nil renderer or array did nothing; a nil renderer answered tag 0.)
		if textureTag == 0 {
			textureTag = renderer?.textureTag(for: self) ?? 0
		}

		var spec = planarSpec()

		renderer?.pushTexture(&spec)
		if let commands = subdirectives() {
			for case let currentDirective as LDrawDirective in commands {
				currentDirective.collectSelf(renderer)
			}
		}
		renderer?.popTexture()
		_ = revalCache(.DisplayList)

	}//end collectSelf:


	//========== hitTest:transform:viewScale:boundsOnly:creditObject:hits: =======
	//
	// Purpose:		Hit-test the geometry.
	//
	//==============================================================================
	@objc(hitTest:transform:viewScale:boundsOnly:creditObject:hits:)
	override func hitTest(_ pickRay: Ray3, transform: Matrix4, viewScale scaleFactor: Float, boundsOnly: Bool,
						  creditObject: Any!, hits: NSMutableDictionary!) {
		let commands		= subdirectives()
		let commandCount	= commands?.count ?? 0
		var counter			= 0

		while counter < commandCount {
			let currentDirective = commands!.object(at: counter) as! LDrawDirective
			currentDirective.hitTest(pickRay, transform: transform, viewScale: scaleFactor, boundsOnly: boundsOnly,
									 creditObject: creditObject, hits: hits)
			counter += 1
		}

		if let dragHandles {
			for case let handle as LDrawDragHandle in dragHandles {
				handle.hitTest(pickRay, transform: transform, viewScale: scaleFactor, boundsOnly: boundsOnly,
							   creditObject: nil, hits: hits)
			}
		}
	}//end hitTest:transform:viewScale:boundsOnly:creditObject:hits:


	//========== boxTest:transform:boundsOnly:creditObject:hits: ===================
	//
	// Purpose:		Check for intersections with screen-space geometry.
	//
	//==============================================================================
	@objc(boxTest:transform:boundsOnly:creditObject:hits:)
	override func boxTest(_ bounds: Box2, transform: Matrix4, boundsOnly: Bool, creditObject: Any!, hits: NSMutableSet!) -> Bool {
		let commands		= subdirectives()
		let commandCount	= commands?.count ?? 0
		var counter			= 0

		while counter < commandCount {
			let currentDirective = commands!.object(at: counter) as! LDrawDirective
			if currentDirective.boxTest(bounds, transform: transform, boundsOnly: boundsOnly, creditObject: creditObject, hits: hits) {
				if creditObject != nil {
					return true
				}
			}
			counter += 1
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
	override func depthTest(_ testPt: Point2, inBox bounds: Box2, transform: Matrix4, creditObject: Any!,
							bestObject: AutoreleasingUnsafeMutablePointer<AnyObject?>!,
							bestDepth: UnsafeMutablePointer<Float>!) {
		let commands		= subdirectives()
		let commandCount	= commands?.count ?? 0
		var counter			= 0

		while counter < commandCount {
			let currentDirective = commands!.object(at: counter) as! LDrawDirective
			currentDirective.depthTest(testPt, inBox: bounds, transform: transform, creditObject: creditObject,
									   bestObject: bestObject, bestDepth: bestDepth)
			counter += 1
		}

		if let dragHandles {
			for case let handle as LDrawDragHandle in dragHandles {
				handle.depthTest(testPt, inBox: bounds, transform: transform, creditObject: creditObject,
								 bestObject: bestObject, bestDepth: bestDepth)
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
		let written			= NSMutableString()
		let CRLF: String	= NSString.crlf()
		let commands		= subdirectives()
		var numberCommands	= 0
		var counter			= 0

		func f(_ number: Float) -> String { LDrawUtilities.outputString(for: number) ?? "(null)" }

		// Start
		// ("%@" printed a nil name as "(null)".)
		written.append("0 \(LDRAW_TEXTURE) \(LDRAW_TEXTURE_START) \(LDRAW_TEXTURE_METHOD_PLANAR) "
					   + "\(f(planePoint1.x)) \(f(planePoint1.y)) \(f(planePoint1.z)) "
					   + "\(f(planePoint2.x)) \(f(planePoint2.y)) \(f(planePoint2.z)) "
					   + "\(f(planePoint3.x)) \(f(planePoint3.y)) \(f(planePoint3.z)) "
					   + "\(displayName ?? "(null)")")

		if let glossmap {
			written.append(" \(LDRAW_TEXTURE_GLOSSMAP) \(glossmap)")
		}

		written.append(CRLF)

		// Write all the primary geometry
		numberCommands = commands?.count ?? 0
		while counter < numberCommands {
			let currentCommand	= commands!.object(at: counter) as! LDrawDirective
			let commandString	= currentCommand.write() as NSString?

			// Pre-pend the !: meta if it hasn't already been put there. Nesting !:
			// is illegal.
			// (-hasPrefix: of nil answered NO; appending nil raised: BUG-P6B-meta-5.)
			if commandString?.hasPrefix(LDRAW_TEXTURE_GEOMETRY) != true {
				// Note: I make no attempt to remember if the original geometry had
				//		 the !: meta when parsed. Doing so is far more trouble than
				//		 it seems worth.
				written.append("0 \(LDRAW_TEXTURE_GEOMETRY) \((commandString as String?) ?? "(null)")")
			}
			else if let commandString {
				written.append(commandString as String)
			}
			written.append(CRLF)
			counter += 1
		}

		// Fallback geometry
		if let fallback, fallback.count > 0 {
			written.append("0 \(LDRAW_TEXTURE) \(LDRAW_TEXTURE_FALLBACK)\(CRLF)")

			for line in fallback {
				// P6b: ObjC raised here (-appendString: of a non-string fallback
				// line; only an archive could hold one); see KNOWN-BUGS BUG-P6B-meta-5
				guard let line = line as? String else {
					return nil
				}
				written.append(line)
				written.append(CRLF)
			}
		}

		// End
		written.append("0 \(LDRAW_TEXTURE) \(LDRAW_TEXTURE_END)")

		return written as String

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
		displayName

	}//end browsingDescription


	//========== iconName ==========================================================
	//
	// Purpose:		Returns the name of image file used to display this kind of
	//				object, or nil if there is no icon.
	//
	//==============================================================================
	@objc(iconName)
	override func iconName() -> String! {
		"Texture"

	}//end iconName


	// MARK: - Accessors

	//========== boundingBox3 ======================================================
	//==============================================================================
	@objc(boundingBox3)
	override func boundingBox3() -> Box3 {
		if revalCache(.CacheFlagBounds) == .CacheFlagBounds {
			cachedBounds = LDrawUtilities.boundingBox3(forDirectives: subdirectives() as? [Any])
		}
		return cachedBounds

	}//end boundingBox3


	//========== glossmapName ======================================================
	//==============================================================================
	@objc(glossmapName)
	func glossmapName() -> String! {
		glossmap
	}


	//========== imageDisplayName ==================================================
	//==============================================================================
	@objc(imageDisplayName)
	func imageDisplayName() -> String! {
		displayName
	}


	//========== imageReferenceName ================================================
	//
	// Purpose:		Returns the name of the image. This is the filename where the
	//				part is found. Since Macintosh computers are case-insensitive,
	//				I have adopted lower-case as the standard for names.
	//
	//==============================================================================
	@objc(imageReferenceName)
	func imageReferenceName() -> String! {
		referenceName
	}


	//========== setGlossmapName: ==================================================
	//
	// Purpose:		Sets the filename of the image to use for a specular reflection
	//				map. Unused.
	//
	//==============================================================================
	@objc(setGlossmapName:)
	func setGlossmapName(_ newName: String!) {
		glossmap = newName
	}


	//========== setImageDisplayName: ==============================================
	//
	// Purpose:		Sets the filename of the image to use as the texture.
	//
	//==============================================================================
	@objc(setImageDisplayName:)
	func setImageDisplayName(_ newName: String!) {
		setImageDisplayName(newName, parse: true, in: nil)
	}


	//========== setImageDisplayName:parse:inGroup: ================================
	//
	// Purpose:		Sets the filename of the image to use as the texture.
	//
	//				If shouldParse is YES, pre-loads the referenced image if
	//				possible. Pre-loading is very import in initial model loading,
	//				because it enables structual optimizations to be performed prior
	//				to OpenGL optimizations. It also results in a more honest load
	//				progress bar.
	//
	//==============================================================================
	@objc(setImageDisplayName:parse:inGroup:)
	func setImageDisplayName(_ newName: String!, parse shouldParse: Bool, in parentGroup: dispatch_group_t!) {
		// -lowercaseString (NSString's, not Swift's lowercased()).
		let newReferenceName			= (newName as NSString?)?.lowercased
		let parseGroup: dispatch_group_t? = nil

		displayName = newName

		referenceName = newReferenceName

		// Force the part library to parse the model this part will display. This
		// pushes all parsing into the same operation, which improves loading time
		// predictability and allows better potential threading optimization.
		if shouldParse == true, let newName, (newName as NSString).length > 0 {
			PartLibrary.shared().loadImage(forName: displayName, in: parseGroup)
		}

	}//end setImageDisplayName:


	//========== setPlanePoint1: ===================================================
	//
	// Purpose:		Sets the texture's first planePoint.
	//
	//==============================================================================
	@objc(setPlanePoint1:)
	func setPlanePoint1(_ newPlanePoint: Point3) {
		planePoint1 = newPlanePoint

		if let dragHandles {
			(dragHandles.object(at: 0) as! LDrawDragHandle).setPosition(newPlanePoint, updateTarget: false)
		}

	}//end setPlanePoint1:


	//========== setPlanePoint2: ===================================================
	//
	// Purpose:		Sets the texture's second planePoint.
	//
	//==============================================================================
	@objc(setPlanePoint2:)
	func setPlanePoint2(_ newPlanePoint: Point3) {
		planePoint2 = newPlanePoint

		if let dragHandles {
			(dragHandles.object(at: 1) as! LDrawDragHandle).setPosition(newPlanePoint, updateTarget: false)
		}

	}//end setPlanePoint2:


	//========== setPlanePoint3: ===================================================
	//
	// Purpose:		Sets the texture's last planePoint.
	//
	//==============================================================================
	@objc(setPlanePoint3:)
	func setPlanePoint3(_ newPlanePoint: Point3) {
		planePoint3 = newPlanePoint

		if let dragHandles {
			(dragHandles.object(at: 2) as! LDrawDragHandle).setPosition(newPlanePoint, updateTarget: false)
		}

	}//end setPlanePoint3:


	//========== setSelected: ======================================================
	//
	// Purpose:		Somebody make this a protocol method.
	//
	//==============================================================================
	@objc(setSelected:)
	override func setSelected(_ flag: Bool) {
		super.setSelected(flag)

		if flag == true {
			let handle1: LDrawDragHandle = LDrawDragHandle(tag: 1, position: planePoint1)
			let handle2: LDrawDragHandle = LDrawDragHandle(tag: 2, position: planePoint2)
			let handle3: LDrawDragHandle = LDrawDragHandle(tag: 3, position: planePoint3)

			handle1.setTarget(self)
			handle2.setTarget(self)
			handle3.setTarget(self)

			handle1.setAction(#selector(dragHandleChanged(_:)))
			handle2.setAction(#selector(dragHandleChanged(_:)))
			handle3.setAction(#selector(dragHandleChanged(_:)))

			dragHandles = NSArray(objects: handle1, handle2, handle3)
		}
		else {
			dragHandles = nil
		}

	}//end setSelected:


	//========== insertDirective:atIndex: ==========================================
	//
	// Purpose:		Inserts the new directive into the step.
	//
	//==============================================================================
	@objc(insertDirective:atIndex:)
	override func insert(_ directive: LDrawDirective!, at index: Int) {
		// P6b: ObjC raised here (-[NSMutableArray insertObject:atIndex:] in
		// LDrawContainer, with a nil directive or an index past the end, before
		// anything changed); see KNOWN-BUGS BUG-P6B-meta-6
		// (A nil array, only from an archive without children, raised nothing.)
		let count = subdirectives()?.count ?? Int.max
		guard directive != nil, index >= 0, index <= count else {
			return
		}
		super.insert(directive, at: index)

		invalCache([.CacheFlagBounds, .DisplayList])

	}//end insertDirective:atIndex:


	//========== removeDirectiveAtIndex: ===========================================
	//
	// Purpose:		Removes the directive from the step.
	//
	//==============================================================================
	@objc(removeDirectiveAtIndex:)
	override func removeDirective(at index: Int) {
		let commands = subdirectives()

		// P6b: ObjC raised here (-objectAtIndex: past the end, before anything
		// changed); see KNOWN-BUGS BUG-P6B-meta-6
		// (A nil array, only from an archive without children, raised nothing.)
		if let commands, index < 0 || index >= commands.count {
			return
		}
		// Keep the directive alive while super removes it (was retain ... release under MRC).
		let directive = commands?.object(at: index)

		super.removeDirective(at: index)

		invalCache([.CacheFlagBounds, .DisplayList])

		withExtendedLifetime(directive) {}

	}//end removeDirectiveAtIndex:


	// MARK: - Actions

	//========== dragHandleChanged: ================================================
	//
	// Purpose:		One of the drag handles on our vertexes has changed.
	//
	//==============================================================================
	@objc(dragHandleChanged:)
	func dragHandleChanged(_ sender: Any!) {
		let handle			= sender as! LDrawDragHandle
		let newPosition		= handle.position()
		let vertexNumber	= handle.tag()

		switch vertexNumber {
			case 1: setPlanePoint1(newPosition)
			case 2: setPlanePoint2(newPosition)
			case 3: setPlanePoint3(newPosition)
			default: break
		}
	}//end dragHandleChanged:


	// MARK: - Utilities

	//========== lineIsTextureFallback: ============================================
	//
	// Purpose:		Returns if line is a 0 !TEXMAP FALLBACK
	//
	//==============================================================================
	@objc(lineIsTextureFallback:)
	class func lineIsTextureFallback(_ line: String!) -> Bool {
		var parsedField: NSString?	= nil
		var workingLine: NSString?	= line as NSString?
		var isEnd					= false

		parsedField = readNextField(workingLine, remainder: &workingLine)
		if fieldIs(parsedField, "0") {
			parsedField = readNextField(workingLine, remainder: &workingLine)

			if fieldIs(parsedField, LDRAW_TEXTURE) {
				parsedField = readNextField(workingLine, remainder: &workingLine)
				if fieldIs(parsedField, LDRAW_TEXTURE_FALLBACK) {
					isEnd = true
				}
			}
		}

		return isEnd
	}


	//========== lineIsTextureBeginning: ===========================================
	//
	// Purpose:		Returns if line is a 0 !TEXMAP START
	//
	//==============================================================================
	@objc(lineIsTextureBeginning:)
	class func lineIsTextureBeginning(_ line: String!) -> Bool {
		var parsedField: NSString?	= nil
		var workingLine: NSString?	= line as NSString?
		var isStart					= false

		parsedField = readNextField(workingLine, remainder: &workingLine)
		if fieldIs(parsedField, "0") {
			parsedField = readNextField(workingLine, remainder: &workingLine)

			if fieldIs(parsedField, LDRAW_TEXTURE) {
				parsedField = readNextField(workingLine, remainder: &workingLine)
				if		fieldIs(parsedField, LDRAW_TEXTURE_START)
					||	fieldIs(parsedField, LDRAW_TEXTURE_NEXT) {
					parsedField = readNextField(workingLine, remainder: &workingLine)
					if fieldIs(parsedField, LDRAW_TEXTURE_METHOD_PLANAR) {
						isStart = true
					}
				}
			}
		}

		return isStart
	}


	//========== lineIsTextureTerminator: ==========================================
	//
	// Purpose:		Returns if line is a 0 !TEXMAP END
	//
	//==============================================================================
	@objc(lineIsTextureTerminator:)
	class func lineIsTextureTerminator(_ line: String!) -> Bool {
		var parsedField: NSString?	= nil
		var workingLine: NSString?	= line as NSString?
		var isEnd					= false

		parsedField = readNextField(workingLine, remainder: &workingLine)
		if fieldIs(parsedField, "0") {
			parsedField = readNextField(workingLine, remainder: &workingLine)

			if fieldIs(parsedField, LDRAW_TEXTURE) {
				parsedField = readNextField(workingLine, remainder: &workingLine)
				if fieldIs(parsedField, LDRAW_TEXTURE_END) {
					isEnd = true
				}
			}
		}

		return isEnd
	}


	//========== parsePlanarTextureFromLine: =======================================
	//
	// Purpose:		Pulls out the fields of a planar texture.
	//
	//==============================================================================
	@objc(parsePlanarTextureFromLine:parentGroup:)
	func parsePlanarTexture(fromLine line: String!, parentGroup: dispatch_group_t!) -> Bool {
		// (+scannerWithString:nil raised; every caller passes a line.)
		let scanner	= Scanner(string: line ?? "")
		let utf16	= scanner.utf16

		if utf16.scanString("0", into: nil) == false {
			return false
		}

		if utf16.scanString(LDRAW_TEXTURE, into: nil) == false {
			return false
		}

		if		utf16.scanString(LDRAW_TEXTURE_START, into: nil) == false
			&&	utf16.scanString(LDRAW_TEXTURE_NEXT, into: nil) == false {
			return false
		}

		if utf16.scanString(LDRAW_TEXTURE_METHOD_PLANAR, into: nil) == false {
			return false
		}

		//---------- Coordinates -----------------------------------------------
		// (Each scan writes straight into the plane point, as the ObjC did, so a
		// header that stops part-way keeps the fields read before it: S33.)

		if utf16.scanFloat(&planePoint1.x) == false {
			return false
		}

		if utf16.scanFloat(&planePoint1.y) == false {
			return false
		}

		if utf16.scanFloat(&planePoint1.z) == false {
			return false
		}


		if utf16.scanFloat(&planePoint2.x) == false {
			return false
		}

		if utf16.scanFloat(&planePoint2.y) == false {
			return false
		}

		if utf16.scanFloat(&planePoint2.z) == false {
			return false
		}


		if utf16.scanFloat(&planePoint3.x) == false {
			return false
		}

		if utf16.scanFloat(&planePoint3.y) == false {
			return false
		}

		if utf16.scanFloat(&planePoint3.z) == false {
			return false
		}

		//---------- Name ------------------------------------------------------
		// TEXMAP has different syntax from linetype 1 because Joshua Delahunty
		// wouldn't consider synchronizing the two.
		// scanQuotableToken: raises when there is no token (utilities golden);
		// that used to be caught here and reported as a syntax error.
		// (A name ending in \" at the end of the line hangs it: BUG-034.)
		if QuotableTokenIsMissing(scanner) {
			return false
		}
		let parsedName = LDrawUtilities.scanQuotableToken(scanner) as NSString?
		if (parsedName?.length ?? 0) == 0 {
			return false
		}
		setImageDisplayName(parsedName as String?)
		setImageDisplayName(parsedName as String?, parse: true, in: parentGroup)

		//---------- Glossmap --------------------------------------------------
		// It's optional and unused. It should have been on a separate TEXMAP
		// line so we didn't have to even bother with it. See above for reason
		// it's not.
		if utf16.scanString(LDRAW_TEXTURE_GLOSSMAP, into: nil) {
			if QuotableTokenIsMissing(scanner) {
				return false
			}
			let parsedGlossmapName = LDrawUtilities.scanQuotableToken(scanner) as NSString?
			if (parsedGlossmapName?.length ?? 0) == 0 {
				return false
			}

			setGlossmapName(parsedGlossmapName as String?)
		}

		return true

	}


	//========== flattenIntoLines:triangles:quadrilaterals:other:currentColor: =====
	//
	// Purpose:		Appends the directive (or a copy of the directive) into the
	//				appropriate container.
	//
	//==============================================================================
	@objc(flattenIntoLines:triangles:quadrilaterals:other:currentColor:currentTransform:normalTransform:recursive:)
	override func flatten(intoLines lines: NSMutableArray!, triangles: NSMutableArray!, quadrilaterals: NSMutableArray!,
						  other everythingElse: NSMutableArray!, currentColor parentColor: LDrawColor!,
						  currentTransform transform: Matrix4, normalTransform: Matrix3, recursive: Bool) {
		planePoint1 = V3MulPointByProjMatrix(planePoint1, transform)
		planePoint2 = V3MulPointByProjMatrix(planePoint2, transform)
		planePoint3 = V3MulPointByProjMatrix(planePoint3, transform)

		if recursive == true {
			let texLines			= NSMutableArray()
			let texTriangles		= NSMutableArray()
			let texQuadrilaterals	= NSMutableArray()
			let texEverythingElse	= NSMutableArray()

			var directiveCount		= 0
			var counter				= 0

			// Traverse the entire hiearchy of part references and sort out each
			// primitive type into a flat list. This allows staggering speed increases.
			for case let directive as LDrawDirective in subdirectives() ?? NSMutableArray() {
				directive.flatten(intoLines: texLines,
								  triangles: texTriangles,
								  quadrilaterals: texQuadrilaterals,
								  other: texEverythingElse,
								  currentColor: parentColor,
								  currentTransform: transform,
								  normalTransform: normalTransform,
								  recursive: recursive)
			}

			// Remove all existing directives
			directiveCount = subdirectives()?.count ?? 0
			counter = directiveCount - 1
			while counter >= 0 {
				removeDirective(at: counter)
				counter -= 1
			}

			fallback = nil

			// Add back all the flattened geometry

			for directive in texLines {
				add(directive as? LDrawDirective)
			}

			for directive in texTriangles {
				add(directive as? LDrawDirective)
			}

			for directive in texQuadrilaterals {
				add(directive as? LDrawDirective)
			}

			for directive in texEverythingElse {
				add(directive as? LDrawDirective)
			}
		}

		// Textures are responsible for drawing their own geometry. We reveal only
		// ourself to the parent, not our child geometry.
		everythingElse?.add(self)

	}//end flattenIntoLines:triangles:quadrilaterals:other:currentColor:
}
