# Attivare le richieste email — AlphaScript

Destinatario del modulo: **alphascript24@gmail.com**.

Il modulo invia un POST HTTPS a `https://formsubmit.co/alphascript24@gmail.com`. Non apre l’app di posta come unico metodo di invio: apre la pagina di FormSubmit, dove il visitatore completa la verifica antispam e legge l’esito del servizio. Il collegamento email diretto rimane disponibile come alternativa.

## Prima attivazione

1. Pubblica la cartella del sito sul tuo hosting con HTTPS.
2. Apri il sito pubblicato, compila una richiesta di prova e completa la verifica nella pagina di FormSubmit.
3. Controlla la casella **alphascript24@gmail.com**, inclusa la cartella spam. Conferma l’email di attivazione di FormSubmit.
4. Dopo la conferma, invia una **nuova** richiesta dal sito pubblicato e verifica che nella casella arrivino nome, email per la risposta, argomento e messaggio.

Non dare per consegnata la prima richiesta di attivazione. Il clic sul pulsante o la sola apertura della pagina del servizio non dimostrano la consegna nella casella.

## Cosa è già predisposto

- Destinatario e metodo POST nel markup: funziona anche senza JavaScript.
- Nome, email per la risposta, argomento, messaggio e lettura dell’informativa obbligatori.
- Controllo dei campi vuoti o composti solo da spazi quando JavaScript è attivo.
- CAPTCHA di FormSubmit mantenuto; honeypot `_honey` per lo spam.
- Messaggi che rimandano all’esito effettivo del servizio, senza annunciare falsi successi.
- Dati lasciati compilati nella pagina, con alternativa email diretta.

## Stato della verifica

Destinatario, dati e comportamento del POST sono verificati in Chromium con trasporto intercettato localmente. **Non è stata inviata alcuna email reale, non è stata attivata la casella e non è stata verificata la consegna.** Questi ultimi passaggi richiedono il titolare della casella e il dominio pubblicato.

Se la pagina del servizio non si apre o il messaggio non arriva dopo l’attivazione, usa il collegamento email alternativo e controlla la disponibilità del servizio e la cartella spam. Non disattivare la verifica antispam per aggirare un problema di consegna.
