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
