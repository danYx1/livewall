import SwiftUI
import PhotosUI
import UIKit

struct CreateView: View {

    @EnvironmentObject private var model: StudioModel

    @State private var videoItem: PhotosPickerItem?
    @State private var imageItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                mediaPicker

                if model.hasMedia {
                    previewCard
                    optionsCard
                    exportSection
                }

                if let status = model.status {
                    statusCard(status)
                }

                tipCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .onChange(of: videoItem) { _, item in
            guard let item else { return }
            videoItem = nil
            Task { await model.loadVideo(item) }
        }
        .onChange(of: imageItem) { _, item in
            guard let item else { return }
            imageItem = nil
            Task { await model.loadImage(item) }
        }
        .overlay {
            if model.isWorking {
                WorkingOverlay(progress: model.progress)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.hasMedia)
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.gradient)

                Text("LiveWall")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text("Живые обои из вашего видео или фото")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    // MARK: - Выбор медиа

    private var mediaPicker: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $videoItem, matching: .videos, photoLibrary: .shared()) {
                pickerTile(
                    icon: "video.fill",
                    title: "Видео",
                    subtitle: "MP4 · MOV",
                    colors: [Theme.accent, Theme.accent3]
                )
            }

            PhotosPicker(selection: $imageItem, matching: .images, photoLibrary: .shared()) {
                pickerTile(
                    icon: "photo.fill",
                    title: "Фото",
                    subtitle: "JPG · HEIC",
                    colors: [Theme.accent2, .orange]
                )
            }
        }
    }

    private func pickerTile(icon: String, title: String, subtitle: String, colors: [Color]) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                )

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
        )
    }

    // MARK: - Превью

    private var previewCard: some View {
        Group {
            switch model.media {
            case .video(let url, _):
                VideoPreview(url: url, start: model.effectiveStart, duration: model.effectiveLength)
                    .frame(height: 380)

            case .photo(let data):
                Color.clear
                    .frame(height: 380)
                    .overlay {
                        if let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .clipped()

            case .none:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            Label("LIVE", systemImage: "livephoto")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.45)))
                .padding(12)
        }
    }

    // MARK: - Настройки

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if case .video = model.media {
                sliderRow(
                    title: "Начало",
                    value: Binding(
                        get: { model.effectiveStart },
                        set: { model.start = $0 }
                    ),
                    range: 0...max(0.01, model.videoDuration - model.effectiveLength),
                    display: timeLabel(model.effectiveStart)
                )
            }

            sliderRow(
                title: "Длительность",
                value: $model.clipLength,
                range: 1...max(1.05, model.maxClipLength),
                display: timeLabel(model.effectiveLength)
            )

            Divider().overlay(Theme.stroke)

            VStack(alignment: .leading, spacing: 8) {
                Text("Масштаб кадра")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)

                Picker("Масштаб", selection: $model.fillMode) {
                    ForEach(FillMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .card()
    }

    private func sliderRow(title: String,
                           value: Binding<Double>,
                           range: ClosedRange<Double>,
                           display: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)

                Spacer()

                Text(display)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Slider(value: value, in: range)
                .tint(Theme.accent)
        }
    }

    private func timeLabel(_ value: Double) -> String {
        String(format: "%.1f с", value)
    }

    // MARK: - Экспорт

    private var exportSection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await model.export() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "livephoto")
                    Text(model.isWorking ? "Создаём…" : "Сделать Live Photo")
                }
            }
            .buttonStyle(PrimaryButtonStyle(enabled: !model.isWorking))
            .disabled(model.isWorking)

            Text("Готовый Live Photo сохранится в Фотопленку")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: - Статус

    private func statusCard(_ status: StudioModel.Status) -> some View {
        HStack(alignment: .top, spacing: 12) {
            switch status {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Готово! Live Photo в Фотопленке")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Осталось установить его как обои.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)

                    Button("Как установить") {
                        model.showGuide = true
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent3)
                }

            case .failure(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Не получилось")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .card()
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundStyle(.yellow)

            Text("Лучший результат — вертикальное видео 9:19.5 длиной 2–3 секунды. Звук в Live Photo не сохраняется.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

// MARK: - Оверлей прогресса

private struct WorkingOverlay: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 6)
                        .frame(width: 76, height: 76)

                    Circle()
                        .trim(from: 0, to: max(0.02, min(progress, 1)))
                        .stroke(Theme.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(min(progress, 1) * 100))%")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("Собираем Live Photo…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}
