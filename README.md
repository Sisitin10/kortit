# Korttipelit

Portrait-iOS-korttipelisovellus Kakkahousulle ja Mustalle Maijalle. Sovelluksen ilme on vaalea ja hillitty; Chrome Hearts -korttipakka ja käyttäjän logo ovat teeman yksityiskohtia.

## Build ja GitHub Releases

GitHub Actions rakentaa sovelluksen GitHubin Xcode 27 -runnerilla, joten paikallista Macia ei tarvita. Jokainen push rakentaa IPA:n ja tallentaa sen Actions-artifactiksi. Repon oletushaaran onnistunut build julkaisee uuden GitHub Releasen, johon liitetään IPA ja Feather-lähde.

IPA:ta ei voi asentaa suoraan iPhoneen ennen Apple-allekirjoitusta ja provisioning-profiilia.

## Feather

Lisää Featheriin tämä repo kerran; sen jälkeen Feather-lähde näyttää uusimman oletushaarasta julkaistun buildin:

`https://github.com/Sisitin10/kortit/releases/latest/download/Korttipelit-feather-source.json`

Feather-lähde päivittyy automaattisesti jokaisen onnistuneen julkaisun yhteydessä. IPA on allekirjoittamaton, joten Feather tarvitsee oman allekirjoitusvarmenteesi ennen asennusta.

## Firebase

Kirjautuminen käyttää Firebase Authenticationin sähköposti-/salasanatapaa. Realtime Database synkronoi huoneet ja pelin tilan.

1. Ota Firebase Consolessa käyttöön **Authentication → Email/Password**.
2. Luo **Realtime Database** ja julkaise sen Rules-näkymässä projektin `database.rules.json`.
3. Rekisteröi iOS-sovellus bundle ID:llä `fi.chromehearts.cards`. Lisää ladattu `GoogleService-Info.plist` repon juureen.
4. Lisää tietokannan URL Actions-secrets-kohtaan nimellä `FIREBASE_DATABASE_URL`, jos osoite ei ole plistissä.

Nykyiset tietokantasäännöt sopivat kokeiluun: kirjautuneet käyttäjät voivat lukea ja kirjoittaa huoneen koko tilan, mukaan lukien pelaajien kädet. Tämä ei estä huijaamista eikä sovi kilpailupelin tuotantokäyttöön.

## Pelit

- **Kakkahousu:** viiden kortin käsi; host valitsee huoneeseen kuvakorttien 7/8/9-alarajan. Kakkahousua voi myös harjoitella yksin.
- **Musta Maija:** online-peli vähintään kahdelle pelaajalle. Valtti ja patarouva huomioidaan pelin vuoroissa.
