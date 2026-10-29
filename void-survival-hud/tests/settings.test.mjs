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
  assert.equal(result.layout, 'cards');
  assert.equal(result.unit, 'kmh');
  assert.equal(result.showLabels, true);
  assert.deepEqual(result.positions.vitals, { x: 20, y: 0 });
  assert.deepEqual(result.positions.vehicle, { x: 100, y: 72 });
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
  assert.deepEqual(result.positions.vitals, { x: 10, y: 86 });
  result.positions.voice.x = 90;
  assert.equal(defaults.positions.voice.x, 20);
  assert.equal(DEFAULTS.positions.voice.x, 20);
});

test('loaded positions and scaled widgets stay inside the current resolution', () => {
  const p = fitPosition({ x: 99, y: 99 }, 398 * 1.3, 110 * 1.3, 1280, 720);
  assert.ok(p.x / 100 * 1280 + 398 * 1.3 <= 1272 + 1e-8);
  assert.ok(p.y / 100 * 720 + 110 * 1.3 <= 712 + 1e-8);
  const negative = fitPosition({ x: -30, y: -10 }, 254, 195, 1920, 1080);
  assert.ok(negative.x > 0 && negative.y > 0);
});
