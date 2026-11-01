# FIELDLINK MK.II — WASTELAND EDITION

Seconda versione dell'interfaccia survival per il pacchetto LB Phone 2.9.0 fornito.

## Cosa cambia rispetto alla prima versione

- Scocca metallica usurata, viti, protezioni laterali, speaker e bande ambra di pericolo.
- Display rettangolare incassato; cornici fisiche superiori e inferiori.
- Schermata da terminale con caratteri monospaziati, verde fosforo e scanline statiche su home/lockscreen.
- 27 icone industriali, squadrate, numerate, con staffe e piccoli segni di usura.
- Sfondo topografico più marcato e leggibile.
- Pannelli, interruttori, notifiche e tastierino coerenti con lo strumento da campo.
- Nomi delle app a tema in italiano e inglese: Diario, Sistema, Cartografia, Archivio, Rilievi, Rifugio, Scambi, Registro, ecc.

Le applicazioni mantengono identificatori e callback LB Phone. La bussola nello sfondo è decorativa. Non vengono aggiunti sistemi di fame, sete, radiazioni, crafting, radio o SOS: questa è una modifica all'interfaccia, non alle meccaniche del server.

## Installazione

1. Fai una copia della tua risorsa `lb-phone` attualmente sul server.
2. Estrai la cartella `lb-phone` da `lb-phone-survival-v2-wasteland.zip` nella cartella risorse, mantenendo il nome `lb-phone`.
3. Se hai personalizzato configurazioni o traduzioni rispetto al pacchetto fornito, usa il pacchetto `lb-phone-survival-v2-solo-tema.zip` e unisci le modifiche dei config/locales descritte sotto, senza sovrascrivere quelle personalizzazioni.
4. Riavvia la risorsa nella console del server con `restart lb-phone`.
5. Prova il telefono nel gioco: sblocco, chiamate, messaggi, voce, fotocamera, mappe e le app del tuo framework.

Puoi installarla anche sopra la prima versione FIELDLINK. Non serve compilare il frontend. Licenza, database e dipendenze originali (tra cui oxmysql) restano necessari.

## File modificati

- `ui/dist/index.html`: carica, dopo i CSS originali e in quest'ordine, `survival/survival.css`, `survival/wasteland.css`, `survival/grid.css`. Titolo/favicon aggiornati, font locale.
- `config/config.json`: wallpaper `survival: survival.svg`; icone dei 27 ID app in `./assets/survival/icons/<ID>.svg`. Le altre proprietà restano quelle ricevute.
- `config/defaultSettings.json`: tema iniziale scuro, sfondo survival, orologio chiaro e disposizione con strumenti in prima fila; nessuna app rimossa.
- `config/config.lua`: lingua predefinita `it`, date `it-IT`, cornice `#4b5837`.
- `config/locales/it.json` e `en.json`: nomi visualizzati delle app, titolo di Sistema e titolo del Diario. I testi delle altre funzioni non cambiano.
- Aggiunti: `ui/dist/assets/survival/` (CSS, icone, sfondo, scocca) e `survival.svg` nelle cartelle wallpaper `default/`, `default/light/`, `default/dark/`.

Per integrare il tema manualmente, aggiungi dopo i CSS originali:

```html
<link rel="stylesheet" href="/ui/dist/assets/survival/survival.css">
<link rel="stylesheet" href="/ui/dist/assets/survival/wasteland.css">
<link rel="stylesheet" href="/ui/dist/assets/survival/grid.css">
```

Le tue app aggiuntive mantengono identificatori e icone. Le icone stock restano fisicamente presenti. Il colore esterno della cornice può ancora seguire l'impostazione originale, mentre la scocca resta oliva usurata.

## Telefoni esistenti

Tema e icone si applicano dopo il caricamento della risorsa. Disposizione, lingua e wallpaper già salvati nel database vengono conservati. Per avere anche il nuovo sfondo su un telefono già configurato, selezionalo in Sistema > Sfondo. La skin usa superfici scure anche quando la preferenza precedente era chiara. Non occorre resettare i telefoni o cancellare dati.

## Ripristino

`originali-prima-del-tema.zip`, incluso nel pacchetto, contiene tutti e sei i file originali modificati con i percorsi corretti, così come presenti nello ZIP ricevuto. Ripristinali, poi riavvia la risorsa. I file nuovi del tema possono essere rimossi o rimanere inutilizzati. Conserva il tuo backup per eventuali personalizzazioni ulteriori del server.

## Verifiche

- Chromium: schermata di blocco, sblocco, home e apertura reale tramite le icone di Sistema, Contatti, Diario e Messaggi.
- Ritorno alla home, chiusura/riapertura e verifica dei colori dopo i CSS caricati dalle singole app.
- 24 app e dock da 4 icone, alle scale 0.55 / 0.7 / 0.9, senza sovrapposizioni; wallpaper preesistente conservato.
- Verifica XML degli SVG e trasparenza dell'apertura del display della scocca.
- Backend Lua, manifest, JavaScript compilati e CSS originali invariati.
- Le risposte NUI sono simulate esclusivamente dai test esterni; il pacchetto consegnato usa i callback originali.

Il server FiveM non è disponibile qui: il comportamento reale in gioco va verificato sul tuo server. La modalità demo originale tenta di caricare `light/cloud8.jpg`, già mancante nello ZIP ricevuto, e usa il fallback originale; tutti i nuovi asset sono presenti. Le anteprime mostrano dati di test della UI, non dati del tuo server.
