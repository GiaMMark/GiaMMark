'use strict';

(() => {
  const raw = window.VOID_INVENTORY || {};
  const text = (value, fallback, max = 120) => typeof value === 'string' ? value.slice(0, max) : fallback;
  const labels = raw.labels && typeof raw.labels === 'object' ? raw.labels : {};
  const copy = {
    vicinity: text(labels.vicinity, 'VICINANZE'), inventory: text(labels.inventory, 'INVENTARIO'),
    survivor: text(labels.survivor, 'SOPRAVVISSUTO'), actions: text(labels.actions, 'AZIONI'),
    quantity: text(labels.quantity, 'QUANTITÀ'), controls: text(labels.controls, 'TRASCINA / GESTISCI / SOPRAVVIVI'),
    hint: text(labels.hint, 'TASTO DESTRO · AZIONI OGGETTO'), closeHint: text(labels.closeHint, 'ESC · CHIUDI')
  };
  if (typeof raw.accent === 'string' && /^#[a-f\d]{6}$/i.test(raw.accent)) document.documentElement.style.setProperty('--void-accent', raw.accent);

  function element(tag, className, value) {
    const node = document.createElement(tag);
    node.className = className;
    if (value !== undefined) node.textContent = value;
    return node;
  }

  const chrome = element('div', 'void-inventory-chrome');
  chrome.setAttribute('aria-hidden', 'true');
  chrome.hidden = true;
  const header = element('header', 'void-inventory-header');
  const identity = element('div', 'void-identity');
  const logo = element('img', 'void-logo');
  logo.alt = '';
  const path = text(raw.logo, 'assets/void-logo.png');
  logo.src = /^assets\/[A-Za-z0-9_.-]+\.png$/i.test(path) ? path : 'assets/void-logo.png';
  logo.addEventListener('error', () => { logo.hidden = true; });
  const brand = element('div', 'void-brand-copy');
  brand.append(element('span', 'void-brand-name', text(raw.brand, 'VOID SURVIVAL', 40)), element('span', 'void-brand-subtitle', text(raw.subtitle, 'EVERYTHING YOU CARRY. EVERYTHING YOU RISK.')));
  identity.append(logo, brand);
  header.append(identity, element('span', 'void-header-status', 'FIELD EQUIPMENT / 01'), element('span', 'void-header-close', copy.closeHint));
  const footer = element('div', 'void-inventory-footer');
  footer.append(element('span', '', copy.hint), element('span', 'void-footer-center', copy.controls), element('span', '', 'VOID / SURVIVAL SYSTEM'));
  chrome.append(header, footer);
  document.body.append(chrome);

  let scheduled = false;
  function decorate() {
    scheduled = false;
    const wrapper = document.querySelector('.inventory-wrapper');
    document.body.classList.toggle('void-inventory-open', Boolean(wrapper));
    chrome.hidden = !wrapper;
    if (!wrapper) return;
    const panes = [...wrapper.querySelectorAll(':scope > .inventory-grid-wrapper')];
    panes.forEach((pane, index) => {
      const role = index === 0 ? 'player' : 'external';
      if (pane.dataset.voidRole === role) return;
      pane.dataset.voidRole = role;
      const caption = element('div', 'void-pane-caption');
      caption.append(element('span', 'void-pane-number', role === 'player' ? '03' : '01'), element('span', '', role === 'player' ? copy.inventory : copy.vicinity), element('span', 'void-pane-line'));
      pane.prepend(caption);
    });
    const controls = wrapper.querySelector('.inventory-control');
    if (controls && !controls.dataset.voidDecorated) {
      controls.dataset.voidDecorated = 'true';
      const figure = element('div', 'void-survivor');
      figure.setAttribute('aria-hidden', 'true');
      const figureTitle = element('div', 'void-survivor-title');
      figureTitle.append(element('span', 'void-pane-number', '02'), element('span', '', copy.survivor));
      const silhouette = element('div', 'void-silhouette');
      // Decorative, original vector figure. It is not a representation of equipped items.
      silhouette.innerHTML = '<svg viewBox="0 0 180 340" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M90 17c-16 0-27 11-27 28 0 17 12 30 27 30s27-13 27-30c0-17-11-28-27-28Z"/><path d="m65 83-24 13-14 71-12 50 14 5 20-45 12-39 1 65-8 51 1 67 20 1 10-67 5-36 6 36 9 67 20-1 1-67-8-51 1-65 12 39 20 45 14-5-12-50-14-71-24-13-16 9-17-9Z"/><path class="figure-detail" d="M61 128h58M65 173h50M77 93l13 39 14-39M69 202h43M91 133v68"/><path class="figure-scan" d="M10 108h160M10 225h160"/></svg>';
      figure.append(figureTitle, silhouette, element('span', 'void-survivor-index', 'NO SECOND CHANCES.'));
      const caption = element('div', 'void-actions-caption', copy.actions);
      controls.prepend(figure);
      controls.querySelector('.inventory-control-wrapper')?.prepend(caption);
      const amount = controls.querySelector('.inventory-control-input');
      if (amount) {
        amount.setAttribute('aria-label', copy.quantity);
        amount.placeholder = copy.quantity;
      }
    }
  }
  const observer = new MutationObserver(() => {
    if (!scheduled) { scheduled = true; requestAnimationFrame(decorate); }
  });
  observer.observe(document.getElementById('root'), {childList: true, subtree: true});
  decorate();
})();
