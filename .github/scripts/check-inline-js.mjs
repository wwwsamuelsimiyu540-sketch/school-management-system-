import { readFileSync } from 'node:fs';
import { Script } from 'node:vm';

let failed = false;
for (const file of process.argv.slice(2)) {
  const html = readFileSync(file, 'utf8');
  const scriptTag = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  let match;
  let number = 0;
  while ((match = scriptTag.exec(html))) {
    number += 1;
    if (/\bsrc\s*=/.test(match[1]) || !match[2].trim()) continue;
    try {
      new Script(match[2], { filename: file + ' inline script ' + number });
      console.log('PASS ' + file + ': inline script ' + number);
    } catch (error) {
      failed = true;
      console.error('FAIL ' + file + ': inline script ' + number + ': ' + error.message);
    }
  }
}
if (failed) process.exit(1);
