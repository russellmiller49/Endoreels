# EndoReels Demo Builder (Web)

A lightweight Vite + React tool for authoring high-quality demo cases that match the structure expected by the iOS app. Use it to tweak metadata, storyboard steps, and export JSON snippets that can be dropped into Supabase or hard-coded seeds.

## Quick Start

```bash
cd web-demo
npm install
npm run dev
```

Open `http://localhost:5173` and you’ll see:

- Preset pickers for the Pulmonary and GI sample cases (plus a blank canvas).
- Editable case outline fields (title, service line, anatomy, device, etc.).
- A storyboard editor where you can reorder steps, add annotations, and change capture type.
- Export buttons to copy/download the JSON payload formatted for `DemoDataStore` / seed scripts.

The exported JSON mirrors the `Reel` / `ReelStep` shape we use in the app:

```json
{
  "title": "Cold EMR of Large Right Colon Lesion",
  "serviceLine": "gastroenterology",
  "steps": [
    {
      "orderIndex": 1,
      "title": "Lesion inspection",
      "keyPoint": "Paris IIa+Is lesion with NICE type 2 pattern.",
      "mediaType": "video",
      "annotations": ["NICE classification overlay", "Tattoo marker"]
    }
  ]
}
```

Copy the JSON into Supabase (e.g., `demo_reels` table) or replace the Swift demo seeds with the generated payload.

## Notes

- The tool runs entirely client-side; no secrets are required.
- Customize the presets in `src/App.tsx` if you want to add additional specialties.
- Styling lives in `src/styles.css`. Update as needed to match future design language.
