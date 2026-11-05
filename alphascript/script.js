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
  const form = document.querySelector('#contact-form');
  const note = document.querySelector('#form-note');
  if (form && note) {
    const textFields = ['name', 'email', 'message'].map(name => form.elements.namedItem(name));
    textFields.forEach(field => field.addEventListener('input', () => {
      field.setCustomValidity('');
      note.classList.remove('is-error');
    }));
    form.addEventListener('submit', event => {
      if (form.elements.namedItem('_honey').value.trim()) {
        event.preventDefault();
        note.textContent = 'Non è stato possibile procedere. Puoi contattarmi tramite il collegamento email qui sotto.';
        note.classList.add('is-error');
        return;
      }
      textFields.forEach(field => {
        field.value = field.value.trim();
        field.setCustomValidity(field.value ? '' : 'Scrivi un testo: questo campo non può contenere solo spazi.');
      });
      if (!form.reportValidity()) {
        event.preventDefault();
        note.textContent = 'Controlla i campi indicati. La richiesta non è stata inoltrata.';
        note.classList.add('is-error');
        return;
      }
      note.classList.remove('is-error');
      note.textContent = 'Completa la verifica nella nuova scheda di FormSubmit. L’esito dell’invio sarà mostrato lì; qui i tuoi dati restano compilati.';
      // Keep native HTTPS POST: only the provider can report its submission result.
    });
  }
  const year = document.querySelector('#year');
  if (year) year.textContent = new Date().getFullYear();
})();
