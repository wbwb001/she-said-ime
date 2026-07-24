package com.osfans.trime.ime.feminist

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.LayoutInflater
import android.view.ViewGroup
import android.view.animation.AccelerateInterpolator
import android.widget.FrameLayout
import android.widget.TextView
import com.osfans.trime.R

/**
 * 她说·女性主义输入法 - 键盘内浮动提示气泡
 *
 * 上屏检测到辱女词/教育词后，在候选栏上方弹出一个浮动气泡。
 * 显示时长可自定义，3秒后自动淡出。
 *
 * 不需要 SYSTEM_ALERT_WINDOW 权限，
 * 直接作为 Trime 键盘布局的子 View 添加/移除。
 */
class FeministBubbleView(context: Context) : FrameLayout(context) {

    private var isShowing = false
    private var autoDismissHandler = Handler(Looper.getMainLooper())
    private var dismissRunnable: Runnable? = null
    private var containerView: ViewGroup? = null

    // UI 元素
    private val bubbleRoot: View = LayoutInflater.from(context).inflate(
        R.layout.feminist_toast_bubble, this, false
    )
    private val iconView: TextView = bubbleRoot.findViewById(R.id.bubble_icon)
    private val titleView: TextView = bubbleRoot.findViewById(R.id.bubble_title)
    private val messageView: TextView = bubbleRoot.findViewById(R.id.bubble_message)
    private val dismissButton: TextView = bubbleRoot.findViewById(R.id.bubble_dismiss)

    init {
        setBackgroundColor(android.graphics.Color.TRANSPARENT)
        dismissButton.setOnClickListener { dismiss() }
    }

    /**
     * 显示气泡
     * @param container 父容器（传 Trime 键盘布局的根 View）
     * @param type 类型："severe"/"mild"(橙), "educate"(蓝)
     * @param message 显示文字
     * @param durationMs 显示时长（毫秒），默认3秒
     */
    fun show(
        container: ViewGroup,
        type: String,
        message: String,
        durationMs: Long = 3000L
    ) {
        if (isShowing) dismiss()

        containerView = container

        // 根据类型设置样式
        val iconText: String
        val titleText: String
        when (type) {
            "severe", "mild" -> {
                iconText = "⚠"
                titleText = if (type == "severe") "该词可能有性别歧视色彩" else "建议换个说法"
            }
            "educate" -> {
                iconText = "📖"
                titleText = "这个词有个小知识"
            }
            else -> return
        }

        iconView.text = iconText
        titleView.text = titleText
        messageView.text = message

        val lp = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        container.addView(this, 0, lp)
        isShowing = true

        // 自动淡出
        dismissRunnable = Runnable { fadeOut() }
        autoDismissHandler.postDelayed(dismissRunnable!!, durationMs)
    }

    /**
     * 更新显示时长
     * 后续设置页会调用（用户自定义）
     */
    fun setDuration(millis: Long) {
        FeministWordChecker.bubbleDurationMs = millis
    }

    private fun dismiss() {
        val runnable = dismissRunnable
        if (runnable != null) {
            autoDismissHandler.removeCallbacks(runnable)
            dismissRunnable = null
        }
        if (isShowing && containerView != null) {
            try {
                containerView?.removeView(this)
            } catch (e: Exception) {
                android.util.Log.w("FeministBubble", "dismiss failed: ${e.message}")
            }
            isShowing = false
        }
    }

    private fun fadeOut() {
        // 防止重入：检查容器是否还在
        if (!isShowing) return

        val animator = ValueAnimator.ofFloat(1.0f, 0.0f)
        animator.duration = 300
        animator.interpolator = AccelerateInterpolator()
        animator.addUpdateListener { animation ->
            if (isShowing) {
                bubbleRoot.alpha = animation.animatedValue as Float
            }
        }
        animator.addListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator) {
                dismiss()
            }
            override fun onAnimationCancel(animation: Animator) {
                // 取消时直接移除，不等动画
                if (isShowing) dismiss()
            }
        })
        animator.start()
    }
}
