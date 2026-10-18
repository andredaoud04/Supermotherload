// Reproducible local / Vercel build. No npm dependencies or global Godot install.
import { mkdir, access, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { createWriteStream } from 'node:fs';
import { Readable, Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import path from 'node:path';
const version = '4.6.3';
const root = path.resolve(import.meta.dirname, '..');
process.chdir(root);
const windows = process.platform === 'win32';
const binary = windows ? `Godot_v${version}-stable_win64_console.exe` : `Godot_v${version}-stable_linux.x86_64`;
const archive = `Godot_v${version}-stable_${windows ? 'win64.exe' : 'linux.x86_64'}.zip`;
const templates = `Godot_v${version}-stable_export_templates.tpz`;
const base = `https://github.com/godotengine/godot-builds/releases/download/${version}-stable`;
const executable = path.join(root, '.tools', 'godot', binary);
await mkdir('.tools/godot', {recursive: true});
await mkdir('.tools/templates', {recursive: true});
await mkdir('build/web', {recursive: true});
await writeFile('build/.gdignore', '');
async function exists(file) { try { await access(file); return true; } catch { return false; } }
function run(cmd, args) {
  const result = spawnSync(cmd, args, {cwd: root, encoding: 'utf8', timeout: 180000, maxBuffer: 8 * 1024 * 1024});
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  // Godot's editor can return 0 despite GDScript parse errors.
  if (result.error || result.status !== 0 || /SCRIPT ERROR:|ERROR: Failed to load|Parse Error:/.test((result.stdout || '') + (result.stderr || ''))) {
    throw result.error || new Error(`${cmd} failed (${result.status})`);
  }
}
let sums;
async function download(name, destination) {
  if (!sums) {
    const response = await fetch(`${base}/SHA512-SUMS.txt`);
    if (!response.ok) throw new Error(`Checksum download: ${response.status}`);
    sums = await response.text();
  }
  const response = await fetch(`${base}/${name}`);
  if (!response.ok) throw new Error(`Download ${name}: ${response.status}`);
  const expected = sums.split('\n').find(line => line.trim().endsWith(name))?.trim().split(/\s+/)[0];
  const hash = createHash('sha512');
  const verifier = new Transform({transform(chunk, encoding, done) { hash.update(chunk); done(null, chunk); }});
  await pipeline(Readable.fromWeb(response.body), verifier, createWriteStream(destination));
  const actual = hash.digest('hex');
  if (actual !== expected?.toLowerCase()) throw new Error(`SHA512 mismatch: ${name}`);
}
if (!await exists(executable)) {
  await download(archive, '.tools/godot.zip');
  if (windows) run('powershell.exe', ['-NoProfile', '-Command', "Expand-Archive -LiteralPath '.tools/godot.zip' -DestinationPath '.tools/godot' -Force"]);
  else run('unzip', ['-o', '.tools/godot.zip', '-d', '.tools/godot']);
}
if (!await exists('.tools/templates/web_nothreads_release.zip')) {
  await download(templates, '.tools/templates.tpz');
  if (windows) {
    run('powershell.exe', ['-NoProfile', '-Command', `Add-Type -AssemblyName System.IO.Compression.FileSystem; $archive = [System.IO.Compression.ZipFile]::OpenRead((Join-Path (Get-Location) '.tools/templates.tpz')); foreach ($entry in $archive.Entries) { if ($entry.Name -in @('web_nothreads_debug.zip','web_nothreads_release.zip')) { [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path (Join-Path (Get-Location) '.tools/templates') $entry.Name), $true) } }; $archive.Dispose()`]);
  } else run('unzip', ['-jo', '.tools/templates.tpz', 'templates/web_nothreads_debug.zip', 'templates/web_nothreads_release.zip', '-d', '.tools/templates']);
}
await writeFile('.tools/godot/_sc_', '');
run(executable, ['--headless', '--path', root, '--editor', '--import', '--quit', '--log-file', path.join(root, '.tools/import.log')]);
  for (const suite of ['smoke', 'persistence', 'controls', 'colony', 'network_smoke']) {
  run(executable, ['--headless', '--path', root, '--script', `res://tests/${suite}.gd`, '--log-file', path.join(root, `.tools/${suite}.log`)]);
}
run(executable, ['--headless', '--path', root, '--export-release', 'Web', 'build/web/index.html', '--log-file', path.join(root, '.tools/export.log')]);
for (const file of ['index.html', 'index.js', 'index.wasm', 'index.pck']) if (!await exists(`build/web/${file}`)) throw new Error(`Missing ${file}`);
await writeFile('build/web/build-info.json', JSON.stringify({engine: version, commit: process.env.VERCEL_GIT_COMMIT_SHA || process.env.GITHUB_SHA || 'local'}, null, 2));
console.log('Verified web export ready: build/web');
