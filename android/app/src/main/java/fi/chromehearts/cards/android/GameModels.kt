package fi.chromehearts.cards.android

import com.google.gson.annotations.SerializedName
import java.util.UUID

enum class Suit(val glyph: String) { spades("♠"), clubs("♣"), diamonds("♦"), hearts("♥") }

data class PlayingCard(val id: String, val suit: Suit, val rank: Int) {
    val label: String get() = when (rank) { 1 -> "A"; 11 -> "J"; 12 -> "Q"; 13 -> "K"; else -> rank.toString() }
    val blackMaija: Boolean get() = suit == Suit.spades && rank == 12
    val strength: Int get() = if (rank == 1) 14 else rank

    companion object {
        fun make(suit: Suit, rank: Int) = PlayingCard("${suit.name}-$rank", suit, rank)
        fun deck() = Suit.entries.flatMap { suit -> (1..13).map { rank -> make(suit, rank) } }.shuffled()
    }
}

enum class GameKind {
    @SerializedName("Kakkahousu") KAKKAHOUSU,
    @SerializedName("Musta Maija") MUSTA_MAIJA;

    val finnish: String get() = when (this) { KAKKAHOUSU -> "Kakkahousu"; MUSTA_MAIJA -> "Musta Maija" }
    val subtitle: String get() = when (this) { KAKKAHOUSU -> "Pelaa, nosta ja vältä viimeistä kättä."; MUSTA_MAIJA -> "Vältä Mustaa Maijaa viimeiseen asti." }
}

data class PlayerInfo(val id: String, val name: String, val handCount: Int = 0)
data class KakkahousuRules(val faceCardsMinimum: Int = 7, val handSize: Int = 5)
enum class MaijaPhase { attack, defense }

data class SharedGameState(
    var roundID: String = UUID.randomUUID().toString(),
    var kind: GameKind,
    var playerOrder: MutableList<String> = mutableListOf(),
    var activePlayerID: String = "",
    var hands: MutableMap<String, MutableList<PlayingCard>> = mutableMapOf(),
    var drawPile: MutableList<PlayingCard> = mutableListOf(),
    var tableCards: MutableList<PlayingCard> = mutableListOf(),
    var isOver: Boolean = false,
    var winnerID: String? = null,
    var kakkahousuRules: KakkahousuRules = KakkahousuRules(),
    var maijaPhase: MaijaPhase = MaijaPhase.attack,
    var maijaAttackerID: String? = null,
    var maijaDefenderID: String? = null,
    var maijaTrump: Suit? = null,
    var maijaTrumpCard: PlayingCard? = null,
    var maijaDiscardCount: Int = 0,
    var kakkahousuPendingDraw: Boolean = false
)

data class OnlineRoom(
    var code: String,
    var game: GameKind,
    var hostID: String,
    var players: MutableMap<String, PlayerInfo> = mutableMapOf(),
    var updatedAt: Double = System.currentTimeMillis() / 1000.0,
    var gameState: SharedGameState? = null,
    var kakkahousuFaceCardsMinimum: Int? = null
)
