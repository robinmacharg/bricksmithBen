//==============================================================================
//
// File:		LDrawColor.swift
//
// Purpose:		Meta-command representing !COLOUR definitions. Color codes are
//				most commonly encountered in ldconfig.ldr, but they may also
//				appear within models for local scope.
//
//				At a high level, colors should be retrieved from a ColorLibrary
//				object.
//
// Notes:		This does NOT conform to LDrawColorable, because we do not want
//				color picker changes affecting the values of these objects.
//
// Modified:	3/16/08 Allen Smith. Creation Date.
//
//				Ported to Swift in P6a. The superclass (LDrawMetaCommand) is
//				still ObjC. LDrawColor.h keeps the LDrawColorT and
//				LDrawColorMaterialT enums and the RGBtoHSV/HSVtoRGB prototypes;
//				those C functions stay in LDrawColor.m.
//
//==============================================================================

import Foundation

/// Four GLfloats laid out like the ObjC ivar `GLfloat colorRGBA[4]`.
private typealias RGBA = (GLfloat, GLfloat, GLfloat, GLfloat)

//========== cInt() ============================================================
//
// Purpose:		The C conversion `(int)aFloat` as it behaves on arm64 (fcvtzs):
//				truncates toward zero, saturates out-of-range values, and gives
//				0 for NaN. Swift's Int32(_:) would trap instead.
//
//==============================================================================
@inline(__always)
private func cInt(_ value: Float) -> Int32 {
	if value.isNaN { return 0 }
	if value >= 2147483648.0 { return Int32.max }
	if value < -2147483648.0 { return Int32.min }
	return Int32(value)
}

////////////////////////////////////////////////////////////////////////////////
//
// Class:	LDrawColor
//
////////////////////////////////////////////////////////////////////////////////
/// Coder keys longer than 15 ASCII bytes. A Swift string literal that long bridges to a freshly
/// allocated NSString on every NSCoder call (shorter ones bridge to tagged pointers); a String
/// wrapping an NSString bridges back to that same object, as the ObjC @"" constants did (P6a perf).
private enum CoderKey {
	static let edgeColorRGBARed		= NSString(string: "edgeColorRGBARed") as String
	static let edgeColorRGBAGreen	= NSString(string: "edgeColorRGBAGreen") as String
	static let edgeColorRGBABlue	= NSString(string: "edgeColorRGBABlue") as String
	static let edgeColorRGBAAlpha	= NSString(string: "edgeColorRGBAAlpha") as String
	static let hasExplicitAlpha		= NSString(string: "hasExplicitAlpha") as String
	static let materialParameters	= NSString(string: "materialParameters") as String
}

@objc(LDrawColor)
final class LDrawColor: LDrawMetaCommand {

	// Defaults are what -[LDrawColor init] set.
	@exclusivity(unchecked) private var code: LDrawColorT			= LDrawColorBogus
	@exclusivity(unchecked) private var rgba: RGBA					= (0, 0, 0, 1)		// range [0.0 - 1.0]
	@exclusivity(unchecked) private var edgeCode: LDrawColorT		= LDrawColorBogus	// == LDrawColorBogus if not used
	@exclusivity(unchecked) private var edgeRGBA: RGBA				= (0, 0, 0, 0)
	private var hasExplicitAlpha			= false
	private var hasLuminance				= false
	private var luminanceValue: UInt8		= 0
	private var materialValue: LDrawColorMaterialT = .none
	private var materialParams: String?		= nil
	private var colorName: String?			= ""

	/// Synthesized, not according to !COLOUR rules. Strong, as in ObjC; the
	/// complement never points back, so there is no cycle.
	private var fakeComplimentColor: LDrawColor?

	private static let ldrawEXEColorTable: [(UInt8, UInt8, UInt8)] = [
		( 51,  51,  51),
		(  0,  51, 178),
		(  0, 127,  51),
		(  0, 181, 166),
		(204,   0,   0),
		(255,  51, 153),
		(102,  51,   0),
		(153, 153, 153),
		(102, 102,  88),
		(  0, 128, 255),
		( 51, 255, 102),
		(171, 253, 249),
		(255,   0,   0),
		(255, 176, 204),
		(255, 229,   0),
		(255, 255, 255),
	]

	// MARK: - Initialization

	//========== init ==============================================================
	//
	// Purpose:		Initialize a new object.
	//
	//==============================================================================
	@objc(init)
	override init() {
		super.init()
	}

	//========== initWithLines:inRange:parentGroup: ================================
	//
	// Purpose:		LDrawDirective's version: -init, then nil when there are no
	//				lines. LDrawColor is parsed through +[LDrawMetaCommand
	//				directiveWithLines:...] and -finishParsing:, so this only keeps
	//				a direct call working.
	//
	//==============================================================================
	@objc(initWithLines:inRange:parentGroup:)
	override convenience init!(lines: [Any]!, in range: NSRange, parentGroup: dispatch_group_t?) {
		self.init()
		if (lines?.count ?? 0) == 0 {
			return nil
		}
	}

	@objc(initWithLines:inRange:)
	override convenience init!(lines: [Any]!, in range: NSRange) {
		self.init(lines: lines, in: range, parentGroup: nil)
	}

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

		code				= LDrawColorT(rawValue: decoder.decodeCInt(forKey: "colorCode"))
		rgba.0				= decoder.decodeFloat(forKey: "colorRGBARed")
		rgba.1				= decoder.decodeFloat(forKey: "colorRGBAGreen")
		rgba.2				= decoder.decodeFloat(forKey: "colorRGBABlue")
		rgba.3				= decoder.decodeFloat(forKey: "colorRGBAAlpha")
		edgeCode			= LDrawColorT(rawValue: decoder.decodeCInt(forKey: "edgeColorCode"))
		edgeRGBA.0			= decoder.decodeFloat(forKey: CoderKey.edgeColorRGBARed)
		edgeRGBA.1			= decoder.decodeFloat(forKey: CoderKey.edgeColorRGBAGreen)
		edgeRGBA.2			= decoder.decodeFloat(forKey: CoderKey.edgeColorRGBABlue)
		edgeRGBA.3			= decoder.decodeFloat(forKey: CoderKey.edgeColorRGBAAlpha)
		hasExplicitAlpha	= decoder.decodeBool(forKey: CoderKey.hasExplicitAlpha)
		hasLuminance		= decoder.decodeBool(forKey: "hasLuminance")
		luminanceValue		= UInt8(truncatingIfNeeded: decoder.decodeCInt(forKey: "luminance"))
		materialValue		= LDrawColorMaterialT(rawValue: decoder.decodeCInt(forKey: "material")) ?? .none
		materialParams		= decoder.decodeObject(forKey: CoderKey.materialParameters) as? String
		colorName			= decoder.decodeObject(forKey: "name") as? String
	}

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

		encoder.encodeCInt(code.rawValue,				forKey: "colorCode")
		encoder.encode(rgba.0,							forKey: "colorRGBARed")
		encoder.encode(rgba.1,							forKey: "colorRGBAGreen")
		encoder.encode(rgba.2,							forKey: "colorRGBABlue")
		encoder.encode(rgba.3,							forKey: "colorRGBAAlpha")
		encoder.encodeCInt(edgeCode.rawValue,			forKey: "edgeColorCode")
		encoder.encode(edgeRGBA.0,						forKey: CoderKey.edgeColorRGBARed)
		encoder.encode(edgeRGBA.1,						forKey: CoderKey.edgeColorRGBAGreen)
		encoder.encode(edgeRGBA.2,						forKey: CoderKey.edgeColorRGBABlue)
		encoder.encode(edgeRGBA.3,						forKey: CoderKey.edgeColorRGBAAlpha)
		encoder.encode(hasExplicitAlpha,				forKey: CoderKey.hasExplicitAlpha)
		encoder.encode(hasLuminance,					forKey: "hasLuminance")
		encoder.encodeCInt(Int32(luminanceValue),		forKey: "luminance")
		encoder.encodeCInt(materialValue.rawValue,		forKey: "material")
		encoder.encode(materialParams as NSString?,		forKey: CoderKey.materialParameters)
		encoder.encode(colorName as NSString?,			forKey: "name")
	}

	//========== copyWithZone: =====================================================
	//
	// Purpose:		Returns a duplicate of this color.
	//
	// Notes:		Since almost all colors are supposed to be from libraries, and
	//				since copy must be efficient because dictionary keys are copied,
	//				and particularly since equal objects must have the same hash, it
	//				is *VASTLY* easier to return the object itself for its "copy."
	//				The -hash implementation will die if this is not the case.
	//
	//==============================================================================
	@objc(copyWithZone:)
	override func copy(with zone: NSZone? = nil) -> Any {
		return self
	}

	//========== fullCopyWithZone: =================================================
	//
	// Purpose:		Returns a duplicate of this color. Used for creating transparent
	//				versions of a color on the fly.
	//
	//==============================================================================
	@objc(fullCopyWithZone:)
	func fullCopy(with zone: NSZone!) -> Any! {
		let copied = super.copy(with: zone) as! LDrawColor

		copied.code				= self.code
		copied.rgba				= self.rgba
		copied.edgeCode			= self.edgeCode
		copied.edgeRGBA			= self.edgeRGBA
		copied.hasExplicitAlpha	= self.hasExplicitAlpha
		copied.hasLuminance		= self.hasLuminance
		copied.luminanceValue	= self.luminanceValue
		copied.materialValue	= self.materialValue
		copied.setMaterialParameters(self.materialParameters())
		copied.setName(self.name())

		return copied
	}

	//========== finishParsing: ====================================================
	//
	// Purpose:		+[LDrawMetaCommand directiveWithLines:inRange:parentGroup:] is
	//				responsible for parsing out the line code and color command
	//				(i.e., "0 !COLOUR"); now we just have to finish the
	//				color-command specific syntax.
	//
	// Returns:		YES on success; NO on a syntax error. On NO, the fields parsed
	//				before the error are left set on the receiver.
	//
	// Notes:		Scans with NSScanner's own UTF-16 methods (scanner.utf16,
	//				LEARNINGS L101).
	//
	//==============================================================================
	@objc(finishParsing:)
	override func finishParsing(_ scanner: Scanner!) -> Bool {
		let ns						= scanner.utf16
		var field: NSString?		= nil
		var scannedInt: Int32		= 0
		var scannedAlpha: Int32		= 0
		var scannedLuminance: Int32	= 0

		scanner.charactersToBeSkipped = .whitespaces

		// Name
		_ = ns.scanUpToCharacters(from: .whitespaces, into: &field)
		setName(field as String?)

		// Color Code
		if ns.scanString(LDRAW_COLOR_DEF_CODE, into: nil) == false {
			return false // syntax error: fields parsed so far are kept (KNOWN-BUGS S1)
		}
		scannedInt = code.rawValue
		let gotCode = ns.scanInt(&scannedInt)
		code = LDrawColorT(rawValue: scannedInt)
		if gotCode == false {
			return false // syntax error: fields parsed so far are kept (KNOWN-BUGS S1)
		}

		// Color Components
		if ns.scanString(LDRAW_COLOR_DEF_VALUE, into: nil) == false {
			return false // syntax error: fields parsed so far are kept (KNOWN-BUGS S1)
		}
		guard let parsedRGBA = Self.scanHexRGBA(scanner) else {
			return false // syntax error: fields parsed so far are kept (KNOWN-BUGS S1)
		}
		rgba = parsedRGBA

		// Edge
		if ns.scanString(LDRAW_COLOR_DEF_EDGE, into: nil) == false {
			return false // syntax error: fields parsed so far are kept (KNOWN-BUGS S1)
		}
		if let parsedColor = Self.scanHexRGBA(scanner) {
			edgeRGBA = parsedColor
			edgeCode = LDrawColorBogus
		}
		else {
			scannedInt = edgeCode.rawValue
			_ = ns.scanInt(&scannedInt)
			edgeCode = LDrawColorT(rawValue: scannedInt)
		}

		// Optional Fields

		// - Alpha
		if ns.scanString(LDRAW_COLOR_DEF_ALPHA, into: nil) == true {
			_ = ns.scanInt(&scannedAlpha)
			rgba.3				= Float(scannedAlpha) / 255
			hasExplicitAlpha	= true
		}

		// - Luminance
		if ns.scanString(LDRAW_COLOR_DEF_LUMINANCE, into: nil) == true {
			_ = ns.scanInt(&scannedLuminance)
			setLuminance(UInt8(truncatingIfNeeded: scannedLuminance))
		}

		// - Material
		if ns.scanString(LDRAW_COLOR_DEF_MATERIAL_CHROME, into: nil) == true {
			setMaterial(.chrome)
		}
		else if ns.scanString(LDRAW_COLOR_DEF_MATERIAL_PEARLESCENT, into: nil) == true {
			setMaterial(.pearlescent)
		}
		else if ns.scanString(LDRAW_COLOR_DEF_MATERIAL_RUBBER, into: nil) == true {
			setMaterial(.rubber)
		}
		else if ns.scanString(LDRAW_COLOR_DEF_MATERIAL_MATTE_METALLIC, into: nil) == true {
			setMaterial(.matteMetallic)
		}
		else if ns.scanString(LDRAW_COLOR_DEF_MATERIAL_METAL, into: nil) == true {
			setMaterial(.metal)
		}
		else if ns.scanString(LDRAW_COLOR_DEF_MATERIAL_CUSTOM, into: nil) == true {
			setMaterial(.custom)

			// eat whitespace
			scanner.charactersToBeSkipped = nil
			_ = ns.scanCharacters(from: .whitespaces, into: nil)

			// Custom material parameters are implementation-defined and follow the
			// MATERIAL keyword. Just scan them and save them; we can't do anything
			// with them except write them back out when the file is saved.
			let rest = (scanner.string as NSString).substring(from: ns.location())
			setMaterialParameters(rest)
		}

		return true
	}

	//---------- blendedColorForCode: ------------------------------------[static]--
	//
	// Purpose:		Returns pseduocolors according to logic found in LDRAW.EXE.
	//
	// Notes:		James Jessiman's original DOS-based LDraw was limited to 16
	//				colors, so he dithered two colors in a checkerboard to get more.
	//				Part authors used these dithered colors for some stickers and
	//				printed bricks, so Bricksmith supports them strictly for display.
	//				It will NOT show them in its color picker.
	//
	//------------------------------------------------------------------------------
	@objc(blendedColorForCode:)
	class func blendedColor(forCode colorCode: LDrawColorT) -> LDrawColor! {
		let blendedColor = LDrawColor()

		// Find the two base indexes of the blended color's dither.
		let blendCode1 = Int((colorCode.rawValue &- 256) / 16) // div (integer division)
		let blendCode2 = Int((colorCode.rawValue &- 256) % 16)
		let color1 = ldrawEXEColorTable[blendCode1]
		let color2 = ldrawEXEColorTable[blendCode2]

		// Derive the components. Hold your nose.
		// Obviously, we don't support dithering. We average the colors to produce
		// something which looks nicer.
		blendedColor.code = colorCode
		blendedColor.rgba = (Float(Int(color1.0) + Int(color2.0)) / 2 / 255, // red
							 Float(Int(color1.1) + Int(color2.1)) / 2 / 255, // green
							 Float(Int(color1.2) + Int(color2.2)) / 2 / 255, // blue
							 1.0)                                            // alpha
		blendedColor.setName("BlendedColor\(colorCode.rawValue)")

		return blendedColor
	}

	// MARK: - Directives

	//========== draw:viewScale:parentColor: =======================================
	//
	// Purpose:		"Draws" the color.
	//
	//==============================================================================
	@objc(draw:viewScale:parentColor:)
	override func draw(_ optionsMask: UInt, viewScale scaleFactor: Float, parentColor: LDrawColor!) {
		// Need to add this color to the model's color library.
		let colorLibrary = enclosingDirective()?.enclosingModel()?.colorLibrary()

		colorLibrary?.addColor(self)
	}

	//========== write =============================================================
	//
	// Purpose:		Returns a line that can be written out to a file.
	//				Line format:
	//				0 !COLOUR name CODE x VALUE v EDGE e [ALPHA a] [LUMINANCE l]
	//					[ CHROME | PEARLESCENT | RUBBER | MATTE_METALLIC |
	//					  METAL | MATERIAL <params> ]
	//
	// Notes:		This does not try to preserve spacing a la ldconfig.ldr.
	//				A nil name or nil material parameters print "(null)", as %@ did.
	//
	//==============================================================================
	@objc(write)
	override func write() -> String! {
		var line = "0 \(LDRAW_COLOR_DEFINITION) \(colorName ?? "(null)")"
			+ " \(LDRAW_COLOR_DEF_CODE) \(code.rawValue)"
			+ " \(LDRAW_COLOR_DEF_VALUE) \(Self.hexString(rgba.0, rgba.1, rgba.2))"

		if edgeCode == LDrawColorBogus {
			line += " \(LDRAW_COLOR_DEF_EDGE) \(Self.hexString(edgeRGBA.0, edgeRGBA.1, edgeRGBA.2))"
		}
		else {
			line += " \(LDRAW_COLOR_DEF_EDGE) \(edgeCode.rawValue)"
		}

		if hasExplicitAlpha == true {
			line += " \(LDRAW_COLOR_DEF_ALPHA) \(cInt(rgba.3 * 255))"
		}

		if hasLuminance == true {
			line += " \(LDRAW_COLOR_DEF_LUMINANCE) \(luminanceValue)"
		}

		switch materialValue {
		case .none:
			break
		case .chrome:
			line += " \(LDRAW_COLOR_DEF_MATERIAL_CHROME)"
		case .pearlescent:
			line += " \(LDRAW_COLOR_DEF_MATERIAL_PEARLESCENT)"
		case .rubber:
			line += " \(LDRAW_COLOR_DEF_MATERIAL_RUBBER)"
		case .matteMetallic:
			line += " \(LDRAW_COLOR_DEF_MATERIAL_MATTE_METALLIC)"
		case .metal:
			line += " \(LDRAW_COLOR_DEF_MATERIAL_METAL)"
		case .custom:
			line += " \(LDRAW_COLOR_DEF_MATERIAL_CUSTOM) \(materialParams ?? "(null)")"
		@unknown default:
			break
		}

		return line
	}

	// MARK: - Display

	//========== browsingDescription ===============================================
	//
	// Purpose:		Returns a representation of the directive as a short string
	//				which can be presented to the user.
	//
	//==============================================================================
	@objc(browsingDescription)
	override func browsingDescription() -> String! {
		name()
	}

	//========== iconName ==========================================================
	@objc(iconName)
	override func iconName() -> String! {
		"ColorDroplet"
	}

	//========== inspectorClassName ================================================
	@objc(inspectorClassName)
	override func inspectorClassName() -> String! {
		nil
	}

	// MARK: - Accessors

	//========== alpha =============================================================
	@objc(alpha)
	func alpha() -> GLfloat {
		rgba.3
	}

	//========== colorCode =========================================================
	@objc(colorCode)
	func colorCode() -> LDrawColorT {
		code
	}

	//========== complimentColor ===================================================
	//
	// Purpose:		Returns the color which should be used for drawing
	//				LDrawEdgeColor for this color.
	//
	// Notes:		LDConfig compliment colors look ugly. Bricksmith uses
	//				internally-derived compliments which look more like the
	//				original LDraw. Created once and cached.
	//
	//==============================================================================
	@objc(complimentColor)
	func compliment() -> LDrawColor! {
		if let cached = fakeComplimentColor {
			return cached
		}

		let complement = LDrawColor()
		var original = rgba
		var fakeComplimentComponents: RGBA = (0, 0, 0, 0)
		withUnsafePointer(to: &original) { originalPointer in
			withUnsafeMutablePointer(to: &fakeComplimentComponents) { outPointer in
				complimentColor(UnsafeRawPointer(originalPointer).assumingMemoryBound(to: GLfloat.self),
								UnsafeMutableRawPointer(outPointer).assumingMemoryBound(to: GLfloat.self))
			}
		}
		complement.code = LDrawEdgeColor
		complement.rgba = fakeComplimentComponents

		fakeComplimentColor = complement
		return complement
	}

	//========== edgeColorCode =====================================================
	//
	// Purpose:		Return the LDraw color code to be used when drawing the
	//				compilement of this color. If the compliment is stored as actual
	//				components instead, this call will return LDrawColorBogus. When
	//				that code is encountered, you should instead call edgeColorRGBA
	//				for the actual color values.
	//
	//==============================================================================
	@objc(edgeColorCode)
	func edgeColorCode() -> LDrawColorT {
		edgeCode
	}

	//========== getColorRGBA: =====================================================
	//
	// Purpose:		Fills the inComponents array with the RGBA components of this
	//				color.
	//
	//==============================================================================
	@objc(getColorRGBA:)
	func getRGBA(_ inComponents: UnsafeMutablePointer<GLfloat>!) {
		UnsafeMutableRawPointer(inComponents).storeBytes(of: rgba, as: RGBA.self)
	}

	//========== getEdgeColorRGBA: =================================================
	//
	// Purpose:		Returns the actual color components specified for the compliment
	//				of this color.
	//
	// Notes:		These values MAY NOT BE VALID. To determine if they are in
	//				force, you must first call -edgeColorCode. If it returns a value
	//				other than LDrawColorBogus, look up the color for that code
	//				instead. Otherwise, use the values returned by this method.
	//
	//==============================================================================
	@objc(getEdgeColorRGBA:)
	func getEdgeColorRGBA(_ inComponents: UnsafeMutablePointer<GLfloat>!) {
		UnsafeMutableRawPointer(inComponents).storeBytes(of: edgeRGBA, as: RGBA.self)
	}

	//========== localizedName =====================================================
	//
	// Purpose:		Returns the name for the specified color code. If possible, the
	//				name will be localized. For colors which have no localization
	//				defined, this will default to the actual color name from the
	//				config file, with any underscores converted to spaces.
	//
	// Notes:		If, in some bizarre aberration, this color has a code
	//				corresponding to a standard LDraw code, but the color is NOT
	//				actually representing this color, you will get the localized
	//				name of the standard color. Deal with it.
	//
	//==============================================================================
	@objc(localizedName)
	func localizedName() -> String! {
		// Find the color's name in the localized string file.
		// Color names are conveniently keyed.
		let nameKey = "LDraw: \(code.rawValue)"
		var localized: String? = Bundle.main.localizedString(forKey: nameKey, value: "", table: nil)

		// If no localization was defined, then fall back on the name defined in the
		// color directive.
		if localized == nameKey {
			// Since spaces are verboten in !COLOUR directives, color names tend to
			// have a bunch of unsightly underscores in them. We don't want to show
			// that to the user.
			localized = name()?.replacingOccurrences(of: "_", with: " ", options: .literal)
		}

		return localized
	}

	//========== luminance =========================================================
	@objc(luminance)
	func luminance() -> UInt8 {
		luminanceValue
	}

	//========== material ==========================================================
	@objc(material)
	func material() -> LDrawColorMaterialT {
		materialValue
	}

	//========== materialParameters ================================================
	@objc(materialParameters)
	func materialParameters() -> String! {
		materialParams
	}

	//========== name ==============================================================
	@objc(name)
	func name() -> String! {
		colorName
	}

	// MARK: -

	//========== setColorCode: =====================================================
	//
	// Purpose:		Sets the LDraw integer code for this color.
	//
	//==============================================================================
	@objc(setColorCode:)
	func setColorCode(_ newCode: LDrawColorT) {
		code = newCode
	}

	//========== setColorRGBA: =====================================================
	//
	// Purpose:		Sets the actual RGBA component values for this color.
	//
	//==============================================================================
	@objc(setColorRGBA:)
	func setColorRGBA(_ newComponents: UnsafeMutablePointer<GLfloat>!) {
		rgba = UnsafeRawPointer(newComponents).load(as: RGBA.self)
	}

	//========== setEdgeColorCode: =================================================
	//
	// Purpose:		Sets the code of the color to use as this color's compliment
	//				color. That value will have to be resolved by the color library.
	//
	// Notes:		Edge colors may be specified either as real color components or
	//				as a color-code reference. Only one is valid. To signal that the
	//				components should be used instead of this color code, pass
	//				LDrawColorBogus.
	//
	//==============================================================================
	@objc(setEdgeColorCode:)
	func setEdgeColorCode(_ newCode: LDrawColorT) {
		edgeCode = newCode
	}

	//========== setEdgeColorRGBA: =================================================
	//
	// Purpose:		Sets actual color components for the edge color.
	//
	// Notes:		If you call this method, it is assumed you are choosing the
	//				components variation. The edge color code will automatically be
	//				set to LDrawColorBogus.
	//
	//==============================================================================
	@objc(setEdgeColorRGBA:)
	func setEdgeColorRGBA(_ newComponents: UnsafeMutablePointer<GLfloat>!) {
		edgeRGBA = UnsafeRawPointer(newComponents).load(as: RGBA.self)

		// Disable the edge color code, since we have real color values for it now.
		setEdgeColorCode(LDrawColorBogus)
	}

	//========== setLuminance: =====================================================
	//
	// Purpose:		Brightness for colors that glow (range 0-255). Luminance is not
	//				generally used by LDraw renderers (including this one), but may
	//				be used for translation to other rendering systems. LUMINANCE is
	//				optional.
	//
	//==============================================================================
	@objc(setLuminance:)
	func setLuminance(_ newValue: UInt8) {
		luminanceValue	= newValue
		hasLuminance	= true
	}

	//========== setMaterial: ======================================================
	//
	// Purpose:		Sets the material associated with this color.
	//
	// Notes:		Bricksmith doesn't use this value, it just preserves it in the
	//				color directive.
	//
	//==============================================================================
	@objc(setMaterial:)
	func setMaterial(_ newValue: LDrawColorMaterialT) {
		materialValue = newValue
	}

	//========== setMaterialParameters: ============================================
	//
	// Purpose:		Custom (implementation-dependent) values associated with a
	//				custom material.
	//
	//==============================================================================
	@objc(setMaterialParameters:)
	func setMaterialParameters(_ newValue: String!) {
		materialParams = newValue
	}

	//========== setName: ==========================================================
	//
	// Purpose:		Sets the name of the color. Spaces are represented by
	//				underscores.
	//
	//==============================================================================
	@objc(setName:)
	func setName(_ newName: String!) {
		colorName = newName
	}

	// MARK: - Utilities

	//========== isEqual: ==========================================================
	//
	// Purpose:		Allow these objects to serve as keys in a dictionary (used in
	//				LDrawVertexes); -isEqual: and -hash are both required.
	//
	//				We only expect one instance of each unique color to exist, so
	//				the trivial comparison should be valid. After all, two different
	//				(file-local) colors could share the same color code, but they
	//				aren't equal.
	//
	//==============================================================================
	@objc(isEqual:)
	override func isEqual(_ anObject: Any?) -> Bool {
		guard let anObject else { return false }
		return (anObject as AnyObject) === self
	}

	//========== hash ==============================================================
	//
	// Purpose:		Allow these objects to serve as keys in a dictionary (used in
	//				LDrawVertexes). The object's address, as in ObjC.
	//
	//==============================================================================
	@objc(hash)
	override var hash: Int {
		Int(bitPattern: ObjectIdentifier(self))
	}

	//========== compare: ==========================================================
	//
	// Purpose:		Compatibility method directing to our specialized comparison.
	//
	//==============================================================================
	@objc(compare:)
	func compare(_ otherColor: LDrawColor!) -> ComparisonResult {
		hsvaCompare(otherColor)
	}

	//========== HSVACompare: ======================================================
	//
	// Purpose:		Orders colors according to their Hue, Saturation, and
	//				Brightness.
	//
	// Notes:		Both alphas are taken from the receiver, so alpha never breaks a
	//				tie (BUG-037, kept as found).
	//
	//==============================================================================
	@objc(HSVACompare:)
	func hsvaCompare(_ otherColor: LDrawColor!) -> ComparisonResult {
		var ourH: Float = 0, ourS: Float = 0, ourV: Float = 0
		var otherH: Float = 0, otherS: Float = 0, otherV: Float = 0
		let other = otherColor.rgba

		// Convert both to Hue-saturation-brightness
		RGBtoHSV(rgba.0, rgba.1, rgba.2, &ourH, &ourS, &ourV)
		RGBtoHSV(other.0, other.1, other.2, &otherH, &otherS, &otherV)

		// Alpha
		let ourA	= rgba.3
		let otherA	= rgba.3

		// Hue, then Saturation, then Brightness, then Alpha.
		if ourH > otherH { return .orderedDescending }
		if ourH < otherH { return .orderedAscending }
		if ourS > otherS { return .orderedDescending }
		if ourS < otherS { return .orderedAscending }
		if ourV > otherV { return .orderedDescending }
		if ourV < otherV { return .orderedAscending }
		if ourA > otherA { return .orderedDescending }
		if ourA < otherA { return .orderedAscending }
		return .orderedSame
	}

	//========== hexStringForRGB: ==================================================
	//
	// Purpose:		Returns a hex string for the given RGB components, formatted in
	//				the syntax required by the LDraw Colour Definition Language
	//				extension.
	//
	//==============================================================================
	@objc(hexStringForRGB:)
	func hexString(forRGB components: UnsafeMutablePointer<GLfloat>!) -> String! {
		Self.hexString(components[0], components[1], components[2])
	}

	private static func hexString(_ red: GLfloat, _ green: GLfloat, _ blue: GLfloat) -> String {
		String(format: "#%02X%02X%02X", cInt(red * 255), cInt(green * 255), cInt(blue * 255))
	}

	//========== scanHexString:intoRGB: ============================================
	//
	// Purpose:		Parses the given Hexidecimal string into the first three
	//				elements of the components array, dividing each hexidecimal byte
	//				by 255.
	//
	// Notes:		hexString must be prefixed by either "#" or "0x". The LDraw spec
	//				is not clear on the case of the hex letters; we will assume both
	//				are valid.
	//
	// Example:		#77CC00 becomes (R = 0.4666; G = 0.8; B = 0.0)
	//
	//==============================================================================
	@objc(scanHexString:intoRGB:)
	func scanHexString(_ hexScanner: Scanner!, intoRGB components: UnsafeMutablePointer<GLfloat>!) -> Bool {
		guard let parsed = Self.scanHexRGBA(hexScanner) else {
			return false
		}
		UnsafeMutableRawPointer(components).storeBytes(of: parsed, as: RGBA.self)
		return true
	}

	/// The components scanned by -scanHexString:intoRGB:, or nil (nothing written) without a prefix.
	private static func scanHexRGBA(_ hexScanner: Scanner) -> RGBA? {
		let ns					= hexScanner.utf16
		var hexBytes: UInt32	= 0

		// Make sure it has the required prefix, whichever it might be
		guard ns.scanString("#", into: nil) || ns.scanString("0x", into: nil) else {
			return nil
		}

		// Scan the hex bytes into a packed integer, because that's the easiest
		// thing to do with this NSScanner API.
		_ = ns.scanHexInt(&hexBytes)

		// Colors will be stored in the integer as follows: xxRRGGBB
		return (GLfloat((hexBytes >> (2 * 8)) & 0xFF) / 255,	// Red
				GLfloat((hexBytes >> (1 * 8)) & 0xFF) / 255,	// Green
				GLfloat((hexBytes >> (0 * 8)) & 0xFF) / 255,	// Blue
				1.0)											// we shall assume alpha
	}
}
