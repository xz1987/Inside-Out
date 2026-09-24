// Checks that the configured gateway (Cornell or OpenAI) answers, and whether it
// supports strict structured output. Run: npm run smoke:llm
// Never prints the API key.
import { loadConfig } from '../src/config.js';
import { LlmClient } from '../src/llm/llmClient.js';

const config = loadConfig();
const client = new LlmClient(config.llm.input);

console.log(`Base URL: ${config.llm.input.baseURL}`);
console.log(`Model:    ${config.llm.input.model}`);

if (!client.configured) {
  console.error('\nNo key found. Copy .env.example to .env and set OPENAI_API_KEY (or INPUT_DOMAIN_API_KEY).');
  process.exit(1);
}

const schema = {
  type: 'object',
  additionalProperties: false,
  required: ['figure', 'reason'],
  properties: {
    figure: { type: 'string', enum: ['joy', 'sadness', 'anger', 'fear'] },
    reason: { type: 'string', maxLength: 120 },
  },
};

try {
  const started = Date.now();
  const result = await client.completeJson<{ figure: string; reason: string }>({
    system: 'You classify a short diary sentence into the single most present emotion Figure.',
    user: 'A driver cut me off and then yelled at me like it was my fault.',
    schemaName: 'smoke_test',
    schema,
  });
  console.log(`\nOK in ${Date.now() - started} ms`);
  console.log(`JSON mode: ${result.mode}${result.mode === 'json_object' ? '  (gateway rejected json_schema; using fallback)' : '  (strict structured output supported)'}`);
  console.log('Response:', result.data);
} catch (error) {
  const e = error as { status?: number; message?: string };
  console.error(`\nFailed${e.status ? ` (HTTP ${e.status})` : ''}: ${e.message ?? error}`);
  process.exit(1);
}
