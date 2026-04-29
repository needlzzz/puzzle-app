package com.kaleys.puzzle

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import kotlin.random.Random

/**
 * Generates procedural animal images with emoji + gradient backgrounds.
 * Port of the web app's generateProceduralFallback().
 */
object AnimalImageGenerator {

    data class Animal(
        val name: String,
        val emoji: String,
        val bg: List<Int>
    )

    private val animals = listOf(
        Animal("Lion", "🦁", listOf(0xFFF4A460.toInt(), 0xFFCD853F.toInt(), 0xFFDEB887.toInt())),
        Animal("Elephant", "🐘", listOf(0xFF708090.toInt(), 0xFF778899.toInt(), 0xFFB0C4DE.toInt())),
        Animal("Fox", "🦊", listOf(0xFFFF8C00.toInt(), 0xFFFF6347.toInt(), 0xFFFFD700.toInt())),
        Animal("Dolphin", "🐬", listOf(0xFF00CED1.toInt(), 0xFF1E90FF.toInt(), 0xFF87CEEB.toInt())),
        Animal("Owl", "🦉", listOf(0xFF2E0854.toInt(), 0xFF4B0082.toInt(), 0xFF6A0DAD.toInt())),
        Animal("Penguin", "🐧", listOf(0xFF4682B4.toInt(), 0xFFB0E0E6.toInt(), 0xFFF0F8FF.toInt())),
        Animal("Tiger", "🐯", listOf(0xFFFF8C00.toInt(), 0xFFFF4500.toInt(), 0xFFFFD700.toInt())),
        Animal("Bear", "🐻", listOf(0xFF228B22.toInt(), 0xFF2E8B57.toInt(), 0xFF90EE90.toInt())),
        Animal("Cat", "🐱", listOf(0xFFFF69B4.toInt(), 0xFFFFB6C1.toInt(), 0xFFFFC0CB.toInt())),
        Animal("Wolf", "🐺", listOf(0xFF2F4F4F.toInt(), 0xFF696969.toInt(), 0xFFA9A9A9.toInt())),
    )

    fun generate(width: Int = PuzzleEngine.IMAGE_W, height: Int = PuzzleEngine.IMAGE_H): Bitmap {
        val animal = animals[Random.nextInt(animals.size)]
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Gradient background
        paint.shader = LinearGradient(
            0f, 0f, width.toFloat(), height.toFloat(),
            intArrayOf(animal.bg[0], animal.bg[1], animal.bg[2]),
            floatArrayOf(0f, 0.5f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
        paint.shader = null

        // Decorative circles
        for (i in 0 until 25) {
            val cx = (width * 0.1f) + ((i * 131) % (width * 0.8f).toInt())
            val cy = (height * 0.1f) + ((i * 97) % (height * 0.8f).toInt())
            val radius = 30f + (i * 47 % 70)
            val hue = ((i * 40) % 360).toFloat()
            paint.color = Color.HSVToColor(51, floatArrayOf(hue, 0.6f, 0.65f)) // alpha ~0.2
            canvas.drawCircle(cx, cy, radius, paint)
        }

        // Emoji
        paint.color = Color.BLACK
        paint.textSize = minOf(width, height) * 0.35f
        paint.textAlign = Paint.Align.CENTER
        canvas.drawText(animal.emoji, width / 2f, height * 0.48f, paint)

        // Name
        paint.color = Color.argb(230, 255, 255, 255)
        paint.textSize = height * 0.08f
        paint.isFakeBoldText = true
        canvas.drawText(animal.name, width / 2f, height * 0.8f, paint)
        paint.isFakeBoldText = false

        return bitmap
    }

    fun getAnimalCount(): Int = animals.size
}
