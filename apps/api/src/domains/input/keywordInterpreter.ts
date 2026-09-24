import { randomUUID } from 'node:crypto';
import { FIGURE_IDS, type EventInterpretationV1, type FigureId } from '../../contracts/types.js';
import type { RitualInput } from './types.js';

// Port of the iOS LocalEventInterpreter so both sides degrade the same way
// when no LLM is available. Keep the keyword lists in sync with
// apps/ios/InsideOutApp/Services/EventInterpreter.swift.

const KEYWORDS: Record<FigureId, string[]> = {
  anger: [
    'angry', 'anger', 'annoyed', 'unfair', 'interrupt', 'ignored', 'cut me off', 'yelled', 'rude',
    '生气', '愤怒', '不公平', '打断', '被忽视', '烦', '吼', '别车',
  ],
  fear: [
    'afraid', 'fear', 'worried', 'nervous', 'uncertain', 'anxious', 'scared', 'shaky', 'happen again',
    '害怕', '担心', '紧张', '不确定', '焦虑', '后怕', '发抖',
  ],
  sadness: ['sad', 'hurt', 'lost', 'lonely', 'cry', 'miss', '难过', '受伤', '失落', '孤独', '哭', '想念'],
  joy: ['happy', 'joy', 'excited', 'proud', 'great', 'celebrate', '开心', '高兴', '兴奋', '自豪', '庆祝', '很好'],
};

const EVIDENCE: Record<FigureId, string> = {
  anger: 'Anger noticed a boundary, interruption, or sense of unfairness.',
  fear: 'Fear noticed uncertainty, risk, or concern about what happens next.',
  sadness: 'Sadness noticed hurt, distance, or something that felt lost.',
  joy: 'Joy noticed connection, relief, progress, or something worth keeping.',
};

const VOICE_LINES: Record<FigureId, string> = {
  anger: 'That crossed a line. It wasn’t fair.',
  fear: 'I’m worried it’ll happen again.',
  sadness: 'That one hurt. I’ll hold onto it.',
  joy: 'There’s something good here to keep.',
};

// Order used to break ties, matching Swift's rawValue sort.
const TIE_ORDER = [...FIGURE_IDS].sort();

export function signalCounts(text: string): Record<FigureId, number> {
  const normalized = text.toLowerCase();
  const counts = {} as Record<FigureId, number>;
  for (const id of FIGURE_IDS) {
    counts[id] = KEYWORDS[id].filter((keyword) => normalized.includes(keyword)).length;
  }
  return counts;
}

export function interpretWithKeywords(input: RitualInput): EventInterpretationV1 {
  const text = input.text.trim();
  const counts = signalCounts(text);
  if (!Object.values(counts).some((n) => n > 0)) {
    counts.joy = 1;
    counts.sadness = 1;
  }

  const ranked = [...TIE_ORDER].sort((a, b) => counts[b] - counts[a] || a.localeCompare(b));
  const selected = ranked.slice(0, 2);
  const weights = selected.map((id) => Math.max(1, counts[id]));
  const total = weights.reduce((a, b) => a + b, 0);
  const concentrations = weights.map((w) => Math.round((w / total) * 100) / 100);
  concentrations[0] = Math.round((1 - concentrations.slice(1).reduce((a, b) => a + b, 0)) * 100) / 100;

  return {
    schemaVersion: 'event-interpretation.v1',
    eventId: `event_${randomUUID()}`,
    summary: text.length > 150 ? `${text.slice(0, 150)}…` : text,
    turningPoint: '',
    sourceType: input.inputType,
    figures: selected.map((id, i) => ({
      id,
      concentration: concentrations[i],
      feed: 6 + weights[i] * 6,
      evidence: EVIDENCE[id],
      voiceLine: VOICE_LINES[id],
      confidence: 0.3,
    })),
    relationshipCues: [
      { figures: [selected[0], selected[1]], reason: 'They were both present in the same remembered event.' },
    ],
    objectCandidate: null,
    uncertainties: ['Interpreted locally with keyword matching, not the language model.'],
  };
}
