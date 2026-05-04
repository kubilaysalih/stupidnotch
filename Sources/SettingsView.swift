import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var manager: OverlayManager
    @State private var startAtLogin: Bool = AppSettings.startAtLogin

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Corners")

                row("Radius") {
                    Picker("", selection: $manager.cornerRadius) {
                        Text("None").tag(0.0)
                        Text("Small").tag(14.0)
                        Text("Medium").tag(22.0)
                        Text("Large").tag(32.0)
                        Text("Huge").tag(48.0)
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }

                row("Style") {
                    Picker("", selection: $manager.cornerStyle) {
                        ForEach(CornerStyle.allCases, id: \.self) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }

                sectionLabel("Behavior")

                row("Start at login") {
                    Toggle("", isOn: $startAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: startAtLogin) { newValue in
                            AppSettings.startAtLogin = newValue
                            setLoginItem(enabled: newValue)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            actionArea
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 300)
        .onAppear { manager.refreshState() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.title3)
            Text("StupidNotch").font(.headline)
            if manager.isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 2)
            }
            Spacer()
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power").foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit")
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        if manager.isApplied {
            Button {
                manager.remove()
            } label: {
                Label("Remove notch mask", systemImage: "rectangle.dashed")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        } else {
            Button {
                manager.apply()
            } label: {
                Label("Apply notch mask", systemImage: "rectangle.topthird.inset.filled")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .disabled(!manager.hasNotch || manager.isProcessing)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if manager.unsupportedWallpaper {
                Label("Dynamic / video wallpaper isn't supported. Switch to a still image first.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if manager.hasNotch {
                Label("Built-in display has a notch", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Label("No notched display detected", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("To change wallpaper while applied: Remove → pick new wallpaper in System Settings → Apply.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.top, 2)
    }

    private func row<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            content()
        }
    }

    private func setLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("StupidNotch: login item error \(error)")
            }
        }
    }
}
