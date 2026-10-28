# VOID Survival · Inventario in stile DayZ

Patch grafica per la versione **ox_inventory 2.45.0 dell'archivio fornito**. Le colonne vicinanze, sopravvissuto e inventario personale usano la UI originale, con logo VOID, toni militari e accenti rossi.

![Anteprima browser con oggetti dimostrativi](ox_inventory/docs/preview.png)

**[Scarica la patch ZIP](https://github.com/GiaMMark/GiaMMark/raw/refs/heads/void-characters/downloads/ox_inventory_void_dayz.zip)**

## Applicazione

1. Fai una copia della tua resource `ox_inventory` e fermala durante la manutenzione.
2. Estrai lo ZIP e **sovrapponi** la cartella `ox_inventory` alla tua cartella esistente. È una patch: servono ancora i file originali della resource, i bundle e le immagini già installate.
3. Mantieni `data/`, `modules/`, `web/images/` e le configurazioni del tuo server. Non rinominare la resource.
4. Avvia di nuovo `ox_inventory` e riconnettiti per provare la UI. Non occorre nuovo SQL.

Il pacchetto aggiunge il tema e aggiorna soltanto manifest e pagina HTML fra i file originali. Conserva le operazioni degli oggetti, gli export personalizzati, i trasferimenti e la persistenza gestita da ox_inventory. Non contiene modifiche a multicharacter o illenium.

Personalizza nome, logo, accento e testi in [web/build/void-config.js](ox_inventory/web/build/void-config.js). La [guida della resource](ox_inventory/README-VOID.md) descrive compatibilità, immagini e collaudo.

## Base richiesta e verifiche

La pagina richiede i bundle originali `index-7c4ea07a.js` e `index-9aba2ab3.css`; gli hash della base sono in [base.json](base.json). Questa patch non li sostituisce e non include i dati personalizzati dell'archivio caricato. Non applicarla a una release con frontend diverso senza adattarla.

Verificati 75 file originali invariati e nessun file originale rimosso. I due file originali modificati sono `fxmanifest.lua` e `web/build/index.html`. Il bundle JavaScript e il CSS originali restano identici.

La suite Chromium esercita il bundle React originale con callback server simulate: tooltip, Usa/Dai/Butta, quantità, drag-and-drop con mouse, aggiornamenti slot, negozi, contenitori vuoti, riaperture, chiusura e layout 1920/1366/1280. È stata eseguita anche dopo aver applicato la patch a una copia pulita dell'archivio ricevuto. Non è un collaudo FXServer, del database o delle autorizzazioni del tuo server.

Per rieseguirla dalla cartella della patch con Python, Playwright e Chromium:

```sh
python3 tests/nui.test.py --resource /percorso/ox_inventory --chromium /usr/bin/chromium
```

Le icone schematiche della schermata dimostrativa appartengono alla fixture browser. Il tuo ZIP non conteneva `web/images/`: conserva le immagini che usi sul server. La patch non aggiunge oggetti dimostrativi al gioco e non esegue richieste a font o CDN esterni.
