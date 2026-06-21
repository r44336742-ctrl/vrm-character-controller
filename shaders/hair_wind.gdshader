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
    // ── Hash pseudo-aléatoire par position XZ → variation per-mèche ──
    // Chaque mèche reçoit une amplitude, phase et vitesse uniques
    float hash1 = fract(sin(dot(VERTEX.xz, vec2(127.1, 311.7))) * 43758.5453);
    float hash2 = fract(sin(dot(VERTEX.xz, vec2(269.5, 183.3))) * 76321.1234);
    float hash3 = fract(sin(dot(VERTEX.xz, vec2(420.6, 631.2))) * 28917.8765);

    // Variation per-mèche : amplitude 0.5x à 1.5x, phase 0 à 2π, speed 0.7x à 1.3x
    float amp_var   = 0.5 + hash1;           // [0.5 .. 1.5]
    float phase_var = hash2 * 6.2831;         // [0 .. 2π]
    float speed_var = 0.7 + hash3 * 0.6;      // [0.7 .. 1.3]

    // ── Facteur de hauteur : sommet crâne = 0, pointes pendantes = 1 ──
    vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
    float h = clamp(
        (hair_tip_y - world_pos.y) / max(hair_tip_y - hair_root_y, 0.01),
        0.0, 1.0
    );
    float falloff = h * h;

    // ── Couche 1 : balancement lent (per-mèche) ──
    float slow_x = sin(VERTEX.y * wind_freq_y        + TIME * wind_speed_slow * speed_var + phase_var);
    float slow_z = sin(VERTEX.x * wind_freq_x        + TIME * wind_speed_slow * 0.8 * speed_var + phase_var + 1.3);

    // ── Couche 2 : flutter moyen (per-mèche) ──
    float mid_x  = sin(VERTEX.y * wind_freq_y * 1.6  + TIME * wind_speed_fast * speed_var + phase_var + 0.7);
    float mid_z  = cos(VERTEX.x * wind_freq_x * 1.4  + TIME * wind_speed_fast * 1.2 * speed_var + phase_var + 2.4);

    // ── Couche 3 : micro-vibration (per-mèche) ──
    float micro   = sin(VERTEX.y * wind_freq_y * 3.1  + VERTEX.x * wind_freq_x * 2.3
                        + TIME * wind_speed_fast * 2.7 * speed_var + phase_var + 1.1) * 0.25;

    float disp_x = (slow_x * 0.55 + mid_x * 0.30 + micro) * amp_var;
    float disp_z = (slow_z * 0.55 + mid_z * 0.30 + micro * 0.7) * amp_var;

    // ── Inclinaison due à la vitesse ──
    vec2 vel_xz    = player_velocity.xz;
    float speed    = length(vel_xz);
    float tilt_mag = clamp(speed * speed * 0.004, 0.0, 0.15);
    vec2 tilt_dir  = -normalize(vel_xz + vec2(0.0001));
    vec3 tilt      = vec3(tilt_dir.x, 0.0, tilt_dir.y) * tilt_mag * falloff;

    // ── Déplacement total ──
    vec3 displacement = vec3(disp_x, 0.0, disp_z) * wind_strength * falloff + tilt;

    // ── Anti-clipping : empêcher les cheveux de rentrer dans le corps ──
    // Centre du corps approximé à (0, Y, 0) en model-space
    vec3 new_pos = VERTEX + displacement;
    // Distance du vertex au centre en XZ AVANT et APRÈS displacement
    float dist_before = length(VERTEX.xz);
    float dist_after  = length(new_pos.xz);
    // Si le déplacement rapproche du centre au-delà d'un seuil min → clamp
    float min_radius = max(dist_before * 0.85, 0.02);  // ne jamais aller en dessous de 85% de la distance originale
    if (dist_after < min_radius && dist_after > 0.001) {
        vec2 dir_out = normalize(new_pos.xz);
        new_pos.x = dir_out.x * min_radius;
        new_pos.z = dir_out.y * min_radius;
    }

    VERTEX = new_pos;
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
