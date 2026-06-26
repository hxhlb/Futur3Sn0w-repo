import AppKit
import Foundation

let W: CGFloat = 1200
let H: CGFloat = 400

struct Tweak {
    let id: String; let name: String; let c1: String; let c2: String
}

let tweaks: [Tweak] = [
    .init(id:"com.futur3sn0w.battfx",              name:"BattFX",               c1:"#FFD60A",c2:"#FF9F0A"),
    .init(id:"com.futur3sn0w.batterymirror",       name:"BatteryMirror",        c1:"#5AC8FA",c2:"#007AFF"),
    .init(id:"com.futur3sn0w.ccsupportbatteryfix", name:"CCSupport\nBattery Fix",c1:"#30D158",c2:"#00C7BE"),
    .init(id:"com.futur3sn0w.centerlastrow",       name:"CenterLastRow",        c1:"#BF5AF2",c2:"#5E5CE6"),
    .init(id:"com.futur3sn0w.duowall",             name:"DuoWall",              c1:"#1C1C7E",c2:"#0071E3"),
    .init(id:"com.futur3sn0w.finn",                name:"Finn",                 c1:"#FF375F",c2:"#FF2D55"),
    .init(id:"com.futur3sn0w.muteflash",           name:"MuteFlash",            c1:"#FFD60A",c2:"#FF6B00"),
    .init(id:"com.futur3sn0w.mutemodule",          name:"MuteModule",           c1:"#636366",c2:"#1C1C1E"),
    .init(id:"com.futur3sn0w.noseparators",        name:"NoSeparators",         c1:"#8E8E93",c2:"#48484A"),
    .init(id:"com.futur3sn0w.reroadrunner",        name:"ReRoadRunner",         c1:"#FF9F0A",c2:"#FF3B30"),
    .init(id:"com.futur3sn0w.resettings",          name:"ReSettings",           c1:"#007AFF",c2:"#5856D6"),
    .init(id:"com.futur3sn0w.solert",              name:"Solert",               c1:"#5E5CE6",c2:"#007AFF"),
    .init(id:"com.futur3sn0w.swipeformore7",       name:"SwipeForMore",         c1:"#BF5AF2",c2:"#FF375F"),
    .init(id:"com.futur3sn0w.taptimenneo",         name:"TapTimeNeo",           c1:"#007AFF",c2:"#5E5CE6"),
]

func nsColor(hex: String) -> NSColor {
    let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard h.count == 6, let v = UInt64(h, radix: 16) else { return .white }
    return NSColor(red: CGFloat((v>>16)&0xFF)/255, green: CGFloat((v>>8)&0xFF)/255,
                   blue: CGFloat(v&0xFF)/255, alpha: 1)
}

let iconDir  = "/Users/futur3sn0w/Documents/MoarTweaks/icons"
let outDir   = "/Users/futur3sn0w/Documents/MoarTweaks/banners"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for tweak in tweaks {
    let img = NSImage(size: NSSize(width: W, height: H))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { img.unlockFocus(); continue }

    // ── Gradient background ───────────────────────────────────────────────
    let grad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [nsColor(hex: tweak.c1).cgColor, nsColor(hex: tweak.c2).cgColor] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: 0, y: H),
                           end:   CGPoint(x: W, y: 0),
                           options: [])

    // ── Icon (load from file, draw with shadow) ───────────────────────────
    let iconSize: CGFloat = 260
    let iconX: CGFloat    = 70
    let iconY: CGFloat    = (H - iconSize) / 2

    if let iconImg = NSImage(contentsOfFile: "\(iconDir)/\(tweak.id).png") {
        // Subtle drop shadow
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 24,
                      color: NSColor.black.withAlphaComponent(0.35).cgColor)
        iconImg.draw(in: NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize))
        ctx.restoreGState()
    }

    // ── Wordmark ──────────────────────────────────────────────────────────
    let textX: CGFloat = iconX + iconSize + 52
    let textW: CGFloat = W - textX - 60

    // "by Futur3Sn0w" label above
    let byAttrs: [NSAttributedString.Key: Any] = [
        .font:            NSFont.systemFont(ofSize: 22, weight: .semibold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.55),
        .kern:            2.5 as CFNumber,
    ]
    let byStr = NSAttributedString(string: "MoarTweaks by Futur3Sn0w", attributes: byAttrs)
    let byH = byStr.size().height

    // Tweak name — scale font down if name is long
    let baseFontSize: CGFloat = tweak.name.count > 12 ? 72 : 86
    let nameAttrs: [NSAttributedString.Key: Any] = [
        .font:            NSFont.systemFont(ofSize: baseFontSize, weight: .heavy),
        .foregroundColor: NSColor.white,
    ]
    let nameStr = NSAttributedString(string: tweak.name, attributes: nameAttrs)
    let nameSize = nameStr.boundingRect(
        with: NSSize(width: textW, height: 999),
        options: [.usesLineFragmentOrigin, .usesFontLeading])

    // Stack: byLabel + name, centered vertically
    let stackH = byH + 8 + nameSize.height
    let stackY = (H - stackH) / 2

    byStr.draw(at: NSPoint(x: textX, y: stackY + nameSize.height + 8))
    nameStr.draw(with: NSRect(x: textX, y: stackY, width: textW, height: nameSize.height + 4),
                 options: [.usesLineFragmentOrigin, .usesFontLeading])

    img.unlockFocus()

    if let tiff = img.tiffRepresentation,
       let rep  = NSBitmapImageRep(data: tiff),
       let png  = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(tweak.id).png"))
        print("✓ \(tweak.id)")
    }
}
