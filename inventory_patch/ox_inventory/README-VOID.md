# VOID Survival · Layout LS Inventory

Patch per l’ox_inventory 2.45.0 fornito, ridisegnata sullo screenshot LS Inventory: anteprima ped e condizioni a sinistra, sezioni personali al centro, inventario esterno a destra e barra rapida 1–10.

![Anteprima browser con dati dimostrativi](docs/preview.png)

## Installazione

Sovrapponi questa cartella alla tua resource esistente durante la manutenzione, mantenendo nome `ox_inventory`, immagini, moduli e dati originali. Copia la cartella `void/` insieme al manifest e ai file web. Il frontend originale deve contenere `index-7c4ea07a.js` e `index-9aba2ab3.css`. Non è richiesta una modifica SQL.

Il pacchetto aggiorna manifest e HTML, aggiungendo tema, logo e bridge client. Non sostituisce il bundle React, il core ox o la lista oggetti personalizzata. Le operazioni degli oggetti continuano a passare dai controlli originali.

## Config

- `web/build/void-config.js`: brand, logo PNG, accento, testi, colonne, sezioni e slot rapidi.
- `void/config.lua`: anteprima locale, camera, distanza/FOV/offset, statistiche e tasti aggiuntivi opzionali.

DOTAZIONE/TASCHE/CARICO sono sezioni dello stesso inventario, non borse con capacità indipendenti. I contenitori realmente posseduti si aprono attraverso `metadata.container`, mostrando il contenuto nell’inventario esterno nativo. Non è introdotto un inventario multicella con rotazione. Le icone anatomiche sono riferimenti visivi; non assegnano abiti al personaggio.

La barra rapida mostra gli oggetti reali negli slot 1–10 ed è cliccabile. I tasti 1–5 sono quelli originali; 6–0 si attivano nel config Lua dopo aver verificato le altre associazioni. Le schede armi mostrano le prime due armi presenti; l’arma attiva è indicata solo se il client ox ne comunica lo slot.

## Personaggio e camera

L’anteprima usa un clone locale del tuo personaggio. Il ped reale non viene spostato né nascosto agli altri giocatori. Il bridge pulisce soltanto il proprio clone e la propria camera; una camera di un altro script impedisce o interrompe l’anteprima. In veicolo o da morto il modello può non essere mostrato. La sagoma nel browser è un segnaposto dichiarato.

`Preview.DisableNativeBlur` mantiene nitido il clone disabilitando la sola opzione blur di ox e ripristinandola allo stop. Per il tuo server regola camera e offset, oppure disattiva `Preview.Enabled`. Non sono necessari ox_lib aggiuntivi oltre alle dipendenze già richieste dal tuo ox.

## Collaudo

15 scenari Chromium e 13 test Lua con confini FiveM simulati sono passati. Il test browser include drag-and-drop reale e callback originali; non è una prova del database né del motore GTA. Prova sul server apri/chiudi, logout, cambio modello, veicoli, camere esterne, contenitori, negozi, metadata e peso massimo prima dell’apertura pubblica.

Conserva `web/images/` del tuo server: l’archivio fornito non conteneva icone. Le immagini schematiche del test non vengono installate come oggetti. La licenza originale è mantenuta in `LICENSE`, e i file del bundle originario restano invariati.
