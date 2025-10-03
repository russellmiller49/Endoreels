# EndoReels

## 👨🏻‍⚕️ A Secure, Mobile-First Platform for Medical Education

EndoReels is a revolutionary iOS app designed for the medical community to share, discuss, and learn from endoscopic cases through intuitive, short-form visual storyboards. By combining the engaging format of modern social media with the rigor of a peer-reviewed academic environment, EndoReels transforms passive learning into an active, collaborative experience.

---

## 🎯 Vision & Mission

**Mission**: To empower clinicians to share, learn, and collaborate using secure, concise, and academically rigorous visual media.

**Vision**: Become the essential digital ecosystem for procedural education, initially focusing on Interventional Pulmonology and Gastroenterology, with clear pathways for expansion across procedural medicine.

---

## 🚀 Key Features

### 📱 Core Functionality
- **Guided Case Creator**: Templated case entry with standardized patient context fields
- **Secure Media Hub**: Support for CT slices, endoscopy videos, fluorescence imaging, and pathology slides
- **AI-Powered De-identification**: Automated PHI detection & redaction
- **Clinical Feed**: Vertical scrolling between cases with structured case layouts
- **Knowledge Hub**: Faceted search by procedure, anatomy, pathology, device, and difficulty
- **Academic Credibility**: Multi-tier verification system with Blue and Gold badges
- **HIPAA-Safe Design**: Built with privacy and compliance at the forefront

### 🎬 Advanced Editing Tools
- **Timeline Editor**: Drag-and-drop templates with magnetic timeline and keyframe snapping
- **Annotation Suite**: Timed callouts, arrows, circles, spotlight/magnifier zoom
- **Picture-in-Picture**: PiP overlays, split screen comparisons, before/after sliders
- **Audio Narration**: Noise reduction, auto-generated captions, TTS fallback
- **Visual Enhancement**: Stabilization, color correction (with clinical integrity guardrails)
- **Templates & Macros**: Reusable annotation packs and procedure blueprints

### 🔒 Safety & Compliance
- **PHI Heatmap**: OCR/NER detection with auto-tracked blur for protected content
- **Multi-layer Moderation**: AI-assisted, community-flagging, and expert review
- **Clinical Integrity Mode**: Prevents excessive manipulation that could mislead viewers
- **Mandatory Privacy Checklist**: Ensures consent and PHI removal before publishing

---

## 🏗️ Project Structure

```
EndoReels/
├── EndoReelsApp.swift              # Main app entry point
├── ContentView.swift               # Primary navigation controller
├── DemoModels.swift                # Core data models and demo data
│
├── Creator Flow
├── CreatorView.swift               # Main creation interface
├── MediaAssetEditorView.swift      # Asset management and editing
├── AnnotationEditorView.swift      # Annotation tools and timeline editing
├── NarrationEditorView.swift       # Audio recording and editing
├── MultimodalLayoutView.swift      # PiP, split-screen, and layout tools
├── TemplateSystem.swift            # Templates and macro system
├── PHIDetectionView.swift          # PHI scanning and remediation
├── QualityControlView.swift        # Pre-publish validation and checks
├── ExportView.swift                # Rendering and export options
│
├── Consumption Flow
├── FeedView.swift                  # Main discovery and browsing interface
├── ReelDetailView.swift            # Individual case viewer
├── KnowledgeHubView.swift          # Curated collections and search
├── ReviewCollaborationView.swift   # Peer review and commenting system
│
├── Operations & Administration
├── OperationsView.swift            # Admin tools and moderation queue
├── AnnotationModels.swift          # Data structures for annotations
├── MediaLibrary.swift              # Asset management and storage
│
└── Assets.xcassets/               # App icons, colors, and UI assets
```

---

## 📊 Technical Architecture

### Technology Stack
- **Platform**: iOS (SwiftUI)
- **Data Models**: Swift structs with ObservableObject patterns
- **State Management**: Combine framework with @Published properties
- **UI Framework**: SwiftUI with custom views and components
- **Asset Management**: PHPhotoLibrary integration for media access

### Core Data Models
- **`Reel`**: Primary content unit containing case information, steps, and metadata
- **`ReelStep`**: Individual segments with media, annotations, and teaching points
- **`UserProfile`**: Clinician profiles with verification badges and credentials
- **`PHIFinding`**: Security audit trails for protected health information
- **`MediaAsset`**: Secure container for medical media with processing pipeline
- **`EngagementSignals`**: Analytics for views, interactions, and learning outcomes

### Service Lines Supported
- **Pulmonary**: Diagnostic bronchoscopy, EBUS, therapeutic procedures, pleural interventions
- **Gastroenterology**: EGD, colonoscopy, EUS, endoscopic mucosal resection

---

## 🔧 Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ target deployment
- macOS with Apple Silicon recommended

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/EndoReels.git
   cd EndoReels
   ```

2. Open the project in Xcode:
   ```bash
   open EndoReels.xcodeproj
   ```

3. Build and run on iOS Simulator or physical device

### Project Setup
- The project uses modern SwiftUI patterns and Combine framework
- Demo data is included for testing and development
- All files are structured at the repository root for optimal accessibility
- Runtime configuration is provided through environment variables. Copy `.env.example` to `.env` (not committed) and fill in your Supabase and Railway secrets before running features that rely on the network layer.
- Sign in with a Supabase email/password account after launch to unlock AI processing and credit management (anon credentials will only load demo data).
- Need to craft demo cases from desktop? Check out `web-demo/` for a Vite-based authoring tool that exports JSON in the same shape used by the app's seed data.

---

## 🎓 Educational Features

### Curriculum Integration
- **Procedure Templates**: Pre-built workflows for common endoscopic procedures
- **Anatomical Overlays**: Interactive EBUS lymph node maps and GI anatomy references
- **Teaching Pearls**: Structured key takeaways and clinical insights
- **CME Integration**: Accredited content with continuing medical educational credits
- **Export Tools**: Generate PowerPoint presentations and PDF summaries for lectures

### Collaborative Learning
- **Peer Review**: Time-coded comments with pinning of key discussions
- **Knowledge Collections**: Curated playlists by specialty societies and educators
- **Reaction System**: Clinically-relevant engagement indicators (Insightful, Great Technique, Excellent Teaching)
- **Discussion Threads**: Professional Q&A with verified respondent prioritization

---

## 🔐 Security & Privacy

### HIPAA Compliance
- **Encryption**: End-to-end encryption for all medical media
- **Access Controls**: Role-based permissions and audit logging
- **Data Minimization**: Automatic removal of unnecessary metadata
- **Retention Policies**: Configurable data lifecycle management

### De-identification Pipeline
- **OCR Detection**: Automatic identification of overlay text containing PHI
- **Audio Analysis**: Speech recognition with NER for PHI detection
- **Manual Review**: Expert annotation tools for complex cases
- **Validation**: Multi-stage verification before publication

---

## 📈 Future Roadmap

### Phase 1 (Current)
- ✅ Core SwiftUI implementation
- ✅ Data models and demo content
- ✅ Basic UI framework and navigation
- 🔄 Media asset management
- 🔄 Annotation and editing tools

### Phase 2 (Planned)
- Picture-in-Picture and multimodal layouts
- Advanced PHI detection algorithms
- Real-time collaboration features
- Export and presentation tools

### Phase 3 (Future)
- Android compatibility with React Native
- Machine learning for automated case tagging
- Integration with institutional EMR systems
- Advanced analytics and learning outcomes

---

## 🤝 Contributing

We welcome contributions from the medical and development communities! Please see our contributing guidelines:

1. **Medical Accuracy**: All clinical content must be verified by licensed practitioners
2. **Code Quality**: Follow Swift best practices and include comprehensive tests
3. **Privacy First**: Ensure all changes maintain HIPAA compliance standards
4. **Documentation**: Update relevant documentation for any feature changes

---

## 📞 Contact & Support

- **Clinical Questions**: Review our educational content guidelines
- **Technical Issues**: Submit issues with device and iOS version information
- **Partnership Inquiries**: Contact us for institutional collaboration opportunities

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Important**: This app handles protected health information and must be used only in compliance with applicable healthcare regulations (HIPAA, GDPR, etc.) and institutional policies.

---

## 🏥 Medical Disclaimer

EndoReels is intended for educational purposes only. All clinical decisions must be made in accordance with standard medical practice and institutional guidelines. Users are responsible for ensuring compliance with applicable regulations and obtaining necessary approvals before sharing protected health information.
