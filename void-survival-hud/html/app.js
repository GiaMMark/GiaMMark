import { DEFAULTS, clone, clamp, normalizeSettings, fitPosition } from './settings.js';

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
// The live NUI is always transparent. Demo content only belongs to preview.html.
const isPreview = document.documentElement.dataset.preview === 'true';
const isNui = !isPreview;
const storageKey = 'void-survival-hud:preview:v1';
let defaults = clone(DEFAULTS);
let saved = clone(defaults);
let settings = clone(saved);
let editing = false;
let saving = false;
let selected = 'vitals';
let toastTimer;
let data = { visible: false, vehicle: { active: false } };
let previewVehicle = true;
const names = { vitals: 'Indicatori', vehicle: 'Veicolo', voice: 'Voce' };
const palettes = {
  void: ['#a78bfa', '#67e8f9'], toxic: ['#bef264', '#fbbf24'], ember: ['#fb923c', '#fda4af'],
};

async function post(endpoint, payload = {}) {
  if (!isNui) {
    if (endpoint === 'save') {
      try { localStorage.setItem(storageKey, JSON.stringify(payload.settings)); }
      catch { throw new Error('Il browser non consente il salvataggio locale.'); }
      return { ok: true, settings: payload.settings };
    }
    return { ok: true };
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    let resource = typeof window.GetParentResourceName === 'function' ? window.GetParentResourceName() : null;
    if (!resource && location.hostname.startsWith('cfx-nui-')) resource = location.hostname.slice(8);
    if (!resource && location.protocol === 'nui:') resource = location.hostname;
    if (!resource || !/^[a-z0-9_.-]+$/i.test(resource)) throw new Error('Collegamento NUI non disponibile.');
    const response = await fetch(`https://${resource}/${endpoint}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload), signal: controller.signal,
    });
    if (!response.ok) throw new Error('La risorsa HUD non risponde.');
    return await response.json();
  } finally { clearTimeout(timer); }
}

function toast(message) {
  clearTimeout(toastTimer);
  $('#toast').textContent = message;
  $('#toast').hidden = false;
  toastTimer = setTimeout(() => { $('#toast').hidden = true; }, 4000);
}

function applySettings() {
  const root = document.documentElement;
  root.style.setProperty('--accent', settings.accent);
  root.style.setProperty('--secondary', settings.secondary);
  root.style.setProperty('--panel', `rgba(13, 16, 22, ${settings.opacity / 100})`);
  root.style.setProperty('--hud-scale', settings.scale / 100);
  $('#hud').classList.toggle('compact', settings.layout === 'compact');
  $('#hud').classList.toggle('no-labels', !settings.showLabels);
  $('#hud').classList.toggle('no-background', !settings.showBackground);
  render();
  fitWidgets();
}

function fitWidgets() {
  for (const id of Object.keys(names)) {
    const widget = $(`#${id}`);
    // Hidden modules have no bounding box. They are fitted once made visible.
    if (!widget.hidden && !$('#hud').hidden) {
      const bounds = widget.getBoundingClientRect();
      settings.positions[id] = fitPosition(settings.positions[id], bounds.width, bounds.height, innerWidth, innerHeight);
    }
    const position = settings.positions[id];
    widget.style.left = `${position.x}%`;
    widget.style.top = `${position.y}%`;
  }
  if (editing) syncPosition();
}

function syncControls() {
  for (const key of ['accent', 'secondary', 'scale', 'opacity', 'unit']) $(`#${key}`).value = settings[key];
  $('#accent-value').textContent = settings.accent.toUpperCase();
  $('#secondary-value').textContent = settings.secondary.toUpperCase();
  $('#scale-value').value = `${Math.round(settings.scale)}%`;
  $('#opacity-value').value = `${Math.round(settings.opacity)}%`;
  $('#show-labels').checked = settings.showLabels;
  $('#show-background').checked = settings.showBackground;
  $('#opacity').disabled = !settings.showBackground;
  $$('[data-toggle]').forEach((input) => { input.checked = settings.widgets[input.dataset.toggle]; });
  $$('[data-layout]').forEach((button) => button.setAttribute('aria-pressed', String(button.dataset.layout === settings.layout)));
  $$('[data-palette]').forEach((button) => {
    const palette = palettes[button.dataset.palette];
    const active = palette[0] === settings.accent && palette[1] === settings.secondary;
    button.classList.toggle('active', active);
    button.setAttribute('aria-pressed', String(active));
  });
  syncPosition();
}

function syncPosition() {
  $('#selected-widget').value = selected;
  const pos = settings.positions[selected];
  for (const axis of ['x', 'y']) {
    $(`#position-${axis}`).value = pos[axis];
    $(`#position-${axis}-value`).value = `${pos[axis].toFixed(1)}%`;
  }
  $$('.widget').forEach((widget) => widget.classList.toggle('selected', editing && widget.dataset.widget === selected));
}

function selectWidget(id) {
  if (!Object.hasOwn(names, id)) return;
  selected = id;
  syncPosition();
}

function setEditor(open) {
  if (open && !editing) settings = clone(saved);
  if (!open) settings = clone(saved);
  editing = open;
  document.body.classList.toggle('editing', open);
  $('#editor').hidden = !open;
  $$('.widget').forEach((widget) => {
    widget.tabIndex = open ? 0 : -1;
    widget.setAttribute('aria-label', `${names[widget.dataset.widget]}${open ? ': trascina o usa le frecce per spostare' : ''}`);
  });
  applySettings();
  syncControls();
  if (open) $('#close-editor').focus({ preventScroll: true });
  else if (!isNui) $('#preview-editor').focus({ preventScroll: true });
}

async function closeEditor() {
  try {
    const result = await post('close');
    if (result.ok === false) throw new Error('Impossibile chiudere l’editor.');
    setEditor(false);
  } catch {
    toast('Chiusura non riuscita. Premi F7 o riavvia la risorsa HUD.');
  }
}

function percentage(value) {
  return typeof value === 'number' && Number.isFinite(value) ? clamp(value, 0, 100) : null;
}

function renderStat(name, value, dangerAtHigh = false) {
  const element = $(`[data-stat="${name}"]`);
  const amount = percentage(value);
  element.querySelector('.stat-value').textContent = amount === null ? '--' : Math.round(amount);
  element.querySelector('.stat-track i').style.width = `${amount ?? 0}%`;
  element.classList.toggle('unavailable', amount === null);
  const critical = amount !== null && (dangerAtHigh ? amount >= 70 : amount <= 20);
  element.classList.toggle('critical', name !== 'armor' && critical);
  const label = element.querySelector('.stat-label').textContent;
  element.title = amount === null ? `${label}: dato non disponibile` : `${label}: ${Math.round(amount)}%`;
}

function render() {
  $('#hud').hidden = !(data.visible || editing);
  for (const id of Object.keys(names)) {
    $(`#${id}`).hidden = !settings.widgets[id] || (id === 'vehicle' && !editing && !data.vehicle?.active);
  }
  renderStat('health', data.health);
  renderStat('armor', data.armor);
  renderStat('hunger', data.hunger);
  renderStat('thirst', data.thirst);
  renderStat('stress', data.stressConnected ? data.stress : null, true);
  if (!data.stressConnected) $('[data-stat="stress"]').title = 'Stress JG: addon non disponibile o non ancora pronto';
  const underwater = data.underwater === true;
  $('[data-stat="stamina"] .stat-label').textContent = underwater ? 'OSSIGENO' : 'ENERGIA';
  $('[data-stat="stamina"] use').setAttribute('href', underwater ? '#i-lungs' : '#i-bolt');
  renderStat('stamina', underwater ? data.oxygen : data.stamina);

  const talking = data.talking === true;
  $('#voice').classList.toggle('talking', talking);
  const voice = data.voice;
  $('#voice-mode').textContent = typeof voice === 'string' ? voice.slice(0, 16).toUpperCase()
    : typeof voice === 'number' ? (['VOCE', 'SUSSURRO', 'NORMALE', 'GRIDA'][clamp(Math.round(voice), 0, 3)]) : 'VOCE';
  $('#voice').dataset.level = typeof voice === 'number' ? clamp(Math.round(voice), 1, 3) : 2;

  const vehicle = data.vehicle || {};
  const active = vehicle.active === true;
  const miles = settings.unit === 'mph';
  const sourceMiles = vehicle.tripUnit === 'mi';
  const conversion = sourceMiles === miles ? 1 : miles ? 0.621371 : 1.609344;
  const speed = active && Number.isFinite(vehicle.speed) ? clamp(Math.round(vehicle.speed * conversion), 0, 999) : null;
  const speedText = speed === null ? '---' : String(speed).padStart(3, '0');
  // Construct the padded digits without HTML interpolation of incoming data.
  const dim = document.createElement('span');
  dim.className = 'dim';
  const leading = speed === null ? '' : speedText.match(/^0{0,2}/)[0];
  dim.textContent = leading;
  $('#speed').replaceChildren(dim, document.createTextNode(speedText.slice(leading.length)));
  $('#speed-unit').textContent = miles ? 'MPH' : 'KM/H';
  $('#gear').textContent = active && /^[NR0-9]{1,2}$/.test(String(vehicle.gear)) ? String(vehicle.gear) : 'N';
  $('#vehicle').setAttribute('aria-label', active ? 'Strumenti veicolo' : 'Anteprima strumenti veicolo: dati non disponibili');
  $('#rpm-fill').style.width = `${active && Number.isFinite(vehicle.rpm) ? clamp(vehicle.rpm, 0, 1) * 100 : 0}%`;
  const fuel = active ? percentage(vehicle.fuel) : null;
  $('#fuel').textContent = fuel === null ? '--%' : `${Math.round(fuel)}%`;
  $('#fuel-fill').style.width = `${fuel ?? 0}%`;
  $('.fuel-group').classList.toggle('critical', fuel !== null && fuel <= 15);
  const engine = active ? percentage(vehicle.engine) : null;
  $('#engine').textContent = engine === null ? '--%' : `${Math.round(engine)}%`;
  $('.engine-group').classList.toggle('critical', engine !== null && engine <= 30);
  $('#vehicle-lights').classList.toggle('on', active && vehicle.lights === true);
  $('#trip').textContent = active && Number.isFinite(vehicle.trip) ? Math.max(0, vehicle.trip * conversion).toFixed(1) : '0.0';
  $('#trip-unit').textContent = miles ? 'MI' : 'KM';
}

function setTab(tab, focus = false) {
  for (const id of ['style', 'position']) {
    const active = id === tab;
    $(`#panel-${id}`).hidden = !active;
    $(`#tab-${id}`).setAttribute('aria-selected', String(active));
    $(`#tab-${id}`).tabIndex = active ? 0 : -1;
  }
  if (focus) $(`#tab-${tab}`).focus();
}

$$('[data-tab]').forEach((button) => {
  button.addEventListener('click', () => setTab(button.dataset.tab));
  button.addEventListener('keydown', (event) => {
    if (['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) {
      event.preventDefault();
      setTab(event.key === 'Home' ? 'style' : event.key === 'End' ? 'position' : button.dataset.tab === 'style' ? 'position' : 'style', true);
    }
  });
});
setTab('style');

for (const key of ['accent', 'secondary', 'scale', 'opacity', 'unit']) {
  $(`#${key}`).addEventListener('input', (event) => {
    settings[key] = ['scale', 'opacity'].includes(key) ? Number(event.target.value) : event.target.value;
    applySettings();
    syncControls();
  });
}
$('#show-labels').addEventListener('change', (event) => {
  settings.showLabels = event.target.checked;
  applySettings();
});
$('#show-background').addEventListener('change', (event) => {
  settings.showBackground = event.target.checked;
  applySettings();
  syncControls();
});
$$('[data-layout]').forEach((button) => button.addEventListener('click', () => {
  settings.layout = button.dataset.layout;
  applySettings(); syncControls();
}));
$$('[data-palette]').forEach((button) => button.addEventListener('click', () => {
  [settings.accent, settings.secondary] = palettes[button.dataset.palette];
  applySettings(); syncControls();
}));
$$('[data-toggle]').forEach((input) => input.addEventListener('change', () => {
  settings.widgets[input.dataset.toggle] = input.checked;
  applySettings();
}));
$('#selected-widget').addEventListener('change', (event) => selectWidget(event.target.value));
for (const axis of ['x', 'y']) {
  $(`#position-${axis}`).addEventListener('input', (event) => {
    settings.positions[selected][axis] = Number(event.target.value);
    fitWidgets();
  });
}
$('#reset-position').addEventListener('click', () => {
  settings.positions[selected] = clone(defaults.positions[selected]);
  fitWidgets(); syncPosition();
});
$('#reset-settings').addEventListener('click', () => {
  settings = clone(defaults);
  applySettings(); syncControls();
  toast('Valori iniziali ripristinati. Premi Salva HUD per confermare.');
});
$('#close-editor').addEventListener('click', closeEditor);
$('#cancel-editor').addEventListener('click', closeEditor);
$('#save-settings').addEventListener('click', async () => {
  if (saving) return;
  saving = true;
  $('#save-settings').disabled = true;
  try {
    const result = await post('save', { settings: normalizeSettings(settings, defaults) });
    if (!result.ok) throw new Error(result.error || 'Salvataggio non riuscito.');
    saved = normalizeSettings(result.settings || settings, defaults);
    await closeEditor();
    toast(isNui ? 'HUD salvato per questo personaggio.' : 'HUD salvato in questo browser.');
  } catch (error) {
    toast(error.name === 'AbortError' ? 'Salvataggio scaduto. Riprova o chiudi con ESC.' : error.message);
  } finally {
    saving = false;
    $('#save-settings').disabled = false;
  }
});

let drag = null;
for (const widget of $$('.widget')) {
  widget.addEventListener('pointerdown', (event) => {
    if (!editing || event.button !== 0) return;
    const id = widget.dataset.widget;
    selectWidget(id);
    const bounds = widget.getBoundingClientRect();
    drag = { id, pointerId: event.pointerId, offsetX: event.clientX - bounds.left, offsetY: event.clientY - bounds.top };
    widget.setPointerCapture(event.pointerId);
    widget.classList.add('dragging');
    widget.focus({ preventScroll: true });
    event.preventDefault();
  });
  widget.addEventListener('pointermove', (event) => {
    if (!drag || drag.id !== widget.dataset.widget || !editing) return;
    settings.positions[drag.id] = { x: (event.clientX - drag.offsetX) / innerWidth * 100, y: (event.clientY - drag.offsetY) / innerHeight * 100 };
    fitWidgets();
  });
  const endDrag = () => { widget.classList.remove('dragging'); drag = null; };
  widget.addEventListener('pointerup', endDrag);
  widget.addEventListener('pointercancel', endDrag);
  widget.addEventListener('lostpointercapture', endDrag);
  widget.addEventListener('focus', () => { if (editing) selectWidget(widget.dataset.widget); });
  widget.addEventListener('keydown', (event) => {
    if (!editing || !['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) return;
    event.preventDefault();
    const pos = settings.positions[widget.dataset.widget];
    const delta = event.shiftKey ? 2 : 0.25;
    if (event.key === 'ArrowLeft') pos.x -= delta;
    if (event.key === 'ArrowRight') pos.x += delta;
    if (event.key === 'ArrowUp') pos.y -= delta;
    if (event.key === 'ArrowDown') pos.y += delta;
    fitWidgets();
  });
}

window.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && editing) { event.preventDefault(); closeEditor(); }
  if (!isNui && event.key === 'F7') { event.preventDefault(); setEditor(!editing); }
});
window.addEventListener('resize', fitWidgets);
window.addEventListener('message', ({ data: message }) => {
  if (!isNui || !message || typeof message !== 'object') return;
  if (message.action === 'init') {
    defaults = normalizeSettings(message.defaults);
    saved = normalizeSettings(message.settings, defaults);
    settings = clone(saved);
    applySettings(); syncControls();
  } else if (message.action === 'update' && message.data && typeof message.data === 'object') {
    data = message.data;
    render(); fitWidgets();
  } else if (message.action === 'editor' && typeof message.open === 'boolean') {
    setEditor(message.open);
  }
});

function previewData() {
  data = {
    visible: true, health: 92, armor: 48, hunger: 76, thirst: 64, stress: 28,
    stressConnected: true, stamina: 88, underwater: false, voice: 2, talking: false,
    vehicle: { active: previewVehicle, speed: 84, gear: 3, fuel: 68, engine: 96, rpm: 0.46, trip: 12.4, tripUnit: 'km', lights: true },
  };
  render(); fitWidgets();
}

if (!isNui) {
  document.body.classList.add('preview');
  try { saved = normalizeSettings(JSON.parse(localStorage.getItem(storageKey))); }
  catch { saved = clone(defaults); }
  settings = clone(saved);
  previewData();
  applySettings(); syncControls();
  $('#preview-editor').addEventListener('click', () => setEditor(!editing));
  $('#preview-vehicle').addEventListener('click', () => {
    previewVehicle = !previewVehicle;
    $('#preview-vehicle').textContent = previewVehicle ? 'Mostra a piedi' : 'Mostra in auto';
    previewData();
  });
  if (new URLSearchParams(location.search).get('editor') === '1') setEditor(true);
} else {
  // Retry only the NUI handshake; live data always comes from the FiveM client.
  const handshake = async (attempt = 0) => {
    try { await post('ready'); }
    catch { if (attempt < 3) setTimeout(() => handshake(attempt + 1), 1000); }
  };
  handshake();
}
