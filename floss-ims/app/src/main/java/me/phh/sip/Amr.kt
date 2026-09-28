package me.phh.sip

/**
 * AMR (narrowband, 8 kHz) and AMR-WB (wideband, 16 kHz, "HD voice") frames between the storage
 * format MediaCodec produces/consumes (one header byte with FT and Q, then the speech bits, padded
 * to a byte) and the RTP bandwidth-efficient payload (RFC 4867: 4-bit CMR, TOC entries, speech
 * bits back to back). Works for every mode, so rate changes from the network are handled.
 */
object Amr {
    // Speech bits per frame type (3GPP TS 26.101 / 26.201). Index = FT; last entry is SID.
    private val NB_BITS = intArrayOf(95, 103, 118, 134, 148, 159, 204, 244, 39)
    private val WB_BITS = intArrayOf(132, 177, 253, 285, 317, 365, 397, 461, 477, 40)

    // Bit rate per speech mode, for MediaCodec's KEY_BIT_RATE
    private val NB_RATES = intArrayOf(4750, 5150, 5900, 6700, 7400, 7950, 10200, 12200)
    private val WB_RATES = intArrayOf(6600, 8850, 12650, 14250, 15850, 18250, 19850, 23050, 23850)

    const val CMR_NONE = 15

    fun frameBits(wb: Boolean, ft: Int): Int {
        val t = if (wb) WB_BITS else NB_BITS
        return if (ft in t.indices) t[ft] else 0 // 14 = speech lost, 15 = no data
    }

    /** True for speech frames (not SID / no data). */
    fun isSpeech(wb: Boolean, ft: Int) = ft < (if (wb) 9 else 8)

    /** Size of one storage-format frame (header byte + speech bits) with this frame type. */
    fun storageFrameSize(wb: Boolean, ft: Int) = 1 + (frameBits(wb, ft) + 7) / 8

    fun bitRate(wb: Boolean, mode: Int) = (if (wb) WB_RATES else NB_RATES)[mode]

    fun maxMode(wb: Boolean) = if (wb) 8 else 7

    /**
     * Highest mode allowed by an fmtp line's mode-set (e.g. "mode-set=0,1,2"), capped at
     * [preferred]. Without a mode-set every mode is allowed, so [preferred] is used.
     */
    fun modeFromFmtp(fmtp: String?, wb: Boolean, preferred: Int): Int {
        val set = fmtp?.let { Regex("mode-set=([0-9,]+)").find(it)?.groupValues?.get(1) }
            ?.split(",")?.mapNotNull { it.trim().toIntOrNull() }
            ?.filter { it in 0..maxMode(wb) }
        if (set.isNullOrEmpty()) return preferred
        return set.filter { it <= preferred }.maxOrNull() ?: set.min()
    }

    /** RTP payload for one storage-format frame at [off] (bandwidth-efficient, single frame). */
    fun packRtp(cmr: Int, storage: ByteArray, off: Int, wb: Boolean): ByteArray {
        val ft = (storage[off].toInt() shr 3) and 0xf
        val q = (storage[off].toInt() shr 2) and 1
        val bits = frameBits(wb, ft)
        val w = BitWriter()
        w.put(cmr, 4); w.put(0, 1); w.put(ft, 4); w.put(q, 1)
        for (i in 0 until bits) w.put((storage[off + 1 + i / 8].toInt() shr (7 - i % 8)) and 1, 1)
        return w.toByteArray()
    }

    /** RTP payload for a "no data" frame (sent before the call is answered). */
    fun noDataRtp(cmr: Int): ByteArray {
        val w = BitWriter()
        w.put(cmr, 4); w.put(0, 1); w.put(15, 4); w.put(1, 1)
        return w.toByteArray()
    }

    /** Storage-format frames (header byte + speech bits) from a bandwidth-efficient RTP payload. */
    fun unpackRtp(buf: ByteArray, off: Int, len: Int, wb: Boolean): List<ByteArray> {
        val r = BitReader(buf, off, len)
        if (r.remaining() < 4) return emptyList()
        r.get(4) // CMR
        val toc = mutableListOf<Pair<Int, Int>>()
        do {
            if (r.remaining() < 6) return emptyList()
            val f = r.get(1)
            val ft = r.get(4)
            val q = r.get(1)
            toc += ft to q
        } while (f == 1)
        val frames = mutableListOf<ByteArray>()
        for ((ft, q) in toc) {
            val bits = frameBits(wb, ft)
            if (r.remaining() < bits) break
            val frame = ByteArray(1 + (bits + 7) / 8)
            frame[0] = ((ft shl 3) or (q shl 2)).toByte()
            for (i in 0 until bits) {
                if (r.get(1) == 1) frame[1 + i / 8] = (frame[1 + i / 8].toInt() or (0x80 shr (i % 8))).toByte()
            }
            frames += frame
        }
        return frames
    }

    private class BitWriter {
        private val out = java.io.ByteArrayOutputStream()
        private var cur = 0
        private var n = 0
        fun put(value: Int, bits: Int) {
            for (i in bits - 1 downTo 0) {
                cur = (cur shl 1) or ((value shr i) and 1)
                if (++n == 8) { out.write(cur); cur = 0; n = 0 }
            }
        }
        fun toByteArray(): ByteArray {
            if (n > 0) { out.write(cur shl (8 - n)); cur = 0; n = 0 }
            return out.toByteArray()
        }
    }

    private class BitReader(private val buf: ByteArray, private val off: Int, private val len: Int) {
        private var pos = 0 // in bits
        fun remaining() = len * 8 - pos
        fun get(bits: Int): Int {
            var v = 0
            repeat(bits) {
                val b = (buf[off + pos / 8].toInt() shr (7 - pos % 8)) and 1
                v = (v shl 1) or b
                pos++
            }
            return v
        }
    }
}
