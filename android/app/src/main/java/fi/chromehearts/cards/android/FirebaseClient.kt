package fi.chromehearts.cards.android

import android.content.Context
import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.UUID

data class AuthSession(val idToken: String, val refreshToken: String, val email: String?, val uid: String)

class FirebaseClient(private val context: Context) {
    private val gson = Gson()
    private val preferences = context.getSharedPreferences("firebase-session", Context.MODE_PRIVATE)
    private val apiKey = BuildConfig.FIREBASE_API_KEY
    private val databaseUrl = BuildConfig.FIREBASE_DATABASE_URL.trimEnd('/')
    var session: AuthSession? = null
        private set

    suspend fun restoreSession(): AuthSession? {
        val refresh = preferences.getString("refreshToken", null) ?: return null
        return try {
            val result = request("https://securetoken.googleapis.com/v1/token?key=$apiKey", "POST", "grant_type=refresh_token&refresh_token=${enc(refresh)}", "application/x-www-form-urlencoded")
            val json = gson.fromJson(result, JsonObject::class.java)
            AuthSession(json["id_token"].asString, json["refresh_token"].asString, preferences.getString("email", null), json["user_id"].asString).also(::saveSession)
        } catch (_: Exception) { signOut(); null }
    }

    suspend fun authenticate(email: String, password: String, create: Boolean): AuthSession {
        requireFirebaseConfig()
        val endpoint = if (create) "signUp" else "signInWithPassword"
        val body = gson.toJson(mapOf("email" to email, "password" to password, "returnSecureToken" to true))
        val json = gson.fromJson(request("https://identitytoolkit.googleapis.com/v1/accounts:$endpoint?key=$apiKey", "POST", body), JsonObject::class.java)
        return AuthSession(json["idToken"].asString, json["refreshToken"].asString, json["email"]?.asString, json["localId"].asString).also(::saveSession)
    }

    fun signOut() { session = null; preferences.edit().clear().apply() }

    suspend fun createRoom(game: GameKind, player: PlayerInfo, faceCardsMinimum: Int): OnlineRoom {
        val code = UUID.randomUUID().toString().replace("-", "").take(6).uppercase()
        return OnlineRoom(code, game, player.id, mutableMapOf(player.id to player), kakkahousuFaceCardsMinimum = faceCardsMinimum).also { saveRoom(it) }
    }

    suspend fun joinRoom(code: String, player: PlayerInfo): OnlineRoom {
        val room = loadRoom(code.uppercase()) ?: error("Huonetta ei löytynyt. Tarkista huonekoodi.")
        require(room.players.size < 6 || room.players.containsKey(player.id)) { "Huone on täynnä (enintään 6 pelaajaa)." }
        room.players[player.id] = player
        room.updatedAt = System.currentTimeMillis() / 1000.0
        saveRoom(room)
        return room
    }

    suspend fun loadRoom(code: String): OnlineRoom? {
        val json = database("rooms/${code.uppercase()}.json", "GET")
        if (json == "null") return null
        return gson.fromJson(json, OnlineRoom::class.java)
    }

    suspend fun saveRoom(room: OnlineRoom) {
        room.updatedAt = System.currentTimeMillis() / 1000.0
        database("rooms/${room.code}.json", "PUT", gson.toJson(room))
    }

    private fun saveSession(value: AuthSession) {
        session = value
        preferences.edit().putString("refreshToken", value.refreshToken).putString("email", value.email).apply()
    }

    private fun requireFirebaseConfig() {
        check(apiKey.isNotBlank()) { "Firebase API key puuttuu. Lisää GoogleService-Info.plist repon juureen." }
        check(databaseUrl.startsWith("https://")) { "Realtime Database -osoite puuttuu GoogleService-Info.plist-tiedostosta." }
    }

    private suspend fun database(path: String, method: String, body: String? = null): String {
        requireFirebaseConfig()
        val token = session?.idToken ?: error("Kirjaudu ensin sisään.")
        return request("$databaseUrl/$path?auth=${enc(token)}", method, body)
    }

    private suspend fun request(url: String, method: String, body: String?, contentType: String = "application/json"): String = withContext(Dispatchers.IO) {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = 12_000
            connection.readTimeout = 20_000
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", contentType)
                connection.outputStream.use { it.write(body.toByteArray()) }
            }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val response = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                val message = runCatching { gson.fromJson(response, JsonObject::class.java).getAsJsonObject("error").get("message").asString }.getOrNull()
                error(message ?: "Firebase-pyyntö epäonnistui ($status). Tarkista tietokannan säännöt.")
            }
            response
        } finally { connection.disconnect() }
    }

    private fun enc(value: String) = URLEncoder.encode(value, Charsets.UTF_8.name())
}
