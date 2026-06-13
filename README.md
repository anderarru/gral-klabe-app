# KLAbE: Musikarien praktika instrumentala kudeatzeko eta optimizatzeko aplikazioa

Musikarien eguneroko entseguak planifikatu, monitorizatu eta optimizatzeko plataforma anitzeko aplikazioa. Tresna tekniko guztiak leku bakarrean zentralizatzen ditu, Adimen Artifizial sortzailearen laguntzarekin.

📥 **[Deskargatu APK fitxategia hemen (Android)](https://github.com/anderarru/gral-klabe-app/releases/latest)**

*Oharra: Proiektu hau Euskal Herriko Unibertsitateko (EHU) Informatika Ingeniaritzako Gradu Amaierako Lan (GrAL) gisa garatu da.*

---

## Funtzionalitate nagusiak

* **Agenda adimenduna:** Saioen eta errutinen planifikazio malgua hodeiko sinkronizazioarekin.
* **Doitasun handiko metronomoa:** Exekuzio-hari natiboetan inplementatua, latentzia ezabatzeko eta pultsua zehatz mantentzeko.
* **Afinadore kromatikoa:** YIN algoritmoan oinarritutako denbora errealeko seinaleen prozesamendua, frekuentziak (Hz) nota zehatz bihurtuz.
* **Grabazio sekuentziala:** Entseguen jarraipena egiteko tokiko audio-grabazio optimizatuak (M4A/AAC-LC formatuan).
* **AA Irakasle Birtuala:** LLM ereduak (Llama-3) integratuta, errutinak automatikoki sortzeko eta erabiltzaileari neurrirako *feedback* pedagogikoa emateko.

---

## Arkitektura eta Teknologiak

* **Frontend:** Flutter eta Dart (Material 3).
* **Backend (BaaS):** Firebase Auth (OAuth 2.0) eta Cloud Firestore (NoSQL datu-basea segurtasun arauekin).
* **Audioa eta Hardwarea:** `flutter_audio_capture`, `pitch_detector_dart` eta espezifikoki garatutako harrapaketa-logika.
* **Adimen Artifiziala:** Groq REST APIa (*Prompt Engineering* aurreratua eta JSON egituratuen prozesamendua).
