package com.example.luma

import android.app.Activity
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.RemoteViews
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * What the 1x1 plugin widgets draw. Flutter renders each installed plugin's
 * icon on the current accent (lib/app/home_widgets.dart) and syncs it here;
 * widgets read it back without the Flutter engine running.
 */
internal object PluginWidgetStore {
    private const val PREFS = "luma_plugin_widgets"
    private const val KEY_INSTALLED = "installed"
    private const val KEY_NAMES = "names"
    private const val KEY_PENDING = "pending_pin"
    private const val KEY_PENDING_AT = "pending_pin_at"
    private const val WIDGET_PREFIX = "widget_"

    /** How long a pin request from the app may wait for the launcher. */
    private const val PENDING_PIN_MS = 2 * 60 * 1000L

    data class Plugin(val id: String, val name: String)

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun iconDir(context: Context) = File(context.filesDir, "plugin_widgets")

    private fun iconFile(context: Context, id: String) =
        File(iconDir(context), id.replace(Regex("[^A-Za-z0-9_-]"), "_") + ".png")

    /** Installed plugins, in the app's own order, for the picker. */
    fun installed(context: Context): List<Plugin> {
        val names = names(context)
        val ids = JSONArray(prefs(context).getString(KEY_INSTALLED, "[]"))
        return (0 until ids.length()).map { ids.getString(it) }
            .map { Plugin(it, names.optString(it, it)) }
    }

    /** Every plugin ever synced keeps its name, so a widget for a plugin
     *  that was since removed still has a label. */
    private fun names(context: Context) =
        JSONObject(prefs(context).getString(KEY_NAMES, "{}") ?: "{}")

    fun name(context: Context, id: String): String = names(context).optString(id, id)

    fun icon(context: Context, id: String): Bitmap? {
        val file = iconFile(context, id)
        return if (file.exists()) BitmapFactory.decodeFile(file.path) else null
    }

    fun save(context: Context, entries: List<Map<*, *>>) {
        val dir = iconDir(context).apply { mkdirs() }
        val names = names(context)
        val ids = JSONArray()
        for (entry in entries) {
            val id = entry["id"] as? String ?: continue
            val name = entry["name"] as? String ?: id
            val png = entry["png"] as? ByteArray ?: continue
            iconFile(context, id).writeBytes(png)
            names.put(id, name)
            ids.put(id)
        }
        prefs(context).edit()
            .putString(KEY_INSTALLED, ids.toString())
            .putString(KEY_NAMES, names.toString())
            .apply()
        val keep = (0 until ids.length()).map { iconFile(context, ids.getString(it)) } +
            boundPlugins(context).map { iconFile(context, it) }
        dir.listFiles()?.filter { it !in keep }?.forEach { it.delete() }
    }

    fun pluginFor(context: Context, widgetId: Int): String? =
        prefs(context).getString(WIDGET_PREFIX + widgetId, null)

    fun bind(context: Context, widgetId: Int, pluginId: String) {
        prefs(context).edit().putString(WIDGET_PREFIX + widgetId, pluginId).apply()
    }

    fun unbind(context: Context, widgetIds: IntArray) {
        val editor = prefs(context).edit()
        widgetIds.forEach { editor.remove(WIDGET_PREFIX + it) }
        editor.apply()
    }

    private fun boundPlugins(context: Context): Set<String> =
        prefs(context).all.filterKeys { it.startsWith(WIDGET_PREFIX) }
            .values.filterIsInstance<String>().toSet()

    fun setPendingPin(context: Context, pluginId: String) {
        prefs(context).edit()
            .putString(KEY_PENDING, pluginId)
            .putLong(KEY_PENDING_AT, System.currentTimeMillis())
            .apply()
    }

    /** The plugin the app just asked the launcher to pin, if still fresh.
     *  Consumed: whichever of the pin callback or the configure screen comes
     *  first takes it. */
    fun takePendingPin(context: Context): String? {
        val p = prefs(context)
        val id = p.getString(KEY_PENDING, null) ?: return null
        val age = System.currentTimeMillis() - p.getLong(KEY_PENDING_AT, 0)
        p.edit().remove(KEY_PENDING).remove(KEY_PENDING_AT).apply()
        return if (age in 0..PENDING_PIN_MS) id else null
    }
}

/** A 1x1 home-screen tile that opens luma straight onto one plugin. */
class PluginWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        widgetIds.forEach { manager.updateAppWidget(it, views(context, it)) }
    }

    override fun onDeleted(context: Context, widgetIds: IntArray) {
        PluginWidgetStore.unbind(context, widgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_PINNED) {
            val widgetId = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
            val pluginId = intent.getStringExtra(EXTRA_PLUGIN_ID)
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID && pluginId != null) {
                PluginWidgetStore.takePendingPin(context)
                bindAndDraw(context, widgetId, pluginId)
            }
            return
        }
        super.onReceive(context, intent)
    }

    companion object {
        const val ACTION_OPEN_PLUGIN = "com.example.luma.OPEN_PLUGIN"
        const val EXTRA_PLUGIN_ID = "luma_plugin_id"
        private const val ACTION_PINNED = "com.example.luma.PLUGIN_WIDGET_PINNED"

        fun bindAndDraw(context: Context, widgetId: Int, pluginId: String) {
            PluginWidgetStore.bind(context, widgetId, pluginId)
            AppWidgetManager.getInstance(context)
                .updateAppWidget(widgetId, views(context, widgetId))
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PluginWidgetProvider::class.java))
            ids.forEach { manager.updateAppWidget(it, views(context, it)) }
        }

        fun canPin(context: Context): Boolean =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                AppWidgetManager.getInstance(context).isRequestPinAppWidgetSupported

        /** Asks the launcher to place a widget for [pluginId]; the launcher
         *  shows its own confirmation and calls back with the new id. */
        fun requestPin(context: Context, pluginId: String): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
            val manager = AppWidgetManager.getInstance(context)
            if (!manager.isRequestPinAppWidgetSupported) return false
            val callback = PendingIntent.getBroadcast(
                context,
                pluginId.hashCode(),
                Intent(context, PluginWidgetProvider::class.java)
                    .setAction(ACTION_PINNED)
                    .putExtra(EXTRA_PLUGIN_ID, pluginId),
                PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0,
            )
            val extras = Bundle()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                extras.putParcelable(
                    AppWidgetManager.EXTRA_APPWIDGET_PREVIEW,
                    pluginViews(context, pluginId, null),
                )
            }
            PluginWidgetStore.setPendingPin(context, pluginId)
            return manager.requestPinAppWidget(
                ComponentName(context, PluginWidgetProvider::class.java),
                extras,
                callback,
            )
        }

        private fun views(context: Context, widgetId: Int): RemoteViews {
            val pluginId = PluginWidgetStore.pluginFor(context, widgetId)
            if (pluginId != null) return pluginViews(context, pluginId, widgetId)
            // Not set up yet: show luma itself, and let a tap pick the plugin.
            val views = RemoteViews(context.packageName, R.layout.plugin_widget)
            views.setImageViewResource(R.id.plugin_widget_icon, R.mipmap.launcher_icon)
            views.setContentDescription(
                R.id.plugin_widget_icon,
                context.getString(R.string.plugin_widget_pick_title),
            )
            val configure = Intent(context, PluginWidgetConfigActivity::class.java)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                .setData(Uri.parse("luma-widget://configure/$widgetId"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            views.setOnClickPendingIntent(
                R.id.plugin_widget_icon,
                PendingIntent.getActivity(
                    context,
                    widgetId,
                    configure,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            return views
        }

        private fun pluginViews(context: Context, pluginId: String, widgetId: Int?): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.plugin_widget)
            val icon = PluginWidgetStore.icon(context, pluginId)
            if (icon != null) {
                views.setImageViewBitmap(R.id.plugin_widget_icon, icon)
            } else {
                views.setImageViewResource(R.id.plugin_widget_icon, R.mipmap.launcher_icon)
            }
            views.setContentDescription(R.id.plugin_widget_icon, PluginWidgetStore.name(context, pluginId))
            if (widgetId != null) {
                val open = Intent(context, MainActivity::class.java)
                    .setAction(ACTION_OPEN_PLUGIN)
                    .setData(Uri.parse("luma-widget://plugin/$widgetId"))
                    .putExtra(EXTRA_PLUGIN_ID, pluginId)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                views.setOnClickPendingIntent(
                    R.id.plugin_widget_icon,
                    PendingIntent.getActivity(
                        context,
                        widgetId,
                        open,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            return views
        }
    }
}

/**
 * The plugin picker the launcher opens when a widget is added from its
 * widget list (and on reconfigure, or a tap on a widget not yet set up).
 */
class PluginWidgetConfigActivity : Activity() {

    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        // Placed from inside luma: the plugin is already chosen.
        val pending = PluginWidgetStore.takePendingPin(this)
        if (pending != null && PluginWidgetStore.pluginFor(this, widgetId) == null) {
            choose(pending)
            return
        }
        setContentView(buildContent(PluginWidgetStore.installed(this)))
    }

    private fun choose(pluginId: String) {
        PluginWidgetProvider.bindAndDraw(this, widgetId, pluginId)
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        finish()
    }

    private fun dp(value: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        resources.displayMetrics,
    ).toInt()

    private fun buildContent(plugins: List<PluginWidgetStore.Plugin>): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(20), dp(8), dp(12))
        }
        root.addView(TextView(this).apply {
            text = getString(R.string.plugin_widget_pick_title)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            setPadding(dp(16), 0, dp(16), dp(12))
        })
        if (plugins.isEmpty()) {
            root.addView(TextView(this).apply {
                text = getString(R.string.plugin_widget_none)
                setPadding(dp(16), dp(4), dp(16), dp(16))
            })
            return root
        }
        root.addView(
            ListView(this).apply {
                divider = null
                adapter = PluginAdapter(plugins)
                setOnItemClickListener { _, _, position, _ -> choose(plugins[position].id) }
            },
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT),
        )
        return root
    }

    private inner class PluginAdapter(
        private val plugins: List<PluginWidgetStore.Plugin>,
    ) : BaseAdapter() {
        override fun getCount() = plugins.size
        override fun getItem(position: Int) = plugins[position]
        override fun getItemId(position: Int) = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
            val plugin = plugins[position]
            val row = LinearLayout(this@PluginWidgetConfigActivity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(16), dp(10), dp(16), dp(10))
            }
            val icon = ImageView(this@PluginWidgetConfigActivity).apply {
                val bitmap = PluginWidgetStore.icon(context, plugin.id)
                if (bitmap != null) setImageBitmap(bitmap) else setImageResource(R.mipmap.launcher_icon)
            }
            row.addView(icon, LinearLayout.LayoutParams(dp(40), dp(40)))
            row.addView(
                TextView(this@PluginWidgetConfigActivity).apply {
                    text = plugin.name
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                    setPadding(dp(16), 0, 0, 0)
                },
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
            )
            return row
        }
    }
}
