# EndoReels Development Guide

## Project Structure

```
Projects/
├── EndoReels/              # iOS app repository
│   ├── EndoReels/          # Source code
│   ├── AI_README.md        # Implementation milestones (M0-M7)
│   └── DEVELOPMENT.md      # This file
└── DemoBuilder/            # Swift CLI tool (separate package)
    ├── Sources/DemoBuilder/
    ├── DemoData/           # JSON demo cases
    └── Package.swift
```

**Note**: DemoBuilder lives outside the iOS project to avoid Xcode build conflicts.

## Quick Start

### iOS App

```bash
cd EndoReels

# Open in Xcode
open EndoReels.xcodeproj

# Build and run
⌘ + R
```

### Demo Case Builder

The DemoBuilder is a Swift command-line tool for creating high-quality demo cases that ship with the app.

```bash
# From the Projects directory
cd DemoBuilder

# List all demo cases
swift run DemoBuilder list

# Validate all cases
swift run DemoBuilder validate

# Export to Swift (for iOS app)
swift run DemoBuilder export --format swift --output ../EndoReels/DemoSeeds.swift

# Export to JSON
swift run DemoBuilder export --format json --output demo-cases.json

# Export to Supabase SQL
swift run DemoBuilder export --format supabase --output supabase-seed.sql
```

See [../DemoBuilder/README.md](../DemoBuilder/README.md) for full documentation.

## Development Workflow

### Current Phase: Manual Editing MVP

We're building a non-destructive timeline editor (M0-M5). See [AI_README.md](AI_README.md) for the full roadmap.

#### Completed Milestones

- **M0**: Repo hygiene - Removed AI scene detection UI, preserved PHI hooks

#### Next Steps

- **M1**: Data model & draft storage
- **M2**: Media pipeline (proxy, thumbnails, waveform)
- **M3**: Timeline Editor UI (Clipper)
- **M4**: Review → Steps conversion
- **M5**: Export with AVComposition

### Adding Demo Cases

1. Create JSON file in `DemoBuilder/DemoData/`:
   ```json
   {
     "id": "demo-cardio-001",
     "title": "Your Case Title",
     "serviceLine": "Cardiology",
     "steps": [...]
   }
   ```

2. Validate:
   ```bash
   cd DemoBuilder
   swift run DemoBuilder validate
   ```

3. Export to iOS app:
   ```bash
   swift run DemoBuilder export --format swift -o ../EndoReels/DemoSeeds.swift
   ```

4. Add `DemoSeeds.swift` to Xcode project

## Environment Setup

### Required

- Xcode 15+ (for iOS 17+ support)
- Swift 5.9+
- macOS 13+

### Environment Variables

Create `.env` file (copy from `.env.example`):

```bash
API_BASE_URL=https://your-api.com
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_JWT_SECRET=your-jwt-secret
```

⚠️ **Never commit service role keys to the client!**

Configure in Xcode:
1. Edit Scheme → Run → Environment Variables
2. Add variables from `.env`

## Architecture

### iOS App (SwiftUI)

- **Target**: iOS 17+
- **Concurrency**: `@MainActor` for UI, `actor` for stores
- **Data**: Non-destructive edits, originals untouched
- **Security**: No PHI leaves device during editing

### Key Features

- **Creator Studio**: Service-line presets, storyboard builder
- **Media Library**: Photos/Files import, audio ingestion
- **Review System**: Full reel preview with PiP support
- **Privacy**: PHI detection hooks (for M7)
- **Credits**: Client stubs, server-ready

### Manual Editing Pipeline (In Progress)

```
Import → Proxy/Thumbnails → Timeline Editor → Review → Export
  |          (M2)              (M3)          (M4)    (M5)
  └─> Draft Storage (M1)
```

## Testing

### Manual Testing (Simulator)

From [AI_README.md](AI_README.md#qa--manual-test-plan-simulator):

1. **Import → Proxy**: Import 10-min clip, verify proxy generation
2. **Clipper Basics**: Set I/O, add segments, reorder, ripple delete
3. **Assist Tools**: Remove silence, markers, speed presets
4. **Undo/Redo**: 10+ edits, walk back/forward
5. **Autosave**: Background/kill app, verify draft restored
6. **Export**: Composition renders and plays

### Unit Tests

```bash
# Run tests in Xcode
⌘ + U
```

## Git Workflow

```bash
# Current branch for manual editing work
git checkout working_v2

# Commit style
git commit -m "M1: Add non-destructive timeline models"
git commit -m "M3: Clipper UI skeleton with I/O selection"

# Push
git push origin working_v2

# Create PR to main when MVP compiles
```

## Common Issues

### Build Error: Duplicate README.md

This is a known Xcode configuration issue (not code-related). The Swift code is valid.

**Workaround**: Use Xcode directly instead of command-line builds.

### Missing Environment Variables

If you see auth/credits errors:
1. Check Xcode Scheme → Environment Variables
2. Ensure `.env` values are copied correctly
3. Restart Xcode

## Resources

- [AI_README.md](AI_README.md) - Full implementation roadmap
- [DemoBuilder/README.md](DemoBuilder/README.md) - Demo case authoring
- [.env.example](.env.example) - Environment variable template

## Support

For issues or questions:
1. Check [AI_README.md](AI_README.md) for milestone context
2. Review relevant section in this guide
3. Check git history for recent changes
