import { useMemo, useState } from 'react';
import { StepCard } from './components/StepCard';
import type { StepDraft, CaseDraft, ExportPayload } from './types';
import { v4 as uuidv4 } from 'uuid';

const pulmonaryPreset: CaseDraft = {
  title: 'Stent Rescue Run-through',
  abstract: 'Teaching reel for airway granulation rescue with privacy checklist.',
  serviceLine: 'pulmonary',
  detailedProcedure: 'Bronchial stent rescue with balloon dilation',
  anatomy: 'Left Main Bronchus',
  pathology: 'Granulation Tissue',
  device: 'Boston Scientific Ultraflex Stent',
  difficulty: 'Advanced',
  enableCME: true,
  includeVoiceover: true,
  tags: ['Pulmonology', 'Airway', 'Stent', 'Complication'],
  knowledgeHighlights: [
    'Use balloon dilation to rescue obstructed stents',
    'Verify mucosal perfusion post-dilation',
    'Schedule early follow-up when stent granulation occurs'
  ],
  steps: [
    {
      id: uuidv4(),
      order: 1,
      title: 'Airway Inspection',
      focus: 'Identify granulation tissue and stent margins.',
      mediaType: 'video',
      annotations: ['Arrow on obstruction', 'Text: keep suction ready']
    },
    {
      id: uuidv4(),
      order: 2,
      title: 'Balloon Dilation',
      focus: '12mm balloon inflation with visual cues.',
      mediaType: 'video',
      annotations: ['Timer overlay', 'Callout for pressure']
    },
    {
      id: uuidv4(),
      order: 3,
      title: 'Post-Procedure Review',
      focus: 'Show restored lumen and mucosal perfusion.',
      mediaType: 'image',
      annotations: ['Before/after split']
    }
  ]
};

const giPreset: CaseDraft = {
  title: 'Cold EMR of Large Right Colon Lesion',
  abstract: 'Technique breakdown for a 35mm laterally spreading tumor using cold EMR with traction clips.',
  serviceLine: 'gastroenterology',
  detailedProcedure: 'Cold piecemeal EMR of large right colon LST',
  anatomy: 'Ascending Colon',
  pathology: 'LST-G Tumor',
  device: 'Olympus EndoTherapy Snare',
  difficulty: 'Advanced',
  enableCME: true,
  includeVoiceover: true,
  tags: ['Gastroenterology', 'EMR', 'Bleeding Control'],
  knowledgeHighlights: [
    'Cold EMR reduces perforation risk in proximal colon',
    'Traction clips aid visualization',
    'Assess for residual tissue carefully'
  ],
  steps: [
    {
      id: uuidv4(),
      order: 1,
      title: 'Lesion inspection',
      focus: 'Paris IIa+Is lesion with NICE type 2 pattern.',
      mediaType: 'video',
      annotations: ['NICE classification overlay', 'Tattoo marker']
    },
    {
      id: uuidv4(),
      order: 2,
      title: 'Submucosal lift',
      focus: 'Orise gel injection elevated lesion without fibrosis.',
      mediaType: 'video',
      annotations: ['Injection plane arc', 'Needle entry point']
    },
    {
      id: uuidv4(),
      order: 3,
      title: 'Cold piecemeal resection',
      focus: 'Traction clip improved visualization; all pieces retrieved.',
      mediaType: 'video',
      annotations: ['Clip traction direction', 'Specimen bucket']
    },
    {
      id: uuidv4(),
      order: 4,
      title: 'Defect assessment',
      focus: 'No bleeding; prophylactic clips placed.',
      mediaType: 'image',
      annotations: ['Closure pattern diagram']
    }
  ]
};

const blankCase: CaseDraft = {
  title: 'Untitled Case',
  abstract: '',
  serviceLine: 'pulmonary',
  detailedProcedure: '',
  anatomy: '',
  pathology: '',
  device: '',
  difficulty: 'Intro',
  enableCME: false,
  includeVoiceover: false,
  tags: [],
  knowledgeHighlights: [],
  steps: []
};

type PresetKey = 'pulmonary' | 'gastro' | 'blank';

const presets: Record<PresetKey, CaseDraft> = {
  pulmonary: pulmonaryPreset,
  gastro: giPreset,
  blank: blankCase
};

const cloneCaseDraft = (draft: CaseDraft): CaseDraft => ({
  ...draft,
  tags: [...draft.tags],
  knowledgeHighlights: [...draft.knowledgeHighlights],
  steps: draft.steps.map((step, index) => ({ ...step, id: uuidv4(), order: index + 1 }))
});

export default function App() {
  const [preset, setPreset] = useState<PresetKey>('pulmonary');
  const [caseDraft, setCaseDraft] = useState<CaseDraft>(() => cloneCaseDraft(presets['pulmonary']));

  const loadPreset = (key: PresetKey) => {
    setPreset(key);
    setCaseDraft(cloneCaseDraft(presets[key]));
  };

  const updateField = <K extends keyof CaseDraft>(field: K, value: CaseDraft[K]) => {
    setCaseDraft((prev) => ({ ...prev, [field]: value }));
  };

  const updateStep = (id: string, patch: Partial<StepDraft>) => {
    setCaseDraft((prev) => ({
      ...prev,
      steps: prev.steps.map((step) => (step.id === id ? { ...step, ...patch } : step))
    }));
  };

  const removeStep = (id: string) => {
    setCaseDraft((prev) => ({
      ...prev,
      steps: prev.steps.filter((step) => step.id !== id).map((step, index) => ({ ...step, order: index + 1 }))
    }));
  };

  const moveStep = (id: string, direction: -1 | 1) => {
    setCaseDraft((prev) => {
      const index = prev.steps.findIndex((step) => step.id === id);
      if (index === -1) return prev;
      const targetIndex = index + direction;
      if (targetIndex < 0 || targetIndex >= prev.steps.length) return prev;
      const newSteps = [...prev.steps];
      const [removed] = newSteps.splice(index, 1);
      newSteps.splice(targetIndex, 0, removed);
      return {
        ...prev,
        steps: newSteps.map((step, idx) => ({ ...step, order: idx + 1 }))
      };
    });
  };

  const addStep = () => {
    setCaseDraft((prev) => ({
      ...prev,
      steps: [
        ...prev.steps,
        {
          id: uuidv4(),
          order: prev.steps.length + 1,
          title: 'New Step',
          focus: 'Key point placeholder',
          mediaType: 'video',
          annotations: []
        }
      ]
    }));
  };

  const exportPayload: ExportPayload = useMemo(() => ({
    title: caseDraft.title,
    abstract: caseDraft.abstract,
    procedure: caseDraft.detailedProcedure,
    serviceLine: caseDraft.serviceLine,
    anatomy: caseDraft.anatomy,
    pathology: caseDraft.pathology,
    device: caseDraft.device,
    difficulty: caseDraft.difficulty,
    tags: caseDraft.tags,
    knowledgeHighlights: caseDraft.knowledgeHighlights,
    steps: caseDraft.steps.map((step) => ({
      orderIndex: step.order,
      title: step.title,
      keyPoint: step.focus,
      mediaType: step.mediaType,
      annotations: step.annotations
    }))
  }), [caseDraft]);

  const handleDownload = () => {
    const blob = new Blob([JSON.stringify(exportPayload, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${caseDraft.title.replace(/\s+/g, '_').toLowerCase()}_demo.json`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  const handleCopy = async () => {
    await navigator.clipboard.writeText(JSON.stringify(exportPayload, null, 2));
    alert('JSON copied to clipboard');
  };

  return (
    <div className="container">
      <div className="card">
        <div className="template-selectors">
          {(
            [
              { key: 'pulmonary', label: 'Demo Pulmonary' },
              { key: 'gastro', label: 'Demo GI' },
              { key: 'blank', label: 'Blank' }
            ] as Array<{ key: PresetKey; label: string }>
          ).map(({ key, label }) => (
            <button
              key={key}
              type="button"
              className={preset === key ? 'active' : ''}
              onClick={() => loadPreset(key)}
            >
              {label}
            </button>
          ))}
        </div>
        <p className="badge">Create a demo-ready JSON payload for EndoReels</p>
      </div>

      <div className="card">
        <h2>Case Outline</h2>
        <div className="step-grid">
          <label className="field-label">
            Title
            <input value={caseDraft.title} onChange={(event) => updateField('title', event.target.value)} />
          </label>
          <label className="field-label">
            Service Line
            <select
              value={caseDraft.serviceLine}
              onChange={(event) => updateField('serviceLine', event.target.value as CaseDraft['serviceLine'])}
            >
              <option value="pulmonary">Pulmonary</option>
              <option value="gastroenterology">Gastroenterology</option>
            </select>
          </label>
          <label className="field-label">
            Difficulty
            <select
              value={caseDraft.difficulty}
              onChange={(event) => updateField('difficulty', event.target.value as CaseDraft['difficulty'])}
            >
              <option value="Intro">Intro</option>
              <option value="Intermediate">Intermediate</option>
              <option value="Advanced">Advanced</option>
            </select>
          </label>
          <label className="field-label" style={{ gridColumn: '1 / -1' }}>
            Abstract
            <textarea
              value={caseDraft.abstract}
              onChange={(event) => updateField('abstract', event.target.value)}
            />
          </label>
          <label className="field-label">
            Detailed Procedure
            <textarea
              value={caseDraft.detailedProcedure}
              onChange={(event) => updateField('detailedProcedure', event.target.value)}
            />
          </label>
          <label className="field-label">
            Anatomy
            <input value={caseDraft.anatomy} onChange={(event) => updateField('anatomy', event.target.value)} />
          </label>
          <label className="field-label">
            Pathology
            <input value={caseDraft.pathology} onChange={(event) => updateField('pathology', event.target.value)} />
          </label>
          <label className="field-label">
            Device
            <input value={caseDraft.device} onChange={(event) => updateField('device', event.target.value)} />
          </label>
        </div>
        <div className="step-grid">
          <label className="field-label">
            Tags
            <span className="helper">Comma separated</span>
            <input
              value={caseDraft.tags.join(', ')}
              onChange={(event) => updateField(
                'tags',
                event.target.value
                  .split(',')
                  .map((tag) => tag.trim())
                  .filter(Boolean)
              )}
            />
          </label>
          <label className="field-label">
            Knowledge Highlights
            <span className="helper">One per line</span>
            <textarea
              value={caseDraft.knowledgeHighlights.join('\n')}
              onChange={(event) => updateField(
                'knowledgeHighlights',
                event.target.value
                  .split('\n')
                  .map((tag) => tag.trim())
                  .filter(Boolean)
              )}
            />
          </label>
        </div>
      </div>

      <div className="card">
        <h2>Storyboard Steps ({caseDraft.steps.length})</h2>
        <div className="step-grid">
          {caseDraft.steps.map((step, index) => (
            <StepCard
              key={step.id}
              step={step}
              onChange={updateStep}
              onRemove={removeStep}
              onMove={moveStep}
              canMoveUp={index !== 0}
              canMoveDown={index !== caseDraft.steps.length - 1}
            />
          ))}
        </div>
        <div className="actions" style={{ marginTop: 16 }}>
          <button type="button" onClick={addStep}>Add Step</button>
          <button type="button" className="secondary" onClick={() => loadPreset(preset)}>Reset Storyboard</button>
        </div>
      </div>

      <div className="card">
        <h2>Export</h2>
        <p className="badge">JSON structure aligns with the demo seeds used in the iOS app</p>
        <div className="actions">
          <button type="button" onClick={handleDownload}>Download JSON</button>
          <button type="button" className="secondary" onClick={handleCopy}>Copy JSON</button>
        </div>
        <textarea className="function-output" readOnly value={JSON.stringify(exportPayload, null, 2)} />
      </div>
    </div>
  );
}
