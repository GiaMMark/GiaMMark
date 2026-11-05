# AlphaScript — verifiche della revisione

## Verifiche automatiche

Suite browser con Python unittest, Playwright e Chromium. **14 test superati**: invio POST e codifica dei caratteri speciali, conservazione dei dati, blocco di messaggi vuoti, email non valida, honeypot, destinatario alternativo, funzionamento senza JavaScript, menu da tastiera, focus, primo schermo mobile, responsive e movimento ridotto. Controllo sintattico JavaScript: `node --check alphascript/script.js`.

Le prove di invio intercettano il trasporto HTTPS del provider prima di qualsiasi contatto esterno: esercitano il vero modulo e la serializzazione del browser, senza spedire email reali. Il provider deve gestire la sua verifica antispam e l’esito della richiesta sul sito pubblicato.

Il responsive è controllato a **320, 390, 768, 1024, 1440 e 1920 pixel**, con controlli sulla larghezza del documento e sull’accessibilità dei campi. I controlli verificano anche l’assenza di errori JavaScript durante il caricamento delle pagine. Sono incluse prove con JavaScript disabilitato e movimento ridotto.

## Limiti

- Nessuna attivazione FormSubmit o consegna email reale verificata: vedere `EMAIL_SETUP.md`.
- Nessun deploy o aggiornamento del sito online eseguito durante la revisione.
- Le competenze sono quelle dei materiali forniti; gli esempi sono interventi possibili, non case study di clienti.
- Non sono stati inventati nome legale, indirizzo o dati fiscali del titolare. Le informazioni identificative vanno verificate dal proprietario prima di una pubblicazione definitiva.

## Revisione indipendente

Corretto il menu a 640×320 pixel: il pannello ha un’altezza limitata e scorre internamente, così il contatto rimane raggiungibile. Verificato anche l’invio dell’origine del sito al provider, con policy `strict-origin-when-cross-origin`: il referrer non contiene testo del messaggio o dati del modulo. La scheda esterna mantiene la protezione `noopener`.

Senza JavaScript il modulo conserva i controlli nativi del browser (campi obbligatori, email e lunghezze); il controllo aggiuntivo sui soli spazi è fornito da JavaScript. La compatibilità e la consegna effettiva del provider vanno verificate dal sito pubblicato dopo l’attivazione.
