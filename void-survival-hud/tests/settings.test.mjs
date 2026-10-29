import test from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULTS, normalizeSettings, fitPosition } from '../html/settings.js';

test('malformed stored settings cannot inject colors or escape viewport constraints', () => {
  const result = normalizeSettings({
    accent: 'red; background:url(https://example.com)', secondary: '#00FFAA',
    scale: 999, opacity: -1, layout: '__proto__', unit: 'knots', showLabels: 'false',
    positions: { vitals: { x: Infinity, y: -30 }, vehicle: { x: 999, y: '20' } },
    widgets: { voice: false, vitals: 'false' }, injected: '<script>',
  });
  assert.equal(result.accent, DEFAULTS.accent);
  assert.equal(result.secondary, '#00ffaa');
  assert.equal(result.scale, 130);
  assert.equal(result.opacity, 35);
  assert.equal(result.layout, 'row');
  assert.equal(result.unit, 'kmh');
  assert.equal(result.showLabels, false);
  assert.deepEqual(result.positions.vitals, { x: 20, y: 0 });
  assert.deepEqual(result.positions.vehicle, { x: 100, y: 90 });
  assert.equal(result.widgets.voice, false);
  assert.equal(result.widgets.vitals, true);
  assert.equal(Object.hasOwn(result, 'injected'), false);
});

test('server defaults are merged without sharing mutable widget or position objects', () => {
  const defaults = normalizeSettings({ accent: '#123456', scale: 80, widgets: { voice: false } });
  const result = normalizeSettings({ opacity: 60, positions: { vitals: { x: 10 } } }, defaults);
  assert.equal(result.accent, '#123456');
  assert.equal(result.scale, 80);
  assert.equal(result.opacity, 60);
  assert.equal(result.widgets.voice, false);
  assert.deepEqual(result.positions.vitals, { x: 10, y: 90 });
  result.positions.voice.x = 90;
  assert.equal(defaults.positions.voice.x, 62);
  assert.equal(DEFAULTS.positions.voice.x, 62);
});

test('loaded positions and scaled widgets stay inside the current resolution', () => {
  const p = fitPosition({ x: 99, y: 99 }, 398 * 1.3, 110 * 1.3, 1280, 720);
  assert.ok(p.x / 100 * 1280 + 398 * 1.3 <= 1272 + 1e-8);
  assert.ok(p.y / 100 * 720 + 110 * 1.3 <= 712 + 1e-8);
  const negative = fitPosition({ x: -30, y: -10 }, 254, 195, 1920, 1080);
  assert.ok(negative.x > 0 && negative.y > 0);
});


test('version 1 preferences migrate to a row without losing personal placement and colors', () => {
  const result = normalizeSettings({
    version: 1, layout: 'cards', showLabels: true, accent: '#123456', secondary: '#abcdef',
    scale: 110, opacity: 75, unit: 'mph', widgets: { voice: false },
    positions: { vitals: { x: 11, y: 65 }, vehicle: { x: 70, y: 81 } },
  });
  assert.equal(result.version, 2);
  assert.equal(result.layout, 'row');
  assert.equal(result.showLabels, false);
  assert.equal(result.accent, '#123456');
  assert.equal(result.secondary, '#abcdef');
  assert.equal(result.scale, 110);
  assert.equal(result.opacity, 75);
  assert.equal(result.unit, 'mph');
  assert.equal(result.widgets.voice, false);
  assert.deepEqual(result.positions.vitals, { x: 11, y: 65 });
  assert.deepEqual(result.positions.vehicle, { x: 70, y: 81 });
});

test('version 2 can enable labels and select compact row after migration', () => {
  const result = normalizeSettings({ version: 2, layout: 'compact', showLabels: true });
  assert.equal(result.layout, 'compact');
  assert.equal(result.showLabels, true);
  assert.equal(normalizeSettings({ layout: 'cards', showLabels: true }).showLabels, false);
});

test('saved settings without background field inherit transparent modules and keep opacity', () => {
  const result = normalizeSettings({ version: 2, opacity: 82, accent: '#123456' });
  assert.equal(result.showBackground, false);
  assert.equal(result.opacity, 82);
  assert.equal(result.accent, '#123456');
});

test('background preference accepts only booleans and persists both choices', () => {
  assert.equal(normalizeSettings({ showBackground: 'true' }).showBackground, false);
  assert.equal(normalizeSettings({ showBackground: 1 }).showBackground, false);
  const enabled = normalizeSettings(JSON.parse(JSON.stringify({ showBackground: true, opacity: 74 })));
  assert.equal(enabled.showBackground, true);
  assert.equal(enabled.opacity, 74);
  const disabled = normalizeSettings(JSON.parse(JSON.stringify({ ...enabled, showBackground: false })));
  assert.equal(disabled.showBackground, false);
  assert.equal(disabled.opacity, 74);
  const customDefaults = normalizeSettings({ showBackground: true });
  assert.equal(normalizeSettings({ showBackground: 'false' }, customDefaults).showBackground, true);
});
