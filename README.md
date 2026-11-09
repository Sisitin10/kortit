# Korttipelit

Portrait-muotoinen iOS-korttipelisovellus Kakkahousulle ja Mustalle Maijalle. Käyttöliittymä on suomeksi, ja korttipakan ulkoasussa käytetään Chrome Hearts -teemaa. Sovelluksen vähimmäisversio on iOS 27.

## Sovelluksen käyttö

- **Pelit:** näytä voitot ja tappiot, isännöi uutta huonetta tai liity peliin skannaamalla QR-koodi. Skannerista voi vaihtaa huonekoodin syöttöön.
- **Isännöi peliä:** valitse Kakkahousu tai Musta Maija. Kakkahousussa isäntä valitsee kuvakorttien säännön (7, 8 tai 9).
- **Asetukset:** valitse profiilikuva, tumma tila, logotausta ja uloskirjautuminen. Tumma tila kääntää myös korttien kuvat.
- **Pikaisäntä:** aloitusnäkymän plus-painikkeesta voi lisätä Kakkahousun yhden painalluksen pikakuvakkeen 7 kortin säännöllä.

Kakkahousussa kortit pelataan valitsemalla tai vetämällä ne pöytään. Korttien pelaamisen jälkeen pelaaja nostaa itse pakasta ennen vuoron siirtymistä. Jos kädessä ei ole sopivaa korttia, nostopainike tulee näkyviin. Mustassa Maijassa valtti näkyy pakan alla; patarouvaa ei voi kaataa. Kun hyökkäys on ratkaistu, hyökkääjä ja puolustaja täydentävät kätensä viiteen korttiin varaston salliessa.

## GitHub Actions -buildit

GitHub Actions generoi Xcode-projektin XcodeGenillä ja rakentaa allekirjoittamattoman IPA:n macOS/Xcode-runnerilla. Windows-konetta tai paikallista Macia ei tarvita. Oletushaaran onnistunut build julkaisee IPA:n GitHub Releasesiin ja päivittää Feather-lähteen. IPA vaatii allekirjoituksen ennen asennusta iPhoneen.

Feather-lähde:

`https://github.com/Sisitin10/kortit/releases/latest/download/Korttipelit-feather-source.json`

## Firebase-asetukset

Kirjautuminen käyttää Firebase Authenticationin sähköposti-/salasanakirjautumista. Realtime Database synkronoi huoneet ja pelin tilan.

1. Ota Firebase Consolessa käyttöön **Authentication → Email/Password**.
2. Luo Realtime Database ja julkaise `database.rules.json`-tiedoston säännöt.
3. Rekisteröi iOS-sovellus bundle ID:llä `fi.chromehearts.cards` ja lisää `GoogleService-Info.plist` repon juureen.
4. Lisää Firebase Realtime Database -osoite GitHub Actionsin repository secretiksi nimellä `FIREBASE_DATABASE_URL`, jos osoite ei ole plistissä.

Nykyisillä tietokantasäännöillä kirjautunut pelaaja voi lukea ja kirjoittaa huoneen koko tilan, mukaan lukien kaikkien pelaajien kädet. Säännöt soveltuvat testikäyttöön, eivät huijausta estävään julkaisuversioon.
