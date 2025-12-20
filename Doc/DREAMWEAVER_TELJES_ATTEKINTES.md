# DreamWeaver Alkalmazás - Teljes Áttekintés

## 🎯 Alapkoncepció

**DreamWeaver** — *"See What Your Mind Creates"*

Egy integrált iOS + watchOS alkalmazáscsalád, amely az alvás közbeni biosignálokat művészi vizualizációvá alakítja AI segítségével.

---

## 📱 Két Platform, Egy Élmény

### ⌚ Apple Watch Szerepe
**Adatgyűjtő és monitorozó eszköz**

#### Funkciók:
- 🫀 **Valós idejű pulzusmérés** (HealthKit integrációval)
- 💓 **HRV (Heart Rate Variability) számítás** - az érzelmi intenzitás mérésére
- 🏃 **Mozgásérzékelés** - CoreMotion accelerométer használatával
- ⏱️ **Alváskövetés indítása/leállítása** közvetlenül az órán
- 📡 **Automatikus szinkronizálás** iPhone-ra 5 percenként
- 🔋 **Háttérben működő workout session** a folyamatos méréshez
- 🌙 **Bedside Mode** - minimalista éjszakai kijelző

#### Adatok amit gyűjt:
- Pulzus (BPM) folyamatosan
- HRV értékek
- Mozgási adatok (testi aktivitás mértéke)
- REM és mély alvás fázisok (becsült)

---

### 📱 iPhone Szerepe
**Fő felhasználói felület, adatelemzés és vizualizáció**

#### Főbb funkciók:

**1. Álomkövetés Indítása**
- "Start Dream Mode" gomb
- Apple Watch automatikus aktiválása
- Valós idejű biosignál megjelenítés
- Időzítő (órák:percek:másodpercek)
- Kapcsolati státusz kijelzés (⌚ Watch Connected)

**2. Adatfogadás és Tárolás**
- WatchConnectivity protokoll használata
- Biosignál idősor mentése (BiosignalDataPoint modellek)
- SwiftData adatbázis helyi tároláshoz
- Teljes adatvédelem - minden helyben marad

**3. AI Álomértelmezés** ✨
- **Automatikus feldolgozás** az alvás végeztével
- **3 AI opció:**
  - **OpenAI GPT-4o-mini** - kreatív narratívák
  - **Anthropic Claude 3.5 Sonnet** - alternatív stílus
  - **Helyi algoritmus (alapértelmezett)** - internet nélkül, teljesen privát

- **AI által generált elemek:**
  - 🎨 Poétikus álom narratíva (2-3 mondat)
  - 🏷️ Témák felismerése (pl. "cosmos", "transformation", "chaos")
  - 🔮 Szimbolizmus (emojik: ⭐ csillagok, 🌊 víz, 🔥 tűz stb.)
  - 📊 Intenzitás skála (0-1, álom élénkségének mértéke)
  - 🧘 Tudatosság szint (0-1, lucid dreaming detektálás)
  - 🎬 Vizuális prompt a rendereléshez

**4. Álom Vizualizáció** 🌈
- **10-30 másodperces AI-generált animáció**
- **Dinamikus részecske rendszer** (60 részecske)
- **Hangulat-alapú színátmenetek:**
  - Ethereal (éteri) - halvány kékek/lilák
  - Turbulent (viharos) - vörösek/narancsok
  - Intense (intenzív) - élénk színek
  - Peaceful (békés) - pasztell színek
  - Calm (nyugodt) - hideg tónusok

- **Szimbolikus központi orb** - forog, emoji ikonokkal
- **Lebegő témacímkék** - horizontális scroll
- **Narratíva overlay** - 2 másodperc után felcsúszik
- **Tudatossági gyűrű** - lucid álmoknál megjelenik (>50%)

**5. Álom Dashboard** (főképernyő)
```
┌─────────────────────────────┐
│    DreamWeaver              │
│    🌙 ✨                     │
│ See What Your Mind Creates  │
│                             │
│  [Start Dream Mode]         │ ← Fő indító gomb
│   Track your sleep and      │
│   visualize your dreams     │
│                             │
│  Last Dream    3 days, 7hrs │
│  ┌─────────────────────┐   │
│  │     Peaceful         │   │ ← Színes kártya
│  │  ⏱️ 0h 0m  🧠 23% REM │   │
│  │        ▶️            │   │ ← Lejátszás
│  └─────────────────────┘   │
│                             │
│  Dream History              │
│  ┌───────────────────────┐ │
│  │ Peaceful               │ │
│  │ ⏱️ 0h 0m • 9 Nov 2025  │ │
│  └───────────────────────┘ │
└─────────────────────────────┘
```

**6. Részletes Álom Nézet**
- Teljes biosignál grafikonok
- **Pulzus idősor** (line chart + area fill)
- **HRV trend** (külön diagram)
- Statisztikák (átlag/min/max)
- AI értelmezés teljes szövege
- Témacímkék (kattintható pilulák)
- Intenzitás és tudatosság progress bar-ok
- "Play Dream Visualization" gomb

**7. Álom Napló**
- Lista nézet minden álomról
- Miniatűr előnézetek
- Kereshető témák és érzések szerint
- AI insights: *"Ismétlődő nyugodt álmaid vannak szerdánként edzés után"*

---

## 🧠 Technológiai Stack

| Réteg | Technológia |
|-------|-------------|
| **Biosignálok** | HealthKit, CoreMotion, Apple Watch szenzrok |
| **Adatgyűjtés** | WatchConnectivity (Bluetooth), WorkoutSession |
| **Adattárolás** | SwiftData (@Model), helyi adatbázis |
| **AI Értelmezés** | OpenAI API / Anthropic API / Helyi ML |
| **Vizualizáció** | SwiftUI Charts, Metal, SceneKit |
| **Részecske rendszer** | Custom particle engine 60 objektummal |
| **Hangulatelemzés** | HRV + mozgás + REM/Deep sleep arány algoritmus |

---

## 🔄 Munkafolyamat (User Flow)

### 1️⃣ **Lefekvés Előtt**
```
Felhasználó → Megnyitja az appot iPhone-on
           → "Start Dream Mode" gomb megnyomása
           → Apple Watch automatikusan elindul
           → iPhone az éjjeliszekrényen marad
           → Watch a csukló közelében folyamatosan mér
```

### 2️⃣ **Alvás Közben**
```
Apple Watch → Pulzus mérés (folyamatos)
           → HRV számítás
           → Mozgás detektálás (accelerometer)
           → Adatok 5 percenként iPhone-ra
           
iPhone     → Adatok fogadása WatchConnectivity-vel
           → BiosignalDataPoint tárolás SwiftData-ban
           → Környezeti zaj elemzés (opcionális, Core Audio ML)
           → Háttérben fut, képernyő kikapcsolva
```

### 3️⃣ **Reggel (Felébredés)**
```
Felhasználó → "Stop Tracking" gomb (iPhone vagy Watch)
           → AI feldolgozás automatikusan indul
           → Loading indicator jelenik meg
           
AI Engine  → Biosignálok elemzése
           → Hangulat klasszifikáció (Peaceful/Chaotic/Intense/Calm)
           → Narratíva generálás (2-3 mondat)
           → Témák és szimbólumok azonosítása
           → Vizuális prompt készítés
           
App        → Álom kártya hozzáadása a történethez
           → Push notification: "Your dream is ready! 🌙"
```

### 4️⃣ **Álom Megtekintése**
```
Felhasználó → Álom kártyára kattintás
           → Részletes nézet megnyitása
           → Pulzus/HRV grafikonok böngészése
           → AI narratíva olvasása
           → "Play Dream Visualization" gomb
           
Vizualizáció → 10-30 mp animáció
            → Részecskék mozgása (AI intenzitás szerint)
            → Színátmenetek (hangulat szerint)
            → Szimbolikus orb emoji ikonokkal
            → Narratíva szöveg overlay
            → Opció: újragenerálás, mentés, megosztás
```

---

## 🎨 Design Elemek

### iPhone App Ikonjai
- 🌙 Hold + ✨ Csillagok
- 🫀 Szív (pulzusmérés)
- 📊 Grafikonok
- 🎨 Festő ecsetek (álom mint művészet)
- 🔮 Kristálygömb (szimbolikus)

### Apple Watch App UI
```
┌─────────────────┐
│  🌙 DreamWeaver │
│   Tracking...   │
│                 │
│   ❤️ 62 BPM     │ ← Valós idejű pulzus
│   💓 45 ms      │ ← HRV
│                 │
│   03:25:14      │ ← Időzítő
│                 │
│ 📡 Syncing to   │
│    iPhone       │
│                 │
│    [Stop]       │
└─────────────────┘
```

### Színpaletta
- **Háttér:** Sötét gradiens (lila → fekete)
- **Peaceful álmok:** Kék, türkiz, ezüst
- **Chaotic álmok:** Vörös, narancs, sárga
- **Intense álmok:** Élénk magenta, kék, zöld
- **Calm álmok:** Pasztell rózsaszín, halványkék

---

## 🔐 Adatvédelem & Biztonság

### Alapelvek:
- ✅ **Minden adat lokálisan tárolva** (iPhone SwiftData)
- ✅ **Nincs felhő szinkronizálás** alapértelmezetten
- ✅ **HealthKit engedélykérés** átlátható
- ✅ **AI API-k opcionálisak** - helyi mód mindig működik
- ✅ **Titkosítás** nyugalmi állapotban (iOS encryption)
- ✅ **Törölhető adatok** - felhasználó ellenőrzése alatt

### Mit KÜLD az AI-nak (ha engedélyezett):
- Alvás időtartama
- Átlagos pulzus & HRV
- Mozgás százalék
- REM & mély alvás százalék
- Zajszint
- Hangulat klasszifikáció

### Mit NEM küld:
- Név, személyes azonosítók
- Helyadatok
- Fotók, képek
- Korábbi álomtörténet
- Egyéb app adatok

---

## 🚀 Fejlesztési Prioritások

### ✅ Már Kész (Fázis 1-2)
- iPhone alapalkalmazás
- SwiftData modellek
- Álom dashboard UI
- Részecske animációs motor
- AI integráció (OpenAI/Anthropic/Helyi)
- WatchConnectivity alap

### 🚧 Folyamatban (Fázis 3-4)
- Apple Watch app finomítása
- HealthKit teljes implementáció
- Valós biosignál gyűjtés
- Háttér workout session
- Grafikonok optimalizálása

### 🔮 Jövőbeli Funkciók (Fázis 5-6)
- **Bedside Mode** (Watch minimalista UI)
- **Okos ébresztő** - könnyű alvási fázisban
- **Hangszimfónia** - biorhythm alapú zenei generálás
- **Álom Galéria** - közösségi réteg (opcionális)
- **Trend analízis** - hónapok/évek adatai
- **Export PDF** - álomnapló nyomtathatóan
- **Videó megosztás** - vizualizációk TikTok/Instagram-ra
- **Hangos narráció** - AI felolvassa az álmot

---

## 💡 Kulcs Innovációk

1. **Biosignálok → Művészet transzformáció**
   - Nem csak grafikonok, hanem élő, mozgó vizualizáció

2. **Személyre szabott AI**
   - Hosszú távon tanulja a felhasználó álommintáit

3. **Két eszköz, egy élmény**
   - Watch = érzékelő, iPhone = értelmező + megjelenítő

4. **Teljes adatvédelem**
   - Helyi AI mód = zero cloud dependency

5. **Tudományos alapok**
   - HRV ↔ Érzelmi állapot korreláció
   - REM fázis ↔ Élénk álmok összefüggése
   - Mozgás ↔ Narratív változékonyság

---

## 📊 Technikai Kihívások & Megoldások

| Kihívás | Megoldás |
|---------|----------|
| Watch szimulátor nem támogatja HealthKit-et | Fizikai eszköz tesztelés szükséges |
| Akkumulátor fogyás éjszaka | 5 perces mintavétel, optimalizált workout session |
| AI API költség | Helyi fallback mindig elérhető |
| Részecske renderelés teljesítmény | Metal gyorsítás, max 60 particle limit |
| WatchConnectivity megszakadás | Context update háttérben, újraküldési logika |

---

## 🎯 Sikermetrikák

- ✅ Pontosság: ±5 BPM pulzusmérés
- ✅ Akkumulátor: <15% fogyás éjszaka
- ✅ Szinkronizáció: 95%+ megbízhatóság
- ✅ Felhasználói elégedettség: >4.5⭐
- ✅ Stabilitás: 0 crash éjszakai követésnél

---

## 📂 Projekt Struktúra

```
DreamWeaver/
├── DreamWeaver (iPhone App)/
│   ├── Models/
│   │   ├── SleepData.swift
│   │   ├── BiosignalDataPoint.swift
│   │   └── DreamMood.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── DreamDashboardView.swift
│   │   ├── SleepTrackingView.swift
│   │   ├── DreamDetailView.swift
│   │   ├── DreamVisualizationView.swift
│   │   └── HeartRateChartView.swift
│   ├── Services/
│   │   ├── WatchConnectivityManager.swift
│   │   ├── AIDreamService.swift
│   │   ├── HealthKitManager.swift
│   │   └── ParticleEngine.swift
│   └── Resources/
│       └── Assets.xcassets
│
└── DreamWeaverWatch (watchOS App)/
    ├── Views/
    │   ├── ContentView.swift
    │   └── SleepTrackingView.swift
    ├── Managers/
    │   ├── WorkoutManager.swift
    │   └── WatchConnectivityManager.swift
    └── Resources/
        └── Assets.xcassets
```

---

**Ez a DreamWeaver - ahol az álmok művészetté válnak! 🌙✨**
