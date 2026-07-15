/// fin_labels.dart — Rótulos PT-BR + helpers de exibição do módulo Financeiro.
///
/// Porte de `web/src/lib/financeiro/labels.ts`. O texto/sinal vive aqui; a COR
/// (verde receita / vermelho despesa / tom do chip de status) é resolvida pela
/// UI a partir do [StatusTone] + do `CleanoxColors` (paleta `fin*`).
library;

import 'dart:math' show Random;

import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/formatters/formatters.dart';
import '../../core/models/financeiro.dart';

/* ─────────────────────── rótulos de unions ─────────────────────── */

String tipoLancamentoLabel(TipoLancamento t) =>
    t == TipoLancamento.receita ? 'Receita' : 'Despesa';

String recorrenciaLabel(RecorrenciaTipo r) => switch (r) {
  RecorrenciaTipo.unica => 'Única',
  RecorrenciaTipo.fixa => 'Fixa',
  RecorrenciaTipo.recorrente => 'Recorrente',
  RecorrenciaTipo.parcelada => 'Parcelada',
};

String statusLancamentoLabel(LancamentoStatus s) => switch (s) {
  LancamentoStatus.pago => 'Pago',
  LancamentoStatus.pendente => 'Pendente',
  LancamentoStatus.previsto => 'Previsto',
  LancamentoStatus.emAtraso => 'Em atraso',
};

String origemLabel(OrigemLancamento o) =>
    o == OrigemLancamento.viaOs ? 'Via OS' : 'Manual';

String contaTipoLabel(ContaTipo t) => switch (t) {
  ContaTipo.carteira => 'Carteira',
  ContaTipo.banco => 'Banco',
  ContaTipo.cartao => 'Cartão',
  ContaTipo.caixa => 'Caixa',
};

IconData contaTipoIcon(ContaTipo t) => switch (t) {
  ContaTipo.carteira => Icons.account_balance_wallet_outlined,
  ContaTipo.banco => Icons.account_balance_outlined,
  ContaTipo.cartao => Icons.credit_card_outlined,
  ContaTipo.caixa => Icons.savings_outlined,
};

/* ─────────────────────── valor com sinal ─────────────────────── */

/// Valor COM sinal: receita → +valor, despesa → −valor.
double signedValue(FinLancamento l) =>
    l.tipo == TipoLancamento.receita ? l.valor : -l.valor;

/// Formata o valor JÁ com sinal explícito (+/−) em BRL. A COR é da UI.
/// Ex.: receita 300 → "+R\$ 300,00" · despesa 980 → "−R\$ 980,00".
String formatSigned(FinLancamento l) {
  final sinal = l.tipo == TipoLancamento.receita ? '+' : '−';
  return '$sinal${formatCurrency(l.valor)}';
}

/// Formata um total COM sinal a partir de um número (para `totalDia`, saldos).
String formatSignedValue(double v) {
  final sinal = v < 0 ? '−' : '+';
  return '$sinal${formatCurrency(v.abs())}';
}

/* ─────────────────────── tom semântico do status ─────────────────────── */

enum StatusTone { success, warning, info, error }

StatusTone statusTone(LancamentoStatus s) => switch (s) {
  LancamentoStatus.pago => StatusTone.success,
  LancamentoStatus.pendente => StatusTone.warning,
  LancamentoStatus.previsto => StatusTone.info,
  LancamentoStatus.emAtraso => StatusTone.error,
};

/// Cor do texto/realce de um tom (a partir da paleta de feedback do tema).
Color toneColor(CleanoxColors clx, StatusTone tone) => switch (tone) {
  StatusTone.success => clx.success,
  StatusTone.warning => clx.warning,
  StatusTone.info => clx.info,
  StatusTone.error => clx.error,
};

/// Fundo do chip de um tom.
Color toneBg(CleanoxColors clx, StatusTone tone) => switch (tone) {
  StatusTone.success => clx.successBg,
  StatusTone.warning => clx.warningBg,
  StatusTone.info => clx.infoBg,
  StatusTone.error => clx.errorBg,
};

/// Cor de um tipo de lançamento (receita=verde, despesa=vermelho).
Color tipoColor(CleanoxColors clx, TipoLancamento t) =>
    t == TipoLancamento.receita ? clx.finIncome : clx.finExpense;

/* ─────────────────────── ícones de categoria ─────────────────────── */

/// Catálogo de ícones (chave → Material). Usado no form e na alocação automática.
/// Chaves estáveis gravadas em `fin_categorias.icone`.
const Map<String, IconData> kFinCategoriaIcons = {
  // legado / seed
  'tag': Icons.sell_outlined,
  'cash': Icons.payments_outlined,
  'card': Icons.credit_card_outlined,
  'cart': Icons.shopping_cart_outlined,
  'shopping-cart': Icons.shopping_cart_outlined,
  'home': Icons.home_outlined,
  'car': Icons.directions_car_outlined,
  'tools': Icons.build_outlined,
  'cleaning': Icons.cleaning_services_outlined,
  'people': Icons.groups_outlined,
  'users': Icons.groups_outlined,
  'megaphone': Icons.campaign_outlined,
  'chart': Icons.insights_outlined,
  'gift': Icons.card_giftcard_outlined,
  'health': Icons.favorite_outline_rounded,
  'food': Icons.restaurant_outlined,
  'utensils': Icons.restaurant_outlined,
  'bolt': Icons.bolt_outlined,
  'truck': Icons.local_shipping_outlined,
  'briefcase': Icons.work_outline_rounded,
  'landmark': Icons.account_balance_outlined,
  'banknote': Icons.payments_outlined,
  'monitor': Icons.desktop_windows_outlined,
  'calculator': Icons.calculate_outlined,
  'spray-can': Icons.cleaning_services_outlined,
  'circle-dashed': Icons.circle_outlined,
  'hand-coins': Icons.handshake_outlined,
  'user-check': Icons.person_outline_rounded,
  'plug': Icons.power_outlined,
  'cog': Icons.settings_outlined,
  'palette': Icons.palette_outlined,
  'search': Icons.search_rounded,
  'thumbs-up': Icons.thumb_up_alt_outlined,
  'package': Icons.inventory_2_outlined,
  'flask-conical': Icons.science_outlined,
  'user': Icons.person_outline_rounded,
  'fuel': Icons.local_gas_station_outlined,
  'wrench': Icons.build_outlined,
  // pool extra p/ alocação automática (sem repetir chaves)
  'store': Icons.storefront_outlined,
  'flight': Icons.flight_outlined,
  'school': Icons.school_outlined,
  'pets': Icons.pets_outlined,
  'fitness': Icons.fitness_center_outlined,
  'movie': Icons.movie_outlined,
  'music': Icons.music_note_outlined,
  'phone': Icons.phone_outlined,
  'wifi': Icons.wifi_rounded,
  'cloud': Icons.cloud_outlined,
  'leaf': Icons.eco_outlined,
  'water': Icons.water_drop_outlined,
  'sun': Icons.wb_sunny_outlined,
  'moon': Icons.dark_mode_outlined,
  'star': Icons.star_outline_rounded,
  'flag': Icons.flag_outlined,
  'map': Icons.map_outlined,
  'pin': Icons.place_outlined,
  'key': Icons.key_outlined,
  'lock': Icons.lock_outline_rounded,
  'shield': Icons.shield_outlined,
  'bell': Icons.notifications_outlined,
  'mail': Icons.mail_outline_rounded,
  'camera': Icons.photo_camera_outlined,
  'image': Icons.image_outlined,
  'book': Icons.menu_book_outlined,
  'pen': Icons.edit_outlined,
  'scissors': Icons.content_cut_rounded,
  'hammer': Icons.handyman_outlined,
  'factory': Icons.factory_outlined,
  'beach': Icons.beach_access_outlined,
  'cake': Icons.cake_outlined,
  'coffee': Icons.coffee_outlined,
  'bike': Icons.pedal_bike_outlined,
  'bus': Icons.directions_bus_outlined,
  'train': Icons.train_outlined,
  'boat': Icons.sailing_outlined,
  'rocket': Icons.rocket_launch_outlined,
  'diamond': Icons.diamond_outlined,
  'trophy': Icons.emoji_events_outlined,
  'heart': Icons.favorite_border_rounded,
  'smile': Icons.sentiment_satisfied_alt_outlined,
  'clock': Icons.schedule_rounded,
  'calendar': Icons.calendar_month_outlined,
  'folder': Icons.folder_outlined,
  'link': Icons.link_rounded,
  'globe': Icons.public_rounded,
  'anchor': Icons.anchor_outlined,
  'umbrella': Icons.beach_access_outlined,
  'fire': Icons.local_fire_department_outlined,
  'snow': Icons.ac_unit_rounded,
  'tree': Icons.park_outlined,
  'flower': Icons.local_florist_outlined,
  'apple': Icons.restaurant_outlined,
  'pizza': Icons.local_pizza_outlined,
  'beer': Icons.sports_bar_outlined,
  'baby': Icons.child_care_outlined,
  'dog': Icons.pets_outlined,
  'cat': Icons.cruelty_free_outlined,
  'fish': Icons.set_meal_outlined,
  'bug': Icons.bug_report_outlined,
  'brush': Icons.brush_outlined,
  'print': Icons.print_outlined,
  'code': Icons.code_rounded,
  'database': Icons.storage_rounded,
  'server': Icons.dns_outlined,
  'chip': Icons.memory_rounded,
  'battery': Icons.battery_charging_full_rounded,
  'lightbulb': Icons.lightbulb_outline_rounded,
  'extension': Icons.extension_outlined,
  'widgets': Icons.widgets_outlined,
  'dashboard': Icons.dashboard_outlined,
  'analytics': Icons.analytics_outlined,
  'trending': Icons.trending_up_rounded,
  'savings': Icons.savings_outlined,
  'wallet': Icons.account_balance_wallet_outlined,
  'receipt': Icons.receipt_long_outlined,
  'percent': Icons.percent_rounded,
  'balance': Icons.account_balance_outlined,
  'handshake': Icons.handshake_outlined,
  'groups': Icons.groups_2_outlined,
  'badge': Icons.badge_outlined,
  'work': Icons.work_outline_rounded,
  'construction': Icons.construction_outlined,
  'plumbing': Icons.plumbing_outlined,
  'electric': Icons.electrical_services_outlined,
  'water_damage': Icons.water_damage_outlined,
  'inventory': Icons.inventory_outlined,
  'local_offer': Icons.local_offer_outlined,
  'loyalty': Icons.loyalty_outlined,
  'card_travel': Icons.card_travel_outlined,
  'luggage': Icons.luggage_outlined,
  'hotel': Icons.hotel_outlined,
  'restaurant': Icons.restaurant_menu_outlined,
  'cafe': Icons.local_cafe_outlined,
  'bar': Icons.local_bar_outlined,
  'grocery': Icons.local_grocery_store_outlined,
  'pharmacy': Icons.local_pharmacy_outlined,
  'hospital': Icons.local_hospital_outlined,
  'spa': Icons.spa_outlined,
  'gym': Icons.sports_gymnastics_outlined,
  'soccer': Icons.sports_soccer_outlined,
  'tennis': Icons.sports_tennis_outlined,
  'gaming': Icons.sports_esports_outlined,
  'tv': Icons.tv_outlined,
  'radio': Icons.radio_outlined,
  'headphones': Icons.headphones_outlined,
  'mic': Icons.mic_none_rounded,
  'videocam': Icons.videocam_outlined,
  'photo': Icons.photo_outlined,
  'palette2': Icons.color_lens_outlined,
  'design': Icons.design_services_outlined,
  'architecture': Icons.architecture_outlined,
  'science': Icons.science_outlined,
  'biotech': Icons.biotech_outlined,
  'psychology': Icons.psychology_outlined,
  'public': Icons.travel_explore_outlined,
  'language': Icons.language_rounded,
  'translate': Icons.translate_rounded,
  'history': Icons.history_rounded,
  'update': Icons.update_rounded,
  'sync': Icons.sync_rounded,
  'cloud_done': Icons.cloud_done_outlined,
  'security': Icons.security_rounded,
  'verified': Icons.verified_outlined,
  'policy': Icons.policy_outlined,
  'gavel': Icons.gavel_outlined,
  'balance_scale': Icons.scale_outlined,
  'volunteer': Icons.volunteer_activism_outlined,
  'church': Icons.church_outlined,
  'mosque': Icons.mosque_outlined,
  'temple': Icons.temple_buddhist_outlined,
  'park': Icons.park_outlined,
  'forest': Icons.forest_outlined,
  'waves': Icons.waves_outlined,
  'pool': Icons.pool_outlined,
  'hot_tub': Icons.hot_tub_outlined,
  'bed': Icons.bed_outlined,
  'chair': Icons.chair_outlined,
  'table_bar': Icons.table_bar_outlined,
  'kitchen': Icons.kitchen_outlined,
  'microwave': Icons.microwave_outlined,
  'blender': Icons.blender_outlined,
  'checkroom': Icons.checkroom_outlined,
  'dry_cleaning': Icons.dry_cleaning_outlined,
  'iron': Icons.iron_outlined,
  'washing': Icons.local_laundry_service_outlined,
  'recycling': Icons.recycling_outlined,
  'compost': Icons.compost_outlined,
  'delete': Icons.delete_outline_rounded,
  'archive': Icons.archive_outlined,
  'unarchive': Icons.unarchive_outlined,
  'push_pin': Icons.push_pin_outlined,
  'attach': Icons.attach_file_rounded,
  'folder_open': Icons.folder_open_outlined,
  'description': Icons.description_outlined,
  'article': Icons.article_outlined,
  'newspaper': Icons.newspaper_outlined,
  'menu_book': Icons.menu_book_outlined,
  'auto_stories': Icons.auto_stories_outlined,
  'quiz': Icons.quiz_outlined,
  'school2': Icons.cast_for_education_outlined,
  'toys': Icons.toys_outlined,
  'smart_toy': Icons.smart_toy_outlined,
  'extension2': Icons.extension_outlined,
  'puzzle': Icons.extension_outlined,
  'casino': Icons.casino_outlined,
  'attractions': Icons.attractions_outlined,
  'festival': Icons.festival_outlined,
  'celebration': Icons.celebration_outlined,
  'cake2': Icons.cake_outlined,
  'cookie': Icons.cookie_outlined,
  'icecream': Icons.icecream_outlined,
  'liquor': Icons.liquor_outlined,
  'wine': Icons.wine_bar_outlined,
  'smoking': Icons.smoking_rooms_outlined,
  'medication': Icons.medication_outlined,
  'vaccines': Icons.vaccines_outlined,
  'healing': Icons.healing_outlined,
  'monitor_heart': Icons.monitor_heart_outlined,
  'bloodtype': Icons.bloodtype_outlined,
  'emergency': Icons.emergency_outlined,
  'fire_truck': Icons.fire_truck_outlined,
  'police': Icons.local_police_outlined,
  'military': Icons.military_tech_outlined,
  'engineering': Icons.engineering_outlined,
  'precision': Icons.precision_manufacturing_outlined,
  'handyman': Icons.handyman_outlined,
  'carpenter': Icons.carpenter_outlined,
  'hardware': Icons.hardware_outlined,
  'home_repair': Icons.home_repair_service_outlined,
  'roofing': Icons.roofing_outlined,
  'foundation': Icons.foundation_outlined,
  'apartment': Icons.apartment_outlined,
  'cottage': Icons.cottage_outlined,
  'villa': Icons.villa_outlined,
  'cabin': Icons.cabin_outlined,
  'warehouse': Icons.warehouse_outlined,
  'store_mall': Icons.store_mall_directory_outlined,
  'local_mall': Icons.local_mall_outlined,
  'shop': Icons.shop_outlined,
  'shopping_bag': Icons.shopping_bag_outlined,
  'shopping_basket': Icons.shopping_basket_outlined,
  'add_shopping': Icons.add_shopping_cart_outlined,
  'credit_score': Icons.credit_score_outlined,
  'paid': Icons.paid_outlined,
  'price_check': Icons.price_check_outlined,
  'sell': Icons.sell_outlined,
  'point_of_sale': Icons.point_of_sale_outlined,
  'qr_code': Icons.qr_code_outlined,
  'barcode': Icons.qr_code_scanner_outlined,
  'nfc': Icons.nfc_outlined,
  'contactless': Icons.contactless_outlined,
  'atm': Icons.atm_outlined,
  'currency': Icons.currency_exchange_outlined,
  'attach_money': Icons.attach_money_rounded,
  'euro': Icons.euro_rounded,
  'money': Icons.money_outlined,
  'request_quote': Icons.request_quote_outlined,
  'account_tree': Icons.account_tree_outlined,
  'hub': Icons.hub_outlined,
  'device_hub': Icons.device_hub_outlined,
  'router': Icons.router_outlined,
  'cable': Icons.cable_outlined,
  'usb': Icons.usb_outlined,
  'bluetooth': Icons.bluetooth_outlined,
  'cell_tower': Icons.cell_tower_outlined,
  'satellite': Icons.satellite_alt_outlined,
  'radar': Icons.radar_outlined,
  'speed': Icons.speed_outlined,
  'timer': Icons.timer_outlined,
  'alarm': Icons.alarm_outlined,
  'watch': Icons.watch_outlined,
  'hourglass': Icons.hourglass_empty_rounded,
  'event': Icons.event_outlined,
  'today': Icons.today_outlined,
  'date_range': Icons.date_range_outlined,
  'pending': Icons.pending_outlined,
  'task': Icons.task_alt_outlined,
  'checklist': Icons.checklist_rounded,
  'assignment': Icons.assignment_outlined,
  'note': Icons.note_outlined,
  'sticky_note': Icons.sticky_note_2_outlined,
  'draw': Icons.draw_outlined,
  'gesture': Icons.gesture_outlined,
  'back_hand': Icons.back_hand_outlined,
  'front_hand': Icons.front_hand_outlined,
  'waving_hand': Icons.waving_hand_outlined,
  'thumb_up': Icons.thumb_up_outlined,
  'thumb_down': Icons.thumb_down_outlined,
  'favorite': Icons.favorite_outline_rounded,
  'grade': Icons.grade_outlined,
  'bookmark': Icons.bookmark_border_rounded,
  'label': Icons.label_outline_rounded,
  'category': Icons.category_outlined,
  'interests': Icons.interests_outlined,
  'style': Icons.style_outlined,
  'texture': Icons.texture_outlined,
  'gradient': Icons.gradient_outlined,
  'filter': Icons.filter_vintage_outlined,
  'blur': Icons.blur_on_outlined,
  'opacity': Icons.opacity_outlined,
  'brightness': Icons.brightness_6_outlined,
  'contrast': Icons.contrast_outlined,
  'palette3': Icons.palette_outlined,
  'colorize': Icons.colorize_outlined,
  'format_paint': Icons.format_paint_outlined,
  'brush2': Icons.brush_outlined,
  'auto_fix': Icons.auto_awesome_outlined,
  'edit': Icons.edit_outlined,
  'create': Icons.create_outlined,
  'content_cut': Icons.content_cut_rounded,
  'content_copy': Icons.content_copy_rounded,
  'content_paste': Icons.content_paste_rounded,
  'save': Icons.save_outlined,
  'download': Icons.download_outlined,
  'upload': Icons.upload_outlined,
  'share': Icons.share_outlined,
  'send': Icons.send_outlined,
  'reply': Icons.reply_outlined,
  'forward': Icons.forward_outlined,
  'redo': Icons.redo_rounded,
  'undo': Icons.undo_rounded,
  'refresh': Icons.refresh_rounded,
  'replay': Icons.replay_rounded,
  'play': Icons.play_circle_outline_rounded,
  'pause': Icons.pause_circle_outline_rounded,
  'stop': Icons.stop_circle_outlined,
  'skip': Icons.skip_next_outlined,
  'shuffle': Icons.shuffle_rounded,
  'repeat': Icons.repeat_rounded,
  'volume': Icons.volume_up_outlined,
  'mic2': Icons.mic_outlined,
  'hearing': Icons.hearing_outlined,
  'record_voice': Icons.record_voice_over_outlined,
  'campaign': Icons.campaign_outlined,
  'ads_click': Icons.ads_click_outlined,
  'trending_down': Icons.trending_down_rounded,
  'show_chart': Icons.show_chart_outlined,
  'bar_chart': Icons.bar_chart_rounded,
  'pie_chart': Icons.pie_chart_outline_rounded,
  'donut_large': Icons.donut_large_outlined,
  'scatter_plot': Icons.scatter_plot_outlined,
  'multiline_chart': Icons.multiline_chart_outlined,
  'candlestick': Icons.candlestick_chart_outlined,
  'area_chart': Icons.area_chart_outlined,
  'waterfall': Icons.waterfall_chart_outlined,
  'ssid_chart': Icons.ssid_chart_outlined,
  'stacked_line': Icons.stacked_line_chart_outlined,
  'query_stats': Icons.query_stats_outlined,
  'insights': Icons.insights_outlined,
  'leaderboard': Icons.leaderboard_outlined,
  'emoji_events': Icons.emoji_events_outlined,
  'military_tech': Icons.military_tech_outlined,
  'workspace_premium': Icons.workspace_premium_outlined,
  'verified_user': Icons.verified_user_outlined,
  'admin_panel': Icons.admin_panel_settings_outlined,
  'manage_accounts': Icons.manage_accounts_outlined,
  'supervisor': Icons.supervisor_account_outlined,
  'support_agent': Icons.support_agent_outlined,
  'contact_support': Icons.contact_support_outlined,
  'help': Icons.help_outline_rounded,
  'info': Icons.info_outline_rounded,
  'warning': Icons.warning_amber_rounded,
  'error': Icons.error_outline_rounded,
  'report': Icons.report_outlined,
  'feedback': Icons.feedback_outlined,
  'reviews': Icons.reviews_outlined,
  'rate_review': Icons.rate_review_outlined,
  'thumb_up2': Icons.thumb_up_alt_outlined,
  'recommend': Icons.recommend_outlined,
  'stars': Icons.stars_outlined,
  'auto_awesome': Icons.auto_awesome_outlined,
  'flare': Icons.flare_outlined,
  'wb_twilight': Icons.wb_twilight_outlined,
  'nights_stay': Icons.nights_stay_outlined,
  'bedtime': Icons.bedtime_outlined,
  'light_mode': Icons.light_mode_outlined,
  'dark_mode': Icons.dark_mode_outlined,
  'thermostat': Icons.thermostat_outlined,
  'air': Icons.air_outlined,
  'water_drop': Icons.water_drop_outlined,
  'opacity2': Icons.opacity_outlined,
  'grain': Icons.grain_rounded,
  'landscape': Icons.landscape_outlined,
  'filter_hdr': Icons.filter_hdr_outlined,
  'terrain': Icons.terrain_outlined,
  'map2': Icons.map_outlined,
  'explore': Icons.explore_outlined,
  'compass': Icons.explore_outlined,
  'near_me': Icons.near_me_outlined,
  'my_location': Icons.my_location_outlined,
  'location_city': Icons.location_city_outlined,
  'home_work': Icons.home_work_outlined,
  'business': Icons.business_outlined,
  'domain': Icons.domain_outlined,
  'corporate': Icons.corporate_fare_outlined,
  'meeting': Icons.meeting_room_outlined,
  'desk': Icons.desk_outlined,
  'computer': Icons.computer_outlined,
  'laptop': Icons.laptop_outlined,
  'tablet': Icons.tablet_outlined,
  'phone_iphone': Icons.phone_iphone_outlined,
  'phone_android': Icons.phone_android_outlined,
  'watch2': Icons.watch_outlined,
  'headphones2': Icons.headphones_outlined,
  'speaker': Icons.speaker_outlined,
  'keyboard': Icons.keyboard_outlined,
  'mouse': Icons.mouse_outlined,
  'gamepad': Icons.gamepad_outlined,
  'sports_esports': Icons.sports_esports_outlined,
  'casino2': Icons.casino_outlined,
  'toys2': Icons.toys_outlined,
  'sports': Icons.sports_outlined,
  'sports_baseball': Icons.sports_baseball_outlined,
  'sports_basketball': Icons.sports_basketball_outlined,
  'sports_football': Icons.sports_football_outlined,
  'sports_golf': Icons.sports_golf_outlined,
  'sports_handball': Icons.sports_handball_outlined,
  'sports_hockey': Icons.sports_hockey_outlined,
  'sports_kabaddi': Icons.sports_kabaddi_outlined,
  'sports_mma': Icons.sports_mma_outlined,
  'sports_motorsports': Icons.sports_motorsports_outlined,
  'sports_rugby': Icons.sports_rugby_outlined,
  'sports_volleyball': Icons.sports_volleyball_outlined,
  'skateboarding': Icons.skateboarding_outlined,
  'surfing': Icons.surfing_outlined,
  'snowboarding': Icons.snowboarding_outlined,
  'downhill_skiing': Icons.downhill_skiing_outlined,
  'kayaking': Icons.kayaking_outlined,
  'kitesurfing': Icons.kitesurfing_outlined,
  'paragliding': Icons.paragliding_outlined,
  'scuba': Icons.scuba_diving_outlined,
  'sailing': Icons.sailing_outlined,
  'directions_boat': Icons.directions_boat_outlined,
  'directions_bus': Icons.directions_bus_outlined,
  'directions_car': Icons.directions_car_outlined,
  'directions_railway': Icons.directions_railway_outlined,
  'directions_subway': Icons.directions_subway_outlined,
  'directions_transit': Icons.directions_transit_outlined,
  'directions_walk': Icons.directions_walk_outlined,
  'directions_run': Icons.directions_run_outlined,
  'directions_bike': Icons.directions_bike_outlined,
  'electric_scooter': Icons.electric_scooter_outlined,
  'electric_car': Icons.electric_car_outlined,
  'local_taxi': Icons.local_taxi_outlined,
  'airport_shuttle': Icons.airport_shuttle_outlined,
  'two_wheeler': Icons.two_wheeler_outlined,
  'pedal_bike': Icons.pedal_bike_outlined,
  'moped': Icons.moped_outlined,
  'agriculture': Icons.agriculture_outlined,
  'grass': Icons.grass_outlined,
  'yard': Icons.yard_outlined,
  'fence': Icons.fence_outlined,
  'garage': Icons.garage_outlined,
  'car_rental': Icons.car_rental_outlined,
  'car_repair': Icons.car_repair_outlined,
  'build_circle': Icons.build_circle_outlined,
  'handyman2': Icons.handyman_outlined,
  'plumbing2': Icons.plumbing_outlined,
  'electrical': Icons.electrical_services_outlined,
  'hvac': Icons.hvac_outlined,
  'propane': Icons.propane_tank_outlined,
  'gas_meter': Icons.gas_meter_outlined,
  'water_damage2': Icons.water_damage_outlined,
  'flood': Icons.flood_outlined,
  'thunderstorm': Icons.thunderstorm_outlined,
  'tornado': Icons.tornado_outlined,
  'tsunami': Icons.tsunami_outlined,
  'volcano': Icons.volcano_outlined,
  'landslide': Icons.landslide_outlined,
  'cyclone': Icons.cyclone_outlined,
  'severe_cold': Icons.severe_cold_outlined,
  'heat': Icons.device_thermostat_outlined,
  'ac_unit': Icons.ac_unit_rounded,
  'mode_fan': Icons.air_outlined,
  'air_purifier': Icons.air_outlined,
  'dehumidifier': Icons.water_drop_outlined,
  'humidifier': Icons.water_drop_outlined,
  'iron2': Icons.iron_outlined,
  'checkroom2': Icons.checkroom_outlined,
  'dry': Icons.dry_outlined,
  'soap': Icons.soap_outlined,
  'sanitizer': Icons.sanitizer_outlined,
  'clean_hands': Icons.clean_hands_outlined,
  'self_improvement': Icons.self_improvement_outlined,
  'spa2': Icons.spa_outlined,
  'hot_tub2': Icons.hot_tub_outlined,
  'bathtub': Icons.bathtub_outlined,
  'shower': Icons.shower_outlined,
  'wc': Icons.wc_outlined,
  'door': Icons.door_front_door_outlined,
  'window': Icons.window_outlined,
  'blinds': Icons.blinds_outlined,
  'curtain': Icons.curtains_outlined,
  'chair2': Icons.chair_outlined,
  'bed2': Icons.bed_outlined,
  'weekend': Icons.weekend_outlined,
  'table_restaurant': Icons.table_restaurant_outlined,
  'countertops': Icons.countertops_outlined,
  'kitchen2': Icons.kitchen_outlined,
  'microwave2': Icons.microwave_outlined,
  'oven': Icons.kitchen_outlined,
  'coffee_maker': Icons.coffee_maker_outlined,
  'blender2': Icons.blender_outlined,
  'dining': Icons.dining_outlined,
  'lunch_dining': Icons.lunch_dining_outlined,
  'breakfast': Icons.free_breakfast_outlined,
  'brunch': Icons.brunch_dining_outlined,
  'dinner': Icons.dinner_dining_outlined,
  'nightlife': Icons.nightlife_outlined,
  'liquor2': Icons.liquor_outlined,
  'local_bar': Icons.local_bar_outlined,
  'wine_bar': Icons.wine_bar_outlined,
  'sports_bar': Icons.sports_bar_outlined,
  'emoji_food': Icons.emoji_food_beverage_outlined,
  'fastfood': Icons.fastfood_outlined,
  'ramen': Icons.ramen_dining_outlined,
  'tapas': Icons.tapas_outlined,
  'set_meal': Icons.set_meal_outlined,
  'kebab': Icons.kebab_dining_outlined,
  'egg': Icons.egg_outlined,
  'nutrition': Icons.restaurant_outlined,
};

/// Ícone de uma categoria a partir da chave gravada (fallback: etiqueta).
IconData finCategoriaIcon(String? key) {
  if (key == null || key.isEmpty) return Icons.sell_outlined;
  return kFinCategoriaIcons[key] ??
      kFinCategoriaIcons[key.toLowerCase()] ??
      Icons.sell_outlined;
}

/// Pool de cores bem distintas para raízes (hex #RRGGBB).
const List<String> kFinCategoriaCoresPool = [
  '#EF4444', // red
  '#F97316', // orange
  '#F59E0B', // amber
  '#EAB308', // yellow
  '#84CC16', // lime
  '#22C55E', // green
  '#10B981', // emerald
  '#14B8A6', // teal
  '#06B6D4', // cyan
  '#0EA5E9', // sky
  '#3B82F6', // blue
  '#6366F1', // indigo
  '#8B5CF6', // violet
  '#A855F7', // purple
  '#D946EF', // fuchsia
  '#EC4899', // pink
  '#F43F5E', // rose
  '#0E9F9C', // brand teal
  '#64748B', // slate
  '#78716C', // stone
  '#B45309', // amber dark
  '#065F46', // emerald dark
  '#1D4ED8', // blue dark
  '#7C3AED', // violet dark
  '#BE185D', // pink dark
  '#DC2626', // red dark
  '#EA580C', // orange dark
  '#CA8A04', // yellow dark
  '#4D7C0F', // lime dark
  '#0F766E', // teal dark
  '#0369A1', // sky dark
  '#4338CA', // indigo dark
  '#6D28D9', // purple dark
  '#A21CAF', // fuchsia dark
  '#9F1239', // rose dark
  '#334155', // slate dark
  '#FB7185', // rose light
  '#38BDF8', // sky light
  '#4ADE80', // green light
  '#FBBF24', // amber light
  '#C084FC', // purple light
  '#F472B6', // pink light
  '#2DD4BF', // teal light
  '#818CF8', // indigo light
  '#FB923C', // orange light
  '#A3E635', // lime light
  '#67E8F9', // cyan light
  '#E879F9', // fuchsia light
];

/// codePoint do Material icon da chave (fallback: tag).
int finCategoriaIconCode(String? key) => finCategoriaIcon(key).codePoint;

/// Pool de chaves com **IconData distinto** (1ª chave por codePoint).
/// Evita alocar `cart` e `shopping-cart` (mesmo desenho) em raízes diferentes.
List<String> get kFinCategoriaIconKeys {
  final seen = <int>{};
  final out = <String>[];
  for (final e in kFinCategoriaIcons.entries) {
    if (seen.add(e.value.codePoint)) out.add(e.key);
  }
  return out;
}

String _normCorHex(String? cor) {
  if (cor == null || cor.isEmpty) return kFinCategoriaCoresPool.first;
  final u = cor.trim().toUpperCase();
  return u.startsWith('#') ? u : '#$u';
}

/// Aloca ícone + cor **únicos** entre categorias-raiz existentes.
/// Unicidade do ícone é visual ([IconData.codePoint]), não só da string.
/// Subcategoria: herda ícone e cor da mãe (mesmo símbolo; só o tamanho muda).
({String icone, String cor}) alocarIconeCorCategoria({
  required List<FinCategoria> existentes,
  String? parentId,
  Random? random,
}) {
  final rng = random ?? Random();

  if (parentId != null && parentId.isNotEmpty) {
    FinCategoria? mae;
    for (final c in existentes) {
      if (c.id == parentId) {
        mae = c;
        break;
      }
    }
    final icone = (mae?.icone != null && mae!.icone!.isNotEmpty)
        ? mae.icone!
        : 'tag';
    return (icone: icone, cor: _normCorHex(mae?.cor));
  }

  // Só raízes contam para unicidade (sub herda da mãe).
  final raizes = existentes.where((c) => c.parentId == null).toList();
  final usedCodes = <int>{
    for (final c in raizes)
      if (c.icone != null && c.icone!.isNotEmpty)
        finCategoriaIconCode(c.icone),
  };
  final usedCores = <String>{
    for (final c in raizes)
      if (c.cor != null && c.cor!.isNotEmpty) _normCorHex(c.cor),
  };

  final freeIcons = kFinCategoriaIconKeys
      .where((k) => !usedCodes.contains(finCategoriaIconCode(k)))
      .toList();
  final freeCores = kFinCategoriaCoresPool
      .where((c) => !usedCores.contains(c.toUpperCase()))
      .toList();

  final keys = kFinCategoriaIconKeys;
  final icone = freeIcons.isNotEmpty
      ? freeIcons[rng.nextInt(freeIcons.length)]
      : keys[raizes.length % keys.length];
  final cor = freeCores.isNotEmpty
      ? freeCores[rng.nextInt(freeCores.length)].toUpperCase()
      : kFinCategoriaCoresPool[raizes.length % kFinCategoriaCoresPool.length]
          .toUpperCase();

  return (icone: icone, cor: cor);
}

/// Chip de status pronto (label + cores do tom).
class StatusLancamentoChip extends StatelessWidget {
  const StatusLancamentoChip({
    super.key,
    required this.status,
    this.dense = false,
  });

  final LancamentoStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final clx = context.clx;
    final tone = statusTone(status);
    return ClxChip(
      label: statusLancamentoLabel(status),
      color: toneColor(clx, tone),
      background: toneBg(clx, tone),
      dense: dense,
    );
  }
}
