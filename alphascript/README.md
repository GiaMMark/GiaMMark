# AlphaScript by GiaMMarK

Portfolio statico: siti web, applicazioni e sviluppo FiveM. Revisione scura e sobria dei file forniti, con testi più diretti e modulo per **alphascript24@gmail.com**.

## Cosa cambia

- Logo originale e identità AlphaScript leggibili anche su telefono.
- Apertura più compatta, servizi spiegati senza slogan, esempi dichiarati come richieste possibili.
- Rimossi intro bloccante, editor dimostrativo, cursore personalizzato, statistiche decorative e animazioni continue.
- Menu mobile con etichette accessibili, chiusura con Escape e ritorno del focus; FAQ native utilizzabili anche senza JavaScript.
- Modulo con invio POST tramite FormSubmit, verifica antispam, validazione e alternativa email diretta.
- Privacy aggiornata al flusso effettivo; nessun dato anagrafico o societario inventato.

## File e pubblicazione

Non serve una build, un framework o un’installazione npm. La cartella da pubblicare deve contenere:

```text
index.html
privacy.html
style.css
script.js
giammark-logo.png
giammark-favicon.png
```

L’archivio di consegna contiene questi file direttamente nella radice. Per Netlify, estrai lo ZIP e carica la cartella che contiene `index.html` nel tuo progetto. Per un altro hosting statico, carica gli stessi file mantenendo i nomi. Usa HTTPS. Non è stato eseguito alcun deploy durante questa revisione.

Anteprima locale dalla cartella `alphascript/`:

```bash
python3 -m http.server 8092 --directory .
```

## Attivare l’email

**La ricezione richiede l’attivazione una tantum del destinatario su FormSubmit.** Segui [EMAIL_SETUP.md](EMAIL_SETUP.md), poi verifica una nuova richiesta dal dominio pubblicato. I test locali non hanno inviato email reali e non dimostrano la consegna alla casella.

Il collegamento email diretto è disponibile subito per chi ha un’app di posta configurata: l’invio finale resta manuale nell’app. Non inserire password o credenziali nel codice del sito.

## Modificare il sito

- Testi e sezioni: `index.html`.
- Colori, dimensioni e responsive: `style.css`.
- Menu e controlli aggiuntivi del modulo: `script.js`.
- Destinatario: attributo `action` del modulo e collegamenti `mailto:` in `index.html`; aggiornare anche `privacy.html` e la guida se cambia.
- Logo e favicon: i due PNG originali forniti.

Le competenze provengono dai materiali ricevuti. Gli esempi non sono presentati come lavori di clienti. Prima di una pubblicazione definitiva, verifica che competenze e informazioni identificative del titolare corrispondano alla tua attività effettiva; i dati personali mancanti non sono stati inventati.

## Verifiche

I test di sviluppo usano Python, Playwright e Chromium; non sono dipendenze del sito. Nell’ambiente Linux predisposto:

```bash
python3 alphascript/tests/test_site.py
node --check alphascript/script.js
```

Il comando parte dalla radice del repository. I test avviano un server locale temporaneo e intercettano le richieste al provider di invio. Non eseguono invii email reali. I dettagli e i limiti delle verifiche sono in [VALIDAZIONE.md](VALIDAZIONE.md).
