# Revisione grafica 5 — rosso e bianco

Aggiornamento della grafica richiesto dopo la conferma del funzionamento della revisione 4.

- Griglia sinistra adattata alla larghezza reale del pannello: eliminata la fascia vuota causata dalle celle limitate a 48px. La misura tiene conto anche della barra di scorrimento e viene aggiornata al ridimensionamento.
- Palette rossa e bianca, superfici antracite più leggibili, bordi uniformi e selezione rossa.
- Intestazione sinistra e ricerca a tutta larghezza, senza testo tagliato.
- Deposito destro allineato agli slot rapidi e largo quanto il pannello.
- Rimosso il testo laterale compresso verticalmente; rimangono le aree native per gettare gli oggetti con icona e indicatore di hover.
- Migliorate etichette, contrasto del pulsante impostazioni e orientamento dell'immagine dell'oggetto quando è ruotato.

Il motore, le verifiche server, i salvataggi, le protezioni e la diagnostica della revisione 4 rimangono presenti. L'HTML carica il nuovo adapter `ox-grid-r5.js` e i fogli stile con revisione 5. Il comando di diagnostica mantiene l'etichetta motore r4 e riconosce `index=r5 (grafica)`.

## Aggiornamento dalla revisione 4 funzionante

Conserva una copia attuale e arresta la risorsa in una finestra di manutenzione. Dallo ZIP puoi aggiornare soltanto:

- la cartella `ox_inventory/web` completa;
- `ox_inventory/modules/grid/client.lua` (aggiornamento dell'indicazione diagnostica della versione grafica).

Mantieni `data/grid.lua` se hai personalizzato dimensioni o capacità. Non serve modificare il database o cancellare gli inventari/KVP. Riavvia ox_inventory e riconnettiti.

In alternativa il pacchetto contiene la risorsa completa; preserva le tue configurazioni locali prima di sostituirla.

## Verifiche

Controllo visivo a 1837×1054 come lo screenshot dell'utente. Controllati griglia a tutta larghezza, allineamento del deposito e ingombri dei pannelli a 1920×1080, 1837×1054, 1280×720 e 1024×768. Passati i controlli browser esistenti su inserimento del primo oggetto, rotazione, trascinamento nativo, trasferimenti, ricerca, menu, 12 riaperture e ripiego in caso di errore. Nessun errore JavaScript nei controlli ordinari. Mantenuti i test su slot sparsi, chiusura e diagnostica.
