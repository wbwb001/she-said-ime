package com.osfans.trime.ime.feminist

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.serialization.json.Json
import java.io.File

/**
 * 她说·女性主义输入法 - 云端词库同步框架
 *
 * 功能：
 *   1. 记录用户高频词 → 上传到云端
 *   2. 从云端下载更新词频 → 提升联想准确度
 *   3. 用户切输入法时自动同步
 *
 * 性能优化：
 *   - 每次 recordWord 不立即写盘
 *   - 用 Handler 延迟 200ms 写盘（debounce）
 *   - 期间又触发了 recordWord，重置延迟
 *   - 避免每个字都全量写盘
 *
 * 状态：
 *   - 本地缓存：JSON 格式持久化到 cacheDir
 *   - 云端同步：当前是框架，未实现真实网络请求
 *   - SYNC_SERVER 为空时只走本地缓存
 */
object FeministCloudSync {

    private const val TAG = "FeministCloudSync"

    // ========== 配置 ==========
    private var SYNC_SERVER = ""
    private var userId: String = ""
    private const val CACHE_FILE = "feminist_word_freq_cache.json"
    private const val SYNC_INTERVAL_MIN = 30
    private const val DEBOUNCE_MS = 200L

    // ========== 数据结构 ==========

    @kotlinx.serialization.Serializable
    data class WordFreq(
        val word: String,
        val pinyin: String,
        val count: Int = 1,
        val lastUsed: Long = System.currentTimeMillis()
    )

    @kotlinx.serialization.Serializable
    data class CacheData(
        val lastSyncTime: Long = 0L,
        val words: List<WordFreq> = emptyList()
    )

    // ========== 内部状态 ==========

    private val localFreq = mutableMapOf<String, WordFreq>()
    private val saveHandler = Handler(Looper.getMainLooper())
    private val saveRunnable = Runnable { saveLocalCacheImpl() }
    private var cacheDir: File? = null
    private var lastSyncTime: Long = 0L
    private var savePending = false

    // ========== 公开 API ==========

    fun init(context: Context) {
        cacheDir = context.cacheDir
        loadLocalCache()
    }

    /**
     * 记录一个词的使用（带 debounce）
     */
    fun recordWord(word: String, pinyin: String) {
        if (word.isBlank()) return
        synchronized(localFreq) {
            val existing = localFreq[word]
            localFreq[word] = if (existing != null) {
                existing.copy(
                    count = existing.count + 1,
                    lastUsed = System.currentTimeMillis()
                )
            } else {
                WordFreq(
                    word = word,
                    pinyin = pinyin,
                    count = 1,
                    lastUsed = System.currentTimeMillis()
                )
            }
        }
        // 延迟写盘（debounce）
        scheduleSave()
    }

    fun recordWords(words: List<Pair<String, String>>) {
        words.forEach { (word, pinyin) -> recordWord(word, pinyin) }
    }

    fun getTopWords(limit: Int = 100): List<WordFreq> {
        synchronized(localFreq) {
            return localFreq.values
                .sortedByDescending { it.count }
                .take(limit)
        }
    }

    fun syncIfNeeded() {
        if (SYNC_SERVER.isBlank()) return
        if (System.currentTimeMillis() - lastSyncTime < SYNC_INTERVAL_MIN * 60 * 1000L) return
        doSync()
    }

    fun forceSync() {
        if (SYNC_SERVER.isBlank()) return
        doSync()
    }

    /**
     * 强制立即写盘（应用退出前调用）
     */
    fun flushNow() {
        if (savePending) {
            saveHandler.removeCallbacks(saveRunnable)
            saveLocalCacheImpl()
        }
    }

    // ========== 内部：debounce 写盘 ==========

    private fun scheduleSave() {
        savePending = true
        saveHandler.removeCallbacks(saveRunnable)
        saveHandler.postDelayed(saveRunnable, DEBOUNCE_MS)
    }

    private fun saveLocalCacheImpl() {
        val dir = cacheDir ?: return
        val snapshot = synchronized(localFreq) {
            CacheData(
                lastSyncTime = lastSyncTime,
                words = localFreq.values.toList()
            )
        }
        try {
            val json = Json.encodeToString(CacheData.serializer(), snapshot)
            val f = File(dir, CACHE_FILE)
            f.writeText(json)
            savePending = false
        } catch (e: Exception) {
            Log.e(TAG, "saveLocalCache failed: ${e.message}")
        }
    }

    private fun loadLocalCache() {
        val dir = cacheDir ?: return
        try {
            val f = File(dir, CACHE_FILE)
            if (!f.exists()) return
            val json = f.readText()
            val data = Json.decodeFromString(CacheData.serializer(), json)
            lastSyncTime = data.lastSyncTime
            synchronized(localFreq) {
                localFreq.clear()
                data.words.forEach { localFreq[it.word] = it }
            }
        } catch (e: Exception) {
            Log.e(TAG, "loadLocalCache failed: ${e.message}")
        }
    }

    // ========== 云端同步（占位） ==========

    private fun doSync() {
        // 框架占位：未来对接真实 API
        // 当前：仅记录时间戳，避免每次都触发
        lastSyncTime = System.currentTimeMillis()
        scheduleSave()
    }
}
