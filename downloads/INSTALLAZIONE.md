Aggiornamento revisione 2: leggere anche CORREZIONE-RIAPERTURA.md per la correzione di apertura/chiusura.

# ox_inventory con griglia e ingombri

Questa estensione mantiene ox_inventory come inventario principale. Aggiunge ingombri rettangolari, rotazione e validazione server. Non è la risorsa commerciale Grydsystem e non sostituisce ox_inventory con Core Inventory. Non avviare core_inventory/core_clothing e non importare i loro SQL per installare questa modifica.

## Installazione

1. Conserva una copia della risorsa ox_inventory attuale e del database del server.
2. Provala prima su un server FiveM di test con la stessa configurazione del tuo server. L'archivio contiene la cartella `ox_inventory` completa, basata sullo ZIP che hai fornito: sostituisci la risorsa di test con questa cartella, mantenendo il nome `ox_inventory`.
3. Mantieni le dipendenze già necessarie alla tua versione: oxmysql, ox_lib, framework e pinkFrog_inventoryAddon. L'addon pinkFrog non era incluso nei file forniti e non è incluso in questo ZIP.
4. In `data/grid.lua` regola dimensioni, righe e colonne. Il valore predefinito per il giocatore è 10 colonne × 12 righe. Restano anche i limiti di peso, numero di stack e disponibilità slot del tuo ox/pinkFrog.
5. Controlla `clothingByOffset`: la mappa segue l'ordine dei 15 slot finali del frontend fornito. I nomi degli ultimi due slot intimo vanno verificati nella configurazione del tuo addon, perché nel tuo items.lua non sono definiti. Cambia la mappa se il tuo addon usa nomi diversi.
6. Avvia normalmente ox_inventory. Non è richiesta una migrazione del database per le posizioni della griglia.

Il pacchetto completo può essere usato direttamente sul server di test. Per applicare solo la patch a una copia IDENTICA dell'archivio originale, copia tutti i file elencati in `FILE-MODIFICATI.txt`; non basta cambiare il CSS.

## Uso

- Trascina gli oggetti: il rettangolo occupa più celle in base alle dimensioni configurate.
- Premi **R con il cursore sopra un oggetto nella griglia**, prima di trascinarlo, per ruotarlo di 90°. La rotazione viene rifiutata se non c'è spazio.
- I primi due slot rapidi sono riservati alle armi. Gli altri tre restano slot rapidi generici. Le armi non sono limitate a soli due esemplari: possono stare anche nella griglia.
- Stack, quantità, divisione degli stack, menu contestuale e azioni continuano a usare ox_inventory.
- Negozio, ricette e nuovo drop mantengono i loro pannelli nativi; gli oggetti acquisiti devono comunque trovare spazio nella griglia. I depositi già esistenti usano la griglia.
- Gli slot rapidi e abbigliamento di un altro giocatore restano accessibili nel pannello equipaggiamento durante una perquisizione autorizzata.
- Gli oggetti preesistenti senza spazio sono conservati nell'area di recupero. Trasferiscili fuori o aumenta la capacità; non vengono eliminati.
- Il personaggio centrale continua a dipendere dalle funzioni di pinkFrog_inventoryAddon. Il suo rendering/camera va verificato nel gioco; non è un'immagine aggiunta alla pagina web.

## Salvataggio e configurazione

Gli oggetti, i metadati e gli stack restano gestiti e salvati da ox_inventory. Posizioni e rotazioni sono salvate separatamente nei **KVP della risorsa**. Per i giocatori la chiave usa l'identificativo persistente del framework, non il numero temporaneo della connessione. Conserva anche lo storage KVP nei backup e mantieni il nome della risorsa. I drop temporanei non vengono trasformati in contenitori persistenti.

`data/grid.lua` contiene le dimensioni per nome oggetto. Gli oggetti non configurati occupano 1×1; le armi non configurate 4×2. Puoi aggiungere tutti i tuoi oggetti alla tabella `items`. Le dimensioni del server non possono essere sostituite da dimensioni inviate dal browser.

Le operazioni rifiutate non consumano spazio o oggetti. Il crafting simula ingredienti, divisioni per durabilità e risultato; durante la modifica usa un blocco e una copia di ripristino. Le normali API di modifica possono restituire `inventory_busy` se chiamate mentre una transazione è in corso. Risorse esterne che scrivono direttamente nelle tabelle interne, invece di usare le API, richiedono verifica separata.

## Verifiche eseguite

- **91 asserzioni Lua**: collisioni, bordi, dimensioni imposte dal server, rotazione, stack parziali, scambio, trasferimenti, ripristino KVP, richieste non valide, slot armi/abbigliamento, selezione slot, crafting e rollback.
- Chromium sul frontend reale con NUI/server FiveM simulati: oggetti multi-cella, tasto R, trascinamento React DnD, trasferimento al deposito, riordinamento a slot logici pieni, menu contestuale, ricerca, impostazioni, equipaggiamento altrui e pannello nuovo drop.
- Controllati gli ingombri dei pannelli a 1920×1080, 1280×720 e 1024×768. Nessun errore JavaScript nei controlli finali.

Non è stato eseguito un server FiveM con ESX/pinkFrog/MySQL in questo ambiente. Prima dell'uso sul server principale verifica nel gioco: acquisto, crafting riuscito e fallito, consegna, perquisizione, bagagliaio, drop, cambio zaino, abbigliamento, disconnessione/riconnessione e riavvio completo. Il frontend originale può effettuare una richiesta all'immagine inesistente `/none` per gli slot vuoti; il comportamento era già presente nell'archivio.

## Compatibilità e ripristino

La modifica è legata alla versione compilata 2.44.8/pinkFrog che hai caricato. Il modulo leggibile è `web/build/assets/ox-grid.js`; il bundle originale è modificato solo per collegare il componente griglia e rendere disponibili i componenti nativi. Un altro bundle o un aggiornamento di ox richiede di riapplicare e verificare il collegamento.

Per tornare indietro ripristina l'intera risorsa originale durante un arresto del server. Non è necessario convertire gli oggetti nel database. I KVP della griglia possono restare salvati e non sono letti dall'ox originale.
