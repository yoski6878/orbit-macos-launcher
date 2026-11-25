import Cocoa

let candidates = [
    "/System/Library/CoreServices/Finder.app", "/Applications/Safari.app",
    "/System/Applications/Messages.app", "/System/Applications/Mail.app",
    "/System/Applications/Notes.app", "/System/Applications/Calendar.app",
    "/System/Applications/Photos.app", "/System/Applications/Music.app",
    "/Applications/Google Chrome.app", "/Applications/Visual Studio Code.app",
    "/Applications/ChatGPT.app", "/Applications/Claude.app",
    "/Applications/Microsoft Teams.app", "/System/Applications/System Settings.app",
    "/Applications/WhatsApp.app", "/System/Applications/Reminders.app",
    "/Applications/Obsidian.app", "/System/Applications/Utilities/Terminal.app",
    "/System/Applications/FaceTime.app", "/Applications/zoom.us.app",
    "/System/Applications/Shortcuts.app", "/System/Applications/Maps.app",
    "/System/Applications/Books.app", NSHomeDirectory() + "/Downloads"
].filter { FileManager.default.fileExists(atPath: $0) }

final class Dock: NSView {
    let icons = candidates.map { NSWorkspace.shared.icon(forFile: $0) }
    var selected: Int? { didSet { needsDisplay = true } }
    var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
    var radius: CGFloat { min(bounds.width, bounds.height) * 0.48 }
    func point(_ i: Int) -> CGPoint {
        let a = CGFloat.pi / 2 - 2 * .pi * CGFloat(i) / CGFloat(icons.count)
        return CGPoint(x: center.x + radius * 0.859 * cos(a), y: center.y + radius * 0.859 * sin(a))
    }
    func ring(_ r: CGFloat) -> NSRect {
        NSRect(x: center.x - r, y: center.y - r, width: 2*r, height: 2*r)
    }
    override func draw(_ dirtyRect: NSRect) {
        let band = NSBezierPath(ovalIn: ring(radius))
        band.appendOval(in: ring(radius * 0.718))
        band.windingRule = .evenOdd
        NSColor(calibratedWhite: 0.94, alpha: 0.36).setFill()
        band.fill()
        NSColor.white.withAlphaComponent(0.66).setStroke()
        band.lineWidth = 1
        band.stroke()
        for (i, icon) in icons.enumerated() {
            let p = point(i)
            let size = radius * (selected == i ? 0.192 : 0.165)
            if selected == i {
                let diameter = radius * 0.22
                NSColor.white.withAlphaComponent(0.42).setFill()
                NSBezierPath(ovalIn: NSRect(x:p.x-diameter/2,y:p.y-diameter/2,width:diameter,height:diameter)).fill()
            }
            icon.draw(in: NSRect(x:p.x-size/2,y:p.y-size/2,width:size,height:size), from:.zero, operation:.sourceOver, fraction:1)
        }
        if let i = selected {
            let name = URL(fileURLWithPath:candidates[i]).deletingPathExtension().lastPathComponent
            let label = NSAttributedString(string:name, attributes:[.font:NSFont.systemFont(ofSize:15, weight:.medium), .foregroundColor:NSColor.white])
            let s = label.size()
            let box = NSRect(x:center.x-s.width/2-14,y:center.y-s.height/2-7,width:s.width+28,height:s.height+14)
            NSColor.black.withAlphaComponent(0.58).setFill()
            NSBezierPath(roundedRect:box,xRadius:box.height/2,yRadius:box.height/2).fill()
            label.draw(at: CGPoint(x:box.minX+14,y:box.minY+7))
        }
    }
    func index(at e: NSEvent) -> Int? {
        let p = convert(e.locationInWindow, from:nil)
        let d = hypot(p.x-center.x,p.y-center.y)
        guard d >= radius*0.718 && d <= radius else { return nil }
        return icons.indices.min { a,b in
            let u = point(a), v = point(b)
            return hypot(p.x-u.x,p.y-u.y) < hypot(p.x-v.x,p.y-v.y)
        }
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect:.zero,options:[.activeAlways,.inVisibleRect,.mouseMoved,.mouseEnteredAndExited],owner:self,userInfo:nil))
    }
    override func mouseMoved(with e:NSEvent) { selected = index(at:e) }
    override func mouseExited(with e:NSEvent) { selected = nil }
    override func acceptsFirstMouse(for e:NSEvent?) -> Bool { true }
    override func mouseUp(with e:NSEvent) {
        guard let i = index(at:e) else { return }
        openItem(i)
    }
    func openItem(_ i:Int) {
        if NSWorkspace.shared.open(URL(fileURLWithPath:candidates[i])) { window?.orderOut(nil) }
    }
    override var acceptsFirstResponder:Bool { true }
    override func keyDown(with e:NSEvent) {
        switch e.keyCode {
        case 123,126: selected = ((selected ?? 1) + icons.count - 1) % icons.count
        case 124,125: selected = ((selected ?? -1) + 1) % icons.count
        case 36,76: if let i = selected { openItem(i) }
        case 53: window?.orderOut(nil)
        default: super.keyDown(with:e)
        }
    }
}
final class Panel:NSPanel { override var canBecomeKey:Bool { true } }
final class App:NSObject, NSApplicationDelegate {
    var panel:Panel!
    var item:NSStatusItem!
    func applicationDidFinishLaunching(_ notification:Notification) {
        let screen = NSScreen.main!.visibleFrame
        let size = min(780,min(screen.width,screen.height)*0.91)
        panel = Panel(contentRect:NSRect(x:0,y:0,width:size,height:size), styleMask:[.borderless],backing:.buffered,defer:false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace]
        panel.contentView = Dock(frame:NSRect(x:0,y:0,width:size,height:size))
        panel.center()
        item = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName:"circle.circle",accessibilityDescription:"Orbit launcher")
        item.button?.toolTip = "Orbit launcher"
        let menu = NSMenu()
        menu.addItem(withTitle:"Show or Hide Orbit",action:#selector(toggle),keyEquivalent:"").target=self
        menu.addItem(.separator())
        menu.addItem(withTitle:"Quit Orbit",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        item.menu = menu
        show()
    }
    func show() {
        (panel.contentView as? Dock)?.selected = nil
        NSApp.activate(ignoringOtherApps:true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.contentView)
    }
    @objc func toggle() { if panel.isVisible { panel.orderOut(nil) } else { show() } }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool { show(); return true }
}
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
if CommandLine.arguments.contains("--check") {
    let view = Dock(frame:NSRect(x:0,y:0,width:780,height:780))
    let image = view.bitmapImageRepForCachingDisplay(in:view.bounds)!
    view.cacheDisplay(in:view.bounds,to:image)
    try! image.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments.last!))
    print("Rendered",view.icons.count,"launcher icons")
} else { app.run() }
