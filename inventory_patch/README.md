# VOID Survival · Inventory LS

Interfaccia ispirata allo screenshot LS Inventory fornito: personaggio a sinistra, icone laterali, indicatori di salute/armatura/peso, armi trasportate, sezioni personali strette al centro e inventario esterno grande a destra. In basso compare la barra rapida con gli slot reali da 1 a 10. Il logo e l’accento restano VOID Survival.

![Anteprima browser: disposizione LS con dati dimostrativi](ox_inventory/docs/preview.png)

**[Scarica la nuova patch LS](https://github.com/GiaMMark/GiaMMark/raw/refs/heads/void-characters/downloads/ox_inventory_void_ls.zip)**

## Installazione

1. Conserva una copia della tua resource `ox_inventory` funzionante e fermala durante la manutenzione.
2. Estrai lo ZIP e sovrapponi la cartella `ox_inventory` alla tua cartella esistente. Copia anche la nuova cartella `void/`: contiene configurazione e bridge client per l’anteprima.
3. Conserva i file originali `data/`, `modules/`, `web/images/`, i bundle e la configurazione del server. Questa è una patch per l’ox_inventory 2.45.0 del tuo archivio, non una resource completa indipendente.
4. Riavvia ox_inventory e riconnettiti. Non occorre nuovo SQL. La patch sostituisce il precedente tema VOID/DayZ caricando gli stessi nomi di file del tema.

I bundle richiesti sono `index-7c4ea07a.js` e `index-9aba2ab3.css`; [base.json](base.json) ne riporta gli hash. Non sostituire la tua base con una release diversa per applicare questa patch.

## Configurazione

- **Grafica:** [web/build/void-config.js](ox_inventory/web/build/void-config.js), per logo, colore, testi, colonne, barra rapida e titoli delle sezioni.
- **Anteprima e tasti:** [void/config.lua](ox_inventory/void/config.lua), per camera, distanza, inquadratura, rotazione, frequenza degli indicatori e tasti aggiuntivi.

Le sezioni DOTAZIONE, TASCHE e CARICO organizzano gli slot dello stesso inventario personale. Non assegnano nuove capacità o limiti di peso autonomi. Il limite rimane quello autorizzato da ox_inventory.

I pulsanti contenitore mostrano gli oggetti posseduti con `metadata.container` e usano il percorso originale di apertura di ox. L’inventario esterno a destra mostra il contenitore effettivamente aperto: terreno, stash, borsa, negozio o altro. Questa base apre un inventario esterno alla volta.

Le icone anatomiche senza oggetto sono riferimenti visivi, non un sistema di abbigliamento equipaggiabile. Le due schede armi derivano dagli oggetti WEAPON_ realmente presenti. La barra rapida usa gli slot nativi 1–10; il click richiama `useItem` originale. I tasti 1–5 restano quelli originali; i tasti 6–0 si abilitano opzionalmente con `Hotkeys.ExtraEnabled`, dopo aver controllato le associazioni del server.

## Anteprima del personaggio

Il bridge aggiuntivo crea un clone locale del ped e una camera solo mentre ox_inventory è aperto. Non sposta il giocatore, non modifica il suo inventario e non nasconde il ped agli altri client. L’anteprima cede alle camere già attive di altri script e viene rimossa su chiusura, logout o stop della resource. In veicolo, da morto o durante altre camere può risultare non disponibile.

Per mantenere leggibile il ped, `Preview.DisableNativeBlur` disabilita il blur globale della sola opzione di ox mentre l’addon è attivo; il valore precedente viene ripristinato all’arresto. Puoi disattivare `Preview.Enabled` se il tuo server possiede già una propria anteprima. Regola distanza, FOV e offset su GTA in base al modello e alla risoluzione.

La schermata browser usa un segnaposto esplicitamente etichettato: non è una cattura di GTA. Il modello del personaggio, i vestiti e la camera reali richiedono il collaudo in FiveM.

## Verifiche e limiti

Il bundle React, il CSS compilato, il core server, gli oggetti e i moduli Lua originali restano invariati. Fra i file già presenti vengono aggiornati soltanto il manifest e la pagina HTML; il nuovo client è separato in `void/`. Non viene introdotta una seconda logica di autorizzazione o salvataggio degli oggetti.

Passati 15 scenari Chromium sul bundle originale dopo installazione della patch: trascinamento reale fra inventari, quantità, Usa/Dai/Butta, tooltip, aggiornamenti, schede contenitore/armi, dieci slot rapidi, riaperture, shop e contenitori vuoti, trasparenza e layout. Passati 13 test Lua del bridge con native simulate: dati reali, controlli, cleanup camera/clone, rispetto di altre camere e tasti opzionali.

Da questa cartella, per rieseguire i controlli di sviluppo:

```sh
python3 tests/nui.test.py --resource /percorso/ox_inventory --chromium /usr/bin/chromium
lua tests/native_bridge.test.lua
```

Servono Python/Playwright/Chromium e Lua solo per i test. Prima dell’uso pubblico prova sul tuo FXServer camera, chiusura, stash, contenitori, peso limite, abiti e gli altri script del server. Le native, il database e le autorizzazioni server non vengono collaudati da un browser.

L’archivio ricevuto non conteneva `web/images/`: conserva le icone che usi già. Gli oggetti schematici nell’immagine sono fixture del test e non vengono aggiunti al gioco. La licenza GPL originale è mantenuta.
