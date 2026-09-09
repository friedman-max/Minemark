'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { readFile } = require('./minecraft-nbt');

function argument(name, required = true) {
  const index = process.argv.indexOf(`--${name}`);
  if (index === -1) { if (required) throw new Error(`Missing --${name}.`); return null; }
  const value = process.argv[index + 1];
  if (!value || value.startsWith('--')) throw new Error(`Missing value for --${name}.`);
  return value;
}
function ensureDirectory(directory) { fs.mkdirSync(directory, { recursive: true }); }
function hashFile(filePath) { return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex'); }
function copyArtifact(source, destinationDirectory, name) {
  if (!source || !fs.existsSync(source)) return null;
  const destination = path.join(destinationDirectory, name);
  fs.copyFileSync(source, destination);
  return { source: source, captured: destination, sha256: hashFile(destination), bytes: fs.statSync(destination).size };
}
function findPlayerFile(worldPath, uuid) {
  const roots = ['players/data', 'playerdata'].map(relative => path.join(worldPath, relative));
  const candidates = [];
  for (const root of roots) {
    if (!fs.existsSync(root)) continue;
    for (const entry of fs.readdirSync(root)) {
      if (entry.endsWith('.dat') && !entry.endsWith('.dat_old') && (!uuid || entry.startsWith(uuid))) candidates.push(path.join(root, entry));
    }
  }
  if (candidates.length === 0) return null;
  if (uuid && candidates.length > 1) throw new Error(`More than one player data file matched UUID '${uuid}'.`);
  if (!uuid && candidates.length > 1) throw new Error('More than one player data file found. Pass --player-uuid.');
  return candidates[0];
}
function findPlayerJson(worldPath, type, uuid) {
  const roots = [`players/${type}`, type].map(relative => path.join(worldPath, relative));
  for (const root of roots) {
    if (!fs.existsSync(root)) continue;
    const candidates = fs.readdirSync(root).filter(entry => entry.endsWith('.json') && (!uuid || entry.startsWith(uuid)));
    if (candidates.length === 1) return path.join(root, candidates[0]);
    if (candidates.length > 1) throw new Error(`More than one ${type} file found. Pass --player-uuid.`);
  }
  return null;
}
function countInventory(player) {
  const entries = Array.isArray(player?.Inventory) ? player.Inventory : [];
  const totals = {};
  const slots = [];
  for (const entry of entries) {
    const item = entry.id || entry.Id;
    const rawCount = entry.count ?? entry.Count ?? 0;
    const count = typeof rawCount === 'number' ? rawCount : Number(rawCount);
    if (!item || !Number.isFinite(count) || count <= 0) continue;
    totals[item] = (totals[item] || 0) + count;
    slots.push({ slot: entry.Slot ?? null, item, count });
  }
  slots.sort((a, b) => (a.slot ?? 999) - (b.slot ?? 999) || a.item.localeCompare(b.item));
  return { entries: slots, totals: Object.fromEntries(Object.entries(totals).sort(([a], [b]) => a.localeCompare(b))) };
}
function difficultyName(value) { return ({ 0: 'peaceful', 1: 'easy', 2: 'normal', 3: 'hard' })[value] || `unknown:${value}`; }
function gameModeName(value) { return ({ 0: 'survival', 1: 'creative', 2: 'adventure', 3: 'spectator' })[value] || `unknown:${value}`; }

function capture() {
  const worldPath = path.resolve(argument('world'));
  const outputDirectory = path.resolve(argument('out'));
  const stage = argument('stage');
  const logsPath = argument('logs', false);
  const uuid = argument('player-uuid', false);
  if (!fs.existsSync(worldPath)) throw new Error(`World path does not exist: ${worldPath}`);
  ensureDirectory(outputDirectory);
  const artifactsDirectory = path.join(outputDirectory, 'artifacts');
  ensureDirectory(artifactsDirectory);
  const levelPath = path.join(worldPath, 'level.dat');
  if (!fs.existsSync(levelPath)) throw new Error(`Missing level.dat in ${worldPath}`);
  const level = readFile(levelPath);
  const data = level.Data || level;
  const playerFile = findPlayerFile(worldPath, uuid);
  const playerFromFile = playerFile ? readFile(playerFile) : null;
  const player = playerFromFile || data.Player || null;
  if (!player) throw new Error('No player NBT found in player data or level.dat.');
  const resolvedUuid = uuid || (playerFile ? path.basename(playerFile, '.dat') : null);
  const statsPath = findPlayerJson(worldPath, 'stats', resolvedUuid);
  const advancementsPath = findPlayerJson(worldPath, 'advancements', resolvedUuid);
  const stats = statsPath ? JSON.parse(fs.readFileSync(statsPath, 'utf8')) : null;
  const advancements = advancementsPath ? JSON.parse(fs.readFileSync(advancementsPath, 'utf8')) : null;
  const artifacts = {
    level: copyArtifact(levelPath, artifactsDirectory, 'level.dat'),
    playerData: copyArtifact(playerFile, artifactsDirectory, 'player.dat'),
    stats: copyArtifact(statsPath, artifactsDirectory, 'stats.json'),
    advancements: copyArtifact(advancementsPath, artifactsDirectory, 'advancements.json'),
    latestLog: logsPath ? copyArtifact(path.join(path.resolve(logsPath), 'latest.log'), artifactsDirectory, 'latest.log') : null
  };
  const gameType = player.playerGameType ?? data.GameType ?? null;
  const difficulty = data.Difficulty ?? data.difficulty_settings?.difficulty ?? null;
  const state = {
    schemaVersion: 'minemark-world-state-v1',
    stage,
    capturedAt: new Date().toISOString(),
    worldPath,
    playerUuid: resolvedUuid,
    playerDataSource: playerFile ? path.relative(worldPath, playerFile).replaceAll('\\', '/') : 'level.dat:Data.Player',
    level: { dataVersion: data.DataVersion ?? null, gameVersion: data.Version?.Name ?? null, gameType, gameMode: gameType === null ? null : gameModeName(gameType), difficulty, difficultyName: typeof difficulty === 'string' ? difficulty : difficulty === null ? null : difficultyName(difficulty), allowCommands: data.allowCommands === true || data.allowCommands === 1, gameRules: data.GameRules || null },
    player: { gameType: player.playerGameType ?? null, gameMode: player.playerGameType === undefined ? null : gameModeName(player.playerGameType), health: player.Health ?? null, foodLevel: player.foodLevel ?? null, position: Array.isArray(player.Pos) ? player.Pos : null, inventory: countInventory(player) },
    statistics: stats?.stats || null,
    advancements: advancements ? { count: Object.keys(advancements).length, records: advancements } : null,
    artifacts
  };
  const statePath = path.join(outputDirectory, 'state.json');
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2) + '\n');
  process.stdout.write(JSON.stringify({ statePath, stage, playerDataSource: state.playerDataSource, itemCount: Object.keys(state.player.inventory.totals).length }, null, 2) + '\n');
}

try { capture(); } catch (error) { process.stderr.write(`capture-world-state: ${error.message}\n`); process.exitCode = 1; }
