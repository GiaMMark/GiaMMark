# Compatibilità e contratto degli adattatori

Questa pagina distingue le API esaminate dal collaudo in gioco. La lettura dei sorgenti ufficiali conferma i contratti usati, ma non prova che qualsiasi fork o versione di uno script sia interoperabile. Il preset iniziale di VOID è ESX + ox_inventory + illenium-appearance.

## Matrice

| Componente | Supporto previsto | Configurazione / limite |
| --- | --- | --- |
| ESX Legacy | Elenco, identity e login multichar tramite core. | `Config.Multichar=true`, `Config.Identity=true`; vecchi menu disattivati. |
| QBCore | Adattatore ai player e alle tabelle native. | Un solo core, `qb-multicharacter` disattivato. |
| Qbox | Export nativi `qbx_core` per login e player. | `characters.useExternalCharacters=true`; riconoscere license e license2. |
| oxmysql | Dipendenza obbligatoria. | Connessione e schema del framework già operativi. |
| ox_lib | Callback e UI di supporto; dipendenza obbligatoria. | Notifiche e TextUI configurabili anche con provider diversi. |
| ox_inventory | Inventario esterno del server; preset ESX/Qbox. | Installa e configura il bridge ufficiale appropriato. Il login VOID non sostituisce il suo setup. |
| qb-inventory | Inventario esterno QBCore. | Il server gestisce compatibilità e assegnazione degli oggetti iniziali. |
| illenium-appearance | Editor, caricamento e persistenza tramite provider. | Su Qbox la versione esaminata usa il bridge QB attivo. |
| esx_skin + skinchanger | Provider aspetto ESX. | Alternativo a illenium; non eseguire i due stack in parallelo. |
| qb-clothing / fivem-appearance | Integrazione personalizzata. | Implementare `Appearance.Custom` con conferma del salvataggio; nessun adattatore automatico promesso. |
| qb-spawn / qbx_spawn / apartments / housing | Integrazione personalizzata. | Collegare `Spawn.Custom` alla propria versione e attendere il completamento reale. |
| HUD / voice / meteo | Hook client. | Coordinare selezione e ripristino tramite `Config.Hooks`. |

## ESX

Il core espone `ESX.GetIdentifier(source)`, che nella versione esaminata restituisce l'identificatore senza il prefisso `license:`. Gli identificatori personaggio standard sono `char1:<base>`, `char2:<base>` e così via.

Il percorso server ufficiale per selezionare o creare un personaggio è:

```lua
TriggerEvent('esx:onPlayerJoined', source, 'char' .. slot, identityOrNil)
```

Per la creazione, l'identità contiene `firstname`, `lastname`, `dateofbirth`, `sex` e `height`. Il core usa questi dati quando `Config.Identity=true`; non è necessario aprire la UI stock `esx_identity`. La nazionalità non è una colonna identity standard di ESX e richiede la persistenza supplementare di VOID.

Lo schema identity standard ha nome e cognome `VARCHAR(16)`. Non aumentare `Config.Identity.MaxNameLength` senza adeguare deliberatamente lo schema e verificare gli script che leggono questi campi. Il prefisso `Config.Server.ESXIdentifierPrefix` deve corrispondere agli identificatori già presenti se importi un server esistente; cambiarlo non migra i personaggi.

Il logout standard è `TriggerEvent('esx:playerLogout', source, callback)`. VOID non aggiunge un comando pubblico di logout. La cancellazione ESX non ha un export universale: le tabelle devono essere dichiarate esplicitamente, con `users` eliminata dopo i dati collegati. Controlla vincoli SQL e riferimenti dei tuoi script prima di abilitarla.

## QBCore e Qbox

QBCore usa `QBCore.Player.Login(source, citizenid, newData)` e `QBCore.Player.Logout(source)`. `players.citizenid` identifica il personaggio, `players.license` identifica l'account e `charinfo` contiene l'identità. Per la creazione lo slot deve essere coerente fra `newData.cid` e `newData.charinfo.cid`.

Qbox espone `exports.qbx_core:Login(source, citizenid, newData)` e `exports.qbx_core:Logout(source)`. La sua tabella account `users` viene preparata dal percorso di connessione del core: non sostituire quel percorso con una tabella ESX. Qbox può associare i personaggi a `license` oppure `license2`.

L'export Qbox `DeleteCharacter(citizenid)` corrisponde alla cancellazione forzata ed è asincrono. Non verifica l'ownership per conto di una risorsa chiamante. Qualsiasi chiamante deve quindi verificare prima account/personaggio e controllare l'esito sul database. Anche la cancellazione QBCore richiede attenzione ai tempi asincroni e all'elenco delle tabelle configurato nel framework.

I sistemi stock spesso regalano gli oggetti iniziali nel proprio multichar. Sostituire quella risorsa non trasferisce automaticamente tutte le sue regole: configura l'assegnazione nel tuo stack e verifica che avvenga una sola volta per personaggio. Non assegnare oggetti da eventi client senza controlli server.

## Aspetto e ordine degli eventi

Il provider illenium offre `startPlayerCustomization(callback, options)`, `setPlayerAppearance` e `setPedAppearance`. Aprire l'editor tramite export non salva automaticamente il risultato: il callback deve confermare l'aspetto e inviarlo al relativo percorso di persistenza. Il parametro per impedire l'uscita è `enableExit=false`.

La versione verificata salva ESX in `users.skin` e QB/Qbox in `playerskins`. Carica l'aspetto sui rispettivi eventi player-loaded del framework. Altri script che cambiano il modello o applicano una skin sugli stessi eventi possono sovrascriverlo: verifica l'ordine reale nel tuo server.

Il callback dell'editor illenium invia il salvataggio, ma il suo evento server non fornisce una conferma durabile. VOID attende quindi che l'aspetto del personaggio appena creato o incompleto sia leggibile nella tabella del provider prima di rilasciare il bucket. Se il salvataggio non compare entro il timeout, non considera completata la selezione. Questa lettura verifica presenza e non certifica il corretto funzionamento di qualsiasi fork del provider.

Gli adapter personalizzati devono chiamare `done(true)` solo dopo il salvataggio e `done(false)` per errore/annullamento. Il provider spawn personalizzato deve restituire `true` dopo il completamento, non appena il menu è aperto. Nessuna callback di successo immediata deve mascherare un'operazione ancora in corso.

## Fonti ufficiali esaminate

Sono riferimenti di implementazione, non versioni automaticamente installate o prove di collaudo FXServer.

- **ESX Core:** commit `03c3fc7cf41c91663d24b55b7989bc12e39ebc98`. [Join server](https://github.com/esx-framework/esx_core/blob/03c3fc7cf41c91663d24b55b7989bc12e39ebc98/%5Bcore%5D/es_extended/server/modules/player/session/runtime/join.lua), [multicharacter](https://github.com/esx-framework/esx_core/blob/03c3fc7cf41c91663d24b55b7989bc12e39ebc98/%5Bcore%5D/esx_multicharacter/server/modules/multicharacter.lua), [schema identity](https://github.com/esx-framework/esx_core/blob/03c3fc7cf41c91663d24b55b7989bc12e39ebc98/%5Bcore%5D/esx_identity/esx_identity.sql).
- **QBCore multicharacter:** commit `85a03c4f3bdc100e898b9fb65614a9ce914fe926`. [Server e contratto del core](https://github.com/qbcore-framework/qb-multicharacter/blob/85a03c4f3bdc100e898b9fb65614a9ce914fe926/server.lua).
- **Qbox Core:** commit `58b345e2b53be98928c3e4ee44b100613ac9257f`. [Player API](https://github.com/Qbox-project/qbx_core/blob/58b345e2b53be98928c3e4ee44b100613ac9257f/server/player.lua), [configurazione client](https://github.com/Qbox-project/qbx_core/blob/58b345e2b53be98928c3e4ee44b100613ac9257f/config/client.lua), [schema e storage](https://github.com/Qbox-project/qbx_core/blob/58b345e2b53be98928c3e4ee44b100613ac9257f/server/storage/players.lua).
- **illenium-appearance:** commit `1b003ec169b15f145d519438ba7c6454bf746f27`. [Export editor](https://github.com/iLLeniumStudios/illenium-appearance/blob/1b003ec169b15f145d519438ba7c6454bf746f27/game/customization.lua), [flusso creator](https://github.com/iLLeniumStudios/illenium-appearance/blob/1b003ec169b15f145d519438ba7c6454bf746f27/client/client.lua), [salvataggio server](https://github.com/iLLeniumStudios/illenium-appearance/blob/1b003ec169b15f145d519438ba7c6454bf746f27/server/server.lua).

## Registrazione dei risultati

Per ogni stack annota artifact FXServer, commit core, versioni oxmysql/ox_lib/inventario/aspetto, schema usato e risultato del percorso di prova nel [README](../README.md#collaudo-prima-dellapertura). Segna separatamente prove passate, fallite e non eseguite. Finché manca il collaudo su FXServer, la compatibilità in gioco rimane da verificare.
