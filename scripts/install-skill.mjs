import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '..');
const source = path.join(repo, 'skills', 'wardrobe-stylist');
const codexHome = process.env.CODEX_HOME || path.join(os.homedir(), '.codex');
const target = path.join(codexHome, 'skills', 'wardrobe-stylist');

if (!fs.existsSync(path.join(source, 'SKILL.md'))) {
  console.error('找不到 skills/wardrobe-stylist/SKILL.md，请从仓库根目录执行此命令。');
  process.exit(1);
}

fs.mkdirSync(path.dirname(target), { recursive: true });
fs.cpSync(source, target, { recursive: true, force: true });
console.log(`已安装 wardrobe-stylist：${target}`);
console.log('请重新打开 Agent 会话，让 Skill 索引刷新。');
