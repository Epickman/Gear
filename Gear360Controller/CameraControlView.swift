import SwiftUI

struct CameraControlView: View {
    @StateObject private var previewManager = LivePreviewManager()
    @State private var cameraInfo: CameraInfo?
    @State private var isRecording  = false
    @State private var selectedLens: LensMode = .dual
    @State private var errorMessage: String?
    @State private var isBusy = false

    private let service = Gear360Service.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LivePreviewView(manager: previewManager)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(2, contentMode: .fit)

                controlPanel
            }
            .navigationTitle("Gear 360")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { cameraInfoToolbar }
            .task { await connect() }
        }
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 24) {
            lensSegmentedPicker
            captureButtons
            errorLabel
        }
        .padding(24)
    }

    private var lensSegmentedPicker: some View {
        Picker("Lente", selection: $selectedLens) {
            ForEach(LensMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .disabled(isBusy)
        .onChange(of: selectedLens) { _, mode in
            Task { await applyLensMode(mode) }
        }
    }

    private var captureButtons: some View {
        HStack(spacing: 16) {
            Button { Task { await takePhoto() } } label: {
                Label("Foto", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(isBusy || isRecording)

            Button { Task { await toggleRecording() } } label: {
                Label(
                    isRecording ? "Detener" : "Grabar",
                    systemImage: isRecording ? "stop.fill" : "video.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRecording ? .red : .green)
            .disabled(isBusy)
        }
    }

    @ViewBuilder
    private var errorLabel: some View {
        if let msg = errorMessage {
            Text(msg)
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    private var cameraInfoToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if let info = cameraInfo {
                Text(info.model)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Acciones

    private func connect() async {
        do {
            cameraInfo = try await service.fetchInfo()
            previewManager.start(using: service)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func takePhoto() async {
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await service.takePicture()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleRecording() async {
        isBusy = true
        defer { isBusy = false }
        do {
            if isRecording {
                _ = try await service.stopCapture()
            } else {
                _ = try await service.startCapture()
            }
            isRecording.toggle()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyLensMode(_ mode: LensMode) async {
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await service.setLensMode(mode)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
