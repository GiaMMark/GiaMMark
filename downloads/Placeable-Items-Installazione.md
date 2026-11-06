# KQ Placeable Items — configurazione ESTESA


## Ampliamento richiesto

Tutti i 1.769 item attivi restano posizionabili. Questa versione aggiunge 788 associazioni rispetto alle 258 della prima consegna, arrivando a **1046**; 723 restano scatole generiche. Include **631 nuove approssimazioni visive**, autorizzate nella conversazione: colori, taglia, confezione, piatto o variante possono differire. Una tazza standard non riproduce tutti i caffè custom; un prop di collana non ricrea la gioielleria specifica. Le vecchie associazioni sono preservate e possono già essere equivalenti generici.

`mappatura.csv` contiene item, etichetta, prop, tipo e limiti di ciascuna scelta. `item_senza_prop.csv` elenca gli item rimasti con scatola; nessun file originale di armi, animali o modelli custom era allegato. Gli indossabili per animali, i pesci, le anatomie mediche e gli oggetti senza un equivalente autonomo richiedono risorse aggiuntive per una corrispondenza precisa. Non sono stati usati nomi di modelli custom inventati né modelli ped/veicoli come oggetti.

## Compatibilità: verificare prima di usarli sul server

I nomi sono presenti nel catalogo GTA consultato, ma alcuni appartengono a DLC recenti, inclusi `m25_1`, `m25_2` e `reh`. Questo non dimostra che la build GTA imposta dal tuo server li includa. **Il nome verificato nel catalogo non equivale a uno spawn verificato in FiveM.**

È inclusa la risorsa **facoltativa** `kq_propcheck`, che non crea oggetti né cambia la configurazione:

1. Copia la cartella `kq_propcheck` nelle risorse del server.
2. Avviala dopo la risorsa principale con `ensure kq_propcheck`.
3. Da un client esegui `/kqcheckprops`, quindi apri la console F8. Leggi le righe `NON DISPONIBILE`, con i nomi degli item interessati.
4. Per quei modelli usa un modello disponibile o sostituisci l'associazione con `hei_prop_heist_box` nel config. Non dare per scontato che il fallback KQ corregga ogni modello esplicitamente configurato ma assente.

Il controllo richiede il nome risorsa esatto `kq_placeable_items` e il file `config.lua`, che carica separatamente all'avvio. Se cambi il config, riavvia anche il controllo; non legge modifiche fatte in seguito dentro il runtime di KQ. Le sue native sono state simulate nei test locali: la disponibilità effettiva deve essere controllata dal client FiveM.

Presenza e validità del modello non verificano collisioni, dimensioni, rotazione o pickup. Prova prima gli oggetti voluminosi, in particolare pietre (`prop_rock_4_c`), pannelli (`prop_plywoodpile_01a`), rampe (`prop_skate_flatramp`) e le strutture per animali. I componenti meccanici generici possono non avere dimensioni adatte al singolo ricambio.

## Contenuto

- `items.lua`: file ox_inventory completo con pulsante «Posiziona a terra» per tutti i 1.769 item attivi.
- `kq_placeable_items/`: risorsa originale allegata; modificato esclusivamente `config.lua`.
- `config.lua`: copia dello stesso config per chi desidera aggiornare solo quello.
- `mappatura.csv`: elenco di tutti gli item attivi e relativo prop oppure scatola generica.

1046 item hanno un'associazione GTA; i restanti 723 mantengono `hei_prop_heist_box`, come richiesto. I modelli GTA equivalenti non riproducono necessariamente colori, marche o modelli personalizzati degli item. Non sono stati inventati nomi di prop custom. Il catalogo pubblico usato per controllare i nomi è https://github.com/DurtyFree/gta-v-data-dumps/blob/master/ObjectList.ini ; la presenza nel catalogo non prova disponibilità e collisioni nella build del tuo server.

## Installazione

1. Fai una copia dei file attuali del server. Non sovrascrivere eventuali modifiche successive agli allegati senza confrontarle.
2. Sostituisci `ox_inventory/data/items.lua` con `items.lua` incluso qui. Il file contiene le definizioni originali e aggiunge i pulsanti alla fine, prima del `return items`: conserva anche quel blocco nelle modifiche future.
3. Sostituisci `kq_placeable_items/config.lua` con quello incluso. In alternativa usa la cartella completa della risorsa, se corrisponde alla tua installazione e licenza.
4. Mantieni l'ordine di avvio esistente: framework e database, ox_inventory, quindi kq_placeable_items. Riavvia il server in manutenzione per ricaricare coerentemente gli item e la risorsa.
5. La persistenza era già abilitata negli allegati. Se installi KQ da zero, importa lo schema SQL secondo `_INSTALLATION.md`; se la tabella esiste già, controlla la versione e applica solo l'eventuale migrazione prevista, senza ricreare o cancellare dati.

La configurazione originale del database (`mysql` / mysql-async), gli eventi di caricamento framework, il target, i comandi e la persistenza sono conservati. Anche i riferimenti originali a `0r-pack1` e `/assetpacks` nel manifest sono conservati: questa consegna non installa quelle dipendenze e non sostituisce l'autorizzazione della risorsa escrow.

## Cosa è cambiato

- Tutti gli item attivi ricevono il pulsante KQ; `document` conserva il proprio pulsante esistente senza duplicarlo.
- Pulsanti metal detector e riciclatore, export, eventi, metadata, pesi, consumi e altre proprietà sono preservati.
- Abilitato il fallback già presente; rimossa soltanto la voce di esempio `iron` dalla blacklist per consentire tutti gli item.
- Aggiunte associazioni esplicite per documenti, telefoni, computer, alcuni alimenti, medicinali, attrezzi, sostanze e altri oggetti riconoscibili.
- Le associazioni KQ preesistenti, comprese le quantità multiple di oro/cocaina/metanfetamina, hanno la precedenza e sono conservate.
- Per le nuove associazioni: rilascio consentito, lancio disabilitato e raccolta tramite testo 3D per facilitare gli oggetti piccoli. I comportamenti delle associazioni originali restano invariati.

Un oggetto appoggiato con KQ è un prop fisico: il pulsante non attiva automaticamente le funzioni di altre risorse (computer Electus, router, riciclatore, dispositivi medici, ecc.). Per quelle funzioni continua a usare l'azione originale dell'item. Non sono state modificate altre risorse.

## Verifiche eseguite

- Caricamento ed esecuzione delle tabelle con Lua 5.4, traducendo i soli hash tra backtick CfxLua in costanti JOAAT in copie temporanee di verifica. I file consegnati conservano la sintassi FiveM originale.
- Confronto dei 1.769 item effettivamente restituiti da Lua: nessun item aggiunto o rimosso; proprietà e bytecode delle azioni originali preservati; nessun pulsante KQ duplicato sul documento.
- Esecuzione di ogni callback «Posiziona a terra» con export simulato e verifica dell'inoltro dello slot.
- Caricamento config, integrazione ox_inventory, fallback e blacklist; conservazione delle associazioni originali per quantità multiple.
- Tutti i nuovi nomi di modello controllati nel catalogo GTA indicato sopra.

Nel file originale esistono chiavi duplicate e un blocco di item commentati. Sono conservati: Lua continua a usare l'ultima definizione attiva per ogni chiave. Il CSV descrive gli item attivi, escludendo quelli commentati.

## Prova necessaria nel server

Non è disponibile un runtime FiveM in questo ambiente, quindi spawn, collisioni, rotazioni, raccolta, persistenza e integrazione con le versioni installate non sono stati provati in gioco.

Con un inventario di prova verifica: documento, telefono, laptop, un item piccolo, oro in quantità 1 e 6 e un item custom senza mappatura. Apri il menu dell'item, posizionalo, raccoglilo e controlla quantità/metadata. Prova separatamente i pulsanti originali di metal detector e riciclatore. Per gli oggetti persistenti verifica il comportamento dopo un riavvio controllato.

Per aggiungere in seguito un prop custom, servono il nome esatto del modello e la risorsa che lo carica. Aggiungi l'item a `additionalItemModels` nel config; per quantità o opzioni specifiche definiscilo direttamente in `Config.items`, che ha precedenza.
