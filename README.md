# Subtitle Sync

[English](#english) | [Magyar](#magyar)

<a id="english"></a>
## English

Subtitle Sync is a local Windows app for aligning SRT subtitles, extracting text subtitle tracks from MKV files, and previewing/exporting corrected subtitles. Video and subtitle content stay on your computer; the app does not upload them.

## Requirements and startup

- Windows, PowerShell, and the files in this repository.
- Double-click `Inditas.bat`. Keep the PowerShell window open while using the app; it runs the local service at `http://127.0.0.1:8765/`.
- Opening `index.html` directly supports loading, previewing, manual timing adjustments, and export. MKV extraction and synchronization engines require `Inditas.bat`.

The app remembers local tool paths in `%LOCALAPPDATA%\SubtitleSync\settings.json` and checks configured tools when it starts.

## Subtitle inputs

- **Subtitle to correct** is the target SRT whose timings will be changed and exported.
- **Reference subtitle** is a separate, correctly timed SRT. Loading or syncing a target never replaces the reference.
- Reference and target cue numbers are independent. Recaps, alternate edits, and different line breaks can make cue 1 correspond to a later cue in the other file.
- The preview displays the first 100 cues in each column; the summary and exported file cover all cues.

## Extract and download from MKV

MKV operations require the free [MKVToolNix](https://mkvtoolnix.download/). Use **Install MKVToolNix automatically**, or choose `mkvmerge.exe` with **Set MKVToolNix location**; `mkvextract.exe` must be in the same folder. The selected location is saved locally.

1. Click **Choose MKV** and select a video.
2. For each listed text subtitle track, choose **Load as reference**, **Load as target**, or **Download SRT**. Downloading saves an SRT without loading it into either subtitle field.
3. Review the selected track and continue with synchronization or export.

The app works with text-based SRT/SubRip tracks. Image-based PGS/VobSub and formats such as ASS/SSA may need conversion to SRT first.

## AI reference synchronization

1. Load the correctly timed reference SRT and the target SRT.
2. On first use, click **Install local text model**. The app installs `sentence-transformers` and downloads `paraphrase-multilingual-MiniLM-L12-v2` (about 471 MB). This requires internet once; alignment then runs locally on CPU.
3. Click **AI re-sync to reference**. The multilingual model compares sentence meaning across languages, aligns cue groups in sequence, and interpolates timings between confident matches. It can handle different cue segmentation; it does not require a literal translation match.
4. Review the result, then use **Save corrected SRT** to export it.

The app reports how many text groups it matched and their average similarity. If it cannot find enough confident matches, it reports an error; use **Speech-pattern fallback** instead. Subtitle text is not sent to a remote service. A successful automatic sync clears any previous manual offset and drift anchors so those corrections are not applied twice.

## Local AI subtitle translation

**Local AI subtitle translation** translates the loaded target SRT; it is separate from AI reference synchronization. Choose a source language or leave it on auto-detect, then select a target language. English and Hungarian are available along with Spanish, German, and French.

1. Choose **Qwen3 8B** for the recommended quality or **Qwen3 4B** for a smaller model.
2. Click **Set up local translator**. The app reuses an Ollama service that is already running. If Ollama is installed but stopped, the app starts it. If it is not installed, the app downloads the official portable Windows runtime into `%LOCALAPPDATA%\SubtitleSync\ollama`, verifies its SHA-256 checksum, and starts it. The selected model is downloaded automatically as part of setup.
3. Review or edit the show glossary, then click **Translate target subtitle**. Translation runs in 12-cue batches with up to three neighboring cues on either side for context.
4. Review the translated preview and click **Save corrected SRT** to export.

The translator preserves cue numbering and timestamps, protects speaker labels and SRT formatting tags, and validates the structured response before accepting each batch. If any batch is incomplete or changes protected content, the app reports an error instead of loading a partial result. Original files are never overwritten. Translation prompts and results are sent only to the local Ollama API; the model itself is downloaded from the official Ollama distribution on first setup.

The first setup can download about 1.5 GB for the portable Ollama runtime and about 5.2 GB for Qwen3 8B; Qwen3 4B is smaller. **Download selected model** and **Remove selected model** let you manage models from the app. If an existing Ollama service is reused, these actions use its shared model library; deleting a model there also removes it for other apps that use that Ollama service. The app-managed portable runtime keeps its models in the Subtitle Sync app-data folder.

## Local AI subtitle translation

The **Local AI subtitle translation** panel translates the loaded target SRT while keeping its original cue IDs and timestamps. Source language can be auto-detected or selected as English, Hungarian, Spanish, German, or French; choose the target language separately.

1. Choose **Qwen3 8B** (recommended) or the smaller **Qwen3 4B**.
2. Click **Set up local translator**. The app reuses a running local Ollama service if available. Otherwise it downloads the official portable Windows runtime into `%LOCALAPPDATA%\SubtitleSync\ollama`, verifies its SHA-256 checksum, and starts it locally. The selected model is then downloaded by the app.
3. Edit the show glossary/context if needed, then click **Translate target subtitle**.
4. Review the translated preview and export with **Save corrected SRT**.

The translator sends 12 cues per request with up to three neighboring cues on each side as context. Glossary entries, speaker labels, cue IDs, and formatting tags are protected or validated. If a batch fails or the model changes cue IDs/tags, the app reports an error instead of loading a partial translation. Original SRT files are not overwritten.

First-time setup can require about 1.5 GB for the portable Ollama runtime and about 5.2 GB for Qwen3 8B; the smaller 4B model uses less space. Both setup and download can be started in the app. If an existing Ollama installation is reused, its models are in that Ollama installation's shared model store, so removing a model from the app removes it from that active store. With the app-managed runtime, models are kept under the Subtitle Sync app-data folder. Subtitle content stays local in either case.

## Speech-pattern fallback

**Speech-pattern fallback** uses local `ffsubsync` to align the target's speech/silence timing pattern to the reference SRT. This is useful when semantic text matching finds too few reliable pairs. It does not use the selected MKV video, but it requires the local sync engine (`ffsubsync` and FFmpeg).

To install the engine, switch to **Video audio auto-sync** and click **Install sync engine automatically**. The app installs Python if needed, then `ffsubsync` and FFmpeg. You can instead choose an existing `ffsubsync.exe` with **Set ffsubsync location**; FFmpeg must also be configured.

## Video-audio auto-sync

**Video audio auto-sync** aligns the target subtitle to speech and silence in the selected MKV using local `ffsubsync` and FFmpeg.

1. Select the MKV.
2. Load or extract the target SRT.
3. Click **Auto sync loaded subtitle** and review the output.

The progress indicator is indeterminate because the sync engine does not provide percentage progress. Video and subtitle data remain local.

## Manual timing controls

- **Global offset** shifts every target cue by the entered milliseconds. Positive values move it later; negative values move it earlier. **Set offset from first cue** is only suitable when the first reference and target cues describe the same moment.
- **Gradual timing correction** uses two matching scenes as anchors to correct linear timing drift. Enter target times and their corresponding reference times. The correction continues at the same rate outside the anchors.
- Click **Refresh preview** after changing a global offset. Successful automatic sync resets manual timing values.

Times accept `HH:MM:SS,mmm` or seconds, for example `312.5`. Before exporting, review the start, middle, and end; different video releases can have recaps, edits, or scene changes that no single alignment can fully correct.

## Troubleshooting

- If MKV or sync controls are unavailable, start the app with `Inditas.bat`; direct `index.html` mode does not provide the local API.
- If a tool was moved, use its **Set ... location** button to configure it again.
- After updating the local server code, stop the old PowerShell process with `Ctrl+C` and relaunch `Inditas.bat`.
- If AI sync reports too few confident matches, verify that both SRTs cover the same episode and use **Speech-pattern fallback**.

<a id="magyar"></a>
## Magyar

A Subtitle Sync egy helyben futó Windows-alkalmazás SRT-feliratok időzítéséhez, szöveges MKV-feliratsávok kinyeréséhez és a javított felirat előnézetéhez/mentéséhez. A videó és a felirat a számítógépeden marad; az alkalmazás nem tölti fel őket.

## Követelmények és indítás

- Windows, PowerShell és a repó fájljai szükségesek.
- Kattints duplán az `Inditas.bat` fájlra. Használat közben hagyd nyitva a PowerShell-ablakot; a helyi szolgáltatás a `http://127.0.0.1:8765/` címen fut.
- Az `index.html` közvetlen megnyitásával felirat tölthető be, előnézhető, kézzel állítható és exportálható. Az MKV-kinyeréshez és a szinkronmotorokhoz az `Inditas.bat` szükséges.

Az alkalmazás a helyi eszközútvonalakat a `%LOCALAPPDATA%\SubtitleSync\settings.json` fájlban jegyzi meg, és indításkor ellenőrzi őket.

## Feliratok betöltése

- A **Subtitle to correct** a célfelirat: ennek az időzítése változik és ez exportálható.
- A **Reference subtitle** külön betöltött, helyesen időzített referencia. A célfelirat betöltése vagy szinkronizálása nem cseréli le.
- A referencia és a cél sorszámai egymástól függetlenek. Összefoglaló, eltérő videóvágás vagy sortörés miatt az egyik felirat 1. sora a másikban későbbi cue-nak felelhet meg.
- Az előnézet oszloponként az első 100 sort mutatja; az összes cue benne marad az összegzésben és az exportban.

## MKV-felirat kinyerése és letöltése

Az MKV-műveletekhez az ingyenes [MKVToolNix](https://mkvtoolnix.download/) szükséges. Használd az **Install MKVToolNix automatically** gombot, vagy a **Set MKVToolNix location** gombbal válaszd ki az `mkvmerge.exe` fájlt; a mellette lévő `mkvextract.exe`-et is használja. Az útvonalat helyben elmenti.

1. Kattints a **Choose MKV** gombra és válassz videót.
2. A felsorolt szöveges feliratsávnál válaszd a **Load as reference**, **Load as target** vagy **Download SRT** műveletet. A letöltés SRT-t ment, de nem tölti be egyik mezőbe sem.
3. Ellenőrizd a kiválasztott sávot, majd folytasd a szinkronnal vagy exporttal.

Az alkalmazás szöveges SRT/SubRip sávokkal működik. A képalapú PGS/VobSub és az ASS/SSA formátumokat előbb SRT-vé kellhet alakítani.

## AI-szinkron referencia alapján

1. Töltsd be a helyesen időzített referencia SRT-t és a javítandó célfeliratot.
2. Első használatkor kattints az **Install local text model** gombra. Az alkalmazás telepíti a `sentence-transformers` csomagot, és letölti a `paraphrase-multilingual-MiniLM-L12-v2` modellt (kb. 471 MB). Ehhez egyszer internet kell; utána az illesztés helyben, CPU-n fut.
3. Kattints az **AI re-sync to reference** gombra. A többnyelvű modell a mondatok jelentését hasonlítja össze, sorrendben illeszti a cue-csoportokat, majd a biztos egyezések között számolja ki az időzítést. Eltérő nyelv és sortagolás mellett is működhet; nem igényel szó szerinti egyezést.
4. Ellenőrizd az eredményt, majd a **Save corrected SRT** gombbal exportáld.

Az alkalmazás jelzi az egyező szövegcsoportok számát és átlagos hasonlóságát. Ha nincs elég biztos egyezés, hibát jelez; ilyenkor használd a **Speech-pattern fallback** módot. A feliratszöveg nem kerül távoli szolgáltatáshoz. Sikeres automatikus szinkron törli a korábbi kézi offsetet és drift-horgonyokat, hogy ne alkalmazza őket kétszer.

## Helyi AI-feliratfordítás

A **Local AI subtitle translation** a betöltött célfeliratot fordítja; ez külön funkció az AI referencia-alapú időzítés-szinkrontól. Válassz forrásnyelvet, vagy hagyd automatikus felismerésen, majd válaszd ki a célnyelvet. Angol, magyar, spanyol, német és francia érhető el.

1. Válaszd a jobb minőségre ajánlott **Qwen3 8B** modellt, vagy a kisebb **Qwen3 4B** modellt.
2. Kattints a **Set up local translator** gombra. Az alkalmazás újrahasználja a már futó Ollamát; ha telepítve van, de nem fut, elindítja. Ha nincs telepítve, letölti a hivatalos hordozható Windows-futtatót a `%LOCALAPPDATA%\SubtitleSync\ollama` mappába, SHA-256-tal ellenőrzi, elindítja, majd letölti a kiválasztott modellt.
3. Ellenőrizd vagy szerkeszd a sorozat szójegyzékét, majd kattints a **Translate target subtitle** gombra. A fordítás 12 cue-s batch-ekben fut, mindkét oldalon legfeljebb három szomszédos cue kontextusával.
4. Ellenőrizd az előnézetet, majd exportáld a **Save corrected SRT** gombbal.

A fordító megőrzi a cue-számozást és időbélyegeket, védi a beszélőcímkéket és az SRT-formázó tageket, és minden batch strukturált válaszát ellenőrzi. Hiányos batch vagy módosított védett tartalom esetén hibát jelez, és nem tölt be részleges fordítást. Az eredeti fájlt nem írja felül. A promptok és a válaszok csak a helyi Ollama API-hoz kerülnek; maga a modell az első beállításkor az Ollama hivatalos terjesztéséből töltődik le.

Az első beállítás kb. 1,5 GB hordozható Ollama-futtatót és kb. 5,2 GB Qwen3 8B modellt tölthet le; a Qwen3 4B kisebb. A **Download selected model** és **Remove selected model** gombokkal az appból kezelhetők a modellek. Már futó Ollama használatakor ezek annak közös modellkönyvtárára hatnak; törléskor az adott modell más Ollama-alkalmazások számára is eltűnik. Az app által kezelt hordozható futtató a saját modelljeit a Subtitle Sync alkalmazásadat-mappájában tartja.

## Helyi AI-feliratfordítás

A **Local AI subtitle translation** panel a betöltött célfeliratot fordítja le, az eredeti cue-azonosítók és időbélyegek megtartásával. A forrásnyelv automatikusan felismerhető, vagy megadható angol, magyar, spanyol, német és francia nyelv; a célnyelvet külön választhatod.

1. Válaszd a **Qwen3 8B** modellt (ajánlott), vagy a kisebb **Qwen3 4B** modellt.
2. Kattints a **Set up local translator** gombra. Az alkalmazás újrahasználja a már futó helyi Ollamát, ha van. Ha nincs, letölti a hivatalos hordozható Windows-futtatót a `%LOCALAPPDATA%\SubtitleSync\ollama` könyvtárba, ellenőrzi az SHA-256 ellenőrzőösszegét, majd helyben elindítja. Ezután az alkalmazás letölti a kiválasztott modellt.
3. Szükség esetén szerkeszd a sorozat szójegyzékét és kontextusát, majd kattints a **Translate target subtitle** gombra.
4. Ellenőrizd a fordított előnézetet, majd mentsd a **Save corrected SRT** gombbal.

A fordító kérésenként 12 cue-t küld, oldalanként legfeljebb három szomszédos sort adva kontextusként. A szójegyzék, a beszélőcímkék, a cue-azonosítók és a formázó tagek védettek vagy ellenőrzöttek. Ha egy batch hibázik, vagy a modell megváltoztatja az azonosítókat/tageket, az alkalmazás hibát jelez, és nem tölt be részleges fordítást. Az eredeti SRT-fájlt nem írja felül.

Az első beállítás kb. 1,5 GB futtatókörnyezetet és kb. 5,2 GB Qwen3 8B modellt igényelhet; a kisebb 4B modell kevesebb helyet foglal. A futtatókörnyezet és a modell is az alkalmazáson belül tölthető le. Meglévő Ollama használatakor a modellek annak közös modellkönyvtárába kerülnek, így az alkalmazásból törölt modell abból az aktív Ollama-könyvtárból is törlődik. Az app-managed futtató saját modelleket tart a Subtitle Sync alkalmazásadat-mappájában. A felirat tartalma egyik esetben sem kerül felhőbe.

## Beszédmintás tartalék mód

A **Speech-pattern fallback** a helyi `ffsubsync` motorral a célfelirat beszéd/csend időmintáját igazítja a referencia SRT-hez. Akkor hasznos, ha a szövegegyezésből kevés biztos pár található. A kiválasztott MKV-videót nem használja, viszont szükséges hozzá a helyi szinkronmotor (`ffsubsync` és FFmpeg).

A motor telepítéséhez válts a **Video audio auto-sync** módra, és kattints az **Install sync engine automatically** gombra. Az alkalmazás szükség esetén Pythont telepít, majd telepíti az `ffsubsync`-et és az FFmpeg-et. Meglévő `ffsubsync.exe` is kiválasztható a **Set ffsubsync location** gombbal; az FFmpeg-et is be kell állítani.

## Automatikus szinkron videóhanghoz

A **Video audio auto-sync** a kiválasztott MKV beszéd/csend mintájához igazítja a célfeliratot a helyi `ffsubsync` és FFmpeg segítségével.

1. Válaszd ki az MKV-t.
2. Töltsd be vagy nyerd ki a javítandó célfeliratot.
3. Kattints az **Auto sync loaded subtitle** gombra, majd ellenőrizd az eredményt.

A folyamatjelző határozatlan, mert a szinkronmotor nem közöl százalékos készültséget. A videó és a felirat helyben marad.

## Kézi időzítés

- A **Global offset** minden célcue-t eltol a megadott ezredmásodperccel. A pozitív érték későbbre, a negatív korábbra mozgatja. A **Set offset from first cue** csak akkor megfelelő, ha a referencia és a cél első sora ugyanahhoz a pillanathoz tartozik.
- A **Gradual timing correction** két azonos jelenet horgonyidejével javítja a lineáris driftet. Add meg mindkét célidőt és a hozzájuk tartozó referenciaidőt. A korrekció a horgonyokon kívül is azonos ütemben folytatódik.
- A globális offset módosítása után kattints a **Refresh preview** gombra. A sikeres automatikus szinkron visszaállítja a kézi időzítési értékeket.

Az idő `HH:MM:SS,mmm` formában vagy másodpercben adható meg, például `312.5`. Export előtt ellenőrizd az elejét, közepét és végét; az eltérő videókiadásokban lehet összefoglaló, vágás vagy jeleneteltérés, amit egyetlen illesztés nem feltétlenül javít ki teljesen.

## Hibaelhárítás

- Ha az MKV- vagy szinkronvezérlők nem működnek, indítsd az alkalmazást az `Inditas.bat` fájllal; a közvetlen `index.html` nem biztosít helyi API-t.
- Ha egy eszköz átkerült, állítsd be újra a hozzá tartozó **Set ... location** gombbal.
- A helyi szerverkód frissítése után állítsd le a régi PowerShell-folyamatot `Ctrl+C`-vel, majd indítsd újra az `Inditas.bat`-ot.
- Ha az AI-szinkron kevés biztos egyezést talál, ellenőrizd, hogy mindkét SRT ugyanahhoz az epizódhoz tartozik-e, majd próbáld a **Speech-pattern fallback** módot.
