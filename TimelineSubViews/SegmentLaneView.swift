import SwiftUI

struct SegmentLaneView: View {
    let segments: [SegmentDisplay]
    let selectedSegmentID: UUID?
    let isRippleDelete: Bool
    let onSelect: (UUID) -> Void
    let onMoveLeft: (Int) -> Void
    let onMoveRight: (Int) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        if segments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("No segments yet", systemImage: "rectangle.dashed")
                    .foregroundStyle(.secondary)
                Text("Set In/Out and tap Add Segment to build your timeline. Drag chips once they appear to reorder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(segments) { display in
                        SegmentChip(
                            segment: display.segment,
                            index: display.index,
                            totalCount: segments.count,
                            isSelected: selectedSegmentID == display.segment.id,
                            isRippleDelete: isRippleDelete,
                            onSelect: { onSelect(display.segment.id) },
                            onMoveLeft: { onMoveLeft(display.index) },
                            onMoveRight: { onMoveRight(display.index) },
                            onDelete: { onDelete(display.segment.id) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct SegmentDisplay: Identifiable {
    let segment: Segment
    let index: Int
    var id: UUID { segment.id }
}

private struct SegmentChip: View {
    let segment: Segment
    let index: Int
    let totalCount: Int
    let isSelected: Bool
    let isRippleDelete: Bool
    let onSelect: () -> Void
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(segment.label.isEmpty ? "Segment \(index + 1)" : segment.label)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !segment.markers.isEmpty {
                    Label("\(segment.markers.count)", systemImage: "bookmark")
                        .font(.caption2)
                }
            }

            Text("\(formatTime(segment.start_s)) – \(formatTime(segment.end_s))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Button(action: onMoveLeft) {
                    Image(systemName: "arrow.left")
                }
                .buttonStyle(.bordered)
                .disabled(index == 0)

                Button(action: onMoveRight) {
                    Image(systemName: "arrow.right")
                }
                .buttonStyle(.bordered)
                .disabled(index >= totalCount - 1)

                Button(action: onDelete) {
                    Image(systemName: isRippleDelete ? "trash.slash" : "trash")
                }
                .buttonStyle(.bordered)
            }
            .font(.caption)
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onTapGesture(perform: onSelect)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
