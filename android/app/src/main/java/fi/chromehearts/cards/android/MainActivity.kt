package fi.chromehearts.cards.android

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color as AndroidColor
import android.media.MediaPlayer
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.QrCode2
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.Upload
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.roundToInt

private val Ink = Color(0xFF171719)
private val Wine = Color(0xFF64252D)
private val Page = Color(0xFFF1F2F4)
private val Quiet = Color(0xFF707176)
private enum class Screen { HOME, HOST, JOIN, ROOM, GAME, SETTINGS, AUTH }

class MainActivity : ComponentActivity() {
    private var deepLinkCode by mutableStateOf("")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = AndroidColor.rgb(241, 242, 244)
        window.navigationBarColor = AndroidColor.rgb(241, 242, 244)
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        deepLinkCode = intent?.data?.lastPathSegment.orEmpty().uppercase()
        setContent { KorttipelitApp(deepLinkCode) }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deepLinkCode = intent.data?.lastPathSegment.orEmpty().uppercase()
    }
}

@Composable
private fun KorttipelitApp(deepLinkCode: String) {
    val context = LocalContext.current
    val client = remember { FirebaseClient(context) }
    val prefs = remember { context.getSharedPreferences("korttipelit-settings", Context.MODE_PRIVATE) }
    val scope = rememberCoroutineScope()
    var dark by rememberSaveable { mutableStateOf(prefs.getBoolean("dark", false)) }
    var pattern by rememberSaveable { mutableStateOf(prefs.getBoolean("pattern", true)) }
    var screen by rememberSaveable { mutableStateOf(Screen.HOME) }
    var authReturnScreen by remember { mutableStateOf(Screen.HOME) }
    var auth by remember { mutableStateOf<AuthSession?>(null) }
    var room by remember { mutableStateOf<OnlineRoom?>(null) }
    var localState by remember { mutableStateOf<SharedGameState?>(null) }
    var userID by remember { mutableStateOf("") }
    var userName by remember { mutableStateOf("") }
    var selectedGame by remember { mutableStateOf(GameKind.KAKKAHOUSU) }
    var faceRule by rememberSaveable { mutableIntStateOf(7) }
    var message by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var wins by rememberSaveable { mutableIntStateOf(prefs.getInt("wins", 0)) }
    var losses by rememberSaveable { mutableIntStateOf(prefs.getInt("losses", 0)) }
    var roomCode by rememberSaveable { mutableStateOf("") }
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var signup by rememberSaveable { mutableStateOf(false) }
    val selectedCards = remember { mutableStateListOf<String>() }
    val gameState = room?.gameState ?: localState
    val isOnline = room != null
    val playerID = if (isOnline) userID else "local-player"
    val scheme = if (dark) darkColorScheme(primary = Color(0xFFE0BDAA), secondary = Color(0xFFD5D4D0), background = Color(0xFF151517), surface = Color(0xFF222225), onBackground = Color(0xFFF2F0EC), onSurface = Color(0xFFF2F0EC)) else lightColorScheme(primary = Wine, secondary = Wine, background = Page, surface = Color.White, onBackground = Ink, onSurface = Ink)

    fun persistState(next: SharedGameState) {
        if (isOnline) {
            val current = room ?: return
            scope.launch {
                busy = true
                runCatching { current.gameState = next; client.saveRoom(current); room = current.copy() }
                    .onFailure { message = it.message ?: "Pelin tallennus epäonnistui." }
                busy = false
            }
        } else localState = next
    }

    LaunchedEffect(Unit) {
        client.restoreSession()?.let { restored ->
            auth = restored
            email = restored.email.orEmpty()
            userName = restored.email?.substringBefore('@')?.take(18) ?: "Pelaaja"
            userID = restored.uid
        }
    }
    LaunchedEffect(deepLinkCode, auth?.idToken) {
        if (deepLinkCode.length == 6) {
            roomCode = deepLinkCode
            screen = Screen.JOIN
            if (auth != null) {
                busy = true
                runCatching { client.joinRoom(deepLinkCode, PlayerInfo(playerID, userName.ifBlank { "Pelaaja" })) }
                    .onSuccess { room = it; screen = if (it.gameState == null) Screen.ROOM else Screen.GAME }
                    .onFailure { message = it.message ?: "Huoneeseen liittyminen epäonnistui." }
                busy = false
            }
        }
    }
    LaunchedEffect(room?.code, auth?.idToken, screen) {
        val code = room?.code ?: return@LaunchedEffect
        val tokenExists = auth != null
        if (!tokenExists) return@LaunchedEffect
        while (true) {
            delay(1700)
            runCatching { client.loadRoom(code) }.onSuccess { fresh ->
                if (fresh != null) {
                    room = fresh
                    screen = if (fresh.gameState != null) Screen.GAME else Screen.ROOM
                }
            }
        }
    }
    LaunchedEffect(gameState?.roundID, gameState?.activePlayerID, isOnline) {
        if (!isOnline && gameState?.activePlayerID == "computer" && gameState != null && !gameState.isOver) {
            delay(650)
            val bot = copyState(localState ?: return@LaunchedEffect)
            runBot(bot)
            localState = bot
        }
    }

    MaterialTheme(colorScheme = scheme) {
        val background = if (dark) Color(0xFF151517) else Page
        SideEffect {
            (context as? Activity)?.let { activity ->
                val surface = if (dark) AndroidColor.rgb(21, 21, 23) else AndroidColor.rgb(241, 242, 244)
                activity.window.statusBarColor = surface
                activity.window.navigationBarColor = surface
                @Suppress("DEPRECATION")
                activity.window.decorView.systemUiVisibility = if (dark) 0 else android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
            }
        }
        Box(Modifier.fillMaxSize().background(background)) {
            if (pattern) BrandPattern(dark, Modifier.fillMaxSize())
            Scaffold(containerColor = Color.Transparent, contentWindowInsets = WindowInsets(0, 0, 0, 0)) { inner ->
                val topInset = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
                val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
                Column(Modifier.fillMaxSize().padding(inner).padding(top = topInset, bottom = bottomInset)) {
                    AnimatedContent(
                        targetState = screen,
                        modifier = Modifier.weight(1f),
                        transitionSpec = { (fadeIn() + slideInHorizontally { it / 10 }).togetherWith(fadeOut() + slideOutHorizontally { -it / 12 }) },
                        label = "screen"
                    ) { page ->
                        when (page) {
                            Screen.HOME -> HomeScreen(wins, losses, userName, onHost = { screen = Screen.HOST }, onJoin = { screen = Screen.JOIN }, onSettings = { screen = Screen.SETTINGS }, onAuth = { screen = Screen.AUTH }, onQuickHost = {
                                if (auth == null) { authReturnScreen = Screen.HOST; screen = Screen.AUTH; message = "Kirjaudu sisään ennen verkkopelin aloittamista." }
                                else { selectedGame = GameKind.KAKKAHOUSU; faceRule = 7; screen = Screen.HOST }
                            })
                            Screen.HOST -> HostScreen(selectedGame, faceRule, onBack = { screen = Screen.HOME }, onGame = { selectedGame = it }, onRule = { faceRule = it }, onPractice = {
                                val state = newGameState(selectedGame, mutableListOf("local-player", "computer"), "local-player", faceRule)
                                localState = state; room = null; selectedCards.clear(); screen = Screen.GAME
                            }, onCreate = {
                                if (auth == null) { authReturnScreen = Screen.HOST; screen = Screen.AUTH; message = "Kirjaudu sisään ennen huoneen luomista." }
                                else scope.launch {
                                    busy = true
                                    runCatching { client.createRoom(selectedGame, PlayerInfo(playerID, userName.ifBlank { "Pelaaja" }), faceRule) }
                                        .onSuccess { room = it; screen = Screen.ROOM; message = "" }
                                        .onFailure { message = it.message ?: "Huoneen luominen epäonnistui." }
                                    busy = false
                                }
                            }, busy = busy, message = message)
                            Screen.JOIN -> JoinScreen(roomCode, onBack = { screen = Screen.HOME }, onCode = { roomCode = it.uppercase().take(6) }, onJoin = {
                                if (auth == null) { authReturnScreen = Screen.JOIN; screen = Screen.AUTH; message = "Kirjaudu sisään ennen huoneeseen liittymistä." }
                                else scope.launch {
                                    busy = true
                                    runCatching { client.joinRoom(roomCode, PlayerInfo(playerID, userName.ifBlank { "Pelaaja" })) }
                                        .onSuccess { room = it; screen = if (it.gameState == null) Screen.ROOM else Screen.GAME; message = "" }
                                        .onFailure { message = it.message ?: "Huoneeseen liittyminen epäonnistui." }
                                    busy = false
                                }
                            }, message = message, busy = busy)
                            Screen.ROOM -> room?.let { activeRoom -> LobbyScreen(activeRoom, playerID, onBack = { room = null; screen = Screen.HOME }, onCopy = { copy(context, activeRoom.code); message = "Huonekoodi kopioitu." }, onStart = {
                                if (activeRoom.hostID != playerID) message = "Vain huoneen isäntä voi aloittaa pelin."
                                else {
                                    val ids = activeRoom.players.keys.toMutableList()
                                    val next = newGameState(activeRoom.game, ids, activeRoom.hostID, activeRoom.kakkahousuFaceCardsMinimum ?: 7)
                                    activeRoom.gameState = next
                                    scope.launch {
                                        busy = true
                                        runCatching { client.saveRoom(activeRoom) }.onSuccess { room = activeRoom.copy(); selectedCards.clear(); screen = Screen.GAME }.onFailure { message = it.message ?: "Pelin aloitus epäonnistui." }
                                        busy = false
                                    }
                                }
                            }, message = message, busy = busy) }
                            Screen.GAME -> gameState?.let { state -> GameScreen(
                                state = state,
                                playerID = playerID,
                                message = message,
                                selected = selectedCards.toSet(),
                                dark = dark,
                                autoReturnToLobby = isOnline,
                                onToggle = { card -> if (selectedCards.contains(card.id)) selectedCards.remove(card.id) else selectedCards.add(card.id) },
                                onDraw = {
                                    val updated = copyState(state)
                                    val hand = updated.hands[playerID] ?: mutableListOf()
                                    if (updated.activePlayerID != playerID) message = "Odota omaa vuoroasi."
                                    else if (updated.drawPile.isEmpty() && updated.maijaTrumpCard == null) message = "Pakka on tyhjä."
                                    else {
                                        val target = if (updated.kind == GameKind.KAKKAHOUSU && updated.kakkahousuPendingDraw) 5 else if (updated.kind == GameKind.KAKKAHOUSU && hand.size < 5 && hand.any { legalKakka(updated, it) }) 5 else hand.size + 1
                                        while (hand.size < target && (updated.drawPile.isNotEmpty() || updated.maijaTrumpCard != null)) drawOne(updated, hand)
                                        updated.kakkahousuPendingDraw = false
                                        if (updated.kind == GameKind.KAKKAHOUSU) updated.activePlayerID = nextPlayer(updated, playerID)
                                        message = "Kortti nostettu."
                                        persistState(updated)
                                    }
                                },
                                onPlay = {
                                    val chosen = (state.hands[playerID] ?: mutableListOf()).filter { it.id in selectedCards }
                                    val updated = copyState(state)
                                    val error = playCards(updated, playerID, chosen)
                                    if (error != null) message = error else {
                                        selectedCards.clear()
                                        persistState(updated)
                                        message = ""
                                    }
                                },
                                onExit = { room = null; localState = null; screen = Screen.HOME; selectedCards.clear(); message = "" },
                                onRecord = { won ->
                                    if (won) { wins++; prefs.edit().putInt("wins", wins).apply() }
                                    else { losses++; prefs.edit().putInt("losses", losses).apply() }
                                },
                                onNewRound = {
                                    if (room != null && room?.hostID == playerID) {
                                        val activeRoom = room!!
                                        activeRoom.gameState = null
                                        scope.launch { runCatching { client.saveRoom(activeRoom) }.onSuccess { room = activeRoom.copy(); screen = Screen.ROOM } }
                                    } else if (room == null) {
                                        localState = newGameState(state.kind, state.playerOrder.toMutableList(), playerID, state.kakkahousuRules.faceCardsMinimum)
                                    }
                                }
                            ) }
                            Screen.SETTINGS -> SettingsScreen(userName, dark, pattern, onBack = { screen = Screen.HOME }, onDark = { dark = it; prefs.edit().putBoolean("dark", it).apply() }, onPattern = { pattern = it; prefs.edit().putBoolean("pattern", it).apply() }, onAccount = { screen = Screen.AUTH }, onSignOut = { client.signOut(); auth = null; userID = ""; userName = ""; screen = Screen.AUTH })
                            Screen.AUTH -> AuthScreen(email, password, signup, userName, busy, message, onBack = { message = ""; screen = Screen.HOME }, onEmail = { email = it }, onPassword = { password = it }, onName = { userName = it }, onMode = { signup = !signup }, onSubmit = {
                                scope.launch {
                                    busy = true
                                    runCatching { client.authenticate(email.trim(), password, signup) }.onSuccess { loggedIn ->
                                        auth = loggedIn
                                        userID = loggedIn.uid
                                        if (userName.isBlank()) userName = email.substringBefore('@').take(18)
                                        message = ""
                                        screen = if (room != null) Screen.ROOM else authReturnScreen
                                    }.onFailure { message = it.message ?: "Kirjautuminen epäonnistui." }
                                    busy = false
                                }
                            })
                        }
                    }
                    if (screen in setOf(Screen.HOME, Screen.SETTINGS)) BottomNav(screen, onHome = { screen = Screen.HOME }, onSettings = { screen = Screen.SETTINGS })
                }
            }
        }
    }
}

@Composable
private fun HomeScreen(wins: Int, losses: Int, userName: String, onHost: () -> Unit, onJoin: () -> Unit, onSettings: () -> Unit, onAuth: () -> Unit, onQuickHost: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(horizontal = 22.dp, vertical = 14.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            BrandMark(36.dp)
            Column(Modifier.weight(1f).padding(start = 12.dp)) { Text("Korttipelit", fontSize = 19.sp, fontWeight = FontWeight.Bold); Text("Kakkahousu · Musta Maija", color = Quiet, fontSize = 14.sp) }
            IconButton(onClick = onQuickHost) { Icon(Icons.Default.Add, "Pikaisäntä") }
        }
        Spacer(Modifier.height(4.dp))
        Column(verticalArrangement = Arrangement.spacedBy(5.dp)) { Text("Pelit", fontSize = 32.sp, fontWeight = FontWeight.Bold); Text("Klassikot omalla korttipakalla.", color = Quiet, fontSize = 17.sp) }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            StatTile("VOITOT", wins, Color(0xFF297448), Modifier.weight(1f))
            StatTile("TAPPiot".uppercase(), losses, if (wins + losses == 0) Quiet else Color(0xFF9B3E42), Modifier.weight(1f))
        }
        MenuAction("Luo huone", "Valitse peli ja kutsu ystävät.", "＋", onHost)
        MenuAction("Liity peliin", "Skannaa QR-koodi tai syötä huonekoodi.", "⌗", onJoin)
        ElevatedCard(onClick = onQuickHost, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(20.dp), colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface), elevation = CardDefaults.elevatedCardElevation(defaultElevation = 1.dp)) {
            Row(Modifier.padding(18.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.SportsEsports, null, tint = Wine, modifier = Modifier.size(25.dp))
                Column(Modifier.weight(1f).padding(horizontal = 14.dp)) { Text("Pikaisäntä", fontWeight = FontWeight.SemiBold, fontSize = 17.sp); Text("Kakkahousu · 7-kortin sääntö", color = Quiet, fontSize = 14.sp) }
                Icon(Icons.AutoMirrored.Filled.ArrowForward, null, tint = Quiet)
            }
        }
        Spacer(Modifier.weight(1f))
        if (userName.isBlank()) TextButton(onClick = onAuth, modifier = Modifier.align(Alignment.CenterHorizontally)) { Text("Kirjaudu sisään, niin voit pelata verkossa") }
    }
}

@Composable
private fun StatTile(label: String, count: Int, color: Color, modifier: Modifier) {
    Card(modifier, shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), border = BorderStroke(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f))) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 15.dp, vertical = 13.dp)) { Text(label, fontSize = 10.sp, letterSpacing = 1.4.sp, color = Quiet, fontWeight = FontWeight.Bold); Text(count.toString(), fontSize = 26.sp, fontWeight = FontWeight.SemiBold, color = color) }
    }
}

@Composable
private fun MenuAction(title: String, detail: String, symbol: String, onClick: () -> Unit) {
    ElevatedCard(onClick = onClick, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(20.dp), colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface), elevation = CardDefaults.elevatedCardElevation(defaultElevation = 1.dp)) {
        Row(Modifier.padding(horizontal = 17.dp, vertical = 19.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(symbol, color = Wine, fontSize = 28.sp, fontWeight = FontWeight.Medium, modifier = Modifier.width(42.dp), textAlign = TextAlign.Center)
            Column(Modifier.weight(1f).padding(start = 10.dp)) { Text(title, fontSize = 19.sp, fontWeight = FontWeight.SemiBold); Text(detail, fontSize = 14.sp, color = Quiet) }
            Icon(Icons.AutoMirrored.Filled.ArrowForward, null, tint = Quiet)
        }
    }
}

@Composable
private fun HostScreen(game: GameKind, rule: Int, onBack: () -> Unit, onGame: (GameKind) -> Unit, onRule: (Int) -> Unit, onPractice: () -> Unit, onCreate: () -> Unit, busy: Boolean, message: String) {
    Column(Modifier.fillMaxSize().padding(horizontal = 22.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(15.dp)) {
        PageHeader("Luo peli", onBack)
        Text("Valitse peli", color = Quiet)
        GameChoice(GameKind.KAKKAHOUSU, game == GameKind.KAKKAHOUSU, onClick = { onGame(GameKind.KAKKAHOUSU) })
        GameChoice(GameKind.MUSTA_MAIJA, game == GameKind.MUSTA_MAIJA, onClick = { onGame(GameKind.MUSTA_MAIJA) })
        if (game == GameKind.KAKKAHOUSU) {
            Text("Kuvakortit käyvät vähintään", fontWeight = FontWeight.SemiBold)
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                listOf(7, 8, 9).forEachIndexed { index, number -> SegmentedButton(selected = rule == number, onClick = { onRule(number) }, shape = SegmentedButtonDefaults.itemShape(index, 3)) { Text(number.toString()) } }
            }
        }
        messageBlock(message)
        Spacer(Modifier.weight(1f))
        OutlinedButton(onClick = onPractice, modifier = Modifier.fillMaxWidth().height(54.dp), shape = RoundedCornerShape(18.dp)) { Text("Harjoittele yksin") }
        PrimaryAction("Luo online-huone", busy, onCreate)
    }
}

@Composable
private fun GameChoice(game: GameKind, selected: Boolean, onClick: () -> Unit) {
    val fill by animateColorAsState(if (selected) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surface.copy(alpha = .72f), label = "choice")
    Card(onClick = onClick, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(17.dp), colors = CardDefaults.cardColors(containerColor = fill), border = BorderStroke(1.dp, if (selected) Wine.copy(alpha = .35f) else Ink.copy(alpha = .07f))) {
        Row(Modifier.padding(17.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(if (game == GameKind.KAKKAHOUSU) "♠" else "♣", color = Wine, fontSize = 27.sp, modifier = Modifier.width(40.dp))
            Column(Modifier.weight(1f)) { Text(game.finnish, fontWeight = FontWeight.SemiBold, fontSize = 18.sp); Text(game.subtitle, color = Quiet, fontSize = 14.sp) }
            if (selected) Icon(Icons.Default.Check, null, tint = Wine)
        }
    }
}

@Composable
private fun JoinScreen(code: String, onBack: () -> Unit, onCode: (String) -> Unit, onJoin: () -> Unit, message: String, busy: Boolean) {
    val context = LocalContext.current
    var scan by remember { mutableStateOf(false) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> if (granted) scan = true else onCode(code) }
    Column(Modifier.fillMaxSize().padding(horizontal = 22.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(15.dp)) {
        PageHeader("Liity peliin", onBack)
        ElevatedCard(shape = RoundedCornerShape(22.dp), colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface)) {
            Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("Pelikutsu", fontSize = 21.sp, fontWeight = FontWeight.SemiBold)
                Text("Skannaa hostin QR-koodi tai kirjoita huonekoodi.", color = Quiet)
                if (scan) QRScanner(onCode = { scanned -> onCode(scanned); scan = false })
                else OutlinedButton(onClick = {
                    if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) scan = true
                    else launcher.launch(Manifest.permission.CAMERA)
                }, modifier = Modifier.fillMaxWidth().height(55.dp), shape = RoundedCornerShape(15.dp)) { Icon(Icons.Default.QrCode2, null); Text("  Skannaa QR-koodi") }
                OutlinedTextField(value = code, onValueChange = onCode, modifier = Modifier.fillMaxWidth(), label = { Text("Huonekoodi") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Ascii), shape = RoundedCornerShape(15.dp))
                messageBlock(message)
                PrimaryAction("Liity huoneeseen", busy, onJoin)
            }
        }
    }
}

@Composable
private fun LobbyScreen(room: OnlineRoom, userID: String, onBack: () -> Unit, onCopy: () -> Unit, onStart: () -> Unit, message: String, busy: Boolean) {
    Column(Modifier.fillMaxSize().padding(horizontal = 22.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(15.dp)) {
        PageHeader("Pelihuone", onBack)
        ElevatedCard(shape = RoundedCornerShape(22.dp), colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface)) {
            Column(Modifier.fillMaxWidth().padding(18.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(room.game.finnish, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                if (room.game == GameKind.KAKKAHOUSU) Text("Kuvakortit ${room.kakkahousuFaceCardsMinimum ?: 7} tai suurempi", color = Quiet)
                QRImage("chromehearts://join/${room.code}", 180.dp)
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.clip(RoundedCornerShape(14.dp)).clickable(onClick = onCopy).background(Page).padding(horizontal = 16.dp, vertical = 10.dp)) {
                    Text(room.code, fontSize = 22.sp, fontWeight = FontWeight.Bold, letterSpacing = 3.sp)
                    Icon(Icons.Default.ContentCopy, "Kopioi huonekoodi", modifier = Modifier.padding(start = 12.dp).size(20.dp), tint = Wine)
                }
                Text("Napauta koodia kopioidaksesi sen", fontSize = 13.sp, color = Quiet)
            }
        }
        Text("Pelaajat  ${room.players.size}/6", fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
        room.players.values.forEach { player ->
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.surface).padding(15.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Person, null, tint = Wine)
                Text(player.name, modifier = Modifier.weight(1f).padding(start = 10.dp), fontWeight = FontWeight.Medium)
                if (player.id == room.hostID) Text("ISÄNTÄ", color = Quiet, fontSize = 10.sp, letterSpacing = 1.sp)
                if (player.id == userID) Text("SINÄ", color = Wine, fontSize = 10.sp, modifier = Modifier.padding(start = 8.dp))
            }
        }
        Spacer(Modifier.weight(1f))
        if (room.hostID == userID) PrimaryAction("Aloita peli", busy, onStart) else Text("Odotetaan, että isäntä aloittaa…", modifier = Modifier.fillMaxWidth().padding(16.dp), textAlign = TextAlign.Center, color = Quiet)
        messageBlock(message)
    }
}

@Composable
private fun GameScreen(state: SharedGameState, playerID: String, message: String, selected: Set<String>, dark: Boolean, autoReturnToLobby: Boolean, onToggle: (PlayingCard) -> Unit, onDraw: () -> Unit, onPlay: () -> Unit, onExit: () -> Unit, onRecord: (Boolean) -> Unit, onNewRound: () -> Unit) {
    val context = LocalContext.current
    val stockSize = state.drawPile.size + if (state.maijaTrumpCard == null) 0 else 1
    var previousStockSize by remember(state.roundID) { mutableIntStateOf(stockSize) }
    LaunchedEffect(stockSize) {
        if (stockSize < previousStockSize) playCardSound(context)
        previousStockSize = stockSize
    }
    val hand = state.hands[playerID].orEmpty()
    val current = state.activePlayerID == playerID
    val pending = state.kind == GameKind.KAKKAHOUSU && state.kakkahousuPendingDraw && current
    val mustDraw = state.kind == GameKind.KAKKAHOUSU && current && hand.isNotEmpty() && hand.none { legalKakka(state, it) }
    Column(Modifier.fillMaxSize().padding(horizontal = 17.dp, vertical = 5.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp)) {
            IconButton(onClick = onExit) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Takaisin") }
            Column(Modifier.weight(1f)) { Text(state.kind.finnish, fontWeight = FontWeight.Bold, fontSize = 19.sp); Text(if (state.isOver) "Kierros päättyi" else if (current) "Sinun vuorosi" else "Odotetaan vuoroa", color = Quiet, fontSize = 14.sp) }
            Spacer(Modifier.width(42.dp))
        }
        Row(Modifier.fillMaxWidth().padding(top = 5.dp), horizontalArrangement = Arrangement.SpaceAround, verticalAlignment = Alignment.Top) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.clickable(enabled = current && !state.isOver && (state.drawPile.isNotEmpty() || state.maijaTrumpCard != null), onClick = onDraw)) {
                    if (state.drawPile.isNotEmpty()) CardBack(104.dp, dark)
                    else if (state.maijaTrumpCard == null) EmptySlot(104.dp)
                }
                Spacer(Modifier.height(9.dp)); Text("PAKKA", fontSize = 10.sp, color = Quiet, letterSpacing = 1.3.sp, fontWeight = FontWeight.Bold)
                if (state.maijaTrumpCard != null && state.kind == GameKind.MUSTA_MAIJA) {
                    PlayingCardFace(state.maijaTrumpCard!!, 62.dp, dark, Modifier.graphicsLayer { rotationZ = 90f }.padding(top = 5.dp))
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.clickable(enabled = selected.isNotEmpty() && current && !state.isOver, onClick = onPlay), contentAlignment = Alignment.Center) {
                    if (state.tableCards.isEmpty()) EmptySlot(104.dp) else TableStack(state.tableCards.takeLast(5), 104.dp, dark)
                }
                Spacer(Modifier.height(9.dp)); Text("PÖYTÄ", fontSize = 10.sp, color = Quiet, letterSpacing = 1.3.sp, fontWeight = FontWeight.Bold)
            }
        }
        Spacer(Modifier.height(18.dp))
        val caption = when {
            state.isOver -> if (state.winnerID == playerID) "Sinä voitit kierroksen." else "Kierros päättyi."
            pending -> "Nosta pakasta ennen vuoron vaihtumista."
            mustDraw -> "Kortti ei käy. Nosta pakasta."
            !current -> "Vastustajan vuoro."
            state.kind == GameKind.MUSTA_MAIJA && state.maijaPhase == MaijaPhase.defense -> "Valitse kortit hyökkäyksen kaatamiseksi."
            else -> "Valitse kortit ja pelaa pöytään."
        }
        Text(caption, modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp), textAlign = TextAlign.Center, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
        Spacer(Modifier.height(3.dp))
        Spacer(Modifier.weight(1f))
        if (state.isOver) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp)) {
                Text(if (state.winnerID == playerID) "Voitto" else "Peli päättyi", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                if (state.winnerID == playerID) Text("+1 voitto", color = Color(0xFF297448))
                if (state.winnerID != playerID) Text("+1 tappio", color = Color(0xFF9B3E42))
                if (state.playerOrder.firstOrNull() == playerID) TextButton(onClick = onNewRound) { Text("Uusi kierros") }
            }
        }
        HandFan(hand, selected, current && !state.isOver, dark, onToggle, onPlay)
        Spacer(Modifier.height(3.dp))
        Spacer(Modifier.height(6.dp))
        if (message.isNotBlank()) Text(message, modifier = Modifier.fillMaxWidth().padding(bottom = 5.dp), textAlign = TextAlign.Center, color = Wine, fontSize = 13.sp)
    }
    val context = LocalContext.current
    LaunchedEffect(state.roundID, state.isOver) {
        if (state.isOver && state.winnerID != null) {
            val preferences = context.getSharedPreferences("korttipelit-settings", Context.MODE_PRIVATE)
            val won = state.winnerID == playerID
            val key = if (won) "wins" else "losses"
            if (!preferences.getBoolean("recorded-${state.roundID}-$playerID", false)) {
                preferences.edit().putInt(key, preferences.getInt(key, 0) + 1).putBoolean("recorded-${state.roundID}-$playerID", true).apply()
                onRecord(won)
            }
            if (autoReturnToLobby) {
                delay(2800)
                onNewRound()
            }
        }
    }
}

@Composable
private fun HandFan(hand: List<PlayingCard>, selected: Set<String>, enabled: Boolean, dark: Boolean, onToggle: (PlayingCard) -> Unit, onPlay: () -> Unit) {
    BoxWithConstraints(Modifier.fillMaxWidth().height(190.dp), contentAlignment = Alignment.BottomCenter) {
        if (hand.isNotEmpty()) {
            val density = androidx.compose.ui.platform.LocalDensity.current
            val maxWidthPx = with(density) { maxWidth.toPx() }
            val cardWidthPx = with(density) { ((maxWidth - 12.dp).toPx() / (1f + (hand.size - 1) * .63f)).coerceIn(56.dp.toPx(), 118.dp.toPx()) }
            val width = with(androidx.compose.ui.platform.LocalDensity.current) { cardWidthPx.toDp() }
            val step = cardWidthPx * .63f
            val total = cardWidthPx + (hand.size - 1) * step
            hand.forEachIndexed { index, card ->
                val raised by animateDpAsState(if (card.id in selected) 28.dp else 0.dp, spring(stiffness = Spring.StiffnessMediumLow), label = "select")
                val x = (maxWidthPx - total) / 2f + index * step
                PlayingCardFace(card, width, dark, Modifier.offset { IntOffset((x - maxWidthPx / 2f + cardWidthPx / 2f).roundToInt(), 0) }.offset(y = -raised).shadow(if (card.id in selected) 11.dp else 3.dp, RoundedCornerShape(5.dp)).clickable(enabled = enabled) {
                    onToggle(card)
                }.pointerInput(card.id, enabled) {
                    var drag = 0f
                    detectDragGestures(onDragStart = { drag = 0f }, onDrag = { change, amount -> drag += amount.y; change.consume() }, onDragEnd = { if (drag < -45f && enabled) { if (card.id !in selected) onToggle(card); onPlay() } })
                })
            }
        }
    }
}

@Composable
private fun PlayingCardFace(card: PlayingCard, width: androidx.compose.ui.unit.Dp, dark: Boolean, modifier: Modifier = Modifier) {
    Box(modifier.width(width).height(width / .64f).clip(RoundedCornerShape(5.dp)).background(Color.White), contentAlignment = Alignment.Center) {
        CardArtwork("card_face", Modifier.fillMaxSize(), dark)
        Column(Modifier.fillMaxSize().padding(horizontal = 6.dp, vertical = 5.dp), verticalArrangement = Arrangement.SpaceBetween) {
            CornerMark(card, false)
            CornerMark(card, true, Modifier.align(Alignment.End))
        }
    }
}

@Composable
private fun CornerMark(card: PlayingCard, upsideDown: Boolean, modifier: Modifier = Modifier) {
    Column(modifier.graphicsLayer { if (upsideDown) rotationZ = 180f }, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy((-5).dp)) {
        Text(card.label, fontSize = 16.sp, fontWeight = FontWeight.Black, color = Color.Black, lineHeight = 17.sp)
        Text(card.suit.glyph, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color.Black, lineHeight = 15.sp)
    }
}

@Composable
private fun CardBack(width: androidx.compose.ui.unit.Dp, dark: Boolean) {
    Box(Modifier.width(width).height(width / .64f).clip(RoundedCornerShape(5.dp)).shadow(3.dp).background(Color.Black)) { CardArtwork("card_back", Modifier.fillMaxSize(), dark) }
}

@Composable
private fun EmptySlot(width: androidx.compose.ui.unit.Dp) {
    Box(Modifier.width(width).height(width / .64f).clip(RoundedCornerShape(5.dp)).background(MaterialTheme.colorScheme.surface).then(Modifier), contentAlignment = Alignment.Center) {
        Text("", color = Quiet, fontSize = 12.sp)
    }
}

@Composable
private fun TableStack(cards: List<PlayingCard>, width: androidx.compose.ui.unit.Dp, dark: Boolean) {
    Box(Modifier.width(width).height(width / .64f)) {
        val visible = cards.takeLast(4)
        visible.forEachIndexed { index, card ->
            val relative = index - visible.lastIndex
            PlayingCardFace(card, width, dark, Modifier.align(Alignment.Center).offset(x = (relative * 6).dp, y = (relative * -2).dp).graphicsLayer { rotationZ = relative * 3f })
        }
    }
}

@Composable
private fun CardArtwork(name: String, modifier: Modifier, dark: Boolean) {
    val inverted = androidx.compose.ui.graphics.ColorMatrix(floatArrayOf(-1f, 0f, 0f, 0f, 255f, 0f, -1f, 0f, 0f, 255f, 0f, 0f, -1f, 0f, 255f, 0f, 0f, 0f, 1f, 0f))
    Image(painter = androidx.compose.ui.res.painterResource(if (name == "card_back") R.drawable.card_back else R.drawable.card_face), contentDescription = null, modifier = modifier, contentScale = androidx.compose.ui.layout.ContentScale.Crop, colorFilter = if (dark) androidx.compose.ui.graphics.ColorFilter.colorMatrix(inverted) else null)
}

@Composable
private fun BrandPattern(dark: Boolean, modifier: Modifier = Modifier) {
    BoxWithConstraints(modifier) {
        val columns = (maxWidth / 76.dp).toInt() + 2
        val rows = (maxHeight / 76.dp).toInt() + 2
        val tint = if (dark) Color.White.copy(alpha = .075f) else Color(0xFF85868A).copy(alpha = .11f)
        Column {
            repeat(rows) { row ->
                Row(modifier = Modifier.offset(x = if (row % 2 == 0) 0.dp else 36.dp), horizontalArrangement = Arrangement.spacedBy(44.dp)) {
                    repeat(columns) {
                        Image(painter = androidx.compose.ui.res.painterResource(R.drawable.brand_mark), contentDescription = null, modifier = Modifier.size(30.dp).graphicsLayer { rotationZ = 45f; alpha = .8f }, colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(tint))
                    }
                }
                Spacer(Modifier.height(44.dp))
            }
        }
    }
}

@Composable
private fun BrandMark(size: androidx.compose.ui.unit.Dp) {
    val tint = if (MaterialTheme.colorScheme.background == Page) Ink else Color(0xFFF1F0EC)
    Image(painter = androidx.compose.ui.res.painterResource(R.drawable.brand_mark), contentDescription = null, modifier = Modifier.size(size), contentScale = androidx.compose.ui.layout.ContentScale.Fit, colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(tint))
}

@Composable
private fun SettingsScreen(name: String, dark: Boolean, pattern: Boolean, onBack: () -> Unit, onDark: (Boolean) -> Unit, onPattern: (Boolean) -> Unit, onAccount: () -> Unit, onSignOut: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(horizontal = 22.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(13.dp)) {
        PageHeader("Asetukset", onBack)
        ElevatedCard(onClick = onAccount, shape = RoundedCornerShape(20.dp), colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface)) {
            Row(Modifier.fillMaxWidth().padding(18.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(48.dp).clip(CircleShape).background(Page), contentAlignment = Alignment.Center) { Icon(Icons.Default.Person, null, tint = Wine, modifier = Modifier.size(28.dp)) }
                Column(Modifier.weight(1f).padding(start = 13.dp)) { Text(name.ifBlank { "Tili" }, fontWeight = FontWeight.SemiBold, fontSize = 17.sp); Text(if (name.isBlank()) "Kirjaudu sisään" else "Tili ja kirjautuminen", color = Quiet, fontSize = 14.sp) }
                Icon(Icons.AutoMirrored.Filled.ArrowForward, null, tint = Quiet)
            }
        }
        Text("ULKOASU", fontWeight = FontWeight.Bold, fontSize = 11.sp, letterSpacing = 1.4.sp, color = Quiet, modifier = Modifier.padding(start = 5.dp, top = 5.dp))
        SettingRow("Tumma tila", "Korttien kuvat mukautuvat tilaan", Icons.Default.DarkMode, dark, onDark)
        SettingRow("Logotausta", "Hienovarainen kuvio pelinäkymässä", Icons.Default.ExpandMore, pattern, onPattern)
        Spacer(Modifier.weight(1f))
        if (name.isNotBlank()) OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(16.dp)) { Text("Kirjaudu ulos") }
    }
}

@Composable
private fun SettingRow(title: String, detail: String, icon: androidx.compose.ui.graphics.vector.ImageVector, checked: Boolean, onChecked: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(17.dp)).background(MaterialTheme.colorScheme.surface).padding(horizontal = 15.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = Wine)
        Column(Modifier.weight(1f).padding(horizontal = 12.dp)) { Text(title, fontWeight = FontWeight.Medium); Text(detail, fontSize = 12.sp, color = Quiet) }
        Switch(checked, onCheckedChange = onChecked)
    }
}

@Composable
private fun AuthScreen(email: String, password: String, signup: Boolean, name: String, busy: Boolean, message: String, onBack: () -> Unit, onEmail: (String) -> Unit, onPassword: (String) -> Unit, onName: (String) -> Unit, onMode: () -> Unit, onSubmit: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(horizontal = 22.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        PageHeader("Tili", onBack)
        ElevatedCard(shape = RoundedCornerShape(22.dp), colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface)) {
            Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(if (signup) "Luo tili" else "Kirjaudu sisään", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text("Tili tarvitaan online-peliin. Kirjautuminen säilyy laitteella.", color = Quiet)
                if (signup) OutlinedTextField(name, onName, modifier = Modifier.fillMaxWidth(), label = { Text("Pelaajanimi") }, singleLine = true, shape = RoundedCornerShape(14.dp))
                OutlinedTextField(email, onEmail, modifier = Modifier.fillMaxWidth(), label = { Text("Sähköposti") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email), shape = RoundedCornerShape(14.dp))
                OutlinedTextField(password, onPassword, modifier = Modifier.fillMaxWidth(), label = { Text("Salasana") }, singleLine = true, visualTransformation = PasswordVisualTransformation(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password), shape = RoundedCornerShape(14.dp))
                messageBlock(message)
                PrimaryAction(if (signup) "Luo tili" else "Kirjaudu", busy, onSubmit)
                TextButton(onClick = onMode, modifier = Modifier.align(Alignment.CenterHorizontally)) { Text(if (signup) "Minulla on jo tili" else "Luo uusi tili") }
            }
        }
    }
}

@Composable
private fun QRScanner(onCode: (String) -> Unit) {
    val lifecycleOwner = LocalLifecycleOwner.current
    val alreadyScanned = remember { AtomicBoolean(false) }
    AndroidView(factory = { context ->
        val previewView = PreviewView(context).apply { scaleType = PreviewView.ScaleType.FILL_CENTER }
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            val provider = cameraProviderFuture.get()
            val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
            val options = BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE).build()
            val scanner = BarcodeScanning.getClient(options)
            val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
            val executor = Executors.newSingleThreadExecutor()
            analysis.setAnalyzer(executor) { imageProxy ->
                val mediaImage = imageProxy.image
                if (mediaImage == null) imageProxy.close() else {
                    val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                    scanner.process(image).addOnSuccessListener { codes ->
                        codes.firstOrNull()?.rawValue?.let { raw ->
                            if (alreadyScanned.compareAndSet(false, true)) onCode(raw.substringAfterLast('/').uppercase())
                        }
                    }.addOnCompleteListener { imageProxy.close() }
                }
            }
            try { provider.unbindAll(); provider.bindToLifecycle(lifecycleOwner, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis) } catch (_: Exception) { }
        }, ContextCompat.getMainExecutor(context))
        previewView
    }, modifier = Modifier.fillMaxWidth().height(230.dp).clip(RoundedCornerShape(17.dp)))
}

@Composable
private fun QRImage(value: String, size: androidx.compose.ui.unit.Dp) {
    val bitmap = remember(value) {
        val matrix = QRCodeWriter().encode(value, BarcodeFormat.QR_CODE, 480, 480)
        Bitmap.createBitmap(480, 480, Bitmap.Config.ARGB_8888).apply {
            for (y in 0 until 480) for (x in 0 until 480) setPixel(x, y, if (matrix[x, y]) AndroidColor.BLACK else AndroidColor.WHITE)
        }
    }
    Image(bitmap.asImageBitmap(), contentDescription = "Huoneen QR-koodi", modifier = Modifier.size(size).clip(RoundedCornerShape(10.dp)))
}

@Composable
private fun BottomNav(screen: Screen, onHome: () -> Unit, onSettings: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 28.dp, vertical = 7.dp).clip(RoundedCornerShape(28.dp)).background(MaterialTheme.colorScheme.surface.copy(alpha = .95f)).padding(5.dp), horizontalArrangement = Arrangement.Center) {
        BottomNavItem("Pelit", Icons.Default.SportsEsports, screen == Screen.HOME, Modifier.weight(1f), onHome)
        BottomNavItem("Asetukset", Icons.Default.Settings, screen == Screen.SETTINGS, Modifier.weight(1f), onSettings)
    }
}

@Composable
private fun BottomNavItem(label: String, icon: androidx.compose.ui.graphics.vector.ImageVector, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val color by animateColorAsState(if (selected) MaterialTheme.colorScheme.primary.copy(alpha = .12f) else Color.Transparent, label = "nav")
    Column(modifier.clip(RoundedCornerShape(23.dp)).background(color).clickable(onClick = onClick).padding(vertical = 6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(icon, null, modifier = Modifier.size(21.dp), tint = if (selected) Wine else Ink)
        Text(label, fontSize = 11.sp, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal)
    }
}

@Composable
private fun PageHeader(title: String, onBack: () -> Unit) {
    Row(Modifier.fillMaxWidth().height(49.dp), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onBack, modifier = Modifier.size(42.dp).clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.surface)) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Takaisin") }
        Text(title, fontSize = 21.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 13.dp))
    }
}

@Composable
private fun PrimaryAction(label: String, busy: Boolean, onClick: () -> Unit) {
    Button(onClick = onClick, enabled = !busy, modifier = Modifier.fillMaxWidth().height(54.dp), shape = RoundedCornerShape(16.dp), colors = ButtonDefaults.buttonColors(containerColor = Ink, contentColor = Color.White)) {
        if (busy) CircularProgressIndicator(Modifier.size(19.dp), color = Color.White, strokeWidth = 2.dp) else Text(label, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
    }
}

@Composable
private fun messageBlock(message: String = "") {
    if (message.isNotBlank()) Text(message, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center, color = Wine, fontSize = 13.sp)
}

private fun copy(context: Context, value: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("Huonekoodi", value))
}

private fun playCardSound(context: Context) {
    runCatching {
        MediaPlayer.create(context, R.raw.card_swap)?.also { player ->
            player.setOnCompletionListener { it.release() }
            player.start()
        }
    }
}

private fun newGameState(kind: GameKind, ids: MutableList<String>, host: String, faceMinimum: Int): SharedGameState {
    val order = (listOf(host) + ids.filter { it != host }).distinct().toMutableList()
    var deck = PlayingCard.deck().toMutableList()
    val hands = order.associateWith { mutableListOf<PlayingCard>() }.toMutableMap()
    repeat(5) { order.forEach { id -> if (deck.isNotEmpty()) hands.getValue(id).add(deck.removeAt(0)) } }
    var trump: Suit? = null
    var trumpCard: PlayingCard? = null
    if (kind == GameKind.MUSTA_MAIJA) {
        val index = deck.indexOfLast { it.suit != Suit.spades }
        if (index >= 0) { trumpCard = deck.removeAt(index); trump = trumpCard.suit }
    }
    val active = if (kind == GameKind.MUSTA_MAIJA && order.size > 1) order[1] else order.minByOrNull { id -> hands[id].orEmpty().minOfOrNull { if (it.rank == 2) 15 else it.strength } ?: Int.MAX_VALUE } ?: host
    val activeIndex = order.indexOf(active)
    return SharedGameState(
        kind = kind, playerOrder = order, activePlayerID = active, hands = hands,
        drawPile = deck, tableCards = mutableListOf(), kakkahousuRules = KakkahousuRules(faceMinimum, 5),
        maijaAttackerID = if (kind == GameKind.MUSTA_MAIJA) active else null,
        maijaDefenderID = if (kind == GameKind.MUSTA_MAIJA && order.size > 1) order[(activeIndex + 1) % order.size] else null,
        maijaTrump = trump, maijaTrumpCard = trumpCard
    )
}

private fun copyState(source: SharedGameState) = SharedGameState(
    roundID = source.roundID, kind = source.kind, playerOrder = source.playerOrder.toMutableList(), activePlayerID = source.activePlayerID,
    hands = source.hands.mapValues { it.value.toMutableList() }.toMutableMap(), drawPile = source.drawPile.toMutableList(),
    tableCards = source.tableCards.toMutableList(), isOver = source.isOver, winnerID = source.winnerID,
    kakkahousuRules = source.kakkahousuRules.copy(), maijaPhase = source.maijaPhase,
    maijaAttackerID = source.maijaAttackerID, maijaDefenderID = source.maijaDefenderID, maijaTrump = source.maijaTrump,
    maijaTrumpCard = source.maijaTrumpCard, maijaDiscardCount = source.maijaDiscardCount,
    kakkahousuPendingDraw = source.kakkahousuPendingDraw
)

private fun nextPlayer(state: SharedGameState, id: String): String {
    val index = state.playerOrder.indexOf(id).coerceAtLeast(0)
    for (offset in 1..state.playerOrder.size) {
        val candidate = state.playerOrder[(index + offset) % state.playerOrder.size]
        if (state.drawPile.isNotEmpty() || state.maijaTrumpCard != null || state.hands[candidate].orEmpty().isNotEmpty()) return candidate
    }
    return id
}

private fun drawOne(state: SharedGameState, hand: MutableList<PlayingCard>) {
    if (state.drawPile.isNotEmpty()) hand.add(state.drawPile.removeAt(0))
    else state.maijaTrumpCard?.let { hand.add(it); state.maijaTrumpCard = null }
}

private fun legalKakka(state: SharedGameState, card: PlayingCard): Boolean {
    val top = state.tableCards.lastOrNull()?.rank ?: return true
    val rank = card.rank
    val minimum = state.kakkahousuRules.faceCardsMinimum
    if (rank == 2) return top != 10 && top != 1
    if (top == 2) return rank == 2
    if (top == 10) return rank == 10
    if (top == 1) return rank == 1
    if (rank == 10) return top in 3..9
    if (rank == 1) return top in 11..13
    if (rank in 11..13) return top >= minimum && rank >= top
    return rank in 3..9 && top in 3..9 && rank >= top
}

private fun playCards(state: SharedGameState, player: String, chosen: List<PlayingCard>): String? {
    if (player != state.activePlayerID) return "Odota omaa vuoroasi."
    if (chosen.isEmpty()) return "Valitse kortit ensin."
    val hand = state.hands[player] ?: return "Kättä ei löytynyt."
    if (chosen.any { it !in hand }) return "Valittua korttia ei löytynyt kädestä."
    if (state.kind == GameKind.KAKKAHOUSU) {
        if (chosen.size > 4 || chosen.any { it.rank != chosen.first().rank }) return "Pelaa enintään neljä samanarvoista korttia."
        if (!legalKakka(state, chosen.first())) return "Tämä kortti ei käy pöydän päälle."
        hand.removeAll(chosen.toSet())
        val rank = chosen.first().rank
        val top = state.tableCards.lastOrNull()?.rank
        val clear = (chosen.size == 4 && rank != 2) || (rank == 10 && top != null && top in 3..9) || (rank == 1 && top != null && top in 11..13)
        if (clear) state.tableCards.clear() else state.tableCards.addAll(chosen)
        if (hand.isEmpty() && state.drawPile.isEmpty()) { state.isOver = true; state.winnerID = player; return null }
        state.kakkahousuPendingDraw = state.drawPile.isNotEmpty() && hand.size < 5
        if (!state.kakkahousuPendingDraw) state.activePlayerID = nextPlayer(state, player)
        return null
    }
    if (state.maijaPhase == MaijaPhase.attack) {
        val defender = state.maijaDefenderID ?: return "Puolustajaa ei ole."
        if (chosen.size > (state.hands[defender]?.size ?: 0)) return "Kortteja ei voi hyökätä puolustajan käsiä enempää."
        if (chosen.any { it.blackMaija } || chosen.map { it.suit }.distinct().size > 1) return "Hyökkää saman maan korteilla (patarouvaa ei pelata)."
        hand.removeAll(chosen.toSet()); state.tableCards = chosen.toMutableList(); state.maijaPhase = MaijaPhase.defense; state.activePlayerID = defender
        state.maijaAttackerID = player
        return null
    }
    if (chosen.size > state.tableCards.size) return "Kaada pöydästä enintään korttien verran."
    val attacks = state.tableCards.toMutableList()
    for (card in chosen) {
        val index = attacks.indexOfFirst { canBeat(card, it, state.maijaTrump) }
        if (index < 0) return "Valitut kortit eivät kaada hyökkäyskortteja."
        attacks.removeAt(index)
    }
    hand.removeAll(chosen.toSet())
    hand.addAll(attacks)
    val defender = player
    val attacker = state.maijaAttackerID ?: state.playerOrder.first()
    state.tableCards.clear(); state.maijaPhase = MaijaPhase.attack
    state.maijaAttackerID = if (attacks.isEmpty()) nextPlayer(state, attacker) else nextPlayer(state, defender)
    state.maijaDefenderID = nextPlayer(state, state.maijaAttackerID!!)
    val drawIDs = listOf(state.maijaAttackerID, state.maijaDefenderID).distinct()
    drawIDs.forEach { id ->
        val target = state.hands[id] ?: return@forEach
        while (target.size < 5 && (state.drawPile.isNotEmpty() || state.maijaTrumpCard != null)) drawOne(state, target)
    }
    state.activePlayerID = state.maijaAttackerID!!
    maybeFinish(state)
    return null
}

private fun canBeat(response: PlayingCard, attack: PlayingCard, trump: Suit?): Boolean {
    if (response.blackMaija || attack.blackMaija || trump == null) return false
    if (response.suit == trump) return attack.suit != trump || response.strength > attack.strength
    return response.suit == attack.suit && response.strength > attack.strength
}

private fun maybeFinish(state: SharedGameState) {
    if (state.drawPile.isNotEmpty() || state.maijaTrumpCard != null) return
    if (state.kind == GameKind.MUSTA_MAIJA) {
        val active = state.playerOrder.filter { state.hands[it].orEmpty().isNotEmpty() }
        if (active.size <= 1) { state.isOver = true; state.winnerID = state.playerOrder.firstOrNull { it != active.firstOrNull() } }
    }
}

private suspend fun runBot(state: SharedGameState) {
    val bot = "computer"
    if (state.activePlayerID != bot || state.isOver) return
    val hand = state.hands[bot] ?: return
    if (state.kind == GameKind.KAKKAHOUSU) {
        val legal = hand.firstOrNull { legalKakka(state, it) }
        if (legal != null) {
            val batch = hand.filter { it.rank == legal.rank }.take(4)
            playCards(state, bot, batch)
        } else {
            val limit = if (state.kakkahousuPendingDraw) 5 else hand.size + 1
            while (hand.size < limit && state.drawPile.isNotEmpty()) drawOne(state, hand)
            state.kakkahousuPendingDraw = false
            state.activePlayerID = nextPlayer(state, bot)
        }
    } else if (state.maijaPhase == MaijaPhase.attack) {
        val card = hand.firstOrNull { !it.blackMaija }
        if (card != null) playCards(state, bot, listOf(card)) else state.activePlayerID = nextPlayer(state, bot)
    } else {
        val cards = state.tableCards.mapNotNull { attack -> hand.firstOrNull { canBeat(it, attack, state.maijaTrump) } }.distinct()
        if (cards.isNotEmpty()) playCards(state, bot, cards) else {
            val id = state.maijaDefenderID ?: return
            state.hands[id]?.addAll(state.tableCards)
            state.tableCards.clear(); state.maijaPhase = MaijaPhase.attack
            state.maijaAttackerID = nextPlayer(state, id); state.maijaDefenderID = nextPlayer(state, state.maijaAttackerID!!); state.activePlayerID = state.maijaAttackerID!!
        }
    }
}
