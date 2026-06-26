import AppKit
import Foundation

let SIZE: CGFloat = 512
let CORNER: CGFloat = 110

struct Tweak {
    let id: String; let symbol: String; let c1: String; let c2: String
}

let tweaks: [Tweak] = [
    .init(id:"com.futur3sn0w.battfx",              symbol:"battery.100.bolt",           c1:"#FFD60A",c2:"#FF9F0A"),
    .init(id:"com.futur3sn0w.batterymirror",       symbol:"arrow.2.squarepath",         c1:"#5AC8FA",c2:"#007AFF"),
    .init(id:"com.futur3sn0w.ccsupportbatteryfix", symbol:"wrench.and.screwdriver.fill",c1:"#30D158",c2:"#00C7BE"),
    .init(id:"com.futur3sn0w.centerlastrow",       symbol:"square.grid.3x3.fill",       c1:"#BF5AF2",c2:"#5E5CE6"),
    .init(id:"com.futur3sn0w.duowall",             symbol:"photo.stack.fill",           c1:"#1C1C7E",c2:"#0071E3"),
    .init(id:"com.futur3sn0w.finn",                symbol:"paintpalette.fill",          c1:"#FF375F",c2:"#FF2D55"),
    .init(id:"com.futur3sn0w.muteflash",           symbol:"flashlight.on.fill",         c1:"#FFD60A",c2:"#FF6B00"),
    .init(id:"com.futur3sn0w.mutemodule",          symbol:"speaker.slash.fill",         c1:"#636366",c2:"#1C1C1E"),
    .init(id:"com.futur3sn0w.noseparators",        symbol:"line.horizontal.3",          c1:"#8E8E93",c2:"#48484A"),
    .init(id:"com.futur3sn0w.reroadrunner",        symbol:"hare.fill",                  c1:"#FF9F0A",c2:"#FF3B30"),
    .init(id:"com.futur3sn0w.resettings",          symbol:"chevron.up.chevron.down",    c1:"#007AFF",c2:"#5856D6"),
    .init(id:"com.futur3sn0w.solert",              symbol:"exclamationmark.bubble.fill",c1:"#5E5CE6",c2:"#007AFF"),
    .init(id:"com.futur3sn0w.swipeformore7",       symbol:"arrow.right.circle.fill",    c1:"#BF5AF2",c2:"#FF375F"),
    .init(id:"com.futur3sn0w.taptimenneo",         symbol:"clock.fill",                 c1:"#007AFF",c2:"#5E5CE6"),
]

func nsColor(hex: String) -> NSColor {
    let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard h.count == 6, let v = UInt64(h, radix: 16) else { return .white }
    return NSColor(red: CGFloat((v>>16)&0xFF)/255, green: CGFloat((v>>8)&0xFF)/255,
                   blue: CGFloat(v&0xFF)/255, alpha: 1)
}

let outDir = "/Users/futur3sn0w/Documents/MoarTweaks/icons"

for tweak in tweaks {
    let img = NSImage(size: NSSize(width: SIZE, height: SIZE))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { img.unlockFocus(); continue }

    // Clip to rounded rect
    NSBezierPath(roundedRect: NSRect(x:0,y:0,width:SIZE,height:SIZE),
                 xRadius: CORNER, yRadius: CORNER).addClip()

    // Gradient top-left → bottom-right
    let grad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [nsColor(hex:tweak.c1).cgColor, nsColor(hex:tweak.c2).cgColor] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x:0, y:SIZE),
                           end:   CGPoint(x:SIZE, y:0),
                           options: [])

    // SF Symbol in white, centred
    let cfg = NSImage.SymbolConfiguration(pointSize: 230, weight: .medium)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: tweak.symbol, accessibilityDescription: nil)?
                     .withSymbolConfiguration(cfg) {
        sym.draw(in: NSRect(x: (SIZE - sym.size.width)  / 2,
                            y: (SIZE - sym.size.height) / 2,
                            width: sym.size.width, height: sym.size.height))
    }
    img.unlockFocus()

    if let tiff = img.tiffRepresentation,
       let rep  = NSBitmapImageRep(data: tiff),
       let png  = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(tweak.id).png"))
        print("✓ \(tweak.id)")
    }
}
