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
    'afraid', 'fear', 'scared', 'unsafe', 'danger', 'threat', 'panic', 'shaky',
    '害怕', '恐惧', '危险', '不安全', '惊吓', '发抖',
  ],
  anxiety: [
    'anxious', 'anxiety', 'worried', 'nervous', 'uncertain', 'overthinking', 'happen again',
    '焦虑', '担心', '紧张', '不确定', '想太多', '后怕',
  ],
  sadness: ['sad', 'hurt', 'lost', 'lonely', 'cry', 'miss', '难过', '受伤', '失落', '孤独', '哭', '想念'],
  joy: ['happy', 'joy', 'excited', 'proud', 'great', 'celebrate', '开心', '高兴', '兴奋', '自豪', '庆祝', '很好'],
  disgust: ['disgust', 'disgusted', 'gross', 'nasty', 'repulsed', 'sickening', '恶心', '反感', '嫌弃', '膈应'],
  embarrassment: ['embarrassed', 'awkward', 'humiliated', 'ashamed', 'cringe', 'self-conscious', '尴尬', '丢脸', '羞耻', '难为情'],
  boredom: ['bored', 'boring', 'dull', 'tedious', 'nothing to do', 'waiting forever', '无聊', '没意思', '乏味', '等太久'],
};

const EVIDENCE: Record<FigureId, string> = {
  anger: 'Anger noticed a boundary, interruption, or sense of unfairness.',
  fear: 'Fear noticed uncertainty, risk, or concern about what happens next.',
  anxiety: 'Anxiety noticed anticipation, uncertainty, or a thought that kept looping.',
  sadness: 'Sadness noticed hurt, distance, or something that felt lost.',
  joy: 'Joy noticed connection, relief, progress, or something worth keeping.',
  disgust: 'Disgust noticed aversion, rejection, or something that crossed a visceral boundary.',
  embarrassment: 'Embarrassment noticed exposure, awkwardness, or a wish to disappear.',
  boredom: 'Boredom noticed repetition, waiting, or a lack of meaningful stimulation.',
};

const VOICE_LINES: Record<FigureId, string> = {
  anger: 'That crossed a line. It wasn’t fair.',
  fear: 'I’m worried it’ll happen again.',
  anxiety: 'My mind keeps circling what might happen next.',
  sadness: 'That one hurt. I’ll hold onto it.',
  joy: 'There’s something good here to keep.',
  disgust: 'I want some distance from that.',
  embarrassment: 'I wish I could hide for a minute.',
  boredom: 'Nothing here is holding my attention.',
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
