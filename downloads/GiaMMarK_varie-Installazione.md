# GiaMMarK_varie — installazione e migrazione

Una sola risorsa FiveM contiene crafting, ricerca bidoni, telefoni pubblici, ricostruzione muscle car e carrello. Il nome della cartella deve rimanere **`GiaMMarK_varie`**, rispettando maiuscole e minuscole: gli export degli item usano questo nome.

## Dipendenze

Mantieni installati e avviati prima di questa risorsa:

- `0r-pack1`: l'inclusione originale `@0r-pack1/src/include/shared.lua` è conservata una volta nel manifest;
- `oxmysql`, `ox_lib`, `es_extended`, `ox_inventory`, `ox_target`;
- `jg-advancedgarages` **v4**, con schema ESX compatibile;
- `lb-phone` per le chiamate dei telefoni pubblici; senza di esso le chiamate non funzionano;
- OneSync per il carrello e le verifiche delle entità lato server.

Non avviare anche `lb-payphone`: il modulo dei telefoni rileva questo conflitto e disabilita le proprie interazioni. Le dipendenze commerciali e il server FiveM non sono inclusi nello ZIP.

## Passaggio dalle cinque risorse originali

1. Conserva un backup delle cartelle originali, delle configurazioni personalizzate e del database. Riponi i carrelli, termina crafting e chiamate prima della sostituzione.
2. Copia la cartella `GiaMMarK_varie` dentro `resources`. Non copiare soltanto le sottocartelle `modules`.
3. Rimuovi gli `ensure`/`start` delle cinque vecchie risorse dal tuo `server.cfg` e da eventuali altri file `.cfg` eseguiti:
   `GiaMMarK_crafting`, `trash_search`, `public_payphones`, `muscle_rebuild`, `mobile_cart_fivem`.
   Non lasciare gli originali avviabili automaticamente da `ensure [nome_categoria]`: spostali fuori da `resources` oppure rimuovili dopo il backup. La nuova risorsa e gli originali registrano gli stessi eventi e non devono funzionare insieme.
4. Se stai operando a server acceso, ferma **tutte e cinque** le vecchie risorse dalla console server:

   ```text
   stop GiaMMarK_crafting
   stop trash_search
   stop public_payphones
   stop muscle_rebuild
   stop mobile_cart_fivem
   ```

5. Aggiorna gli export nelle definizioni **già esistenti** di `ox_inventory/data/items.lua`:

   | Item | `client.export` nuovo |
   | --- | --- |
   | `carrello` | `GiaMMarK_varie.useCart` |
   | `car_rottame` | `GiaMMarK_varie.useCarToken` |

   Gli snippet aggiornati sono `modules/cart/items_snippet.lua` e `modules/muscle/extras/item_car_rottame.lua`. Sono frammenti da inserire nella tabella degli item, non script da caricare nel manifest. Se gli item esistono già, cambia il solo export e conserva le altre personalizzazioni: non duplicare le voci.

6. Per una nuova installazione, copia `modules/cart/ox_inventory_images/mobile_cart.png` in `ox_inventory/web/images/mobile_cart.png`; il relativo snippet usa questa immagine.
7. Riporta le tue personalizzazioni nei nuovi file di configurazione, seguendo la tabella sotto. Mantieni le **prime due righe** di ciascun nuovo file, che separano le configurazioni: non sostituirle con `Config = {}` e non sovrascrivere i nuovi file con quelli vecchi interi.
8. Aggiungi **un solo** `ensure GiaMMarK_varie` dopo le dipendenze. `install/server.cfg.example` è un esempio da integrare, non un sostituto completo del tuo `server.cfg`.
9. Esegui un riavvio completo del server dopo le modifiche agli item, così `ox_inventory` carica gli export nuovi e nessuna vecchia risorsa rimane attiva. Controlla console server e F8 prima di aprire il server ai giocatori.

## Configurazioni separate

| Modulo | File | Tabella dedicata |
| --- | --- | --- |
| Crafting | `modules/crafting/config.lua` | `CraftingConfig` |
| Bidoni | `modules/trash/config.lua` | `TrashConfig` |
| Telefoni | `modules/payphones/config.lua` | `PayphoneConfig` |
| Muscle car | `modules/muscle/config.lua` | `MuscleConfig` |
| Carrello | `modules/cart/config.lua` | `CartConfig` |

All'interno dei file puoi continuare a modificare i campi `Config.*`: sono riferimenti locali alla rispettiva tabella. Coordinate, ricette, nomi degli item, lavori, cooldown e altre impostazioni dello ZIP originale sono conservati.

**Muscle car:** in `modules/muscle/config.lua` imposta il campo `initialGarageId` della tabella `Config.JG`, sostituendo `'INSERISCI_ID_GARAGE_PUBBLICO'` con l'ID reale di un garage pubblico auto. Usa `mr_jg4_list` e poi `mr_jg4_check` dalla console server. Per il ritiro nei garage pubblici condivisi, verifica l'opzione JG “Require transfers between public garages” come spiegato nel README originale. `dukes` rimane il modello di prova originale: configura lo spawn name effettivo del tuo veicolo se diverso.

**Crafting:** il comando predefinito resta `/craftadmin`. I permessi restano quelli configurati: ACE `giammark.crafting.admin` oppure gruppi ESX elencati in `Config.AdminGroups`. Non vengono assegnati nuovi privilegi automaticamente.

## Database e dati esistenti

La fusione conserva tabelle `giammark_crafting_stations`, `mr_car_tokens`, proprietà in `owned_vehicles`, metadata `cart_uid` e stash `mc_cart_<uid>` di `ox_inventory`. **Non cancellare o ricreare database, tabelle, stash o item già distribuiti per questa migrazione.**

Solo per nuove installazioni, o se manca la relativa tabella, importa nel database ESX:

- `modules/crafting/sql/install.sql`;
- `modules/muscle/install.sql`.

Entrambi usano `CREATE TABLE IF NOT EXISTS`; non modificano `owned_vehicles` e non sostituiscono le migrazioni ufficiali ESX/JG. Non serve reimportarli per spostare dati già presenti. I prop dei carrelli vengono rimossi a logout/stop/riavvio come nell'originale; il contenuto dello stash resta disponibile estraendo nuovamente lo stesso item.

## Verifiche nel tuo server

Questo pacchetto richiede una prova sul tuo server FiveM con le versioni effettive delle dipendenze; la verifica locale non dimostra chiamate, garage o sincronizzazione in gioco.

- **Avvio:** nessun errore di dipendenze/export/config in console e F8; gli originali risultano arrestati; un solo target per interazione.
- **Crafting:** apri un banco, produci una ricetta e verifica consumi/ricompensa; annulla una lavorazione. Da admin apri `/craftadmin`, salva e riapri una postazione; verifica che un giocatore senza permessi non acceda al pannello.
- **Bidoni:** prova il lavoro autorizzato configurato, ricerca completa, annullamento e cooldown; controlla loot o risultato vuoto senza duplicazioni. Prova anche un lavoro non autorizzato.
- **Telefoni:** apri il tastierino, chiudi e riapri; chiama un numero raggiungibile, controlla lo stato e riaggancia dalla stessa cabina. Chiudere il pannello non equivale a riagganciare: verifica anche il target “Riaggancia” o `/payphonehangup` e la chiusura per allontanamento.
- **Muscle car:** con lavoro e ingredienti corretti usa il banco, verifica il token `car_rottame`, riscattalo e ritira il veicolo nel garage configurato. Verifica che lo stesso token non sia riscattabile due volte.
- **Carrello:** estrai → deposita con X → apri stash dal target → riprendi → riponi → estrai. Verifica gli stessi contenuti dopo logout/login e riavvio del server usando lo stesso item; prova anche la visualizzazione da un secondo giocatore.
- **Interfacce:** alterna crafting e telefono; Esc/chiusura devono restituire i controlli senza schermo nero, callback incrociati o cursore bloccato. Un pannello già aperto impedisce l'apertura contemporanea dell'altro.

I README e le note conservati nelle cartelle dei moduli documentano il funzionamento originale. I loro vecchi comandi `ensure`, nomi di cartella, percorsi di installazione ed export sono storici: per questa versione prevale questa guida.
