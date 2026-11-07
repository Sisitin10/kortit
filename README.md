# Chrome Hearts — korttipelit iPhonelle

Portrait-SwiftUI-sovellus Kakkahousulle ja Mustalle Maijalle. Käyttöliittymä on vaalea ja koko ruudun mukainen. Korttien etu- ja takapuoli käyttävät projektin Assets-kansioon kopioituja käyttäjän referenssikuvia. iOS 26:ssa käyttöliittymän korttipaneelit käyttävät SwiftUIn natiivia Liquid Glass -efektiä; vanhemmissa tuetuissa iOS-versioissa käytetään järjestelmän `Material`-pintaa.

## Build ilman Macia

GitHub Actions rakentaa iOS-sovelluksen GitHubin macOS-26-runnerilla ja Xcodella. Pushaa muutokset mille tahansa haaralle tai käynnistä **Actions → Build iOS IPA (unsigned) → Run workflow**. Buildin jälkeen lataa `ChromeHearts-unsigned-ipa` Actions-ajon **Artifacts**-osiosta. Artefakti säilyy 14 päivää.

IPA on allekirjoittamaton, eikä iPhone asenna sitä sellaisenaan. Puhelimeen asentaminen vaatii Apple-allekirjoituksen ja provisioning-profiilin.

## Firebase

Firebase Authentication hoitaa sähköposti-/salasanakirjautumisen. Realtime Database välittää huoneet, kortit ja vuorot laitteiden välillä Firebase REST -rajapinnan tapahtumavirralla.

Kakkahousua voi harjoitella yksin. Musta Maija pelataan online-huoneessa, jossa tarvitaan vähintään kaksi pelaajaa. Kirjautuminen tehdään Firebase Authenticationin sähköposti-/salasanatoiminnolla; Google-kirjautumista ei ole kytketty.

1. Firebase Consolessa ota käyttöön **Authentication → Sign-in method → Email/Password**.
2. Luo **Realtime Database**. Sen URL löytyy Realtime Database -näkymästä.
3. Rekisteröi iOS-sovellus bundle ID:llä `fi.chromehearts.cards` ja lataa `GoogleService-Info.plist`. Lisää tiedosto sellaisenaan GitHub-repon juureen. Actions lisää sen rakennetun sovelluksen sisään; API key luetaan tiedoston `API_KEY`-kentästä.
4. Julkaise projektin `database.rules.json` Firebase Consolen **Realtime Database → Rules** -näkymässä. Nykyiset säännöt vaativat kirjautumisen.
5. Jos asetustiedostossa ei ole `DATABASE_URL`-kenttää, lisää Realtime Database -näkymän URL GitHub-repon **Settings → Secrets and variables → Actions** -kohtaan nimellä `FIREBASE_DATABASE_URL`. `FIREBASE_API_KEY`-salaisuutta ei tarvitse lisätä. Ilman tietokannan URL:ia sovellus rakentuu, mutta huoneet eivät yhdisty.

Nykyiset RTDB-säännöt sallivat kirjautuneille käyttäjille huoneen kaikkien tietojen lukemisen ja kirjoittamisen. Pelitila sisältää myös kaikkien pelaajien käsikortit, joten malli sopii kokeiluun mutta ei estä huijaamista eikä sovi julkaistavan kilpailupelin tietosuojaksi. Tuotantoversio tarvitsee palvelinpuolen siirtojen tarkistuksen ja pelaajakohtaisesti suojatut käsikortit.

## Pelisäännöt

Kakkahousu käyttää viiden kortin kättä. Kakkonen on erikoiskortti; kymppi kaataa 3–9 pinon ja ässä kuvakorttipinon. Pakan ollessa jäljellä käsi täydennetään viiteen, ja pinon voi joutua nostamaan. Kuvakorttien pelattavuuden alaraja 7, 8 tai 9 valitaan huoneen hostin asetuksista. Paskahousun säännöissä on alueellisia muunnelmia, joten asetus tekee yleisimmästä kiistakohdasta muokattavan. [Paskahousu / Wikipedia](https://en.wikipedia.org/wiki/Paskahousu)

Mustassa Maijassa jaetaan viisi korttia, käännetään valtti (pata ei kelpaa), hyökätään saman maan korteilla ja puolustaja kaataa korkeamman saman maan kortilla tai valtilla. Patarouva ei kaadu. [Musta Maija / Wikipedia](https://en.wikipedia.org/wiki/Musta_Maija)
