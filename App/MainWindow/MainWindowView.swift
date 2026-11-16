//
//  MainWindowView.swift
//  W3 — Main window composition: toolbar + process tree + status bar.
//

import SwiftUI
import AppKit
import ProcexpModel
import ProcexpGraphs

struct MainWindowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    /// Focus for the search field so ⌘F / the Find button can jump to it.
    @FocusState private var searchFocused: Bool
    /// W8 — routes context-menu / toolbar commands to `ProcessActions` and
    /// drives the confirmation + error dialogs below. Shared with the menu bar
    /// via `AppModel` so both entry points use one flow.
    private var coordinator: ActionCoordinator { model.actionCoordinator }

    /// Refresh-rate choices (seconds) offered in the toolbar.
    private let refreshChoices: [TimeInterval] = [0.5, 1, 2, 5]

    var body: some View {
        processActionAlertContent
    }

    /// Keep the main layout separate from its presentation modifiers so the
    /// Swift compiler can type-check each layer independently in Release builds.
    private var mainContent: some View {
        VStack(spacing: 0) {
            toolbar
                .fixedSize(horizontal: false, vertical: true)
                .zIndex(1)

            if model.targetWindowPickerActive {
                targetPickerBanner
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !model.helperBannerDismissed, model.helperAvailability == .notInstalled || model.helperAvailability == .awaitingApproval {
                helperBanner
            }

            Divider()
            if model.showLowerPane {
                VSplitView {
                    processTree
                        .frame(minHeight: 180)
                    LowerPaneView()
                        .frame(minHeight: 130, idealHeight: 200)
                }
            } else {
                processTree
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            statusBar
        }
    }

    private var sheetContent: some View {
        @Bindable var model = model
        return mainContent
            .frame(minWidth: 900, minHeight: 500)
            .sheet(isPresented: $model.showRunSheet) {
                RunProcessSheet()
            }
            .sheet(isPresented: $model.showSelectColumnsSheet) {
                SelectColumnsSheet()
                    .environment(model)
            }
            .sheet(isPresented: $model.showSaveColumnSetSheet) {
                SaveColumnSetSheet()
                    .environment(model)
            }
            .sheet(isPresented: $model.showOrganizeColumnSetsSheet) {
                OrganizeColumnSetsSheet()
                    .environment(model)
            }
            .background(SpacePauseMonitor {
                model.togglePause()
            })
            .onChange(of: model.focusSearchToken) {
                searchFocused = true
            }
            .onChange(of: model.processRevealRequestToken) {
                searchFocused = false
            }
            .onChange(of: model.saveRequestToken) {
                model.saveProcessReport()
            }
            .onChange(of: model.exportCSVRequestToken) {
                saveProcessList()
            }
    }

    private var actionDialogContent: some View {
        @Bindable var model = model
        return sheetContent
            .confirmationDialog(
                coordinator.pending?.confirmation.title ?? "",
                isPresented: Binding(
                    get: { coordinator.pending?.presentation == .main },
                    set: { if !$0 && coordinator.pending?.presentation == .main { coordinator.cancel() } }
                ),
                presenting: coordinator.pending
            ) { pending in
                Button(
                    pending.confirmButtonTitle,
                    role: pending.confirmation.destructive ? .destructive : nil
                ) {
                    coordinator.confirm(model: model)
                }
                Button("Cancel", role: .cancel) { coordinator.cancel() }
            } message: { pending in
                Text(pending.confirmation.message)
            }
            .alert(
                coordinator.errorTitle,
                isPresented: Binding(
                    get: { coordinator.errorMessage != nil && coordinator.errorPresentation == .main },
                    set: { if !$0 && coordinator.errorPresentation == .main { coordinator.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { coordinator.errorMessage = nil }
            } message: {
                Text(coordinator.errorMessage ?? "")
            }
    }

    private var targetWindowAlertContent: some View {
        @Bindable var model = model
        return actionDialogContent
            .alert(
                model.targetWindowPickerAlert?.title ?? String(localized: "Window Picker"),
                isPresented: Binding(
                    get: { model.targetWindowPickerAlert != nil },
                    set: { if !$0 { model.targetWindowPickerAlert = nil } }
                )
            ) {
                if model.targetWindowPickerAlert?.offersAccessibilitySettings == true {
                    Button("Open Accessibility Settings") {
                        model.openAccessibilitySettingsForTargetPicker()
                    }
                }
                Button("OK", role: .cancel) { model.targetWindowPickerAlert = nil }
            } message: {
                Text(model.targetWindowPickerAlert?.message ?? "")
            }
    }

    private var processActionAlertContent: some View {
        @Bindable var model = model
        return targetWindowAlertContent
            .alert(
                model.processActionAlert?.title ?? String(localized: "Process Action"),
                isPresented: Binding(
                    get: { model.processActionAlert != nil },
                    set: { if !$0 { model.processActionAlert = nil } }
                )
            ) {
                Button("OK", role: .cancel) { model.processActionAlert = nil }
            } message: {
                Text(model.processActionAlert?.message ?? "")
            }
    }

    /// The process tree, shared between the split and non-split layouts.
    private var processTree: some View {
        ProcessOutlineView(model: model,
                           snapshot: model.snapshot,
                           columns: model.columns,
                           colorRules: model.colorRules,
                           treeMode: model.showProcessTree,
                           treeSortResetToken: model.processTreeSortResetToken,
                           searchText: model.processFilter,
                           revealRequestToken: model.processRevealRequestToken) { command, pid in
            handle(command, pid)
        }
    }

    // MARK: Toolbar

    /// Labeled toolbar: Tree · Properties · Force Quit · Lower Pane, followed by
    /// the live, individually-resizable CPU/Memory/I-O mini graphs and the
    /// filter field.
    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                toolbarActions
                toolbarGraphs
                Spacer(minLength: 8)
                toolbarFilter
            }
            HStack(spacing: 6) {
                toolbarActions
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        toolbarGraphs
                    }
                }
                .frame(minWidth: 28, minHeight: 32, maxHeight: 32)
                Spacer(minLength: 8)
                toolbarFilter
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        .background(.bar)
    }

    private var toolbarActions: some View {
        @Bindable var model = model
        return Group {
            // Save, Refresh, System Information, Find and Find Window's Process
            // live in the menus (File / View / Find); their shortcuts are
            // defined there only.
            iconToggle("tree", label: "Tree", isOn: model.showProcessTree,
                       tip: "Show Process Tree (⌥T)") {
                model.setProcessTreeView(!model.showProcessTree)
            }
            iconButton("props", label: "Properties", tip: "Properties… (⌥↩)",
                       shortcut: .init(.return, modifiers: .option),
                       disabled: model.selection == nil) {
                if let pid = model.selection { openProperties(pid) }
            }
            iconButton("kill", label: "Force Quit",
                       tip: "Force Quit Process using SIGKILL (Forward Delete in the process list)",
                       disabled: model.selection == nil) {
                if let pid = model.selection {
                    coordinator.request(.kill, pid: pid, model: model)
                }
            }

            toolbarDivider

            iconToggle("split", label: "Lower Pane", isOn: model.showLowerPane,
                       tip: "Show Lower Pane (⌘L)") {
                model.showLowerPane.toggle()
            }

            toolbarDivider
        }
    }

    private var toolbarGraphs: some View {
        Group {
            // Live, individually-resizable mini history graphs (CPU · Memory ·
            // I/O), placed to the right of all the icon buttons.
            resizableGraph(index: 0,
                           values: model.cpuHistory.values,
                           maxValue: 100,
                           color: RGBA(0, 200, 0),
                           label: String(localized: "CPU"),
                           value: cpuValue,
                           tip: cpuTip,
                           systemInfoTab: .cpu)
            resizableGraph(index: 1,
                           values: model.memoryHistory.values,
                           maxValue: 100,
                           color: RGBA(230, 120, 40),
                           label: String(localized: "Memory"),
                           value: physicalUsageText(model.snapshot.system),
                           tip: memTip,
                           systemInfoTab: .memory)
            resizableGraph(index: 2,
                           values: model.ioHistory.values,
                           maxValue: max(1, model.ioHistory.values.filter(\.isFinite).max() ?? 1),
                           color: RGBA(70, 140, 240),
                           label: String(localized: "I/O"),
                           value: ioValue,
                           tip: ioTip,
                           systemInfoTab: .io)

        }
    }

    private var toolbarFilter: some View {
        @Bindable var model = model
        return TextField("Filter", text: $model.processFilter)
            .accessibilityIdentifier("process-filter")
            .textFieldStyle(.roundedBorder)
            .frame(width: 200)
            .focused($searchFocused)
    }

    private var toolbarDivider: some View {
        Divider().frame(height: 20)
    }

    private var targetPickerBanner: some View {
        HStack(spacing: 8) {
            Image("target")
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
            Text("Click another app's window to select its owning process. Press Esc or click in Process Explorer to cancel.")
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.35))
                .frame(height: 1)
        }
    }

    /// Explains why other users' / system process values are "-" and offers the next step.
    private var helperBanner: some View {
        let awaiting = model.helperAvailability == .awaitingApproval
        return HStack(spacing: 8) {
            Image(systemName: "lock.shield")
            Text(awaiting ? "Waiting for the privileged helper to be approved in System Settings."
                          : "Other users and system processes show “-” until the privileged helper is installed.")
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            if awaiting {
                Button("Open System Settings") { model.dependencies.loginItem.openSettings() }
            } else {
                Button("Install Privileged Helper…") {
                    let model = model
                    Task { await runHelperInstall(model) }
                }
                .disabled(model.helperChanging)
            }
            Button { model.helperBannerDismissed = true } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .help("Close")
                .accessibilityLabel("Close")
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.35))
                .frame(height: 1)
        }
    }

    /// Icon plus optional text label to its right.
    @ViewBuilder
    private func iconLabel(_ asset: String, _ label: LocalizedStringKey?) -> some View {
        let icon = Image(asset)
            .resizable()
            .interpolation(.high)
            .frame(width: 18, height: 18)
        if let label {
            HStack(spacing: 4) { icon; Text(label).font(.system(size: 12)) }
        } else {
            icon
        }
    }

    /// A plain colored-icon toolbar button.
    @ViewBuilder
    private func iconButton(_ asset: String,
                            label: LocalizedStringKey? = nil,
                            tip: LocalizedStringKey,
                            shortcut: KeyboardShortcut? = nil,
                            disabled: Bool = false,
                            action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            iconLabel(asset, label)
        }
        .accessibilityIdentifier("toolbar-\(asset)")
        if let shortcut {
            button
                .keyboardShortcut(shortcut)
                .buttonStyle(.borderless)
                .disabled(disabled)
                .help(tip)
        } else {
            button
                .buttonStyle(.borderless)
                .disabled(disabled)
                .help(tip)
        }
    }

    /// A colored-icon toggle button that highlights while active.
    private func iconToggle(_ asset: String,
                            label: LocalizedStringKey? = nil,
                            isOn: Bool,
                            tip: LocalizedStringKey,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            iconLabel(asset, label)
                .padding(3)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isOn ? Color.accentColor.opacity(0.30) : Color.clear)
                }
                .accessibilityIdentifier("toolbar-\(asset)")
        }
        .buttonStyle(.borderless)
        .help(tip)
    }

    /// A small live sparkline whose width is bound to `model.graphWidths[index]`
    /// and can be dragged from a trailing resize handle.
    private func resizableGraph(index: Int,
                                values: [Double],
                                maxValue: Double,
                                color: RGBA,
                                label: String,
                                value: String,
                                tip: String,
                                systemInfoTab: SystemInfoTab) -> some View {
        @Bindable var model = model
        return ResizableMiniGraph(
            identifier: "toolbar-graph-\(index)",
            width: $model.graphWidths[index],
            values: values,
            maxValue: maxValue,
            color: color,
            label: label,
            value: value,
            tip: tip,
            action: {
                model.systemInfoTab = systemInfoTab
                openWindow(id: SystemInfoWindow.id)
            }
        )
    }

    private var cpuValue: String {
        let system = model.snapshot.system
        return system.unavailableMetrics.contains(.cpu) ? String(localized: "Unavailable") : String(format: "%.1f%%", system.cpuTotalPercent)
    }

    private var cpuTip: String {
        if model.snapshot.system.unavailableMetrics.contains(.cpu) { return String(localized: "CPU: Unavailable") }
        return String(format: "CPU: %.1f%%", model.snapshot.system.cpuTotalPercent)
    }

    private var memTip: String {
        let s = model.snapshot.system
        guard !s.unavailableMetrics.contains(.memory) else { return String(localized: "Memory: Unavailable") }
        guard s.memoryTotal > 0 else { return String(localized: "Memory") }
        return String(localized: "Memory: \(ByteFormat.bytes(s.memoryUsed)) / \(ByteFormat.bytes(s.memoryTotal))")
    }

    private var ioValue: String {
        let rate = model.ioHistory.latest ?? 0
        return rate.isFinite ? GraphUnit.bytesPerSecond.format(rate) : String(localized: "Unavailable")
    }

    private var ioTip: String {
        let rate = model.ioHistory.latest ?? 0
        guard rate.isFinite else { return String(localized: "I/O (disk + network): Unavailable") }
        return String(localized: "I/O (disk + network): \(GraphUnit.bytesPerSecond.format(rate))")
    }

    /// CSV is a separate raw-metric export, not the displayed text report.
    func saveProcessList() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "processes.csv"
        panel.title = String(localized: "Export Process List")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let csv = processListCSV()
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            model.processActionAlert = ProcessActionAlert(
                title: String(localized: "Could Not Export Process List"),
                message: "\(url.path)\n\n\(error.localizedDescription)"
            )
        }
    }

    /// Export byte counts without substituting resident memory for an unavailable footprint.
    private func processListCSV() -> String {
        Self.processListCSV(model.snapshot)
    }

    static func processListCSV(_ snapshot: ProcessSnapshot) -> String {
        var lines = ["Process,PID,CPU %,Physical Footprint (bytes),Resident Memory (RSS bytes),User"]
        let records = snapshot.processes.values
            .sorted { $0.id.pid < $1.id.pid }
        for r in records {
            func escape(_ s: String) -> String {
                s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r")
                    ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
                    : s
            }
            let row = [
                escape(r.name),
                String(r.id.pid),
                String(format: "%.2f", r.cpuPercent),
                r.physFootprint.map(String.init) ?? "",
                String(r.residentSize),
                escape(r.userName ?? ""),
            ].joined(separator: ",")
            lines.append(row)
        }
        return lines.joined(separator: "\n")
    }

    /// Route a context-menu command to the W8 action layer.
    private func handle(_ command: ProcessCommand, _ pid: ProcessID) {
        switch command {
        case .properties:
            openProperties(pid)
        case .kill:
            coordinator.request(.kill, pid: pid, model: model)
        case .killTree:
            coordinator.request(.killTree, pid: pid, model: model)
        case .suspendResume:
            // Toggle based on the process's current suspended state.
            let suspended = model.snapshot.info(pid)?.flags.contains(.suspended) ?? false
            coordinator.request(suspended ? .resume : .suspend, pid: pid, model: model)
        case .setNice(let nice):
            coordinator.setPriority(pid: pid, nice: nice, model: model)
        case .bringToFront:
            coordinator.request(.bringToFront, pid: pid, model: model)
        case .restart:
            coordinator.request(.restart, pid: pid, model: model)
        case .sample:
            model.sampleProcess(pid)
        case .searchOnline:
            model.searchOnline(forProcess: pid)
        case .checkVirusTotal:
            Task { await model.checkVirusTotal(forProcess: pid) }
        case .copy:
            copyToPasteboard(pid)
        }
    }

    /// Copy a short "name (PID)" description of the process to the clipboard.
    private func copyToPasteboard(_ pid: ProcessID) {
        guard let record = model.snapshot.info(pid) else { return }
        let text = "\(record.name) (PID \(record.id.pid))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Opens (or refocuses) the Process Properties window for a process.
    private func openProperties(_ pid: ProcessID) {
        openWindow(id: PropertiesWindow.id, value: pid)
    }

    // MARK: Status bar

    /// Compact status bar: CPU usage, RAM in use, process count, and RAM usage %, each in
    /// its own spaced segment and updated live from `model.snapshot.system`.
    private var statusBar: some View {
        let system = model.snapshot.system
        return HStack(spacing: 0) {
            statusSegment(String(localized: "RAM In Use"), memoryText(system))
                .help("Active + wired + compressed memory, relative to installed RAM. Not memory pressure or committed memory.")
            statusSeparator
            statusSegment(String(localized: "Processes"), "\(system.processCount)")
            statusSeparator
            colorLegend
            Spacer(minLength: 8)
            statusSegment(String(localized: "Refresh"), refreshLabel)
        }
        .font(.system(size: 11))
        .monospacedDigit()
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(.bar)
    }

    /// One swatch + name per enabled row-colour rule, named as in Settings ▸ Row colors.
    private var colorLegend: some View {
        HStack(spacing: 10) {
            ForEach(model.colorRules.filter(\.isEnabled)) { rule in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(rgba: colorScheme == .dark ? rule.backgroundDark : rule.backgroundLight))
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.primary.opacity(0.3), lineWidth: 0.5))
                        .frame(width: 12, height: 10)
                    Text(ColorSettingsView.name(for: rule.flag))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .fixedSize()
    }

    /// A "Label: value" pair for one status-bar segment.
    private func statusSegment(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .foregroundStyle(.secondary)
            Text(value)
                .accessibilityIdentifier("status-value-\(label)")
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .fixedSize()
    }

    private var statusSeparator: some View {
        Divider().frame(height: 12)
    }

    private var refreshLabel: String {
        model.paused
            ? String(localized: "Paused")
            : (model.refreshInterval < 1
                ? String(format: "%.1fs", model.refreshInterval)
                : "\(Int(model.refreshInterval))s")
    }

    private func memoryText(_ system: SystemStats) -> String {
        guard !system.unavailableMetrics.contains(.memory) else { return String(localized: "Unavailable") }
        guard system.memoryTotal > 0 else { return "—" }
        let used = ByteFormat.bytes(system.memoryUsed)
        let total = ByteFormat.bytes(system.memoryTotal)
        return "\(used) / \(total)"
    }

    /// Physical memory usage as a percentage of installed RAM.
    private func physicalUsageText(_ system: SystemStats) -> String {
        guard !system.unavailableMetrics.contains(.memory) else { return String(localized: "Unavailable") }
        guard system.memoryTotal > 0 else { return "—" }
        let pct = Double(system.memoryUsed) / Double(system.memoryTotal) * 100
        return String(format: "%.0f%%", pct)
    }
}

private struct SpacePauseMonitor: NSViewRepresentable {
    var action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.action = action
        context.coordinator.attach(to: view)
    }

    final class Coordinator {
        var action: () -> Void
        private weak var view: NSView?
        private var monitor: Any?

        init(action: @escaping () -> Void) {
            self.action = action
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }

        func attach(to view: NSView) {
            self.view = view
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      event.window === self.view?.window,
                      event.keyCode == 49,
                      event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                      !Self.isTextInput(event.window?.firstResponder)
                else { return event }
                self.action()
                return nil
            }
        }

        private static func isTextInput(_ responder: Any?) -> Bool {
            var current = responder as? NSResponder
            while let item = current {
                if item is NSTextView || item is NSTextField { return true }
                current = item.nextResponder
            }
            return false
        }
    }
}

/// A live toolbar mini history graph with a draggable trailing resize handle.
/// The graph width is bound to the shared `AppModel.graphWidths` array so each
/// of the three toolbar graphs can be sized independently, and the value
/// persists for the lifetime of the session.
private struct ResizableMiniGraph: View {
    var identifier: String
    @Binding var width: Double
    var values: [Double]
    var maxValue: Double
    var color: RGBA
    var label: String
    var value: String
    var tip: String
    var action: () -> Void

    /// Width captured at the start of a drag so the delta is applied cleanly.
    @State private var dragStartWidth: Double?

    private let minWidth: Double = 28
    private let maxWidth: Double = 320
    /// Matches the toolbar buttons beside the graphs; the top band holds the name and value so they never overlap the plotted line.
    private let graphHeight: CGFloat = 24
    private let labelHeight: CGFloat = 11

    var body: some View {
        HStack(spacing: 2) {
            Button(action: action) {
                VStack(spacing: 0) {
                    Text("\(label) \(value)")
                        .font(.system(size: 9, weight: .medium))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .frame(maxWidth: .infinity, minHeight: labelHeight, maxHeight: labelHeight, alignment: .leading)
                        .background(Color(red: 12 / 255, green: 12 / 255, blue: 12 / 255))
                    SparklineRepresentable(
                        values: values,
                        maxValue: maxValue,
                        lineColor: color,
                        fillColor: RGBA(r: color.r, g: color.g, b: color.b, a: 0.28),
                        backgroundColor: RGBA(12, 12, 12)
                    )
                }
                .frame(width: max(minWidth, width), height: graphHeight)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.primary.opacity(0.25), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
                .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .help(tip)
            .accessibilityLabel(tip)
            .accessibilityIdentifier(identifier)

            resizeHandle
                .accessibilityIdentifier(identifier + "-resize")
        }
    }

    /// A thin trailing grabber; dragging it adjusts this graph's width.
    private var resizeHandle: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.primary.opacity(0.35))
            .frame(width: 3, height: graphHeight - 2)
            .contentShape(Rectangle().inset(by: -6))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartWidth ?? width
                        if dragStartWidth == nil { dragStartWidth = start }
                        width = min(maxWidth, max(minWidth, start + value.translation.width))
                    }
                    .onEnded { _ in dragStartWidth = nil }
            )
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .help("Drag to resize this graph")
    }
}

/// R1 — a simple "Run…" launcher (Procexp File ▸ Run…, ⌘R). Launches an
/// executable path or app with `NSWorkspace` / `Process`.
struct RunProcessSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run")
                .font(.headline)
            Text("Type the path of a program, app, document or folder and it will be opened.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField("/path/to/program or /Applications/App.app", text: $path)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(run)
                Button("Browse…") { browse() }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Run", action: run)
                    .keyboardShortcut(.defaultAction)
                    .disabled(path.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }

    private func run() {
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let url = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        let isApp = url.pathExtension.lowercased() == "app"
        let isExecutable = FileManager.default.isExecutableFile(atPath: url.path)

        if isApp || !isExecutable {
            // Apps, documents and folders — let the workspace open them.
            guard NSWorkspace.shared.open(url) else {
                errorMessage = String(localized: "Could not open: \(url.path)")
                return
            }
            dismiss()
            return
        }
        // A plain executable — launch it directly.
        let process = Process()
        process.executableURL = url
        do {
            try process.run()
            dismiss()
        } catch {
            errorMessage = String(localized: "Could not launch: \(error.localizedDescription)")
        }
    }
}
