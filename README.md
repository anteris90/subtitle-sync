# Felirat Szinkron

[English](README.en.md) | Magyar

Egyszerű, teljesen helyben futó Windows-os eszköz `.srt` feliratok időzítéséhez és MKV-ból történő feliratkinyeréshez. Nincs felhő vagy feltöltés: a helyi segédprogram csak a saját gépeden fut.

## Indítás

Kattints duplán az `Inditas.bat` fájlra. Megnyílik az alkalmazás az alapértelmezett böngészőben. Az ablakban futó helyi segédprogramot hagyd nyitva a használat idejére; bezárásával leáll az alkalmazás.

Az `index.html` közvetlen megnyitásával az SRT-időzítés működik, de az MKV-kinyeréshez az `Inditas.bat` szükséges.

## MKV feliratsáv kinyerése

Az MKV-kinyeréshez szükséges az ingyenes [MKVToolNix](https://mkvtoolnix.download/). Először kattints a **Set MKVToolNix location** gombra, és válaszd ki az `mkvmerge.exe` fájlt; az ugyanabban a mappában lévő `mkvextract.exe`-et is használja. A helyet a Windows helyi alkalmazásadatai között elmenti, és minden indításkor ellenőrzi. Ha a program átkerül vagy törlődik, figyelmeztetést kapsz, és új helyet választhatsz.

1. Kattints az **MKV kiválasztása** gombra.
2. Válaszd ki az MKV-fájlt, majd a feliratsáv mellett válaszd a **Load as reference**, **Load as target** vagy **Download SRT** műveletet. A letöltés nem tölti be és nem módosítja a szinkronizáláshoz kiválasztott feliratot.
3. Ezután ugyanúgy állítsd az időzítést és mentsd az új SRT-t.

Az eszköz SRT/UTF-8 szöveges feliratsávokkal működik. A képalapú (például PGS/VobSub) vagy ASS/SSA formátumú sávokat az MKVToolNix ki tudja nyerni, de azokat előbb külön SRT-vé kell alakítani.

## Automatikus, hangalapú szinkronizálás

Az **Automatic sync to video** funkció az `ffsubsync` helyi motorját használja. A motor a beszéd és csend időmintázata alapján illeszti a feliratot a videóhoz; nem küldi el a videót vagy a feliratot.

Legegyszerűbben kattints az alkalmazásban az **Install sync engine automatically** gombra. Ez a Windows Package Manager segítségével szükség esetén telepíti a Python 3.11-et, utána letölti a helyi `ffsubsync` motort és az FFmpeg hangfeldolgozó motort. Internet csak ehhez az egyszeri telepítéshez kell.

Kézi előkészítésként telepíts Python 3-at, majd futtasd a következőt egy parancssorban:

```text
py -m pip install ffsubsync
```

Ezután az alkalmazásban válaszd a **Set ffsubsync location** gombot, és jelöld ki a telepítés `Scripts` mappájában lévő `ffsubsync.exe` fájlt. Az alkalmazás ezt az útvonalat is megjegyzi és indításkor ellenőrzi.

Az automatikus szinkron előtt válaszd ki az MKV-fájlt, majd töltsd be vagy nyerd ki a javítandó SRT-t. Az eredmény előnézetben jelenik meg; export előtt mindig ellenőrizd a videó elejét, közepét és végét.

## Használat

1. Töltsd be a referencia SRT-t (például az angolt) a külön **Reference subtitle** mezőben – ez nem helyettesíti a javítandó fájlt.
2. Töltsd be a javítandó SRT-t (például a magyart).
3. Első használatkor kattints az **Install local text model** gombra. A Python-könyvtárak és a kb. 471 MB-os modell egyszer töltődnek le; ezután a szinkron teljesen helyben fut.
4. Kattints az **AI re-sync to reference** gombra. A többnyelvű modell a sorok jelentését párosítja akkor is, ha a referencia és a cél más nyelvű vagy eltérően tagolt. A célfeliratot frissíti, a referenciát nem módosítja.
5. Ha a modell kevés biztos szövegegyezést talál, próbáld a **Speech-pattern fallback** gombot.
6. Ellenőrizd az előnézetet, majd kattints a **Javított SRT mentése** gombra.
7. Kézi korrekcióhoz használd a globális eltolást vagy a két horgonyos drift-javítást.

Az idő megadható `00:05:12,500` alakban vagy másodpercben (például `312.5`).

## Fontos

Az eltérő videókiadásokban lehet más az intró, reklámszünet vagy jelenetvágás. Ilyenkor a globális és a lineáris javítás nem biztos, hogy mindenhol pontos: ellenőrizd az elejét, a közepét és a végét, és szükség esetén dolgozz külön szakaszokban.
