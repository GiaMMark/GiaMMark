# Verifiche della fusione — 6 novembre 2026

Verificati localmente:

- sintassi Lua 5.4 dei 20 script/manifest e degli snippet item dentro una tabella;
- sintassi dei quattro file JavaScript;
- sei test di conservazione del pacchetto: manifest, configurazioni, SQL/asset,
  eventi, export e generazione delle posizioni cabine;
- caricamento congiunto dei moduli client e server in ambienti Lua separati,
  con sostituti delle dipendenze FiveM non disponibili;
- callback NUI distinte, ownership del focus, chiusure inattive, risposta
  asincrona di banco/admin e riapertura dopo crafting mentre il telefono è aperto;
- isolamento delle configurazioni nei callback, hook UID del carrello,
  permessi bidoni, ricetta e accesso al banco muscle;
- router NUI con accodamento prima del caricamento delle interfacce;
- prova con i documenti HTML reali in Chromium: apertura, tastiera, Esc,
  campi admin, numero telefonico e POST dei callback con prefissi separati.

Nessun errore JavaScript o console nella prova browser. Il generatore opzionale
delle cabine è verificato offline con una risposta simulata di 350 posizioni;
non è stata verificata la disponibilità del sito esterno da cui scarica i dati.

Le tabelle, immagini e CSS originali sono conservati; gli eventi e gli
identificativi persistenti mantengono i nomi originali. È stato corretto anche
il generatore di locations.lua affinché mantenga la configurazione dei telefoni.

Queste prove non avviano GTA/FiveM, MySQL, ESX, ox_inventory, JG o LB Phone reali.
Non dimostrano transazioni inventario/database, chiamate audio, assegnazione del
veicolo o sincronizzazione OneSync sul tuo server. Usa la checklist in
README_INSTALLAZIONE.md prima della messa in servizio. L'ID del garage pubblico
deve essere configurato; nessun dato del tuo server è stato inventato.
