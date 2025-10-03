import { useState } from 'react';
import type { StepDraft, MediaType } from '../types';

type StepCardProps = {
  step: StepDraft;
  onChange: (step: StepDraft) => void;
  onRemove: (id: string) => void;
  onMove: (id: string, direction: -1 | 1) => void;
  canMoveUp: boolean;
  canMoveDown: boolean;
};

export function StepCard({ step, onChange, onRemove, onMove, canMoveDown, canMoveUp }: StepCardProps) {
  const [annotationInput, setAnnotationInput] = useState('');

  const update = (patch: Partial<StepDraft>) => {
    onChange({ ...step, ...patch });
  };

  const addAnnotation = () => {
    const trimmed = annotationInput.trim();
    if (!trimmed) return;
    update({ annotations: [...step.annotations, trimmed] });
    setAnnotationInput('');
  };

  const removeAnnotation = (value: string) => {
    update({ annotations: step.annotations.filter((ann) => ann !== value) });
  };

  return (
    <div className="step-card">
      <header>
        <span className="badge">Step {step.order}</span>
        <div className="template-selectors">
          <button type="button" disabled={!canMoveUp} onClick={() => onMove(step.id, -1)}>
            ↑
          </button>
          <button type="button" disabled={!canMoveDown} onClick={() => onMove(step.id, 1)}>
            ↓
          </button>
          <button type="button" onClick={() => onRemove(step.id)}>
            Remove
          </button>
        </div>
      </header>
      <label className="field-label">
        Title
        <input value={step.title} onChange={(event) => update({ title: event.target.value })} />
      </label>
      <label className="field-label">
        Focus
        <textarea value={step.focus} onChange={(event) => update({ focus: event.target.value })} />
      </label>
      <label className="field-label">
        Capture Type
        <select
          value={step.mediaType}
          onChange={(event) => update({ mediaType: event.target.value as MediaType })}
        >
          <option value="video">Video</option>
          <option value="image">Image</option>
        </select>
      </label>
      <div>
        <label className="field-label">
          Annotations
          <span className="helper">Press enter to add</span>
        </label>
        <div>
          {step.annotations.map((annotation) => (
            <span key={annotation} className="annotation-chip">
              {annotation}
              <button type="button" onClick={() => removeAnnotation(annotation)}>
                ×
              </button>
            </span>
          ))}
        </div>
        <input
          value={annotationInput}
          placeholder="Add annotation"
          onChange={(event) => setAnnotationInput(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter') {
              event.preventDefault();
              addAnnotation();
            }
          }}
        />
      </div>
    </div>
  );
}
