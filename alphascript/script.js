(() => {
  'use strict';
  const button = document.querySelector('.menu-toggle');
  const nav = document.querySelector('#main-nav');
  const mobile = window.matchMedia('(max-width: 800px)');
  const closeMenu = (restoreFocus = false) => {
    if (!button || !nav) return;
    button.setAttribute('aria-expanded', 'false');
    button.setAttribute('aria-label', 'Apri il menu');
    nav.classList.remove('is-open');
    document.body.classList.remove('menu-open');
    if (restoreFocus) button.focus();
  };
  if (button && nav) {
    button.addEventListener('click', () => {
      if (button.getAttribute('aria-expanded') === 'true') {
        closeMenu(true);
      } else {
        button.setAttribute('aria-expanded', 'true');
        button.setAttribute('aria-label', 'Chiudi il menu');
        nav.classList.add('is-open');
        document.body.classList.add('menu-open');
        nav.querySelector('a')?.focus();
      }
    });
    nav.querySelectorAll('a').forEach(link => link.addEventListener('click', () => closeMenu()));
    document.addEventListener('keydown', event => {
      if (event.key === 'Escape' && button.getAttribute('aria-expanded') === 'true') closeMenu(true);
    });
    document.addEventListener('click', event => {
      if (!event.target.closest('.header-inner')) closeMenu();
    });
    mobile.addEventListener('change', () => closeMenu());
    document.documentElement.classList.add('js');
  }
  const year = document.querySelector('#year');
  if (year) year.textContent = new Date().getFullYear();
})();
