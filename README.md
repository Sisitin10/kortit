# Korttipelit

Suomenkielinen Kakkahousu- ja Musta Maija -korttipeli iOS:lle ja Androidille. Molemmissa sovelluksissa on sama Chrome Hearts -teemainen korttipakka, online-huoneet ja suomenkielinen käyttöliittymä. iOS-projekti on repon juuressa; itsenäinen Android-sovellus on [android/](android/)-kansiossa.

## Sovelluksen käyttö

- **Pelit:** näytä voitot ja tappiot, isännöi uutta huonetta tai liity peliin skannaamalla QR-koodi. Skannerista voi vaihtaa huonekoodin syöttöön.
- **Isännöi peliä:** valitse Kakkahousu tai Musta Maija. Kakkahousussa isäntä valitsee kuvakorttien säännön (7, 8 tai 9).
- **Asetukset:** valitse profiilikuva, tumma tila, logotausta ja uloskirjautuminen. Tumma tila kääntää myös korttien kuvat.
- **Pikaisäntä:** aloitusnäkymän plus-painikkeesta voi lisätä Kakkahousun yhden painalluksen pikakuvakkeen 7 kortin säännöllä.

Kakkahousussa kortit pelataan valitsemalla tai vetämällä ne pöytään. Korttien pelaamisen jälkeen pelaaja nostaa itse pakasta ennen vuoron siirtymistä. Jos kädessä ei ole sopivaa korttia, nostopainike tulee näkyviin. Mustassa Maijassa valtti näkyy pakan alla; patarouvaa ei voi kaataa. Kun hyökkäys on ratkaistu, hyökkääjä ja puolustaja täydentävät kätensä viiteen korttiin varaston salliessa.

## Android

Android-sovelluksen lähdekoodi ja Gradle-asetukset ovat `android/`-kansiossa. XcodeGenin `project.yml` sisällyttää vain iOS:n `Sources`-, `Assets.xcassets`- ja `Resources`-tiedostot, joten Android-moduuli ei tule mukaan IPA-buildiin.

Android-versio vaatii Android 8.0:n (API 26) tai uudemman. Se käyttää samoja Firebase Authentication -tilejä ja Realtime Database -huoneita kuin iOS. Android-build lukee Firebase API-avaimen ja tietokantaosoitteen repon juuren `GoogleService-Info.plist`-tiedostosta.

GitHub Actions rakentaa asennettavan `Korttipelit-android.apk`-tiedoston ja liittää sen samaan GitHub Releaseen iOS:n IPA:n ja Feather-lähdetiedoston kanssa. APK on debug-allekirjoitettu, jos allekirjoitusavaimen GitHub Secrets -arvoja ei ole määritetty. Tällöin uudemman APK:n asentaminen aiemman päälle voi vaatia vanhan sovelluksen poistamista.

Jatkuvia päivityksiä varten lisää GitHub-repositorion Actions-secrets-arvoiksi `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` ja `ANDROID_KEY_PASSWORD`. Ne allekirjoittavat kaikki julkaisut samalla avaimella.

## GitHub Actions -buildit

GitHub Actions generoi Xcode-projektin XcodeGenillä ja rakentaa iOS:n allekirjoittamattoman IPA:n macOS/Xcode-runnerilla. Rinnakkainen Ubuntu-jobi rakentaa Android-APK:n. Windows-konetta tai paikallista Macia ei tarvita. Oletushaaran onnistunut build julkaisee APK:n, IPA:n ja Feather-lähteen samaan GitHub Releaseen. IPA vaatii allekirjoituksen ennen asennusta iPhoneen.

Feather-lähde:

`https://github.com/Sisitin10/kortit/releases/latest/download/Korttipelit-feather-source.json`

## Firebase-asetukset

Kirjautuminen käyttää Firebase Authenticationin sähköposti-/salasanakirjautumista. Realtime Database synkronoi huoneet ja pelin tilan.

1. Ota Firebase Consolessa käyttöön **Authentication → Email/Password**.
2. Luo Realtime Database ja julkaise `database.rules.json`-tiedoston säännöt.
3. Rekisteröi iOS-sovellus bundle ID:llä `fi.chromehearts.cards` ja lisää `GoogleService-Info.plist` repon juureen.
4. Lisää Firebase Realtime Database -osoite GitHub Actionsin repository secretiksi nimellä `FIREBASE_DATABASE_URL`, jos osoite ei ole plistissä.

Nykyisillä tietokantasäännöillä kirjautunut pelaaja voi lukea ja kirjoittaa huoneen koko tilan, mukaan lukien kaikkien pelaajien kädet. Säännöt soveltuvat testikäyttöön, eivät huijausta estävään julkaisuversioon.
