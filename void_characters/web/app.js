'use strict';

(() => {
  const $ = (id) => document.getElementById(id);
  const app = $('app');
  const preview = new URLSearchParams(window.location.search).get('preview') === '1';
  const inGame = typeof GetParentResourceName === 'function';
  const resource = inGame ? GetParentResourceName() : null;
  const state = { open: false, busy: false, characters: [], selectedId: null, creatingSlot: null, payload: {}, revision: 0 };
  let launchTimer;
  let handshakeRunning = false;
  let previewCharacters = [
    { id: 'preview-1', slot: 1, firstname: 'Andrea', lastname: 'Moretti', dateofbirth: '1998-04-12', sex: 'm', height: 182, nationality: 'Italiana', job: 'Meccanico', cash: 1250, bank: 24800 },
    { id: 'preview-2', slot: 2, firstname: 'Sofia', lastname: 'De Luca', dateofbirth: '2000-09-23', sex: 'f', height: 169, nationality: 'Italiana', job: 'Disoccupata', cash: 350, bank: 5200 }
  ];

  function textElement(tag, className, text) {
    const element = document.createElement(tag);
    element.className = className;
    element.textContent = String(text);
    return element;
  }

  function feedback(message = '') {
    $('feedback').textContent = message;
    $('feedback').hidden = !message;
  }

  function money(value) {
    const amount = Number(value);
    return '$ ' + (Number.isFinite(amount) ? Math.round(amount) : 0).toLocaleString('it-IT');
  }

  function birth(value) {
    if (!value) return '—';
    const date = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value));
    return date ? `${date[3]}.${date[2]}.${date[1]}` : String(value);
  }

  function jobName(job) {
    return typeof job === 'object' && job ? String(job.label || job.name || 'Cittadino') : String(job || 'Cittadino');
  }

  function personName(character) {
    return `${character.firstname || ''} ${character.lastname || ''}`.trim() || 'Personaggio';
  }

  function currentCharacter() {
    return state.characters.find((character) => String(character.id) === state.selectedId);
  }

  function slotCount() {
    return Math.min(128, Math.max(0, Math.trunc(Number(state.payload.slots) || 0)));
  }

  function visibleSlots() {
    const slots = new Set(Array.from({ length: slotCount() }, (_, index) => index + 1));
    for (const character of state.characters) {
      const slot = Number(character.slot);
      if (Number.isSafeInteger(slot) && slot > 0) slots.add(slot);
    }
    const highest = Math.max(0, ...slots);
    if (highest <= 128) for (let slot = 1; slot <= highest; slot += 1) slots.add(slot);
    return [...slots].sort((a, b) => a - b);
  }

  function updateDisabled() {
    app.querySelectorAll('button, input, select').forEach((element) => {
      if (element.id !== 'confirm-delete') element.disabled = state.busy || element.dataset.locked === 'true';
    });
    $('confirm-delete').disabled = state.busy || $('delete-confirmation').value !== confirmationWord();
    app.setAttribute('aria-busy', String(state.busy));
  }

  function setBusy(value) {
    state.busy = value;
    updateDisabled();
  }

  function confirmationWord() {
    return String(state.payload.deleteConfirmation || 'ELIMINA');
  }

  function renderStage() {
    const character = currentCharacter();
    const title = $('stage-name');
    title.replaceChildren();
    if (state.creatingSlot !== null) {
      title.append(document.createTextNode('Nuova'), document.createElement('br'), document.createTextNode('identità.'));
      $('stage-label').textContent = 'UNA PAGINA BIANCA';
      $('stage-description').textContent = 'Un nuovo nome. Infinite possibilità.';
      $('stage-index').textContent = `V.${String(state.creatingSlot).padStart(2, '0')}`;
    } else if (character) {
      title.append(document.createTextNode(character.firstname || ''), document.createElement('br'), document.createTextNode(character.lastname || ''));
      $('stage-label').textContent = 'IL PROSSIMO CAPITOLO';
      $('stage-description').textContent = `${jobName(character.job)} / ${character.nationality || 'Cittadino di VOID'}`;
      $('stage-index').textContent = `V.${String(character.slot).padStart(2, '0')}`;
    } else {
      title.append(document.createTextNode('La tua'), document.createElement('br'), document.createTextNode('identità.'));
      $('stage-label').textContent = 'TUTTO DEVE ANCORA INIZIARE';
      $('stage-description').textContent = 'Il vuoto è solo un nuovo inizio.';
      $('stage-index').textContent = 'V.00';
    }
  }

  function render() {
    const characters = state.characters;
    const selected = currentCharacter();
    $('selection-view').hidden = state.creatingSlot !== null;
    $('identity-view').hidden = state.creatingSlot === null;
    $('character-list').replaceChildren();
    for (const slot of visibleSlots()) {
      const character = characters.find((item) => Number(item.slot) === slot);
      const locked = Boolean(character?.disabled) || (!character && slot > slotCount());
      const button = document.createElement('button');
      button.type = 'button';
      button.dataset.locked = String(locked);
      button.className = 'character-card' + (character ? '' : ' empty-slot') + (character && String(character.id) === state.selectedId ? ' selected' : '') + (locked ? ' locked-slot' : '');
      button.setAttribute('aria-pressed', String(Boolean(character && String(character.id) === state.selectedId)));
      button.setAttribute('aria-label', character ? (character.disabled ? `Personaggio sospeso: ${personName(character)}, slot ${slot}` : `Seleziona ${personName(character)}, slot ${slot}`) : (locked ? `Slot ${slot} non disponibile` : `Crea un personaggio nello slot ${slot}`));
      button.append(textElement('span', 'slot-number', String(slot).padStart(2, '0')));
      const copy = document.createElement('span');
      copy.className = 'card-copy';
      copy.append(textElement('span', 'card-name', character ? personName(character) : (locked ? 'SLOT NON DISPONIBILE' : 'NUOVA IDENTITÀ')));
      if (character) copy.append(textElement('span', 'card-meta', `SLOT ${String(slot).padStart(2, '0')} / ${character.disabled ? 'SOSPESO / CONTATTA LO STAFF' : jobName(character.job).toUpperCase()}`));
      button.append(copy, textElement('span', 'card-arrow' + (character ? ' diagonal-arrow' : ''), character ? '' : '+'));
      button.lastChild.setAttribute('aria-hidden', 'true');
      button.addEventListener('click', () => {
        if (state.busy || locked) return;
        feedback();
        if (character) {
          state.selectedId = String(character.id);
          state.creatingSlot = null;
          render();
          previewSelected();
        } else openIdentity(slot);
      });
      $('character-list').append(button);
    }
    $('slot-count').textContent = `${String(characters.length).padStart(2, '0')} / ${String(slotCount()).padStart(2, '0')}`;
    $('character-details').hidden = !selected;
    $('empty-message').hidden = characters.length > 0;
    if (selected) {
      $('detail-job').textContent = jobName(selected.job);
      $('detail-birth').textContent = birth(selected.dateofbirth);
      $('detail-cash').textContent = money(selected.cash);
      $('detail-bank').textContent = money(selected.bank);
    }
    $('delete-button').hidden = state.payload.allowDelete !== true || !selected || Boolean(selected.disabled);
    $('enter-button').dataset.locked = String(!selected || Boolean(selected.disabled));
    renderStage();
    updateDisabled();
  }

  function previewSelected() {
    const character = currentCharacter();
    if (!character || character.disabled || !state.open) return;
    const revision = state.revision;
    request('preview', { id: character.id }).catch((error) => {
      if (state.open && state.revision === revision) feedback(error.message);
    });
  }

  function dateBoundary(age) {
    const today = new Date();
    const targetYear = today.getFullYear() - age;
    const month = today.getMonth();
    const day = Math.min(today.getDate(), new Date(targetYear, month + 1, 0).getDate());
    return `${targetYear}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  }

  function configureForm() {
    const rules = state.payload.identity || {};
    ['firstname', 'lastname'].forEach((id) => {
      $(id).minLength = Number(rules.minNameLength) || 2;
      $(id).maxLength = Number(rules.maxNameLength) || 16;
    });
    $('dateofbirth').max = dateBoundary(Number(rules.minAge) || 18);
    // Allow anyone whose integer age is <= maxAge, including the remainder of that year.
    const oldestExclusive = dateBoundary((Number(rules.maxAge) || 100) + 1);
    const lowerDate = new Date(oldestExclusive + 'T12:00:00Z');
    lowerDate.setUTCDate(lowerDate.getUTCDate() + 1);
    $('dateofbirth').min = lowerDate.toISOString().slice(0, 10);
    $('height').min = Number(rules.minHeight) || 140;
    $('height').max = Number(rules.maxHeight) || 210;
    const select = $('nationality');
    select.replaceChildren();
    const placeholder = new Option('Seleziona', '', true, true);
    placeholder.disabled = true;
    select.add(placeholder);
    const nationalities = Array.isArray(rules.nationalities) && rules.nationalities.length ? rules.nationalities : ['Italiana'];
    nationalities.forEach((nationality) => select.add(new Option(String(nationality), String(nationality))));
  }

  function openIdentity(slot) {
    if (slot > slotCount() || state.characters.some((character) => Number(character.slot) === slot)) return;
    state.creatingSlot = slot;
    $('identity-form').reset();
    configureForm();
    $('new-slot-label').textContent = `NUOVA IDENTITÀ / ${String(slot).padStart(2, '0')}`;
    render();
    $('firstname').focus();
  }

  function applyPayload(payload) {
    state.payload = { ...state.payload, ...payload };
    state.characters = Array.isArray(payload.characters) ? payload.characters.filter((item) => item && item.id !== undefined) : state.characters;
    if (!state.characters.some((character) => String(character.id) === state.selectedId && !character.disabled)) {
      const first = state.characters.find((character) => !character.disabled);
      state.selectedId = first ? String(first.id) : null;
    }
  }

  function open(payload) {
    state.revision += 1;
    clearTimeout(launchTimer);
    state.open = true;
    state.busy = false;
    state.creatingSlot = null;
    state.payload = {};
    state.characters = [];
    state.selectedId = null;
    applyPayload(payload || {});
    $('brand-name').textContent = String(state.payload.brand?.name || 'VOID');
    $('tagline').textContent = String(state.payload.brand?.tagline || 'NON SEGUIRE UNA STORIA. VIVI LA TUA.');
    $('loading-overlay').hidden = true;
    if ($('delete-dialog').open) $('delete-dialog').close();
    app.hidden = false;
    feedback(state.payload.error || state.payload.message || '');
    configureForm();
    render();
    previewSelected();
    if (state.payload.error || state.payload.message) showRetry();
    app.focus({ preventScroll: true });
  }

  function close() {
    state.revision += 1;
    state.open = false;
    state.busy = false;
    clearTimeout(launchTimer);
    $('loading-overlay').hidden = true;
    if ($('delete-dialog').open) $('delete-dialog').close();
    app.hidden = true;
  }

  function showRetry() {
    const button = textElement('button', 'retry-button', 'RIPROVA ↗');
    button.type = 'button';
    button.addEventListener('click', refresh);
    $('feedback').append(document.createElement('br'), button);
  }

  async function refresh() {
    if (state.busy) return;
    const revision = state.revision;
    setBusy(true);
    feedback();
    try {
      const response = await request('list');
      if (state.revision !== revision) return;
      applyPayload(response);
      state.creatingSlot = null;
      render();
      previewSelected();
    } catch (error) {
      if (state.revision !== revision) return;
      feedback(error.message);
      showRetry();
    } finally { if (state.revision === revision) setBusy(false); }
  }

  async function request(action, data = {}, timeoutMs = 25000) {
    if (preview && !inGame) return mockRequest(action, data);
    if (!inGame) throw new Error('Interfaccia disponibile dal server FiveM.');
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(`https://${resource}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
        signal: controller.signal
      });
      if (!response.ok) throw new Error('Il server non ha completato la richiesta. Riprova.');
      const result = await response.json();
      if (!result || result.ok === false) throw new Error(result?.error || 'Operazione non riuscita. Riprova.');
      return result;
    } catch (error) {
      if (error.name === 'AbortError') throw new Error('Il server non risponde. Attendi e riprova.');
      if (error instanceof TypeError) throw new Error('Connessione al server non disponibile. Riprova.');
      throw error;
    } finally { clearTimeout(timeout); }
  }

  async function launch(action, data) {
    if (state.busy) return;
    const revision = state.revision;
    feedback();
    setBusy(true);
    $('loading-text').textContent = action === 'create' ? 'LA TUA STORIA STA PER INIZIARE' : 'APERTURA DEL TUO CAPITOLO';
    $('loading-overlay').hidden = false;
    try {
      await request(action, data);
      if (!state.open || state.revision !== revision) return;
      // The client owns focus and visibility: only an explicit close message dismisses NUI.
      launchTimer = setTimeout(() => {
        if (!state.open || state.revision !== revision) return;
        $('loading-overlay').hidden = true;
        setBusy(false);
        feedback('Avvio più lento del previsto. Attendi il caricamento del personaggio prima di riprovare.');
      }, 35000);
    } catch (error) {
      if (state.revision !== revision) return;
      $('loading-overlay').hidden = true;
      setBusy(false);
      feedback(error.message);
    }
  }

  $('enter-button').addEventListener('click', () => {
    const character = currentCharacter();
    if (character && !character.disabled) launch('select', { id: character.id });
  });

  $('back-button').addEventListener('click', () => {
    if (state.busy) return;
    state.creatingSlot = null;
    feedback();
    render();
    app.querySelector('.character-card.selected, .character-card')?.focus();
  });

  $('identity-form').addEventListener('submit', (event) => {
    event.preventDefault();
    if (state.busy || state.creatingSlot === null) return;
    const form = $('identity-form');
    if (!form.reportValidity()) return;
    const data = Object.fromEntries(new FormData(form));
    data.firstname = data.firstname.trim().normalize('NFC').replaceAll('’', "'");
    data.lastname = data.lastname.trim().normalize('NFC').replaceAll('’', "'");
    const rules = state.payload.identity || {};
    const min = Number(rules.minNameLength) || 2;
    const max = Number(rules.maxNameLength) || 16;
    const namePattern = /^[A-Za-z\u00c0-\u00d6\u00d8-\u00f6\u00f8-\u024f][A-Za-z\u00c0-\u00d6\u00d8-\u00f6\u00f8-\u024f '-]*[A-Za-z\u00c0-\u00d6\u00d8-\u00f6\u00f8-\u024f]$/u;
    for (const key of ['firstname', 'lastname']) {
      const length = [...data[key]].length;
      if (length < min || length > max || !namePattern.test(data[key])) {
        feedback(`Nome e cognome devono contenere da ${min} a ${max} caratteri, usando lettere, spazi, apostrofi o trattini.`);
        $(key).focus();
        return;
      }
    }
    data.height = Number(data.height);
    data.slot = state.creatingSlot;
    launch('create', data);
  });

  $('delete-button').addEventListener('click', () => {
    if (state.busy || !currentCharacter() || currentCharacter().disabled || state.payload.allowDelete !== true) return;
    $('confirmation-word').textContent = confirmationWord();
    $('delete-confirmation').value = '';
    $('delete-error').hidden = true;
    $('confirm-delete').disabled = true;
    $('delete-dialog').showModal();
    $('cancel-delete').focus();
  });

  $('delete-confirmation').addEventListener('input', updateDisabled);
  $('cancel-delete').addEventListener('click', () => { if (!state.busy) $('delete-dialog').close(); });
  $('delete-dialog').addEventListener('cancel', (event) => { if (state.busy) event.preventDefault(); });
  $('delete-form').addEventListener('submit', async (event) => {
    event.preventDefault();
    const character = currentCharacter();
    if (state.busy || !character || character.disabled || $('delete-confirmation').value !== confirmationWord()) return;
    const revision = state.revision;
    setBusy(true);
    $('delete-error').hidden = true;
    try {
      const response = await request('delete', { id: character.id, confirmation: $('delete-confirmation').value });
      if (state.revision !== revision) return;
      const updated = Array.isArray(response.characters) ? response : await request('list');
      applyPayload(updated);
      $('delete-dialog').close();
      render();
      previewSelected();
      feedback('Personaggio eliminato. Una nuova storia può iniziare.');
    } catch (error) {
      if (state.revision !== revision) return;
      $('delete-error').textContent = error.message;
      $('delete-error').hidden = false;
    } finally { if (state.revision === revision) setBusy(false); }
  });

  window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || typeof message !== 'object') return;
    if (message.action === 'request-ready') beginHandshake();
    else if (message.action === 'open') open(message.payload);
    else if (message.action === 'close') close();
    else if (message.action === 'error' && state.open) {
      clearTimeout(launchTimer);
      $('loading-overlay').hidden = true;
      setBusy(false);
      feedback(String(message.message || 'Operazione non riuscita.'));
    }
  });

  function updateClock() {
    $('clock').textContent = new Date().toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
  }
  updateClock();
  setInterval(updateClock, 15000);

  async function mockRequest(action, data) {
    await new Promise((resolve) => setTimeout(resolve, 250));
    if (action === 'select') throw new Error('Anteprima interfaccia: l’ingresso nel mondo richiede FiveM.');
    if (action === 'create') {
      previewCharacters.push({ ...data, id: `preview-${Date.now()}`, job: 'Disoccupato', cash: 500, bank: 5000 });
      open(previewPayload());
      return { ok: true };
    }
    if (action === 'delete') previewCharacters = previewCharacters.filter((character) => character.id !== data.id);
    return { ok: true, ...previewPayload() };
  }

  function previewPayload() {
    return { characters: previewCharacters, slots: 3, allowDelete: true, deleteConfirmation: 'ELIMINA', identity: { minNameLength: 2, maxNameLength: 16, minAge: 18, maxAge: 100, minHeight: 140, maxHeight: 210, nationalities: ['Italiana', 'Americana', 'Francese', 'Spagnola', 'Tedesca'] }, brand: { name: 'VOID', tagline: 'NON SEGUIRE UNA STORIA. VIVI LA TUA.' } };
  }

  async function beginHandshake() {
    if (!inGame || handshakeRunning) return;
    handshakeRunning = true;
    const deadline = Date.now() + 30000;
    try {
      while (Date.now() < deadline) {
        try {
          await request('ready', {}, 1500);
          return;
        } catch (_) {
          await new Promise((resolve) => setTimeout(resolve, 500));
        }
      }
      console.error('[void_characters] NUI ready handshake timed out after 30 seconds.');
      if (state.open) feedback('Interfaccia non collegata al client. Riprova la connessione al server.');
    } finally { handshakeRunning = false; }
  }

  if (preview && !inGame) {
    app.classList.add('is-preview');
    open(previewPayload());
  } else if (inGame) {
    beginHandshake();
  }
})();
