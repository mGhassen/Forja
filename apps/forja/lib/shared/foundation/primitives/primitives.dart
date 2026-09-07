/// App-wide UI primitives — tokens, shell scope, buttons, chips, kit leaf atoms.
///
/// Domains: [tokens] · [shell] · [controls] · [feedback] · [chrome] · [brand] ·
/// [desktop] · [tv].
///
/// Import this for visual atoms. Prefer this over importing `foundation.dart`
/// when you only need chrome (avoids pulling hub protocol/kit composers).
library;

export 'tokens/forja_details_tokens.dart';
export 'tokens/forja_settings_tokens.dart';
export 'tokens/forja_shell_colors.dart';
export 'tokens/forja_shell_tokens.dart';
export 'tokens/forja_theme.dart';

export 'shell/forja_shell_input_policy.dart';
export 'shell/forja_shell_keyboard_focus.dart';
export 'shell/forja_shell_keyboard_focus_scope.dart';
export 'shell/forja_shell_layout.dart';
export 'shell/forja_shell_metrics.dart';
export 'shell/forja_shell_platform.dart';
export 'shell/forja_shell_profile.dart';
export 'shell/forja_shell_scope.dart';
export 'shell/forja_shell_section_title.dart';
export 'shell/forja_shell_tab_header.dart';

export 'controls/forja_action_chip.dart';
export 'controls/forja_button.dart';
export 'controls/forja_buttons.dart';
export 'controls/forja_chip_row.dart';
export 'controls/forja_shell_chip.dart';
export 'controls/forja_status_tabs.dart';
export 'controls/forja_switch.dart';
export 'controls/forja_underline_tab.dart';

export 'feedback/forja_fractal_glass_gradient.dart';
export 'feedback/forja_frosted_panel.dart';
export 'feedback/forja_loading_dots.dart';
export 'feedback/forja_player_overlay.dart';
export 'feedback/forja_toast.dart';

export 'brand/animated_logo.dart';
export 'brand/forja_logo.dart';
export 'brand/forja_profile_avatar.dart';

export 'chrome/forja_network_image.dart';
export 'chrome/forja_poster_card.dart';
export 'chrome/forja_server_grid.dart';
export 'chrome/horizontal_scroller.dart';
export 'chrome/hover_scale.dart';
export 'chrome/loading_overlay.dart';
export 'chrome/shell_card_play_overlay.dart';
export 'chrome/shell_error_retry_panel.dart';
export 'chrome/shell_focusable_tap.dart';
export 'chrome/shell_mood_circle.dart';

export 'desktop/desktop_window_chrome.dart';
export 'desktop/desktop_window_focus.dart';
export 'desktop/desktop_window_geometry.dart';

export 'tv/tv_browse_text_field.dart';
export 'tv/tv_search_browse_overlay.dart';
