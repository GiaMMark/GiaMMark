# Correzione apertura e chiusura — revisione 2

Aggiornamento per il caso in cui il personaggio/preview compare ma il pannello dell'inventario rimane nascosto.

- Ogni messaggio `setupInventory` riporta esplicitamente l'interfaccia allo stato visibile, anche se arriva subito dopo una chiusura.
- Il pannello non rimane in attesa indefinita della posizione abbigliamento: parte al centro o dalla posizione valida già salvata, poi applica le impostazioni pinkFrog quando arrivano.
- Chiusura e uscita azzerano cursore logico, hover, trascinamento, timer e snapshot della griglia.
- Le risposte richieste prima della chiusura non possono sovrascrivere una nuova apertura. Le richieste della griglia hanno un timeout.
- Un blur ritardato della ricerca non riattiva la cattura dell'input dopo la chiusura. Il client rilascia nuovamente il focus al termine della chiusura, senza interferire con una riapertura rapida.
- I riferimenti JavaScript nell'HTML hanno una revisione per ricaricare gli asset aggiornati.

## Come aggiornare

Arresta ox_inventory in una finestra di manutenzione e conserva la copia attuale. Sostituisci la cartella della risorsa con `ox_inventory` contenuta in questo ZIP aggiornato, mantenendo dipendenze e nome della risorsa. Poi riavvia la risorsa e riconnettiti al server. Non serve importare SQL o cancellare inventari/KVP.

Se hai già installato la prima versione e devi applicare solo questa correzione, sostituisci tutti e cinque i file seguenti, non soltanto il CSS:

- `client.lua`
- `pinkFrog/client/clientPinkFrog.lua`
- `web/build/index.html`
- `web/build/assets/index-5aaa6e7c.js`
- `web/build/assets/ox-grid.js`

## Verifiche

Riprodotto e corretto il comando R che continuava a inviare richieste dopo la chiusura. Controllati risposte obsolete, reset del trascinamento, timer e focus. Passati 26 nuovi controlli sulle funzioni Lua del client con native simulate, oltre ai 91 controlli Lua precedenti. Passati 12 cicli di chiusura/riapertura in Chromium, anche rapidi e durante il trascinamento, e i casi senza risposta delle impostazioni colore e con close/setup nello stesso aggiornamento.

La correzione è stata verificata con NUI/FiveM simulati; l'esito sul server FiveM e sull'addon pinkFrog va confermato nel gioco.
