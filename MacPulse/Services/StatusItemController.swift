import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let monitor: MonitorStore
    private let onQuit: () -> Void

    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var lastTitleUpdate = Date.distantPast
    private var lastRenderedTitle = ""

    init(
        monitor: MonitorStore,
        onQuit: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.onQuit = onQuit
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 228, height: 160)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: DashboardView(
                monitor: monitor,
                onQuit: onQuit
            )
        )

        installStatusItem()

        monitor.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.updatePresentation(snapshot: snapshot)
            }
            .store(in: &cancellables)
    }

    func showPopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            monitor.setDashboardVisible(true)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        monitor.setDashboardVisible(false)
    }

    private func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "MacPulse — CPU and Memory"
        updatePresentation(snapshot: monitor.snapshot)
    }

    private func updatePresentation(snapshot: SystemSnapshot) {
        guard let button = statusItem?.button else { return }

        let cpuText = "\(Int(snapshot.cpu.usage.rounded()))%"
        let memText = "\(Int(snapshot.memory.usagePercent.rounded()))%"
        let title = "CPU \(cpuText)  RAM \(memText)"

        let now = Date()
        let mayUpdate = lastRenderedTitle.isEmpty || now.timeIntervalSince(lastTitleUpdate) >= 1.0
        guard mayUpdate, title != lastRenderedTitle else { return }

        lastRenderedTitle = title
        lastTitleUpdate = now
        button.title = title
        button.font = NSFont.monospacedDigitSystemFont(
            ofSize: 11.5,
            weight: .medium
        )
        button.setAccessibilityLabel("MacPulse: CPU \(cpuText), RAM \(memText)")
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(from: sender)
        } else {
            showPopover()
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open MacPulse", action: #selector(openFromMenu), keyEquivalent: "")
        let quit = NSMenuItem(title: "Quit MacPulse", action: #selector(quitFromMenu), keyEquivalent: "q")
        [open, quit].forEach { $0.target = self }
        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(quit)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openFromMenu() { showPopover() }
    @objc private func quitFromMenu() { onQuit() }
}
