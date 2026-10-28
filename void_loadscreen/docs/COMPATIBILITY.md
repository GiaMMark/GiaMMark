# Compatibilità e API della loading screen

VOID Loadscreen è una resource standalone GTA V/FiveM. Non legge personaggi, inventari o database e non seleziona il framework del server. I riferimenti seguenti documentano le API usate; non sostituiscono il collaudo su un FXServer reale né garantiscono qualsiasi fork o combinazione di script.

## Componenti

| Componente | Integrazione |
| --- | --- |
| FXServer/FiveM | Loading-screen NUI dichiarata nel manifest; progresso ricevuto dai messaggi del motore. |
| ESX | In modalità automatica senza VOID Characters, chiusura su `esx:playerLoaded` o `playerSpawned`. |
| QBCore/Qbox | In modalità automatica senza VOID Characters, chiusura su `QBCore:Client:OnPlayerLoaded` o `playerSpawned`. Verifica i segnali del tuo selettore. |
| VOID Characters aggiornato | `auto` gli lascia il controllo; il selettore chiama `exports.void_loadscreen:Finish()` quando scena e NUI sono pronte. |
| Altri multichar/spawn | Modalità `external` ed export `Finish` al completamento effettivo della preparazione. |
| Queue/deferrals | La resource aggiunge un namespace handover; non chiama `defer`, `done`, `update` e non modifica gli endpoints. |
| ox_lib/oxmysql/inventari | Nessuna dipendenza o chiamata diretta. |

Se altri script chiamano direttamente `ShutdownLoadingScreenNui`, la NUI viene chiusa immediatamente e il fade VOID può essere interrotto. Coordina un solo proprietario della transizione per il tuo flusso.

## Manifest e lifetime

Il manifest dichiara `loadscreen 'web/index.html'`, `loadscreen_cursor 'yes'` e `loadscreen_manual_shutdown 'yes'`, oltre a includere HTML, CSS, JavaScript e file audio locali. Non usa `ui_page`: una loading screen è il frame speciale FiveM `loadingScreen`.

In modalità manuale `ShutdownLoadingScreen()` termina il caricamento nativo, mentre `ShutdownLoadingScreenNui()` chiude il frame NUI. `SendLoadingScreenMessage()` consente di inviargli messaggi dopo il caricamento del gioco e la connessione alla rete, quando gli script client iniziano a funzionare. L'export VOID invia `void:shutdown` e concede il tempo di fade prima di chiudere il frame.

L'arresto della resource chiude entrambe le componenti immediatamente, perché i timer della resource non sopravvivono all'arresto. Riavviare la resource mentre un giocatore è già in gioco non equivale a una nuova connessione.

## Config e handover

Il server usa `deferrals.handover({void_loadscreen = publicConfig})` durante `playerConnecting`. FiveM espone questi dati alla pagina in `window.nuiHandoverData`; il motore aggiunge anche informazioni proprie, come `serverAddress`, che VOID non mostra.

Il payload contiene solo le sezioni pubbliche della UI e, se abilitato, un nome giocatore limitato in lunghezza. Le impostazioni di shutdown e altri eventuali campi del config non vengono copiati automaticamente. Il nome è un dato non affidabile: viene inserito come testo, non come HTML.

Nel sorgente ufficiale FiveM `handover` scorre le chiavi ricevute e assegna ciascun valore alla mappa interna. Il namespace `void_loadscreen` preserva quindi gli altri campi handover; un'altra resource che riscrive la stessa chiave può sostituirlo. Il client invia anche `void:config` per aggiornare la pagina quando gli script diventano disponibili. Questo non giustifica l'inserimento di segreti nella configurazione UI.

## Messaggi di progresso

Il formato ufficiale è:

```js
{ eventName: 'loadProgress', loadFraction: 0.0 } // fino a 1.0
```

La UI verifica il tipo numerico, rifiuta valori non finiti e mantiene il progresso nell'intervallo `0–100`. Le notifiche di inizializzazione, caricamento file e mappa aggiornano le etichette della fase. Non sono usate per inventare una percentuale globale alternativa.

Il valore `100%` non coincide necessariamente con la readiness del personaggio: il passaggio al selettore o allo spawn resta governato dal client e dal sistema di personaggi. `index.html?preview=1` è l'unica modalità che invia un avanzamento dimostrativo; serve alla revisione grafica fuori dal gioco.

## Audio e collegamenti

La musica viene caricata dai file inclusi nella resource. Gli URL esterni e i percorsi di traversal non sono accettati per la playlist. Autoplay, codec e disponibilità dello storage dipendono dal CEF della versione FiveM; un click può essere necessario per avviare la musica. L'impossibilità di riprodurre audio non deve bloccare il caricamento.

I pulsanti community accettano indirizzi HTTPS senza credenziali incorporate; FiveM li apre attraverso la funzione di apertura URL del client. Il preset non contiene inviti o domini fittizi già attivi. Le regole visualizzate sono contenuto configurabile e non costituiscono un regolamento universale del server.

## Fonti ufficiali verificate

- **Documentazione FiveM**, commit `8c270c80c4855cb73dce2668ac0f80f93b1b3b43`: [loading screens, cursore, handover, lifetime](https://github.com/citizenfx/fivem-docs/blob/8c270c80c4855cb73dce2668ac0f80f93b1b3b43/content/docs/scripting-manual/nui-development/loading-screens/_index.md), [loadProgress](https://github.com/citizenfx/fivem-docs/blob/8c270c80c4855cb73dce2668ac0f80f93b1b3b43/content/docs/scripting-manual/nui-development/loading-screens/loadProgress.md), [resource manifest](https://github.com/citizenfx/fivem-docs/blob/8c270c80c4855cb73dce2668ac0f80f93b1b3b43/content/docs/scripting-reference/resource-manifest/_index.md).
- **Sorgenti FiveM**, commit `0cfcdb5ead57a4a26fcb6ebad98adbcd0273e607`: [elaborazione handover per chiave](https://github.com/citizenfx/fivem/blob/0cfcdb5ead57a4a26fcb6ebad98adbcd0273e607/code/components/citizen-server-impl/src/ClientDeferral.cpp#L343), [assegnazione alla mappa dati](https://github.com/citizenfx/fivem/blob/0cfcdb5ead57a4a26fcb6ebad98adbcd0273e607/code/components/citizen-server-impl/include/ClientDeferral.h#L63).

Per ogni prova reale annota artifact FXServer, versione del framework, selettore/spawn utilizzato, modalità di shutdown e risultati. I test locali di UI e lifecycle simulano le native: una prova browser riuscita non dimostra da sola che il passaggio fra loading screen e personaggio funzioni nel tuo stack.
