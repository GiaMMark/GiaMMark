# Revisione 3 — blocco quando viene inserito un oggetto

Riprodotto nel componente reale un crash quando gli slot Lua arrivano come un array sparso con valori null: `Cannot read properties of null (reading 'y')`. Il crash può smontare l'interfaccia React, lasciando visibile solo il ped del gioco. I test precedenti usavano mappe JSON senza buchi e non coprivano questo formato di trasporto.

Correzioni:
- Il server invia e salva le posizioni con chiavi stringa e uno slot esplicito, mantenendo gli identificativi degli oggetti.
- Il browser normalizza sia mappe sia array Lua, salta i null e converte correttamente gli indici Lua da 1 e JavaScript da 0.
- Le liste di overflow vuote sono accettate anche se arrivano come oggetti JSON.
- Restano incluse tutte le correzioni della revisione 2 per chiusura, input e riapertura.

## Aggiornamento

Usa lo ZIP della revisione 3. Conserva una copia attuale, arresta ox_inventory, sostituisci la risorsa con la cartella `ox_inventory` aggiornata, poi riavvia e riconnettiti. Non servono SQL, pulizia degli inventari o cancellazione dei KVP.

Se applichi solo la differenza rispetto alla revisione 2, devi sostituire tutti e tre i file:

- `modules/grid/server.lua`
- `web/build/assets/ox-grid.js`
- `web/build/index.html`

Non applicare soltanto una modifica CSS o soltanto il frontend. I vecchi salvataggi delle posizioni sono ancora leggibili.

## Verifiche

- Test riproduttivo inizialmente fallito, poi passato: nessun oggetto, primo oggetto allo slot 6 con celle null, riapertura, slot alto, mappe stringa e overflow vuoto.
- 10 nuove asserzioni Lua verificano che gli snapshot server usino chiavi stringa e mantengano gli slot nei salvataggi.
- Chromium sul frontend reale con trasporto NUI simulato tramite array sparsi: inventario vuoto, aggiunta di acqua, chiusura e riapertura senza scomparsa della pagina. Passati anche trascinamento nativo, rotazione, trasferimento al deposito e 12 cicli di riapertura. Nessun errore JavaScript nel test.

La revisione va confermata sul tuo server FiveM con l'addon pinkFrog effettivo; questo ambiente non esegue il gioco.
