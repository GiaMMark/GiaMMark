# VOID · Loadscreen

Loading screen del pack VOID: interfaccia minimal monocromatica, elemento orbitale animato, avanzamento reale FiveM, musica locale, consigli a rotazione e introduzione alla community. Funziona senza dipendenze da ESX, QBCore, Qbox, ox_lib o database.

![Anteprima browser della loading screen VOID](docs/preview.png)

## Installazione

1. Copia questa cartella in `resources/[void]/void_loadscreen`, mantenendo il nome `void_loadscreen` per le integrazioni del pack.
2. Disattiva le altre resource che dichiarano una loading screen: deve essercene una sola attiva.
3. Configura `config.lua` e avvia VOID Loadscreen nelle prime righe delle resource del tuo `server.cfg`.
4. Riavvia il server e prova una nuova connessione. Il riavvio della sola resource mentre sei già in gioco non riproduce il caricamento iniziale.

Esempio per il preset ESX del pack:

```cfg
ensure void_loadscreen

ensure oxmysql
ensure ox_lib
ensure es_extended
ensure ox_inventory
ensure illenium-appearance
ensure void_characters

# Facoltativo: nasconde lo spinner originale in basso a destra.
setr sv_showBusySpinnerOnLoadingScreen false
```

Le dipendenze del multicharacter rimangono responsabilità di `void_characters`. Questa loading screen non richiede oxmysql o ox_lib e può essere usata anche da sola.

## Configurazione

Il file da modificare è **`config.lua`**. Le impostazioni UI sono inviate al browser del giocatore prima dell'avvio degli script client attraverso l'handover FiveM. Non inserire token, webhook, password o altri valori privati: la configurazione della schermata è pubblica.

| Opzione | Uso |
| --- | --- |
| `ShowPlayerName` | Mostra il nome FiveM del giocatore nel messaggio di benvenuto. Disattivala per un saluto generico. Non è il nome del personaggio. |
| `UI.brand` | Nome, etichetta, titolo e descrizione della schermata. |
| `UI.appearance` | Colore di accento e sfondo in formato `#RRGGBB`; abilita o disabilita le animazioni. |
| `UI.tips` | Attivazione, intervallo in millisecondi ed elenco dei consigli a rotazione. |
| `UI.music` | Attivazione, autoplay, volume iniziale `0.0–1.0` e playlist di file locali. |
| `UI.links` | Pulsanti verso gli indirizzi HTTPS reali della community. L'elenco iniziale è vuoto. |
| `UI.rules` | Titoli e testi del pannello introduttivo. Sostituiscili con i contenuti del tuo server. |
| `UI.labels` | Etichette delle fasi del caricamento. |
| `Shutdown.Mode` | Proprietario della chiusura: `auto`, `external` o `spawn`. |
| `Shutdown.DelayMs` | Attesa dopo un evento automatico di spawn/caricamento; da `0` a `10000` ms. Non è un timeout assoluto. |
| `Shutdown.FadeMs` | Tempo concesso alla transizione prima della chiusura NUI; da `0` a `10000` ms. |

I testi del pannello «Il nostro patto» sono consigli introduttivi. Non costituiscono il regolamento completo di un server: configura i testi e aggiungi il collegamento al tuo regolamento effettivo.

La schermata usa font di sistema e grafica locale; non richiede CDN, video esterni, account o servizi remoti. I collegamenti della community vengono aperti soltanto quando il giocatore li seleziona.

### Musica

È inclusa **VOID / SIGNAL 01**, una traccia ambient originale sintetizzata per il pack, senza campioni o registrazioni di terzi. Il player offre play/pausa, mute e volume; con più tracce compaiono i controlli precedente/successiva. Il tasto Spazio controlla la riproduzione quando il focus non è su un controllo del form o sul pannello delle regole.

Se Chromium/CEF blocca l'autoplay, viene mostrato il pulsante per attivare l'audio. Non è necessario disabilitare le protezioni del browser. Le preferenze volume/mute vengono ricordate localmente quando lo storage del browser è disponibile; una preferenza salvata prevale sul volume iniziale del config.

Per usare i tuoi file:

1. Inserisci file `.ogg`, `.mp3` o `.wav` in `web/media/`.
2. Aggiungi le tracce a `Config.UI.music.tracks`, con percorsi relativi a `web/`:

```lua
Config.UI.music.tracks = {
    { src = 'media/mia-traccia.ogg', title = 'NOME TRACCIA', artist = 'ARTISTA' },
    { src = 'media/seconda-traccia.mp3', title = 'SECONDA TRACCIA', artist = 'ARTISTA' }
}
```

I file di questi formati sono già inclusi dal manifest. Sono accettati percorsi locali della resource; URL audio esterni e percorsi che risalgono alle cartelle superiori vengono rifiutati. Verifica il codec anche nel CEF della tua versione FiveM e usa soltanto musica che puoi distribuire nel tuo server.

Il file audio incluso è già pronto per il server. `tools/generate_ambient.py` serve soltanto a rigenerarlo durante lo sviluppo, con Python e ffmpeg: non è una dipendenza di esecuzione della resource.

### Link della community

```lua
Config.UI.links = {
    { label = 'DISCORD', url = 'https://discord.gg/tuo-invito' },
    { label = 'REGOLAMENTO', url = 'https://tuo-dominio.it/regolamento' }
}
```

Sostituisci gli esempi con indirizzi reali. La UI accetta solo HTTPS, senza credenziali nell'URL. In FiveM utilizza l'apertura link del client; nell'anteprima browser apre una nuova scheda.

## Chiusura e passaggio al personaggio

La percentuale proviene da `loadProgress` di FiveM. Il raggiungimento di `100%` indica il caricamento delle risorse, non certifica che framework, inventario e personaggio abbiano completato il login: la schermata resta in attesa del segnale di chiusura.

| Modalità | Comportamento |
| --- | --- |
| `auto` | Se `void_characters` è avviato o si sta avviando, gli lascia il controllo della transizione. Altrimenti chiude dopo `playerSpawned`, `esx:playerLoaded` o `QBCore:Client:OnPlayerLoaded`. |
| `external` | Attende sempre una chiamata esplicita all'export `Finish` da parte del tuo selettore/spawn. |
| `spawn` | Chiude sui suddetti eventi di spawn/caricamento anche se è presente VOID Characters. Usala solo quando questo comportamento corrisponde al tuo flusso. |

Il multicharacter VOID aggiornato richiama `Finish` quando scena e interfaccia di selezione sono pronte. Se utilizzi un altro selettore, scegli `external` e integra il completamento nel suo codice client:

```lua
-- Esegui quando il tuo selettore o la scena di spawn è davvero pronto.
if GetResourceState('void_loadscreen') == 'started' then
    exports.void_loadscreen:Finish()
end
```

`Finish` è idempotente: chiamarlo più volte non crea transizioni duplicate. Ferma il caricamento nativo, invia il messaggio di uscita alla UI e chiude la NUI dopo `FadeMs`. Le chiamate native di chiusura eseguite direttamente da altri script possono terminare la schermata prima del fade; per una transizione coordinata usa l'export.

Non è presente un timer che forza l'ingresso dopo un numero fisso di secondi. Se il framework o il selettore non segnala la readiness, correggi quell'integrazione anziché simulare il completamento del login.

## Anteprima e test locali

Servi `web/` con un server statico e apri `index.html?preview=1` per vedere grafica e progressione dimostrativa. La modalità normale non genera avanzamento fittizio; l'anteprima è contrassegnata e non simula il login effettivo in FiveM.

Da questa cartella:

```sh
lua tests/syntax.lua
lua tests/lifecycle.test.lua
node --check web/app.js
python3 tests/nui.test.py --chromium /usr/bin/chromium
```

I test Lua richiedono Lua 5.3+ o `texlua`. I test browser richiedono Python, il pacchetto `playwright` e Chromium, e avviano un server HTTP locale temporaneo. Sono strumenti di sviluppo: la resource installata non richiede Node, Python, Playwright o ffmpeg.

Il comando browser supporta `--base-url`, `--chromium` e `--screenshots`. Le native FiveM e le transizioni del framework sono simulate nei test locali; il collaudo finale su FXServer rimane necessario.

Verifiche completate: 6 file Lua compilati e 13 scenari lifecycle/handover passati anche sul runtime Lua 5.4; 11 scenari Chromium passati su progresso, testo e link, autoplay, playlist, preferenze, layout, storage disabilitato e dissolvenza. Il test audio legge e riproduce realmente la traccia inclusa; ffprobe ne conferma formato OGG/Vorbis e durata di 40 secondi. La suite Characters comprende inoltre 2 regressioni dedicate alla nuova transizione e al fallback nativo.

## Collaudo in gioco

Prima dell'utilizzo pubblico verifica una nuova connessione con la tua combinazione di artifact, framework e script:

- UI visibile dall'inizio, avanzamento reale, musica controllabile e nessuna seconda loading screen sovrapposta.
- Config, nome FiveM, consigli, regole e link corretti; autoplay bloccato recuperabile con un click.
- Passaggio a VOID Characters senza cursore/focus residuo, audio persistente o schermo nero; ripeti con un account nuovo e uno con personaggi esistenti.
- Modalità standalone oppure selettore esterno, compresi gli eventi di spawn richiesti dalla tua versione.
- Una connessione lenta: la barra non deve inventare progresso né chiudere la schermata prima del segnale reale.
- Riavvio/arresto della resource durante il caricamento e ripetizione della connessione dopo il riavvio del server.

Per contratti API e fonti ufficiali leggi [COMPATIBILITY.md](docs/COMPATIBILITY.md).
