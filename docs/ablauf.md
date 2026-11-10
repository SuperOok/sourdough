# Ablauf eines Brotback-Durchgangs

Das Diagramm entsteht aus der Ablaufdefinition im Package (`BakeProcess.mermaid()`): jeder Schritt mit dem Titel seines Textes, jede Antwort einer Entscheidung und jede Variante der Utensilien. Rauten sind Entscheidungen, Rechtecke Schritte. `BakeProcessTests` prüft, dass diese Datei zur Definition passt; nach einer Änderung am Ablauf wird der Block hier neu erzeugt.

```mermaid
flowchart TD
    bakePanLid["Backen mit Deckel"]
    bakePanOpen["Backen ohne Deckel, mit Dampf"]
    bakePot["Backen im Bräter"]
    bakePotOpen["Backen im offenen Bräter"]
    bakeTray["Backen auf dem Blech"]
    checkProofRim{"Wie hoch ist der Teig?"}
    checkProofRipe{"Ist die Gare reif?"}
    checkSourdough{"Ist der Sauerteig reif?"}
    checkStarter{"Ist dein Starter aktiv?"}
    cool["Auskühlen lassen"]
    kneadFold["Hauptteig kneten"]
    kneadRye["Hauptteig mischen"]
    mixSourdough["Sauerteigstufe ansetzen"]
    preheatPan["Ofen vorheizen"]
    preheatPot["Ofen und Bräter vorheizen"]
    preheatPotOpen["Ofen und offenen Bräter vorheizen"]
    preheatTray["Ofen vorheizen"]
    shapeBasketLong["Teig lang formen"]
    shapeBasketRound["Teig rund formen"]
    shapeBowl["Teig formen"]
    shapePan["Teig in die Form geben"]
    waitProof["Noch etwas gehen lassen"]
    waitSourdough["Noch etwas Zeit geben"]
    waitStarter["Erst auffrischen"]
    checkStarter -->|notYet| waitStarter
    waitStarter --> checkStarter
    checkStarter -->|yes| mixSourdough
    mixSourdough --> checkSourdough
    checkSourdough -->|notYet| waitSourdough
    waitSourdough --> checkSourdough
    checkSourdough -->|yes| kneadFold
    kneadFold --> shapePan
    shapePan --> checkProofRim
    checkProofRim -->|belowRim| preheatPan
    preheatPan -->|belowRim| bakePanLid
    bakePanLid --> cool
    checkProofRim -->|overRim| preheatPan
    preheatPan -->|overRim| bakePanOpen
    bakePanOpen --> cool
    checkSourdough -->|yes| kneadRye
    kneadRye --> shapePan
    shapePan --> checkProofRipe
    checkProofRipe -->|notYet| waitProof
    waitProof --> checkProofRipe
    checkProofRipe -->|yes| preheatPan
    preheatPan --> bakePanOpen
    kneadFold --> shapeBasketRound
    shapeBasketRound --> checkProofRipe
    checkProofRipe -->|yes| preheatPot
    preheatPot --> bakePot
    bakePot --> cool
    kneadRye --> shapeBasketRound
    checkProofRipe -->|yes| preheatPotOpen
    preheatPotOpen --> bakePotOpen
    bakePotOpen --> cool
    kneadFold --> shapeBasketLong
    shapeBasketLong --> checkProofRipe
    kneadRye --> shapeBasketLong
    kneadFold --> shapeBowl
    shapeBowl --> checkProofRipe
    checkProofRipe -->|yes| preheatTray
    preheatTray --> bakeTray
    bakeTray --> cool
    kneadRye --> shapeBowl
```
