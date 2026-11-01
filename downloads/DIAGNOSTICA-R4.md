# Revisione 4 — protezione e diagnostica del crash residuo

Il crash segnalato persiste sul server dell'utente dopo la revisione 3. La sola posizione `index-5aaa6e7c.js:49` è il rilancio di React e non identifica la lettura originale di `y`. Nei test locali il crash residuo non è stato riprodotto: questa revisione aggiunge protezione e diagnostica, senza dichiarare identificata una nuova causa.

## Installazione e controllo

1. Conserva la copia attuale e arresta la risorsa.
2. Sostituisci l'intera cartella `ox_inventory` con quella dello ZIP. Mantieni questo nome e le dipendenze già usate dal tuo server.
3. Riavvia ox_inventory e riconnettiti. Apri una volta l'inventario.
4. In F8 esegui **`oxgridversion`** e copia la riga `[ox-grid-r4]`.
5. Ripeti l'operazione che provoca il problema. Copia il blocco **`[ox-grid-r4] UI ERROR`**, comprese le righe successive `stack` e `React components`.

La riga versione deve indicare `client=r4`, `browser=ox-grid-r4`, `index=r4`. Se un valore è diverso o il comando non esiste, l'istanza non ha caricato tutti i file di questa revisione. Questo controllo serve a diagnosticare i file effettivi, non a presumere un errore di installazione.

## Cosa cambia

- HTML carica nomi nuovi: `assets/ox-grid-r4.js` e `assets/index-grid-r4.js`. Non usa il vecchio URL con `?reopen=2`.
- Una barriera agli errori attorno al componente griglia mostra i vecchi slot nativi se il componente fallisce. Le regole geometriche del server rimangono attive. Questa barriera non copre eventuali guasti esterni al componente griglia: in quel caso la diagnostica globale registra l'errore.
- Errori JavaScript e component stack vengono inoltrati alla console F8 tramite callback NUI locale. Il rapporto contiene build e stack, non il contenuto dell'inventario o credenziali. I duplicati sono limitati.
- La barriera viene reimpostata a una nuova apertura. Non è necessario cancellare database, oggetti o KVP.

## Verifiche

Passati i controlli precedenti su griglia, trasporto sparso, operazioni e chiusura/riapertura, più sei controlli Lua del comando versione e delle callback diagnostiche. In Chromium è stato iniettato apposta un `TypeError` nel componente Slot della griglia: il pannello nativo è rimasto visibile, il rapporto conteneva stack completo e component stack e la griglia è tornata alla riapertura. Passato anche uno stress separato di 15 cicli con tooltip, notifiche di aggiunta oggetti, menu contestuale e riapertura.

La causa residua sul server FiveM richiede il rapporto F8 prodotto da questa revisione.
