# Chrome Hearts — suomalaiset korttipelit

Portrait-first SwiftUI iOS-sovellus Kakkahousulle ja Mustalle Maijalle. Mukana on paikallinen pelitila, huoneen luonti ja liittyminen QR-/koodilla sekä Firebase Realtime Database -pohjainen huoneiden päivitys.

## Rakenna unsigned IPA GitHub Actionsilla

Push `main`- tai `master`-haaraan tai käynnistä **Actions → Build unsigned iOS IPA**. Workflow asentaa XcodeGenin, luo Xcode-projektin ja lataa `ChromeHearts-unsigned.ipa`-artefaktin. IPA on allekirjoittamaton, joten sen asentaminen vaatii myöhemmin allekirjoituksen sopivalla Apple-kehittäjätyökalulla.

Paikalliseen buildiin tarvitaan macOS, Xcode ja XcodeGen: `brew install xcodegen && xcodegen generate`, sitten avaa `ChromeHearts.xcodeproj` tai rakenna `xcodebuild`-komennolla.

## Verkkopelin konfigurointi

Luo Firebase-projekti, ota käyttöön **Authentication → Email/Password** ja **Realtime Database**. Sovellus käyttää Firebase Authin REST-rajapintaa sähköposti-/salasanakirjautumiseen ja RTDB:n REST-rajapintaa huoneisiin. Julkaise tietokantaan tämän repon `database.rules.json`-säännöt (Firebase Console → Realtime Database → Rules). Ne vaativat kirjautumisen ennen lukua ja kirjoitusta. Lisää GitHub-repon Actions-secreteihin `FIREBASE_API_KEY` ja `FIREBASE_DATABASE_URL` (esim. `https://oma-projekti-default-rtdb.europe-west1.firebasedatabase.app`); workflow sisällyttää arvot sovellukseen. Paikalliseen ajoon lisää samat arvot Xcode-schemeen. Älä jätä tietokantaa avoimeksi.

Ilman Firebase-asetuksia paikallinen korttipöytä toimii; verkkohuone pyytää asetukset ennen luontia. Online-huoneessa host aloittaa jaon, kortit ja vuorot synkronoituvat pelaajien välillä kahden sekunnin kyselyllä. Google-kirjautuminen ei ole tässä versiossa kytketty: sähköposti ja salasana tarjoavat peruskirjautumisen.

## Pelit

Kakkahousu käyttää 52 korttia, pöytään pelataan 1–4 samaa arvoa olevaa korttia ja seuraavan pelin pitää olla vähintään yhtä korkea; pelaaja voi nostaa pöydän. Käden voi täydentää viiteen korttiin nostamalla pakasta. Musta Maija käyttää 52 korttia ilman jokereita; pata-rouvaa ei voi pelata pois. Pelit käyttävät kevyttä ystäväpeliversiota ilman kaikkia alueellisia sääntövariantteja.
