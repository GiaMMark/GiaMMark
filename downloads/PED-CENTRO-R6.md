# Patch ped al centro dei vestiti — revisione 6

Per l'installazione rosso/bianco R5 già funzionante. Questa patch interviene su DUE risorse: ox_inventory e pinkFrog_inventoryAddon.

## Applicazione

1. Conserva una copia delle due risorse e arresta il server durante l'aggiornamento.
2. Apri `ped-centro-patch.zip`: contiene due cartelle con lo stesso nome delle risorse installate.
3. Copia i file sopra quelli delle risorse esistenti, conservando tutti gli altri file.
4. **NON cancellare o sostituire l'intera cartella pinkFrog_inventoryAddon con quella della patch:** la patch contiene solo il manifest aggiornato e un nuovo modulo modificabile. Mantieni il tuo addon completo, i file protetti e `.fxap`.
5. Riavvia il server e riconnettiti, così viene caricato anche il nuovo modulo dell'addon.
6. Apri l'inventario: il preset del ped deve trovarsi nello spazio centrale tra le colonne TESTA/TORSO/PANTALONI e MASCHERA/GIUBBOTTO/ZAINO.

Non sono richiesti SQL, cancellazione di inventari/KVP o modifiche a shared/config.lua.

## Correzione

Il config caricato dell'addon aveva `whereIsClothingPlacedInUI = 'right'`, con ped a x=0.772. Il layout personalizzato invece mantiene l'abbigliamento al centro. Il nuovo modulo viene caricato prima del renderer dell'addon e allinea i suoi preset al pannello centrale, usando la rotazione frontale del preset center.

Il frontend misura anche il centro reale di `.inventory-divider` e lo invia all'addon tramite un export esplicito, prima di aggiornare l'anteprima. In questo layout il centro è normalmente a x=0.555; nei formati più stretti segue le colonne effettive. I vecchi preset salvati left/right non spostano più l'anteprima fuori dal layout centrale fisso.

Altezza y=0.82, profondità, luce e altre impostazioni dell'addon sono conservate. Non viene creato un renderer alternativo. Se la posizione cambia mentre il ped è già visibile, vengono usati gli eventi pubblici stop/start dell'addon; un controllo di sessione impedisce di ricrearlo dopo la chiusura. I file protetti non sono stati decifrati o modificati e non sono distribuiti nella patch.

## File della patch

pinkFrog_inventoryAddon:
- fxmanifest.lua
- client/custom/grid_ped_alignment.lua (nuovo)

ox_inventory:
- pinkFrog/client/clientPinkFrog.lua
- modules/grid/client.lua (indicazione della revisione)
- web/build/index.html
- web/build/assets/ox-grid-r6.js (nuovo adapter attivo)
- web/build/assets/ox-grid.js (sorgente leggibile aggiornato)

La risorsa ox_inventory completa aggiornata è disponibile separatamente, ma necessita comunque dei due file patch dell'addon. Per chi usa già R5 è sufficiente questo archivio di patch.

## Verifiche

38 controlli Lua sul modulo addon: preset destra/sinistra/centro, validazione coordinate, conservazione di altezza, profondità, luce e riferimenti delle tabelle, ordine del manifest. 19 controlli sul bridge ox reale: apertura automatica, toggle, posizione aggiornata, rifiuto di input non validi e annullamento del riavvio dopo chiusura.

In Chromium verificato che il valore inviato coincida con il centro tra le colonne dei vestiti a 1920×1080, 1837×1054, 1280×720 e 1024×768. Superati anche i controlli precedenti su oggetti, rotazione, trascinamento, ricerca e 12 riaperture. L'aspetto effettivo del ped 3D resta da verificare nel gioco con la copia autorizzata di pinkFrog: questo ambiente non esegue FiveM.
