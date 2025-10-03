export type MediaType = 'video' | 'image';

export interface StepDraft {
  id: string;
  order: number;
  title: string;
  focus: string;
  mediaType: MediaType;
  annotations: string[];
}

export interface CaseDraft {
  title: string;
  abstract: string;
  serviceLine: 'pulmonary' | 'gastroenterology';
  detailedProcedure: string;
  anatomy: string;
  pathology: string;
  device: string;
  difficulty: 'Intro' | 'Intermediate' | 'Advanced';
  enableCME: boolean;
  includeVoiceover: boolean;
  tags: string[];
  knowledgeHighlights: string[];
  steps: StepDraft[];
}

export interface ExportPayload {
  title: string;
  abstract: string;
  procedure: string;
  serviceLine: string;
  anatomy: string;
  pathology: string;
  device: string;
  difficulty: string;
  tags: string[];
  knowledgeHighlights: string[];
  steps: Array<{
    orderIndex: number;
    title: string;
    keyPoint: string;
    mediaType: MediaType;
    annotations: string[];
  }>;
}
