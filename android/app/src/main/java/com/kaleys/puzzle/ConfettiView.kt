package com.kaleys.puzzle

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import kotlin.math.max
import kotlin.random.Random

/**
 * Renders a confetti particle animation. Port of the web app's runConfetti().
 */
class ConfettiView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private data class Particle(
        var x: Float,
        var y: Float,
        var vx: Float,
        var vy: Float,
        val size: Float,
        val color: Int,
        var rotation: Float,
        val rotSpeed: Float,
        val gravity: Float,
        var life: Float
    )

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val particles = mutableListOf<Particle>()
    private var frame = 0
    private var running = false

    private val colors = intArrayOf(
        0xFFFF6B6B.toInt(), 0xFF4ECDC4.toInt(), 0xFF45B7D1.toInt(), 0xFF96CEB4.toInt(),
        0xFFFFEAA7.toInt(), 0xFFDDA0DD.toInt(), 0xFFFF8C00.toInt(), 0xFF7B68EE.toInt()
    )

    fun start() {
        particles.clear()
        frame = 0
        running = true

        val cx = width / 2f
        val cy = height / 2f

        for (i in 0 until 200) {
            particles.add(
                Particle(
                    x = cx + (Random.nextFloat() - 0.5f) * 200f,
                    y = cy,
                    vx = (Random.nextFloat() - 0.5f) * 16f,
                    vy = -Random.nextFloat() * 18f - 4f,
                    size = 4f + Random.nextFloat() * 8f,
                    color = colors[Random.nextInt(colors.size)],
                    rotation = Random.nextFloat() * 360f,
                    rotSpeed = (Random.nextFloat() - 0.5f) * 12f,
                    gravity = 0.3f + Random.nextFloat() * 0.2f,
                    life = 1f
                )
            )
        }
        invalidate()
    }

    fun stop() {
        running = false
        particles.clear()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (!running) return

        frame++
        var alive = false

        for (p in particles) {
            if (p.life <= 0f) continue
            alive = true

            p.x += p.vx
            p.y += p.vy
            p.vy += p.gravity
            p.vx *= 0.99f
            p.rotation += p.rotSpeed
            p.life -= 0.005f

            canvas.save()
            canvas.translate(p.x, p.y)
            canvas.rotate(p.rotation)
            paint.color = p.color
            paint.alpha = (max(0f, p.life) * 255).toInt()
            canvas.drawRect(-p.size / 2f, -p.size / 4f, p.size / 2f, p.size / 4f, paint)
            canvas.restore()
        }

        if (alive && frame < 300) {
            invalidate()
        } else {
            running = false
        }
    }
}
