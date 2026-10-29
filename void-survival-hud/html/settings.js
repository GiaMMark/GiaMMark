export const DEFAULTS = Object.freeze({
  version: 2, accent: '#a78bfa', secondary: '#67e8f9', opacity: 65,
  scale: 100, layout: 'row', showLabels: false, showBackground: false, unit: 'kmh',
  widgets: { vitals: true, vehicle: true, voice: true },
  positions: { vitals: { x: 20, y: 90 }, vehicle: { x: 78, y: 90 }, voice: { x: 62, y: 90 } },
});

export const clone = (value) => JSON.parse(JSON.stringify(value));
export const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
const number = (value, fallback, min, max) => typeof value === 'number' && Number.isFinite(value)
  ? clamp(value, min, max) : fallback;
const color = (value, fallback) => typeof value === 'string' && /^#[0-9a-f]{6}$/i.test(value)
  ? value.toLowerCase() : fallback;

// Use only known cosmetic fields; saved or incoming JSON never becomes CSS/HTML directly.
export function normalizeSettings(value, defaults = DEFAULTS) {
  const source = value && typeof value === 'object' ? value : {};
  const base = defaults === DEFAULTS ? clone(DEFAULTS) : normalizeSettings(defaults);
  base.version = 2;
  base.accent = color(source.accent, base.accent);
  base.secondary = color(source.secondary, base.secondary);
  base.opacity = number(source.opacity, base.opacity, 35, 100);
  base.scale = number(source.scale, base.scale, 70, 130);
  if (['row', 'compact'].includes(source.layout)) base.layout = source.layout;
  else if (source.layout === 'cards') base.layout = 'row';
  if (['kmh', 'mph'].includes(source.unit)) base.unit = source.unit;
  const legacy = source.version === 1 || (source.version !== 2 && source.layout === 'cards');
  if (legacy) base.showLabels = false;
  else if (typeof source.showLabels === 'boolean') base.showLabels = source.showLabels;
  if (typeof source.showBackground === 'boolean') base.showBackground = source.showBackground;
  for (const id of Object.keys(base.widgets)) {
    if (typeof source.widgets?.[id] === 'boolean') base.widgets[id] = source.widgets[id];
    const position = source.positions?.[id];
    base.positions[id] = {
      x: number(position?.x, base.positions[id].x, 0, 100),
      y: number(position?.y, base.positions[id].y, 0, 100),
    };
  }
  return base;
}

export function fitPosition(position, width, height, viewportWidth, viewportHeight) {
  const vw = Math.max(1, viewportWidth), vh = Math.max(1, viewportHeight);
  const margin = 8;
  return {
    x: clamp(position.x, 100 * margin / vw, Math.max(100 * margin / vw, 100 * (vw - width - margin) / vw)),
    y: clamp(position.y, 100 * margin / vh, Math.max(100 * margin / vh, 100 * (vh - height - margin) / vh)),
  };
}
