import 'package:flutter/material.dart';

/// Maps a plugin manifest's `icon` string to a Material icon. Plugins are
/// data fetched at runtime, so icons are looked up by name rather than
/// shipped as assets — unknown names fall back to a generic plug icon.
IconData pluginIconFor(String? name) {
  switch (name) {
    case 'qr_code_2':
      return Icons.qr_code_2_rounded;
    case 'account_tree':
      return Icons.account_tree_rounded;
    case 'dashboard':
      return Icons.dashboard_rounded;
    case 'show_chart':
      return Icons.show_chart_rounded;
    case 'calendar_month':
      return Icons.calendar_month_rounded;
    case 'cloud':
      return Icons.cloud_rounded;
    case 'table_chart':
      return Icons.table_chart_rounded;
    case 'dns':
      return Icons.dns_rounded;
    case 'mood':
      return Icons.mood_rounded;
    case 'smart_display':
      return Icons.smart_display_rounded;
    case 'rocket_launch':
      return Icons.rocket_launch_rounded;
    case 'location_city':
      return Icons.location_city_rounded;
    case 'ads_click':
      return Icons.ads_click_rounded;
    case 'insights':
      return Icons.insights_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'description':
      return Icons.description_rounded;
    case 'local_grocery_store':
      return Icons.local_grocery_store_rounded;
    case 'speed':
      return Icons.speed_rounded;
    case 'wallet':
      return Icons.wallet_rounded;
    case 'checklist':
      return Icons.checklist_rounded;
    case 'chat':
      return Icons.chat_rounded;
    default:
      return Icons.extension_rounded;
  }
}
