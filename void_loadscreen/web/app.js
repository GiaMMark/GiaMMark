'use strict';

(() => {
  const $ = (id) => document.getElementById(id);
  const isPreview = new URLSearchParams(location.search).get('preview') === '1';
  const audio = $('audio');
  const defaults = {
    brand: { name: 'VOID', eyebrow: 'ROLEPLAY EXPERIENCE', tagline: 'Ogni storia\ninizia dal vuoto.', description: 'Una città. Infinite possibilità.\nLa prossima storia porta il tuo nome.' },
    appearance: { accent: '#ededed', background: '#090909', animation: true },
    tips: { enabled: true, intervalMs: 9000, items: ['Dai un’identità al tuo personaggio. Il resto arriva vivendo.', 'Rispetta la storia degli altri: il roleplay si costruisce insieme.', 'Durante il caricamento puoi regolare o disattivare la musica.'] },
    music: { enabled: true, autoplay: true, volume: 0.22, tracks: [{ src: 'media/void-ambient.ogg', title: 'VOID / SIGNAL 01', artist: 'VOID' }] },
    links: [],
    rules: [{ title: 'Rispetto, prima di tutto.', text: 'Tratta gli altri giocatori con rispetto. Dietro ogni personaggio c’è una persona.' }, { title: 'Vivi la tua storia.', text: 'Rimani nel personaggio e lascia spazio al gioco e alle conseguenze delle tue azioni.' }, { title: 'Costruiamo qualcosa insieme.', text: 'Consulta il regolamento completo della community prima di iniziare la tua avventura.' }],
    labels: { connecting: 'Connessione al server', downloading: 'Download risorse', initializing: 'Inizializzazione', loadingMap: 'Caricamento mappa', ready: 'Pronto a entrare', waiting: 'Preparazione del personaggio' },
    diagnostics: false
  };
  let config;
  let progress = 0;
  let stage = 'connecting';
  let trackIndex = 0;
  let tipIndex = 0;
  let tipTimer;
  let leaving = false;
  let playAttempt = 0;
  let lastConfigTracks = '';
  let storage = {};
  try { storage = JSON.parse(localStorage.getItem('void_loadscreen.audio') || '{}') || {}; } catch (_) { /* Storage may be disabled by CEF. */ }
  let preferredVolume = typeof storage.volume === 'number' && Number.isFinite(storage.volume) ? Math.min(1, Math.max(0, storage.volume)) : null;
  let preferredMuted = storage.muted === true;

  function string(value, fallback = '', max = 400) {
    return typeof value === 'string' ? value.slice(0, max) : fallback;
  }

  function object(value) { return value && typeof value === 'object' && !Array.isArray(value) ? value : {}; }

  function finite(value, fallback, min, max) {
    return typeof value === 'number' && Number.isFinite(value) ? Math.min(max, Math.max(min, value)) : fallback;
  }

  function safeLink(value) {
    try {
      const url = new URL(value);
      return url.protocol === 'https:' && !url.username && !url.password ? url.href : null;
    } catch (_) { return null; }
  }

  function safeTrack(value) {
    if (typeof value !== 'string' || value.length > 300 || /[\\?#\u0000-\u001f]/.test(value)) return null;
    // Keep audio in the resource. No third-party requests, traversal or script URLs.
    if (!/^(?:media\/)?[A-Za-z0-9_.\/-]+\.(?:ogg|mp3|wav)$/i.test(value) || value.startsWith('/') || value.split('/').includes('..')) return null;
    return value;
  }

  function sanitize(raw) {
    const source = object(raw);
    const brand = object(source.brand), appearance = object(source.appearance), tips = object(source.tips), music = object(source.music), labels = object(source.labels);
    const tracks = Array.isArray(music.tracks) ? music.tracks.slice(0, 30).flatMap((entry) => {
      const track = object(entry), src = safeTrack(track.src);
      return src ? [{ src, title: string(track.title, 'VOID / AUDIO', 80), artist: string(track.artist, 'VOID', 80) }] : [];
    }) : defaults.music.tracks;
    const rules = Array.isArray(source.rules) ? source.rules.slice(0, 20).map((entry) => ({ title: string(object(entry).title, '', 100), text: string(object(entry).text, '', 1000) })).filter((entry) => entry.title || entry.text) : defaults.rules;
    const links = Array.isArray(source.links) ? source.links.slice(0, 5).flatMap((entry) => {
      const link = object(entry), url = safeLink(link.url);
      return url ? [{ url, label: string(link.label, 'COMMUNITY', 30) }] : [];
    }) : [];
    const items = Array.isArray(tips.items) ? tips.items.slice(0, 50).filter((item) => typeof item === 'string' && item.trim()).map((item) => item.slice(0, 400)) : defaults.tips.items;
    const result = {
      brand: {
        name: string(brand.name, defaults.brand.name, 24), eyebrow: string(brand.eyebrow, defaults.brand.eyebrow, 80),
        tagline: string(brand.tagline, defaults.brand.tagline, 180), description: string(brand.description, defaults.brand.description, 400)
      },
      appearance: {
        accent: /^#[\da-f]{6}$/i.test(appearance.accent) ? appearance.accent : defaults.appearance.accent,
        background: /^#[\da-f]{6}$/i.test(appearance.background) ? appearance.background : defaults.appearance.background,
        animation: appearance.animation !== false
      },
      tips: { enabled: tips.enabled !== false, intervalMs: finite(tips.intervalMs, 9000, 4000, 120000), items },
      music: { enabled: music.enabled !== false && tracks.length > 0, autoplay: music.autoplay !== false, volume: finite(music.volume, 0.22, 0, 1), tracks },
      rules, links, labels: {}, playerName: string(source.playerName, '', 80), diagnostics: source.diagnostics === true
    };
    for (const [key, value] of Object.entries(defaults.labels)) result.labels[key] = string(labels[key], value, 100);
    return result;
  }

  function persistAudio() {
    try { localStorage.setItem('void_loadscreen.audio', JSON.stringify({ volume: audio.volume, muted: audio.muted })); } catch (_) { /* Optional persistence. */ }
  }

  function updateAudio() {
    const playing = !audio.paused && !audio.ended;
    $('music-player').classList.toggle('is-playing', playing);
    $('music-player').classList.toggle('is-muted', audio.muted || audio.volume === 0);
    $('music-toggle').setAttribute('aria-label', playing ? 'Metti in pausa la musica' : 'Riproduci musica');
    $('music-toggle').setAttribute('aria-pressed', String(playing));
    $('music-mute').setAttribute('aria-label', audio.muted ? 'Attiva audio' : 'Disattiva audio');
    $('music-mute').setAttribute('aria-pressed', String(audio.muted));
    $('music-volume').value = String(Math.round(audio.volume * 100));
    if (playing) $('music-status').textContent = audio.muted || audio.volume === 0 ? 'AUDIO DISATTIVATO' : 'IN RIPRODUZIONE';
  }

  async function playMusic() {
    if (leaving || !config.music.enabled) return;
    const attempt = ++playAttempt;
    $('music-status').textContent = 'CONNESSIONE AUDIO';
    try {
      await audio.play();
      if (leaving || attempt !== playAttempt) return;
      updateAudio();
    } catch (_) {
      if (leaving || attempt !== playAttempt) return;
      $('music-status').textContent = audio.error ? 'AUDIO NON DISPONIBILE' : 'CLICCA PER ATTIVARE L’AUDIO';
      updateAudio();
    }
  }

  function setTrack(index, shouldPlay) {
    if (!config.music.tracks.length) return;
    ++playAttempt;
    trackIndex = (index + config.music.tracks.length) % config.music.tracks.length;
    const track = config.music.tracks[trackIndex];
    audio.pause();
    audio.src = track.src;
    audio.loop = config.music.tracks.length === 1;
    $('music-title').textContent = track.title;
    $('music-title').title = track.artist ? `${track.title} — ${track.artist}` : track.title;
    $('music-status').textContent = 'AUDIO IN PAUSA';
    updateAudio();
    if (shouldPlay) playMusic();
  }

  function audioAction() {
    if (leaving || !config.music.enabled) return;
    if (audio.paused) playMusic();
    else {
      ++playAttempt;
      audio.pause();
      $('music-status').textContent = 'AUDIO IN PAUSA';
      updateAudio();
    }
  }

  function renderStage() {
    $('progress-value').textContent = String(progress);
    $('progress-bar').style.width = `${progress}%`;
    $('loading-progress').setAttribute('aria-valuenow', String(progress));
    $('loading-status').textContent = config.labels[stage] || config.labels.connecting;
    $('transfer-state').textContent = progress >= 100 ? 'IN ATTESA DEL TUO PERSONAGGIO' : 'ATTENDI IL CARICAMENTO';
  }

  function renderTips() {
    clearInterval(tipTimer);
    $('tips').hidden = !config.tips.enabled || !config.tips.items.length;
    tipIndex = 0;
    $('tip-text').textContent = config.tips.items[0] || '';
    if (config.tips.enabled && config.tips.items.length > 1) tipTimer = setInterval(() => {
      tipIndex = (tipIndex + 1) % config.tips.items.length;
      $('tip-text').textContent = config.tips.items[tipIndex];
    }, config.tips.intervalMs);
  }

  function applyConfig(raw) {
    if (leaving) return;
    config = sanitize(raw);
    document.title = `${config.brand.name} — Il prossimo capitolo`;
    $('brand-name').textContent = config.brand.name;
    $('eyebrow').textContent = config.brand.eyebrow;
    $('headline').textContent = config.brand.tagline;
    $('description').textContent = config.brand.description;
    $('player-welcome').textContent = config.playerName ? `BENVENUTO, ${config.playerName.toLocaleUpperCase('it-IT')}. LA TUA STORIA TI ASPETTA.` : 'IL TUO PROSSIMO CAPITOLO STA ARRIVANDO.';
    document.documentElement.style.setProperty('--accent', config.appearance.accent);
    document.documentElement.style.setProperty('--bg', config.appearance.background);
    document.body.classList.toggle('no-animation', !config.appearance.animation);
    $('rules-list').replaceChildren();
    for (const rule of config.rules) {
      const item = document.createElement('li');
      const title = document.createElement('h3');
      const body = document.createElement('p');
      title.textContent = rule.title; body.textContent = rule.text;
      item.append(title, body); $('rules-list').append(item);
    }
    $('rules-button').hidden = config.rules.length === 0;
    if (!config.rules.length && $('rules-dialog').open) $('rules-dialog').close();
    $('links').replaceChildren();
    for (const link of config.links) {
      const button = document.createElement('button');
      button.type = 'button'; button.textContent = link.label;
      const arrow = document.createElement('span'); arrow.className = 'diagonal-arrow'; arrow.setAttribute('aria-hidden', 'true'); button.append(arrow);
      button.addEventListener('click', () => {
        if (typeof window.invokeNative === 'function') window.invokeNative('openUrl', link.url);
        else window.open(link.url, '_blank', 'noopener,noreferrer');
      });
      $('links').append(button);
    }
    renderTips(); renderStage();
    $('music-player').hidden = !config.music.enabled;
    $('playlist-controls').hidden = config.music.tracks.length < 2;
    audio.volume = preferredVolume === null ? config.music.volume : preferredVolume;
    audio.muted = preferredMuted;
    const trackSignature = JSON.stringify(config.music.tracks);
    if (!config.music.enabled) { ++playAttempt; audio.pause(); }
    else if (lastConfigTracks !== trackSignature) {
      lastConfigTracks = trackSignature;
      setTrack(0, config.music.autoplay);
    }
    updateAudio();
  }

  function setProgress(value) {
    if (typeof value !== 'number' || !Number.isFinite(value)) return;
    progress = Math.max(progress, Math.floor(Math.min(1, Math.max(0, value)) * 100));
    if (progress >= 100) stage = 'waiting';
    else if (stage === 'connecting') stage = 'downloading';
    renderStage();
  }

  function shutdown(duration) {
    if (leaving) return;
    const durationMs = finite(duration, 500, 0, 10000);
    leaving = true; ++playAttempt;
    clearInterval(tipTimer);
    if ($('rules-dialog').open) $('rules-dialog').close();
    $('screen').style.transitionDuration = `${durationMs}ms`;
    document.body.classList.add('is-leaving');
    $('screen').classList.add('leaving');
    stage = 'ready'; renderStage();
    if (durationMs === 0) { audio.pause(); return; }
    const startVolume = audio.volume;
    const started = performance.now();
    function fade(now) {
      const elapsed = Math.min(1, (now - started) / durationMs);
      audio.volume = startVolume * (1 - elapsed);
      if (elapsed < 1) requestAnimationFrame(fade);
      else audio.pause();
    }
    requestAnimationFrame(fade);
  }

  window.addEventListener('message', (event) => {
    const message = object(event.data);
    if (config.diagnostics && typeof message.eventName === 'string'
      && /^(?:void:(?:config|shutdown)|loadProgress|startDataFileEntries|onDataFileEntry|startInitFunction|startInitFunctionOrder|initFunctionInvoking|initFunctionInvoked|performMapLoadFunction|endDataFileEntries)$/.test(message.eventName)) {
      console.debug('[void_loadscreen] event:', message.eventName);
    }
    if (message.eventName === 'void:config') { applyConfig(message.config); return; }
    if (message.eventName === 'void:shutdown') { shutdown(message.durationMs); return; }
    if (leaving) return;
    if (message.eventName === 'loadProgress') { setProgress(message.loadFraction); return; }
    if (progress >= 100) return;
    const stages = { startDataFileEntries: 'downloading', onDataFileEntry: 'downloading', startInitFunction: 'initializing', startInitFunctionOrder: 'initializing', initFunctionInvoking: 'initializing', initFunctionInvoked: 'initializing', performMapLoadFunction: 'loadingMap', endDataFileEntries: 'initializing' };
    if (stages[message.eventName]) { stage = stages[message.eventName]; renderStage(); }
  });

  $('music-toggle').addEventListener('click', audioAction);
  $('music-mute').addEventListener('click', () => {
    audio.muted = !audio.muted; preferredMuted = audio.muted; persistAudio(); updateAudio();
  });
  $('music-volume').addEventListener('input', () => {
    audio.volume = Number($('music-volume').value) / 100;
    if (audio.volume > 0 && audio.muted) { audio.muted = false; preferredMuted = false; }
    preferredVolume = audio.volume; persistAudio(); updateAudio();
  });
  $('music-prev').addEventListener('click', () => setTrack(trackIndex - 1, !audio.paused));
  $('music-next').addEventListener('click', () => setTrack(trackIndex + 1, !audio.paused));
  audio.addEventListener('ended', () => { if (config.music.tracks.length > 1 && !leaving) setTrack(trackIndex + 1, true); });
  audio.addEventListener('error', () => { $('music-status').textContent = 'AUDIO NON DISPONIBILE'; updateAudio(); });
  audio.addEventListener('play', updateAudio);
  audio.addEventListener('pause', updateAudio);
  $('rules-button').addEventListener('click', () => { $('rules-dialog').showModal(); $('rules-close').focus(); });
  $('rules-close').addEventListener('click', () => $('rules-dialog').close());
  $('rules-done').addEventListener('click', () => $('rules-dialog').close());
  document.addEventListener('keydown', (event) => {
    if (event.code === 'Space' && !event.repeat && !$('rules-dialog').open && !['INPUT', 'SELECT', 'TEXTAREA', 'BUTTON', 'A'].includes(document.activeElement?.tagName)) {
      event.preventDefault(); audioAction();
    }
  });
  function clock() { $('clock').textContent = new Date().toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }); }
  clock(); setInterval(clock, 15000);
  applyConfig(object(window.nuiHandoverData).void_loadscreen);
  $('preview-badge').hidden = !isPreview;
  if (isPreview) {
    // Explicit browser demo only. The real loadscreen never manufactures progress.
    const demo = [{ fraction: 0.12, event: 'startDataFileEntries' }, { fraction: 0.37, event: 'initFunctionInvoking' }, { fraction: 0.68, event: 'performMapLoadFunction' }, { fraction: 0.86, event: 'performMapLoadFunction' }, { fraction: 1, event: 'loadProgress' }];
    let index = 0;
    const demoTimer = setInterval(() => {
      if (leaving || index >= demo.length) { clearInterval(demoTimer); return; }
      const step = demo[index++];
      window.postMessage({ eventName: 'loadProgress', loadFraction: step.fraction }, '*');
      if (step.event !== 'loadProgress') window.postMessage({ eventName: step.event }, '*');
    }, 3000);
  }
})();
