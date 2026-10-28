# VOID · Characters

Prima risorsa del pack VOID: selezione dei personaggi e registrazione dell'identità, con NUI monocromatica, scena di selezione e adattatori per ESX, QBCore e Qbox. Il preset di riferimento è **ESX + ox_inventory + illenium-appearance**.

![Anteprima NUI VOID monocromatica, simulazione browser](docs/preview.png)

L'anteprima usa dati dimostrativi e un fondale grafico. In FiveM il fondale è trasparente e lascia visibile il personaggio nella scena di gioco.

Con `void_loadscreen` avviata, la versione 0.1.1 attiva la dissolvenza della schermata di caricamento soltanto dopo l'apertura del selettore. La loadscreen è opzionale: senza di essa usa le native FiveM. Avvia `void_loadscreen` prima di `void_characters` e consulta la sua [guida](../void_loadscreen/README.md).

Non è ancora un intero gamemode: lavori, economia, garage, housing, inventario e negozi rimangono responsabilità delle rispettive risorse. VOID gestisce il percorso di accesso e offre punti di integrazione per gli altri script.

## Stato e requisiti

- FXServer aggiornato, GTA V e OneSync attivo.
- Un solo framework: ESX Legacy, QBCore oppure Qbox; database e schema del framework già installati.
- `oxmysql` e `ox_lib`, anche scegliendo un altro provider di notifiche.
- Un provider di aspetto configurato. Il preset usa `illenium-appearance`; `esx_skin` è previsto soltanto su ESX.
- Importazione dello schema VOID descritto sotto.

Le API degli adattatori sono state confrontate con i sorgenti ufficiali. Questo repository non include FXServer, GTA V, un database del server o i framework: il collaudo con giocatori reali resta necessario prima dell'uso pubblico. I controlli locali su Lua/NUI non equivalgono a una certificazione del flusso in gioco.

## Installazione: ESX consigliato

1. Copia la cartella `void_characters` in `resources/[void]/void_characters`, mantenendo esattamente questo nome.
2. Nel database già utilizzato da ESX importa `sql/schema.sql`. Le tabelle ESX, quelle dell'inventario e quelle di illenium devono essere già presenti secondo le rispettive istruzioni. Lo schema VOID non sostituisce gli SQL di quei progetti.
3. Configura il server come nell'esempio seguente, mantenendo la tua stringa di connessione MySQL nelle impostazioni riservate del server.
4. In `es_extended/shared/config/main.lua` imposta esplicitamente `Config.Multichar = true` e `Config.Identity = true`. Il rilevamento ESX standard cerca una risorsa chiamata `esx_multicharacter`: rimuoverla senza questa modifica può attivare il login singolo.
5. Disabilita l'avvio dei precedenti multicharacter e della UI di registrazione `esx_identity`. Mantieni le colonne identity nel database: VOID passa l'identità direttamente al core. Con illenium non avviare contemporaneamente gli originali `esx_skin` e `skinchanger`; illenium offre i propri eventi di compatibilità. Se scegli il provider `esx_skin`, usa invece il relativo stack e disabilita illenium.
6. Apri `config.lua`, scegli `Config.Framework = 'esx'` per una selezione esplicita e controlla coordinate, slot, regole di identità e provider.

```cfg
set onesync on
setr inventory:framework "esx"

ensure oxmysql
ensure ox_lib
ensure es_extended
ensure ox_inventory
ensure illenium-appearance
ensure void_characters
```

Se usi `ensure [core]` o un'altra cartella, verifica che non riavvii anche le risorse sostituite. Installa le dipendenze proprie di ox_inventory e illenium secondo le rispettive versioni; questo elenco mostra l'ordine del percorso di accesso VOID.

## QBCore e Qbox

Gli adattatori utilizzano i player e le tabelle native del framework. Non eseguire due core o due gestori di personaggi insieme.

**QBCore:** imposta `Config.Framework = 'qb'`; avvia `qb-core` prima di VOID e disabilita `qb-multicharacter`. Mantieni `qb-inventory` se è l'inventario scelto dal server. Il flusso `direct` di VOID gestisce lo spawn; `qb-spawn`, `qb-apartments` e gli script di housing richiedono un adattatore di spawn se vuoi usare i loro menu o appartamenti iniziali. Evita che altri script aprano un secondo creator o regalino di nuovo gli oggetti iniziali.

**Qbox:** imposta `Config.Framework = 'qbox'`; in `qbx_core/config/client.lua` imposta `characters.useExternalCharacters = true`. Avvia `qbx_core`, ox_inventory e il provider di aspetto prima di VOID. Con la versione di illenium esaminata mantieni il bridge QB attivo (`setr qbx:enablebridge "true"`): VOID usa gli export Qbox nativi, mentre illenium usa la compatibilità QB. Non avviare un secondo `qb-core`. Per il menu di `qbx_spawn` o gli appartamenti crea un'integrazione `Config.Spawn.Custom` e attendi il completamento effettivo dello spawn.

Per differenze di schema, API e versioni di riferimento leggi [COMPATIBILITY.md](docs/COMPATIBILITY.md).

## Configurazione

Tutte le opzioni pubbliche sono in `config.lua`; le callback lì definite possono essere adattate senza modificare il codice principale.

| Opzione | Effetto |
| --- | --- |
| `Framework` | `auto`, `esx`, `qb`, `qbox`; `auto` controlla Qbox prima di QBCore ed ESX. |
| `Brand` | Nome e sottotitolo dell'interfaccia. |
| `Slots.Default`, `Slots.Max` | Slot per account e limite superiore. |
| `Slots.IdentifierOverrides` | Eccezioni con identificatore completo `license:…`, decise dal server. |
| `Identity` | Lunghezza nomi, età, altezza, nazionalità ammesse. Il default di 16 caratteri rispetta lo schema ESX standard. |
| `AllowDelete` | Cancellazione disabilitata nel preset. Prima di attivarla definisci e collauda il cleanup dei dati collegati. |
| `Scene` | Posizione del ped, camera, FOV, ora, meteo e modelli base. |
| `Spawn` | Posizione iniziale, ultima posizione disponibile e provider `direct` o `custom`. |
| `Appearance` | `illenium-appearance`, `esx_skin`, `custom`, `none` e sezioni del creator. |
| `Notifications` | `ox_lib`, `esx`, `qb` o callback `custom`. |
| `TextUI` | `ox_lib`, `custom` o `none`; posizione e callback personalizzate. |
| `Server` | Timeout, rate limit, bucket di selezione, prefisso ESX e tabelle cancellabili. |

I dati inviati dalla NUI vengono validati anche sul server. Gli ID dei personaggi, gli slot e l'ownership devono sempre provenire dai dati verificati dal backend, non da valori ritenuti affidabili perché presenti nel browser.

### Aspetto

`illenium-appearance` apre l'editor tramite export e salva tramite l'evento del provider. `esx_skin` usa il proprio menu con callback ed è riservato a ESX. Per entrambi VOID verifica sul database la presenza dell'aspetto prima di rilasciare il bucket di selezione. Una creazione interrotta prima del salvataggio riapre l'editor al login successivo. `none` è utile per sviluppo o server con gestione esterna: usa il modello base e non offre un editor.

`qb-clothing` e `fivem-appearance` non sono provider automatici di questa versione. Possono essere collegati usando `Appearance.Custom`; implementa apertura, salvataggio persistente e callback di completamento della tua specifica versione:

```lua
Config.Appearance.Provider = 'custom'
Config.Appearance.Custom = function(context, done)
    -- Apri il tuo creator e attendi la conferma del relativo salvataggio.
    -- done(true) soltanto dopo un salvataggio riuscito e persistente.
    -- In caso di annullamento/errore: done(false).
end
```

Non usare `done(true)` subito dopo aver lanciato un evento asincrono: il giocatore potrebbe entrare prima che l'aspetto sia salvato.

Il contesto include `character`, `isNew`, `needsAppearance` e `framework`. Con un provider custom che salva fuori dalle tabelle standard, verifica nel tuo adattatore se l'aspetto esiste già: il backend standard non può riconoscere i dati di un archivio esterno.

### Notifiche e TextUI per il pack

Gli altri script client possono riusare i provider configurati:

```lua
exports.void_characters:Notify('Benvenuto su VOID', 'success')
exports.void_characters:ShowTextUI('[E] Interagisci')
exports.void_characters:HideTextUI()
```

Con il preset questi export chiamano `lib.notify`, `lib.showTextUI` e `lib.hideTextUI`. Mantieni un solo proprietario della TextUI alla volta; se hai un sistema di priorità centralizzato, collegalo con il provider `custom`.

### Spawn e script esterni

Il provider `direct` usa la posizione prevista da VOID senza aprire menu di terze parti. Per housing, ospedale iniziale, appartamenti o selettori esterni:

```lua
Config.Spawn.Provider = 'custom'
Config.Spawn.Custom = function(context)
    -- context.character, context.isNew, context.position
    -- Apri il tuo sistema di spawn e attendi il suo evento di completamento.
    -- Restituisci true soltanto quando lo spawn è effettivamente terminato.
    return false
end
```

Usa gli hook client `Config.Hooks.SelectionStarted()` e `Config.Hooks.CharacterReady(context)` per coordinare HUD, voice e sincronizzazione del meteo. Gli hook sono punti di estensione: VOID non configura automaticamente ogni risorsa di housing, jail, voice o HUD disponibile su FiveM.

### Cancellazione e cambio personaggio

La cancellazione richiede l'attivazione di `Config.AllowDelete` e la conferma configurata. Su ESX controlla `Config.Server.ESXDeleteTables`: il preset comprende soltanto `users.identifier`. Inserisci esplicitamente le tabelle collegate del tuo server (veicoli, conti, telefono, housing e altri dati) con colonne che contengono l'identificatore ESX completo. Il cleanup non viene scoperto automaticamente. Su QB/Qbox controlla anche le tabelle di cancellazione configurate nel core.

Per cambiare personaggio riconnettiti. Non viene aggiunto un comando `/relog`, che richiederebbe l'integrazione con restrizioni di combattimento, carcere, inventario e housing del server.

## Collaudo prima dell'apertura

Esegui il percorso completo su una copia del database e ripetilo su ciascun framework che intendi supportare:

1. Con un account nuovo apri VOID, crea un personaggio e completa l'aspetto. Controlla nome, data, sesso, altezza e nazionalità persistenti.
2. Disconnettiti, riconnettiti e seleziona il personaggio: aspetto e posizione devono tornare corretti, senza secondo creator.
3. Crea un secondo personaggio: inventario, denaro e identità devono rimanere separati; prova tutti gli slot e gli override autorizzati.
4. Usa due account diversi: l'elenco, la selezione e la cancellazione non devono consentire accesso ai personaggi dell'altro account. Prova richieste ripetute e slot/ID alterati con gli strumenti del server di sviluppo.
5. Dopo lo spawn apri ox_inventory o l'inventario configurato, esegui un'azione e riconnettiti: verifica che il caricamento framework sia completo e che gli oggetti non vengano duplicati.
6. Verifica isolamento durante la selezione e ripristino del routing bucket dopo lo spawn, anche con housing o altre istanze.
7. Se abiliti delete, prova conferma errata, cancellazione legittima e cleanup di tutte le tabelle del tuo stack; riconnettiti e verifica l'assenza del personaggio.
8. Interrompi e riavvia VOID durante la selezione e durante il gioco: controlla focus NUI, ped congelato/invisibile, camera e bucket. Dopo restart server ripeti il login.
9. Prova creator annullato, provider fermo, database non disponibile e timeout. Verifica errori comprensibili e assenza di duplicazioni.

Conserva log e versioni del server per ogni esito. I test locali e le fonti API non sostituiscono questi controlli.

## Diagnosi rapida

| Sintomo | Controllo |
| --- | --- |
| Due selettori o due editor | Stock multichar/identity e creator automatici di altre risorse ancora attivi. |
| ESX entra senza scelta | `Config.Multichar` del core deve essere `true` prima dell'avvio. |
| SQL segnala tabella/colonna assente | Importa schema framework, identity, aspetto e `sql/schema.sql` nel database corretto. |
| Qbox apre il menu originale | `characters.useExternalCharacters` va impostato nella configurazione client di qbx_core. |
| Aspetto non persiste | Controlla provider, bridge Qbox per illenium, relativo schema SQL e completamento del callback. |
| Spawn/menu bloccato | Il provider custom deve attendere e notificare il completamento reale; controlla anche i log di housing e spawn. |
| Dati orfani dopo delete | Completa la configurazione delle tabelle di cleanup e ripristina il database di prova prima di ripetere il test. |

Controlla la console FXServer e F8 client; non pubblicare stringhe MySQL o credenziali nei log condivisi.

## Test locali

Da questa cartella, con Lua 5.4 (i test sono eseguibili anche con `texlua`):

```sh
lua tests/syntax.lua
lua tests/identity.test.lua
lua tests/bridge.test.lua
lua tests/server.test.lua
lua tests/client.test.lua
node --check web/app.js
```

Per il browser servono Python, il pacchetto `playwright` e Chromium; sono strumenti di sviluppo, non dipendenze della resource:

```sh
python3 tests/nui.test.py --chromium /usr/bin/chromium
```

Il test avvia un server HTTP locale temporaneo e simula le callback NUI. `--base-url`, `--chromium` e `--screenshots` permettono di usare un server, browser o cartella di output diversi. Per guardare solo la grafica, servi `web/` con un server statico e apri `index.html?preview=1`; questa modalità usa dati fittizi e non effettua il login nel gioco.

Verifiche eseguite: compilazione degli 11 file Lua, 26 casi identity, 41 verifiche adapter, 32 verifiche sessioni server e test provider/lifecycle client. Nella versione 0.1.1 la suite client include anche la transizione verso `void_loadscreen` e il fallback alle native. Test Chromium su handshake, preview, slot precedenti, sospensioni, identity, cancellazione, richieste duplicate, recupero errori, trasparenza e mobile: passati. Framework, MySQL e native GTA sono simulati nei test Lua; nessuna prova FXServer o su database reale è stata eseguita qui.
