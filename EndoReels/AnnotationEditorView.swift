import SwiftUI
import AVKit

struct AnnotationEditorView: View {
    @Binding var annotations: [TimedAnnotation]
    let videoDuration: Double
    @State private var selectedAnnotationID: UUID?
    @State private var currentTime: Double = 0
    @State private var selectedPreset: AnnotationPreset?
    @State private var selectedType: AnnotationType = .arrow
    @State private var showPresetPicker = false
    @State private var showAnnotationPacks = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toolbar
                toolbar

                Divider()

                // Main content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Quick Add Section
                        quickAddSection

                        // Presets & Packs
                        presetsSection

                        // Timeline
                        timelineSection

                        // Annotation List
                        annotationListSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Annotations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAnnotationPacks) {
                AnnotationPackBrowser(onSelect: { pack in
                    applyAnnotationPack(pack)
                    showAnnotationPacks = false
                })
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Current: \(currentTime, specifier: "%.1f")s")
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(value: $currentTime, in: 0...max(videoDuration, 1))
                .frame(maxWidth: 200)

            Spacer()

            Text("\(annotations.count) annotations")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AnnotationType.allCases, id: \.self) { type in
                        Button {
                            addAnnotation(type: type)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.systemImage)
                                    .font(.title3)
                                Text(type.displayName)
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 70)
                            .background(selectedType == type ? Color.blue.opacity(0.2) : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Clinical Presets")
                    .font(.headline)
                Spacer()
                Button {
                    showAnnotationPacks = true
                } label: {
                    Label("Browse Packs", systemImage: "book.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PresetCategory.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.rawValue)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(category.presets, id: \.id) { preset in
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    Text(preset.rawValue)
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.headline)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background timeline
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 60)

                    // Annotations on timeline
                    ForEach(annotations) { annotation in
                        annotationTimelineBar(annotation, containerWidth: geometry.size.width)
                    }

                    // Current time indicator
                    let offset = (currentTime / max(videoDuration, 1)) * geometry.size.width * 0.9
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: 60)
                        .offset(x: offset)
                }
            }
            .frame(height: 60)
        }
    }

    private func annotationTimelineBar(_ annotation: TimedAnnotation, containerWidth: CGFloat) -> some View {
        let startOffset = (annotation.startTime / max(videoDuration, 1)) * containerWidth * 0.9
        let width = ((annotation.endTime - annotation.startTime) / max(videoDuration, 1)) * containerWidth * 0.9

        return RoundedRectangle(cornerRadius: 4)
            .fill(annotation.color.swiftUIColor.opacity(0.7))
            .frame(width: max(width, 4), height: 40)
            .offset(x: startOffset)
            .overlay(
                Text(annotation.type.displayName)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .offset(x: startOffset)
            )
    }

    private var annotationListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Annotations (\(annotations.count))")
                .font(.headline)

            if annotations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No annotations yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Use Quick Add or Clinical Presets to get started")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(annotations.sorted(by: { $0.startTime < $1.startTime })) { annotation in
                    AnnotationRow(
                        annotation: annotation,
                        isSelected: selectedAnnotationID == annotation.id,
                        onSelect: { selectedAnnotationID = annotation.id },
                        onDelete: { deleteAnnotation(annotation) },
                        onEdit: { editAnnotation(annotation) }
                    )
                }
            }
        }
    }

    private func addAnnotation(type: AnnotationType) {
        let newAnnotation = TimedAnnotation(
            type: type,
            startTime: currentTime,
            endTime: min(currentTime + 3.0, videoDuration),
            position: CGPoint(x: 0.5, y: 0.5),
            text: type.displayName,
            color: .red
        )
        annotations.append(newAnnotation)
        selectedAnnotationID = newAnnotation.id
    }

    private func applyPreset(_ preset: AnnotationPreset) {
        let offsetTime = currentTime
        let presetAnnotations = preset.defaultAnnotations.map { annotation in
            var adjusted = annotation
            adjusted.startTime += offsetTime
            adjusted.endTime += offsetTime
            return adjusted
        }
        annotations.append(contentsOf: presetAnnotations)
    }

    private func applyAnnotationPack(_ pack: AnnotationPack) {
        let offsetTime = currentTime
        let packAnnotations = pack.annotations.map { annotation in
            var adjusted = annotation
            adjusted.startTime += offsetTime
            adjusted.endTime += offsetTime
            return adjusted
        }
        annotations.append(contentsOf: packAnnotations)
    }

    private func deleteAnnotation(_ annotation: TimedAnnotation) {
        annotations.removeAll { $0.id == annotation.id }
        if selectedAnnotationID == annotation.id {
            selectedAnnotationID = nil
        }
    }

    private func editAnnotation(_ annotation: TimedAnnotation) {
        // Placeholder for detailed editing
        selectedAnnotationID = annotation.id
    }
}

private struct AnnotationRow: View {
    let annotation: TimedAnnotation
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: annotation.type.systemImage)
                .foregroundStyle(annotation.color.swiftUIColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(annotation.text.isEmpty ? annotation.type.displayName : annotation.text)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    Label("\(annotation.startTime, specifier: "%.1f")s", systemImage: "timer")
                    Text("→")
                    Label("\(annotation.endTime, specifier: "%.1f")s", systemImage: "timer")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onSelect)
    }
}

private struct AnnotationPackBrowser: View {
    let onSelect: (AnnotationPack) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Official Packs") {
                    ForEach(AnnotationPack.samples.filter { $0.isOfficial }) { pack in
                        AnnotationPackCard(pack: pack, onSelect: {
                            onSelect(pack)
                        })
                    }
                }

                Section("Community Packs") {
                    ForEach(AnnotationPack.samples.filter { !$0.isOfficial }) { pack in
                        AnnotationPackCard(pack: pack, onSelect: {
                            onSelect(pack)
                        })
                    }
                }
            }
            .navigationTitle("Annotation Packs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct AnnotationPackCard: View {
    let pack: AnnotationPack
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pack.name)
                    .font(.headline)
                if pack.isOfficial {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
            }

            Text(pack.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Label(pack.specialty, systemImage: "stethoscope")
                Spacer()
                Label("\(pack.annotations.count) annotations", systemImage: "number")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button(action: onSelect) {
                Label("Apply Pack", systemImage: "plus.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AnnotationEditorView(annotations: .constant([]), videoDuration: 60)
}
