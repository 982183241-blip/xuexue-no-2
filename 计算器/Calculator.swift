import AppKit

struct Calculator {
    var value = "0"
    var left: Double = 0
    var pending: String?
    var fresh = true
    var error: String?
    var display: String { error ?? value }

    mutating func press(_ key: String) {
        switch key {
        case "清空":
            self = Calculator()
        case "⌫":
            if error != nil { self = Calculator() }
            if !fresh {
                value.removeLast()
                if value.isEmpty { value = "0" }
            }
        case "+", "−", "×", "÷":
            guard error == nil else { return }
            if pending != nil && !fresh { evaluate() }
            guard error == nil else { return }
            left = Double(value) ?? 0
            pending = key
            fresh = true
        case "=":
            if pending != nil && !fresh && error == nil { evaluate() }
        default:
            guard key == "." || (key.count == 1 && "0123456789".contains(key)) else { return }
            if error != nil { self = Calculator() }
            if fresh { value = "0" }
            fresh = false
            if key == "." {
                if !value.contains(".") { value += "." }
            } else if value.count < 15 {
                value = value == "0" ? key : value + key
            }
        }
    }

    private mutating func evaluate() {
        let right = Double(value) ?? 0
        let result: Double
        switch pending {
        case "+": result = left + right
        case "−": result = left - right
        case "×": result = left * right
        case "÷": result = left / right
        default: return
        }
        if result.isFinite {
            value = result == 0 ? "0" : String(format: "%.15g", result)
        } else {
            error = pending == "÷" && right == 0 ? "除数不能为 0" : "结果超出范围"
        }
        pending = nil
        fresh = true
    }
}

private let themeNames = ["暖浅绿", "雾霾蓝", "暖杏色", "淡紫色"]
private var themeIndex = 0

private func rgb(_ hex: UInt32) -> NSColor {
    let palette: [UInt32: [UInt32]] = [
        0xD7E9CD: [0xD7E9CD, 0xD6E7F5, 0xF5DAC4, 0xE6DCF5],
        0xFAF4E3: [0xFAF4E3, 0xF0F6FB, 0xFFF5E6, 0xFBF4FC],
        0xBED9A8: [0xBED9A8, 0xAFCDE6, 0xEDBD97, 0xD4BCE9],
        0xE0EDD3: [0xE0EDD3, 0xDEEBF7, 0xF8E2D0, 0xEDE0F7],
        0xE9EFDC: [0xE9EFDC, 0xE7EFF7, 0xF6E7DB, 0xF0E8F6],
        0x829B73: [0x829B73, 0x839FB8, 0xB18B6D, 0xA78CB8]
    ]
    let hex = palette[hex]?[themeIndex] ?? hex
    return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

final class CalculatorBackground: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(starting: rgb(0xD7E9CD), ending: rgb(0xFAF4E3))?.draw(in: bounds, angle: 48)
    }
}

final class CalculatorKey: NSButton {
    private static let click = Bundle.main.url(forResource: "click", withExtension: "wav")
        .flatMap { NSSound(contentsOf: $0, byReference: false) }

    override func mouseDown(with event: NSEvent) {
        Self.click?.stop()
        Self.click?.play()
        super.mouseDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        let base = bounds.insetBy(dx: 0.5, dy: 0.5)
        let face = NSRect(x: base.minX, y: base.minY + (isHighlighted ? 1 : 4),
                          width: base.width, height: base.height - 4)
        let shape = NSBezierPath(roundedRect: face, xRadius: 12, yRadius: 12)
        rgb(0x829B73).setFill()
        NSBezierPath(roundedRect: base, xRadius: 12, yRadius: 12).fill()
        let isEqual = title == "="
        let isOperator = ["÷", "×", "−", "+"].contains(title)
        let isUtility = title == "清空" || title == "⌫"
        let background: UInt32 = isEqual ? 0xBED9A8 : isOperator ? 0xE0EDD3 : isUtility ? 0xE9EFDC : 0xFFFDF5
        rgb(background).setFill()
        shape.fill()
        rgb(0x637B59).withAlphaComponent(0.19).setStroke()
        shape.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: isUtility ? 15 : 22, weight: .semibold),
            .foregroundColor: rgb(isEqual ? 0x263F24 : 0x304631)
        ]
        let label = title as NSString
        let size = label.size(withAttributes: attributes)
        label.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: face.midY - size.height / 2),
                   withAttributes: attributes)
    }
}

final class CalculatorWindow: NSWindow {
    var handleKey: ((String) -> Void)?

    override func keyDown(with event: NSEvent) {
        let keys = ["-": "−", "*": "×", "/": "÷", "\r": "=", "\u{3}": "=",
                    "\u{1b}": "清空", "\u{7f}": "⌫"]
        if let character = event.characters, character.count == 1,
           let key = keys[character] ?? ("0123456789.+= ".contains(character) && character != " " ? character : nil) {
            handleKey?(key)
        } else {
            super.keyDown(with: event)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: CalculatorWindow?
    private var calculator = Calculator()
    private let display = NSTextField(labelWithString: "0")
    private let operation = NSTextField(labelWithString: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = CalculatorWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 444),
                                      styleMask: [.titled, .closable, .miniaturizable],
                                      backing: .buffered, defer: false)
        window.title = "计算器 1.0"
        window.isReleasedWhenClosed = false
        window.handleKey = { [weak self] in self?.press($0) }
        let content = CalculatorBackground()
        window.contentView = content

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20)
        ])

        themeIndex = min(max(UserDefaults.standard.integer(forKey: "ColorTheme"), 0), themeNames.count - 1)
        let settings = NSPopUpButton(frame: .zero, pullsDown: true)
        settings.addItem(withTitle: "设置")
        settings.addItems(withTitles: themeNames)
        for (index, item) in settings.itemArray.dropFirst().enumerated() {
            item.tag = index
            item.target = self
            item.action = #selector(changeTheme(_:))
            item.state = index == themeIndex ? .on : .off
        }
        stack.addArrangedSubview(settings)

        let screen = NSView()
        screen.wantsLayer = true
        screen.layer?.backgroundColor = rgb(0xFFFBEF).cgColor
        screen.layer?.cornerRadius = 16
        screen.layer?.borderWidth = 1
        screen.layer?.borderColor = rgb(0x829B73).withAlphaComponent(0.25).cgColor
        stack.addArrangedSubview(screen)

        operation.alignment = .right
        operation.textColor = rgb(0x56704F)
        operation.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        display.alignment = .right
        display.textColor = rgb(0x304631)
        display.font = .monospacedDigitSystemFont(ofSize: 26, weight: .medium)
        display.setAccessibilityLabel("当前数值")
        for label in [operation, display] {
            label.translatesAutoresizingMaskIntoConstraints = false
            screen.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: screen.leadingAnchor, constant: 14),
                label.trailingAnchor.constraint(equalTo: screen.trailingAnchor, constant: -14)
            ])
        }
        NSLayoutConstraint.activate([
            screen.widthAnchor.constraint(equalTo: stack.widthAnchor),
            screen.heightAnchor.constraint(equalToConstant: 86),
            operation.topAnchor.constraint(equalTo: screen.topAnchor, constant: 12),
            operation.heightAnchor.constraint(equalToConstant: 18),
            display.bottomAnchor.constraint(equalTo: screen.bottomAnchor, constant: -12),
            display.heightAnchor.constraint(equalToConstant: 38)
        ])
        stack.setCustomSpacing(14, after: screen)

        let rows = [["清空", "⌫", "÷"], ["7", "8", "9", "×"], ["4", "5", "6", "−"],
                    ["1", "2", "3", "+"], ["0", ".", "="]]
        for keys in rows {
            let row = NSStackView()
            row.orientation = .horizontal
            row.distribution = .fill
            row.spacing = 8
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

            var singleColumn: NSButton?
            var wideButton: NSButton?
            for key in keys {
                let button = CalculatorKey(frame: .zero)
                button.title = key
                button.target = self
                button.action = #selector(buttonPressed(_:))
                button.isBordered = false
                button.setAccessibilityLabel(key == "⌫" ? "退格" : key)
                row.addArrangedSubview(button)
                button.heightAnchor.constraint(equalToConstant: 48).isActive = true

                if key == "清空" || key == "0" {
                    wideButton = button
                } else if let singleColumn {
                    button.widthAnchor.constraint(equalTo: singleColumn.widthAnchor).isActive = true
                } else {
                    singleColumn = button
                }
            }
            if let wideButton, let singleColumn {
                wideButton.widthAnchor.constraint(equalTo: singleColumn.widthAnchor,
                                                  multiplier: 2, constant: row.spacing).isActive = true
            }
        }
        content.layoutSubtreeIfNeeded()
        if CommandLine.arguments.contains("--layout-test") {
            for row in stack.arrangedSubviews.compactMap({ $0 as? NSStackView }) {
                precondition(abs(row.frame.width - 300) < 0.5, "Row width: \(row.frame.width)")
                guard let first = row.arrangedSubviews.first, let last = row.arrangedSubviews.last else {
                    preconditionFailure("Empty row")
                }
                precondition(abs(first.frame.minX) < 0.5 && abs(last.frame.maxX - row.bounds.width) < 0.5,
                             "Buttons must span the full row: \(first.frame), \(last.frame)")
                for button in row.arrangedSubviews {
                    let title = (button as? NSButton)?.title
                    let expected: CGFloat = title == "清空" || title == "0" ? 146 : 69
                    precondition(abs(button.frame.width - expected) < 0.5, "Button width: \(button.frame.width)")
                }
            }
            print("5 keyboard rows checked")
            NSApp.terminate(nil)
            return
        }
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc private func changeTheme(_ sender: NSMenuItem) {
        themeIndex = sender.tag
        UserDefaults.standard.set(themeIndex, forKey: "ColorTheme")
        for item in sender.menu?.items.dropFirst() ?? [].dropFirst() {
            item.state = item === sender ? .on : .off
        }
        if let content = window?.contentView {
            redraw(content)
        }
    }

    private func redraw(_ view: NSView) {
        view.needsDisplay = true
        view.subviews.forEach(redraw)
    }

    @objc private func buttonPressed(_ sender: NSButton) { press(sender.title) }

    private func press(_ key: String) {
        calculator.press(key)
        display.stringValue = calculator.display
        operation.stringValue = calculator.pending.map { "\(String(format: "%.15g", calculator.left)) \($0)" } ?? ""
    }
}

if CommandLine.arguments.contains("--self-test") {
    for (keys, expected) in [
        (["2", "+", "3", "="], "5"), (["0", "−", "3", "="], "-3"),
        (["4", "×", "5", "="], "20"), (["8", "÷", "2", "="], "4"),
        ([".", "1", "+", ".", "2", "="], "0.3"),
        (["1", "÷", "0", "="], "除数不能为 0"),
        (["1", "2", "⌫"], "1"), (["7", "清空"], "0")
    ] {
        var calculator = Calculator()
        keys.forEach { calculator.press($0) }
        precondition(calculator.display == expected)
    }
    print("8 checks passed")
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    let menu = NSMenu()
    let applicationItem = NSMenuItem()
    applicationItem.submenu = NSMenu()
    applicationItem.submenu?.addItem(withTitle: "退出计算器", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    menu.addItem(applicationItem)
    app.mainMenu = menu
    app.run()
}
