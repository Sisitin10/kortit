# Lautapelit

Lautapelit on suomenkielinen iPhone-sovellus. Mukana ovat Kakkahousu, Musta Maija ja verkossa pelattava 5 Sekuntia. Pelissä käytetään toimitettuja 5 Sekuntia -pelilauta- ja kysymyskorttikuvia sekä 1 805 suomenkielistä kysymystä.

## 5 Sekuntia

Isäntä luo Firebase-huoneen, muut liittyvät huonekoodilla tai QR-koodilla ja jokainen valitsee yksilöllisen pelinappulan värin. Kysyjä nostaa kysymyskortin vetämällä pakkaa ylöspäin. Kysymys näkyy kaikille; vastaajan puhelin pyytää mikrofonin ja puheentunnistuksen luvat ensimmäisellä pelikerralla. Kysymys näytetään hetken ennen yhteistä viiden sekunnin ajastinta. Tunnistettu puhe jaetaan huoneeseen, ja kysyjä merkitsee vastauksen onnistuneeksi tai hylätyksi. Onnistuminen siirtää vastaajaa yhden ruudun. Voittaja vie pelin loppuun ruudussa 12, minkä jälkeen pelaajat palaavat samaan huoneeseen.

Ohitus- ja vaihtokortit voi kytkeä huoneen asetuksista päälle; oletuksena ne ovat pois. Puheentunnistus tarvitsee internetyhteyden kielissä/laitteissa, joilla Applen tunnistin ei tue laitteen sisäistä tunnistusta. Tämän version oikeellisuuden arvioi kysyjä; sovelluksessa ei ole erillistä faktantarkistuspalvelinta, joten se ei väitä tarkistavansa avoimia vastauksia verkon ajantasaisista lähteistä.

## Firebase

Online-huoneet ja pelivuorot käyttävät Firebase Authenticationia ja Realtime Databasea.

1. Ota Firebase Consolessa käyttöön **Authentication → Email/Password**.
2. Luo Realtime Database ja julkaise repon `database.rules.json`-tiedoston säännöt.
3. Rekisteröi iOS-sovellus bundle ID:llä `fi.chromehearts.cards` ja lisää `GoogleService-Info.plist` repon juureen.
4. Lisää tietokannan osoite GitHub Actionsin repository secretiksi `FIREBASE_DATABASE_URL`, jos sitä ei ole plistissä.

Tietokantasäännöt sallivat kirjautuneen pelaajan lukea ja kirjoittaa huoneen koko tilan. Ne sopivat testaukseen, mutta eivät estä pelaajaa väärentämästä huoneen sisältöä.

## iOS-build ja julkaisu

GitHub Actions luo Xcode-projektin XcodeGenillä ja rakentaa allekirjoittamattoman iOS-IPA:n macOS/Xcode-runnerissa. Windows-konetta tai omaa Macia ei tarvita. Oletushaaran julkaisu liittää IPA:n ja Feather-lähteen samaan GitHub Releaseen. IPA pitää allekirjoittaa ennen asentamista iPhoneen.

Feather-lähde:

`https://github.com/Sisitin10/kortit/releases/latest/download/Lautapelit-feather-source.json`

Androidille ei enää rakenneta tai julkaista uusia versioita GitHub Actionsissa. `android/`-kansion aiempi lähdekoodi on jätetty erilleen, eikä iOS-build sisällytä sitä.
