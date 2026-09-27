import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let monitor: MonitorStore
    private let onQuit: () -> Void

    private let menu = NSMenu()
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

        setupMenu()
        installStatusItem()

        monitor.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.updatePresentation(snapshot: snapshot)
            }
            .store(in: &cancellables)
    }

    func showPopover() {
        guard let button = statusItem?.button else { return }
        statusItem?.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    func menuWillOpen(_ menu: NSMenu) {
        monitor.setDashboardVisible(true)
    }

    func menuDidClose(_ menu: NSMenu) {
        monitor.setDashboardVisible(false)
    }

    private func setupMenu() {
        menu.removeAllItems()
        menu.delegate = self

        let customItem = NSMenuItem()
        let dashboard = DashboardView(
            monitor: monitor,
            onQuit: { [weak self] in
                self?.menu.cancelTracking()
                self?.onQuit()
            }
        )
        let hostingView = InteractiveHostingView(rootView: dashboard)
        hostingView.frame = NSRect(x: 0, y: 0, width: 228, height: 160)
        customItem.view = hostingView
        menu.addItem(customItem)
    }

    private func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.menu = menu

        guard let button = item.button else { return }
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
}

private final class InteractiveHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
