// Public appearance only. Native ox_inventory controls all items and transactions.
window.VOID_INVENTORY = {
  brand: 'VOID SURVIVAL',
  logo: 'assets/void-logo.png',
  accent: '#db2835',
  columns: 3,
  quickSlots: 10,
  // Visual sections of the SAME player inventory: not additional capacities.
  // Align section starts to a row (1, 4, 7, 10, ... with 3 columns).
  sections: [
    { label: 'DOTAZIONE', start: 1 },
    { label: 'TASCHE', start: 10 },
    { label: 'CARICO', start: 13 }
  ],
  labels: {
    vicinity: 'VICINANZE', inventory: 'DOTAZIONE PERSONALE',
    quantity: 'QUANTITÀ', health: 'SALUTE', armor: 'ARMATURA', weight: 'PESO',
    containers: 'CONTENITORI', closeHint: 'ESC · CHIUDI',
    preview: 'Anteprima personaggio disponibile in gioco'
  }
};
