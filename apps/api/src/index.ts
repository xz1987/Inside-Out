import { createApp, createDeps } from './app.js';
import { loadConfig } from './config.js';

const config = loadConfig();
const deps = createDeps(config);
const app = createApp(deps);

app.listen(config.port, config.host, () => {
  console.log(`Inside Out API listening on http://${config.host}:${config.port}`);
  console.log(`  iPhone: set API_BASE_URL to http://<this-Mac>.local:${config.port} or an HTTPS tunnel`);
  console.log(`  LLM base URL: ${config.llm.input.baseURL}`);
  for (const [name, client] of [['input', deps.inputLlm], ['ecosystem', deps.ecosystemLlm]] as const) {
    const status = client.configured ? `model ${client.config.model}` : 'no API key — local fallback only';
    console.log(`  ${name} domain: ${status}`);
  }
});
