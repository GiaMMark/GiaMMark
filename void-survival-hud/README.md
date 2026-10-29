# Void Survival HUD — FiveM ESX

HUD a riga in nero, viola e ciano: vita, armatura, fame, sete, resistenza/ossigeno,
stress JG, voce e strumenti veicolo. Tutti i player possono cambiare posizione,
dimensione, trasparenza, colori, larghezza del layout e visibilità dei gruppi senza permessi staff.
Nessun titolo sopra gli indicatori; le etichette sono nascoste inizialmente.
Gli indicatori partono senza sfondo; puoi riattivare i pannelli dall'editor.
La minimappa richiede il possesso dell'item `mappa`.

## Installazione

1. Copia la cartella **`void-survival-hud`** in `resources/[local]/` mantenendo questo nome.
2. Mantieni la tua installazione funzionante di ESX Legacy e `esx_status` con
   `esx_basicneeds` (o il sistema che aggiorna fame e sete). L'HUD legge i bisogni,
   non li crea e non li modifica.
3. Installa il tuo **`jg-stress-addon`** e la sua dipendenza `ox_lib` come previsto
   dal tuo server. L'addon allegato viene integrato senza modificarne i file.
4. Ordina gli avvii in `server.cfg`, dopo le altre dipendenze di ESX già presenti:

   ```cfg
   ensure es_extended
   ensure esx_status
   ensure esx_basicneeds
   ensure ox_lib
   ensure jg-stress-addon
   ensure void-survival-hud
   ```

5. Disattiva l'eventuale vecchio HUD per evitare sovrapposizioni e apri **F7** o
   **`/hud`** in gioco dopo aver caricato il personaggio.

Non richiede SQL, npm, librerie NUI esterne, nuovi eventi server o credenziali.
Le eventuali dipendenze del tuo ESX e del tuo addon JG restano quelle del tuo server.

## Aggiornamento

Ferma `void-survival-hud`, sostituisci la cartella con quella del nuovo ZIP e avvia
`ensure void-survival-hud`. Non lasciare una seconda copia della risorsa avviata.
La pagina di gioco ora forza lo sfondo trasparente e non contiene la scena
di anteprima. La preview è separata in `preview.html`, attivabile solo esplicitamente.
La versione 1.1 usa una riga orizzontale con layout normale o compatto. Le preferenze
precedenti vengono lette: colori, posizione, dimensione e moduli restano salvati;
i vecchi riquadri diventano una riga e le etichette iniziali vengono nascoste.
Per applicare le nuove posizioni iniziali apri `/hud`, premi **Ripristina tutto**
e poi **Salva HUD**.

La versione 1.2 mostra la riga senza sfondo anche con preferenze precedenti.
L'opzione **Sfondo indicatori** riattiva i pannelli usando l'opacità già salvata.
Il logo V non ha sfondo o bordo proprio.

## Minimappa e item mappa

La minimappa appare solo quando il personaggio ha almeno un item chiamato
`mappa` nell'inventario, sia a piedi sia in auto. Si nasconde se il player perde
l'ultimo esemplare, esce dal personaggio o l'inventario non è ancora disponibile.
La verifica è automatica: non devi usare o consumare l'item.

Il nome è quello interno dell'item, modificabile in `config.lua`:

```lua
Config.Minimap = {
    Enabled = true,
    Item = 'mappa',
    Inventory = 'auto',
    CheckInterval = 500
}
```

`auto` usa `ox_inventory` se presente; altrimenti legge l'inventario ESX.
Puoi scegliere esplicitamente `esx` oppure `ox_inventory`. Se ox è presente ma
in arresto o non pronto, in modalità auto il radar resta nascosto fino al suo
riavvio per evitare di usare una copia ESX non aggiornata dell'inventario.
L'item deve già essere registrato nel sistema inventario del server; l'HUD non
crea o assegna item. Non serve modificare il database per l'HUD.

Lascia il controllo della minimappa a questa risorsa: disattiva eventuali
altri HUD/script che la forzano visibile. `Enabled = false` disabilita il
controllo del radar da parte dell'HUD. La mappa nel menu pausa è separata e
non viene bloccata. Alla chiusura della risorsa, con personaggio caricato, il
radar torna allo stato precedente; dopo il logout resta nascosto.

## Editor personale

Apri l'editor, trascina i tre gruppi sullo schermo e modifica i controlli.
Premi **Salva HUD** per rendere persistenti le preferenze. **Annulla**, il pulsante
di chiusura ed **Esc** scartano le modifiche non salvate. **Ripristina tutto** prepara
i valori iniziali: premi Salva HUD per confermarli.
La posizione viene mantenuta come percentuale dello schermo e limitata al viewport.
Il tachimetro è visibile quando sali su un veicolo; l'editor ne mostra il pannello
anche a piedi, con trattini al posto dei dati non disponibili.

Le preferenze sono **locali al client FiveM** e separate per identificatore del
personaggio ESX. Sopravvivono al riavvio della risorsa; non si sincronizzano su un
altro PC e possono andare perse cancellando i dati locali FiveM. Modificare
`Config.DefaultSettings` cambia i valori iniziali, senza sovrascrivere le scelte già
salvate dai player. Il reset nell'editor ripristina quei valori iniziali.

F7 è il tasto iniziale: ogni player può cambiarlo in **Impostazioni GTA →
Associazione tasti → FiveM → Apri editor HUD Void**. Il server può modificare
`Config.DefaultKey` per i nuovi binding e `Config.Command` per il comando.

## Stress JG

Legge l'export client **`exports['jg-stress-addon']:getStress()`** dell'addon
fornito. Se l'export non è disponibile, usa lo stesso statebag **`LocalPlayer.state.stress`**
quando l'addon è avviato. Il valore è limitato a 0–100; l'export conserva le
esenzioni dei lavori configurate nell'addon.

L'HUD **non genera, azzera, salva o modifica lo stress**: incidenti, armi, effetti,
zone relax e `/toglistress` continuano a essere gestiti esclusivamente da JG.
Se l'addon non è avviato o non restituisce dati, l'interfaccia segnala l'assenza
del collegamento. Se la cartella JG ha un altro nome, cambia `Config.StressResource`.

## Strumenti veicolo

Velocità in **km/h o mph**, marcia, carburante, stato motore, giri e luci.
Il campo viaggio misura la **distanza della sessione sul veicolo corrente**:
si azzera uscendo/cambiando veicolo o riavviando la risorsa. Gli spostamenti
incompatibili con la velocità o oltre `Config.TripTeleportDistance` sono ignorati.
Non è un contachilometri storico salvato per targa e non scrive nel database.

Per impostazione iniziale il carburante usa `GetVehicleFuelLevel`. Per un sistema
carburante che espone un export client compatibile, modifica per esempio:

```lua
Config.Fuel = { Resource = 'LegacyFuel', Export = 'GetFuel' }
```

L'export deve ricevere il veicolo e restituire una percentuale 0–100; se fallisce
si usa il dato nativo. Per un export con firma diversa serve un adattatore nel
metodo `readFuel` di `client/main.lua`.

## Configurazione e compatibilità

- `config.lua`: palette predefinita, layout, posizioni, unità e frequenze di lettura.
  Dimensione da 70 a 130%; opacità pannelli da 35 a 100%; colori in formato `#RRGGBB`.
- `Config.OxygenSeconds`: capacità polmonare usata per la percentuale ossigeno.
- Fame/sete sono lette tramite `esx_status:getStatus`, `getPercent()` o `val / 10000`.
  Se mancano i dati vengono mostrate come non disponibili.
- La voce usa `NetworkIsPlayerTalking`; se esiste il statebag `proximity.distance`
  (per esempio pma-voice), viene mostrata anche la distanza. Nessuna dipendenza voce.
- La minimappa non viene spostata. La visibilità dipende da `Config.Minimap`
  e dall'inventario; eventuali HUD terzi che controllano il radar vanno configurati.
- In pausa l'HUD si nasconde (`HideOnPause`). Nessun parametro influenza salute,
  bisogni, motore, carburante o altri valori di gioco: tutti sono letti soltanto.

## Verifica sul server

1. Avvia le risorse nell'ordine indicato e controlla console server/F8 senza errori.
2. Apri `/hud` con un account player normale; sposta e salva. Ricollegati con lo
   stesso personaggio e verifica il ripristino delle preferenze.
3. Consuma un cibo/bevanda con il sistema del server e verifica fame/sete.
4. Genera stress con il tuo addon JG; confronta l'HUD con `getStress()` e verifica
   anche un lavoro esente e il comando staff già fornito dall'addon.
5. Entra in auto, guida e controlla velocità, marcia, carburante e viaggio;
   cambia km/h/mph dall'editor. Esci dal veicolo: il gruppo deve scomparire.
6. Prova Esc, pausa, logout e `restart void-survival-hud`: il cursore non deve
   rimanere bloccato e la HUD non deve apparire nella selezione personaggio.
7. Senza `mappa`, verifica radar nascosto a piedi e in auto. Aggiungi l'item:
   deve apparire; rimuovi l'ultimo esemplare: deve scomparire. Ripeti dopo un
   ricollegamento e il riavvio della risorsa inventario.

## Anteprima fuori da FiveM

Dalla cartella della risorsa avvia `python3 -m http.server 8000 --directory html`
e apri `http://localhost:8000/preview.html` nel tuo browser locale. L'anteprima usa dati dimostrativi,
non si collega a ESX e salva le preferenze nel browser, separate da quelle in gioco.
Non aprire `preview.html` direttamente come file: gli script sono moduli JavaScript.
I file NUI sono già pronti, senza compilazione o download da CDN.

I sette test di normalizzazione, migrazione e posizionamento si eseguono con
`node tests/settings.test.mjs` (Node 18 o successivo, solo per lo sviluppo).

La preview browser serve a controllare interfaccia ed editor. La verifica dei
nativi GTA, di ESX e dello stress JG richiede un server FiveM e un client di gioco.
