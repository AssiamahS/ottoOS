import SwiftUI
import PhotosUI

struct WallpaperView: View {
    @Environment(AppModel.self) private var model
    @State private var pickerItem: PhotosPickerItem?
    @State private var saving = false
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    preview
                    controls
                }
                .padding()
            }
            .navigationTitle("Wallpaper")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving { ProgressView() } else { Label("Save to Photos", systemImage: "square.and.arrow.down") }
                    }
                    .disabled(saving)
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .glassEffect()
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        model.setBackground(data: data)
                    }
                    pickerItem = nil
                }
            }
        }
    }

    // MARK: Preview

    private var preview: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let ref = LockScreenLayout.referenceSize
            let h = w * ref.height / ref.width
            WallpaperCanvas(agenda: model.agenda, style: model.style, background: model.background, size: ref)
                .scaleEffect(w / ref.width, anchor: .topLeading)
                .frame(width: w, height: h)
                .overlay(alignment: .top) { fakeClock.padding(.top, h * 0.09) }
                .clipShape(RoundedRectangle(cornerRadius: 34))
                .overlay(RoundedRectangle(cornerRadius: 34).stroke(.secondary.opacity(0.3), lineWidth: 1))
        }
        .aspectRatio(LockScreenLayout.referenceSize.width / LockScreenLayout.referenceSize.height, contentMode: .fit)
        .frame(maxWidth: 300)
    }

    private var fakeClock: some View {
        VStack(spacing: 2) {
            Text(Date(), format: .dateTime.weekday(.wide).month().day())
                .font(.system(size: 12, weight: .medium))
            Text(Date(), format: .dateTime.hour().minute())
                .font(.system(size: 56, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.9))
        .shadow(radius: 4)
        .allowsHitTesting(false)
    }

    // MARK: Controls

    private var controls: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 18) {
            GroupBox("Background") {
                HStack {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(model.background == nil ? "Choose photo" : "Change photo", systemImage: "photo")
                    }
                    .buttonStyle(.borderedProminent)
                    if model.background != nil {
                        Button("Use gradient", role: .destructive) { model.clearBackground() }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                }
                VStack(alignment: .leading) {
                    LabeledContent("Dim") { Slider(value: $model.style.dim, in: 0...0.8) }
                    LabeledContent("Blur") { Slider(value: $model.style.blur, in: 0...20) }
                }
            }

            GroupBox("Note block") {
                Picker("Position", selection: $model.style.position) {
                    ForEach(WallpaperStyle.Position.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Ink", selection: $model.style.ink) {
                    ForEach(WallpaperStyle.Ink.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Type", selection: $model.style.typeface) {
                    ForEach(WallpaperStyle.Typeface.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Size") { Slider(value: $model.style.scale, in: 0.8...1.5) }
                Toggle("Show date", isOn: $model.style.showDate)
            }

            GroupBox("Pull from") {
                ForEach(OttoSourceKind.allCases) { kind in
                    Toggle(isOn: Binding(
                        get: { model.style.sources.contains(kind) },
                        set: { on in if on { model.style.sources.insert(kind) } else { model.style.sources.remove(kind) } }
                    )) { Label(kind.label, systemImage: kind.symbol) }
                }
                Stepper("Look ahead: \(model.style.days) day\(model.style.days == 1 ? "" : "s")", value: $model.style.days, in: 1...7)
                    .onChange(of: model.style.days) { _, _ in Task { await model.refresh() } }
                Stepper("Max lines: \(model.style.maxItems)", value: $model.style.maxItems, in: 3...14)
            }

            GroupBox("Refresh it every morning") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The wallpaper is a picture, so it only changes when it is rebuilt. Let Shortcuts do it:")
                    Text("1. Shortcuts → Automation → Time of Day (e.g. 5:00 AM), Run Immediately.\n2. Add action **Make OttoOS Wallpaper**.\n3. Add action **Set Wallpaper** → Lock Screen, input = the wallpaper.\n\nThe Set Wallpaper action only works while your lock screen uses a plain Photo wallpaper (not Photo Shuffle). For live updates during the day, add the OttoOS lock screen widgets instead.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let url = URL(string: "shortcuts://") {
                        Link("Open Shortcuts", destination: url)
                    }
                }
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        guard let image = WallpaperRenderer.render(agenda: model.agenda, style: model.style, background: model.background) else {
            show("Could not render the wallpaper.")
            return
        }
        if let err = await WallpaperRenderer.saveToPhotos(image) {
            show(err)
        } else {
            show("Saved to Photos. Set it under Settings → Wallpaper.")
        }
    }

    private func show(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { toast = nil }
        }
    }
}
