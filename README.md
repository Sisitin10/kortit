# Chrome Hearts — suomalaiset korttipelit

Portrait-tilaan tehty iOS-korttipelisovellus. Kakkahousussa ja Mustassa Maijassa on korttikäsi, pakka, pöytä, vuorot, animaatiot ja äänipalaute. Online-huoneessa host jakaa QR-koodin tai kuusimerkkisen huonekoodin. Sovelluksen tämänhetkiset säännöt ovat kevyet ystäväpeliversiot.

## Rakenna GitHubissa ilman Macia

Workflow käyttää GitHubin macOS-runneria ja Xcodea. Sinun ei tarvitse asentaa Xcodea omalle koneelle. Buildin voi käynnistää myös puhelimen selaimella:

1. Laita projektin tiedostot GitHub-repoon. Repon juureen kuuluvat mm. `project.yml`, `Sources/`, `.github/workflows/` ja `database.rules.json`.
2. Lisää Firebase-arvot repon **Settings → Secrets and variables → Actions → New repository secret** -kohdassa. Lisää nimet `FIREBASE_API_KEY` ja `FIREBASE_DATABASE_URL` alla olevien Firebase-ohjeiden mukaan.
3. Avaa repon **Actions → Build iOS IPA (unsigned) → Run workflow** ja käynnistä ajo.
4. Kun ajo on vihreä, avaa sen sivu. Lataa **Artifacts**-osiosta `ChromeHearts-unsigned-ipa`-paketti. Sen sisältä löytyy `ChromeHearts-unsigned.ipa`. Artefakti säilyy 14 päivää.

Workflow rakentaa iOS-sovelluksen pilvessä `xcodebuild`illa, paketoi sen IPA:ksi ja julkaisee sen Actions-artefaktina. IPA on allekirjoittamaton. iPhone ei asenna sitä suoraan: laitteelle jakaminen vaatii Applelta kelvollisen allekirjoituksen ja provisioning-profiilin. Tämä workflow ei pyydä Apple-tunnuksia eikä allekirjoita sovellusta. [Applen ohje rekisteröidyille testilaitteille jakamisesta](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices) kertoo allekirjoituksen ja profiilin vaatimuksista.

## Firebase: kirjautuminen ja online-peli

Firebase-projekti hoitaa molemmat eri palveluilla:

- **Firebase Authentication** tarkistaa pelaajan sähköpostin ja salasanan.
- **Realtime Database** tallentaa huoneen, pelaajat, kortit ja vuoron, jotta muiden laitteiden peli päivittyy.

Tee Firebase Consolessa seuraavat asetukset:

1. Avaa projektisi **Project settings → General**. Lisää iOS-sovellus bundle ID:llä `fi.chromehearts.cards`. Kopioi projektin **Web API Key**; nykyinen sovellus käyttää Firebase REST-rajapintaa, joten `GoogleService-Info.plist`-tiedostoa ei tarvita.
2. Avaa **Authentication → Sign-in method** ja ota käyttöön **Email/Password**. Sovelluksen kirjautumisruutu voi sen jälkeen luoda tilin tai kirjautua sisään. Google-kirjautumista ei ole vielä kytketty.
3. Avaa **Realtime Database → Create database**. Valitse tietokannan sijainti ja luo tietokanta.
4. Kopioi Consolen näyttämä tietokannan URL, esimerkiksi `https://oma-projekti-default-rtdb.europe-west1.firebasedatabase.app`.
5. Julkaise repon `database.rules.json` Firebase Consolen **Realtime Database → Rules** -välilehdellä. Nykyiset säännöt vaativat kirjautumisen, mutta sallivat kaikille kirjautuneille käyttäjille luku- ja kirjoitusoikeuden huonereitteihin. Tämä sopii prototyypin kokeiluun, ei tuotantoon.
6. Lisää API key ja tietokannan URL GitHubin Actions-secreteihin täsmälleen nimillä `FIREBASE_API_KEY` ja `FIREBASE_DATABASE_URL`. Käynnistä workflow uudelleen, jotta arvot päätyvät rakennettuun sovellukseen.

Ilman näitä kahta salaisuutta IPA kyllä rakentuu, mutta online-kirjautumisella ja huoneilla ei ole yhteyttä Firebaseen. Kirjautumisruudun **Jatka vieraana** toimii vain paikallisessa pelitilassa.

## Pelien säännöt

Kakkahousussa pelataan 1–4 samanarvoista korttia, ja pöydän päälle pelataan vähintään yhtä korkeaa arvoa; pelaaja voi nostaa pöydän. Kättä täydennetään nostamalla pakasta. Mustassa Maijassa pata-rouvaa ei voi pelata pois kädestä. Alueellisia sääntövariantteja tai Google-kirjautumista ei ole vielä asetuksina.
