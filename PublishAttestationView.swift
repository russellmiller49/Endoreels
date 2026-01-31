import SwiftUI

struct PublishAttestationView: View {
    @Binding var title: String
    @Binding var procedure: String
    @Binding var anatomy: String
    @Binding var tags: String

    let onPreview: () -> Void
    let onPublish: () -> Void

    @State private var noPatientIdentifiers = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Final Pre-Flight Check")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 20)

            Form {
                Section("Metadata") {
                    TextField("Title", text: $title)
                    TextField("Procedure", text: $procedure)
                    TextField("Anatomy", text: $anatomy)
                    TextField("Tags (comma-separated)", text: $tags, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                }

                Section("Attestations (required)") {
                    Toggle("I attest that this video contains NO unmasked patient identifiers (Names, Faces, MRNs).", isOn: $noPatientIdentifiers)
                }

                Section {
                    Button {
                        onPreview()
                    } label: {
                        Label("Preview Reel", systemImage: "play.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onPublish()
                    } label: {
                        Label("Publish Reel", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!noPatientIdentifiers)
                }
            }
        }
    }
}

#Preview {
    PublishAttestationView(
        title: .constant("Cold EMR Case"),
        procedure: .constant("Colonoscopy"),
        anatomy: .constant("Ascending colon"),
        tags: .constant("EMR, colon, teaching"),
        onPreview: {},
        onPublish: {}
    )
}
