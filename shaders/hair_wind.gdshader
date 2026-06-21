shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// ── Propriétés du matériau VRM original (copiées au runtime) ──
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4     albedo_color   : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float    roughness      : hint_range(0.0, 1.0) = 0.9;
uniform float    metallic       : hint_range(0.0, 1.0) = 0.0;
uniform float    alpha_scissor  : hint_range(0.0, 1.0, 0.001) = 0.25;

// ── Paramètres du vent vertex ──
uniform float wind_strength   : hint_range(0.0, 0.12) = 0.022;  // déplacement max en mètres
uniform float wind_speed_slow : hint_range(0.0, 4.0)  = 0.75;   // fréquence temporelle lente
uniform float wind_speed_fast : hint_range(0.0, 8.0)  = 2.20;   // fréquence temporelle rapide
uniform float wind_freq_y     : hint_range(0.0, 60.0) = 18.0;   // fréquence spatiale Y
uniform float wind_freq_x     : hint_range(0.0, 60.0) = 12.0;   // fréquence spatiale X
uniform float hair_root_y     : hint_range(0.0, 3.0)  = 1.20;   // Y racines cheveux
uniform float hair_tip_y      : hint_range(0.0, 3.0)  = 1.81;   // Y pointes cheveux

// ── Vitesse du joueur (mis à jour depuis vroid_controller.gd) ──
global uniform vec3 player_velocity;

void vertex() {
    // ── Facteur de hauteur : 0 aux racines → 1 aux pointes (quadratique) ──
    vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
    float h = clamp(
        (world_pos.y - hair_root_y) / max(hair_tip_y - hair_root_y, 0.01),
        0.0, 1.0
    );
    float falloff = h * h;

    // ── Couche 1 : balancement lent ──
    float slow_x = sin(VERTEX.y * wind_freq_y        + TIME * wind_speed_slow);
    float slow_z = sin(VERTEX.x * wind_freq_x        + TIME * wind_speed_slow * 0.8 + 1.3);

    // ── Couche 2 : flutter moyen ──
    float mid_x  = sin(VERTEX.y * wind_freq_y * 1.6  + TIME * wind_speed_fast + 0.7);
    float mid_z  = cos(VERTEX.x * wind_freq_x * 1.4  + TIME * wind_speed_fast * 1.2 + 2.4);

    // ── Couche 3 : micro-vibration ──
    float micro   = sin(VERTEX.y * wind_freq_y * 3.1  + VERTEX.x * wind_freq_x * 2.3
                        + TIME * wind_speed_fast * 2.7 + 1.1) * 0.25;

    float disp_x = slow_x * 0.55 + mid_x * 0.30 + micro;
    float disp_z = slow_z * 0.55 + mid_z * 0.30 + micro * 0.7;

    // ── Inclinaison due à la vitesse (cheveux partent en arrière) ──
    // Seulement XZ (pas de mouvement vertical)
    vec2 vel_xz    = player_velocity.xz;
    float speed    = length(vel_xz);
    // Tilt quadratique : doux en walk, fort en sprint
    // walk ≈ 3 m/s → 0.027m   sprint ≈ 6 m/s → 0.054m aux pointes
    float tilt_mag = clamp(speed * speed * 0.0015, 0.0, 0.07);
    // Direction INVERSE du mouvement → les cheveux traînent derrière
    vec2 tilt_dir  = -normalize(vel_xz + vec2(0.0001));
    vec3 tilt      = vec3(tilt_dir.x, 0.0, tilt_dir.y) * tilt_mag * falloff;

    VERTEX += vec3(disp_x, 0.0, disp_z) * wind_strength * falloff + tilt;
}

void fragment() {
    vec4 tex = texture(albedo_tex, UV);
    ALBEDO = tex.rgb * albedo_color.rgb;
    float a = tex.a * albedo_color.a;
    if (a < alpha_scissor) { discard; }
    ALPHA     = a;
    ROUGHNESS = roughness;
    METALLIC  = metallic;
}
