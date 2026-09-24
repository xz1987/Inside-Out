import { createApp, createDeps } from './app.js';
import { loadConfig } from './config.js';

const config = loadConfig();
const deps = createDeps(config);
const app = createApp(deps);

app.listen(config.port, () => {
  console.log(`Inside Out API listening on http://localhost:${config.port}`);
  console.log(`  LLM base URL: ${config.llm.input.baseURL}`);
  for (const [name, client] of [['input', deps.inputLlm], ['ecosystem', deps.ecosystemLlm]] as const) {
    const status = client.configured ? `model ${client.config.model}` : 'no API key — local fallback only';
    console.log(`  ${name} domain: ${status}`);
  }
});
