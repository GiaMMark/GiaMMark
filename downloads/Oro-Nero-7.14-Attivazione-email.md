# Richieste via email

Il modulo prenotazioni di tutte le pagine invia tramite POST HTTPS a `https://formsubmit.co/alphascript24@gmail.com`. Non servono credenziali nel codice. Il mittente inserisce la propria email, oltre ai dati della richiesta; il telefono è facoltativo. Il tavolo resta da confermare dal ristorante.

L’invio apre una nuova scheda di FormSubmit: il visitatore completa la verifica antispam del servizio e vede l’esito reale nella sua pagina. Il CAPTCHA resta abilitato e il modulo include anche il campo honeypot `_honey`. Il sito non dichiara la consegna sulla base del solo clic. Il collegamento alternativo “Scrivici direttamente” apre il programma email del visitatore con i dati già compilati: richiede un successivo invio manuale.

## Attivazione necessaria

1. Pubblicare il sito tramite HTTPS.
2. Eseguire una richiesta reale dal modulo pubblicato e completare la verifica di FormSubmit.
3. In `alphascript24@gmail.com`, cercare l’email di attivazione di FormSubmit (anche in spam) e confermare il destinatario. Questa operazione richiede il titolare della casella: non può essere completata dal codice.
4. Dopo l’attivazione, eseguire una nuova richiesta e verificare nella casella che arrivino nome, email, eventuale telefono, persone, data, ora e note. Non considerare la prima richiesta o il solo esito del browser come prova di consegna.

Il destinatario non è stato attivato o verificato durante lo sviluppo e non sono state inviate email reali di prova. Prima dell’attivazione l’invio alle caselle non può essere dato per operativo. Non impostare `_captcha=false` e non includere password o token nei file del sito.

## Verifiche locali

`npm test` comprende la verifica del contratto POST (indirizzo, metodo, campi), della validazione, dell’honeypot e del collegamento mailto. I test simulano l’evento submit senza eseguire richieste al servizio o inviare email. La build statica include automaticamente `site/assets/booking.js`.
