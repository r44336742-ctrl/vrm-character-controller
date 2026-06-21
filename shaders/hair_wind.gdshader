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
    // ══════════════════════════════════════════════════════════════════
    // STRAND ID : quantiser la position XZ en grille → mêmes vertices
    // dans une cellule = même mèche = même mouvement.
    // Cellules voisines = mouvement très différent (hash discontinu).
    // ══════════════════════════════════════════════════════════════════
    float cell_size = 0.012;  // ~1.2cm par mèche
    vec2 cell = floor(VERTEX.xz / cell_size);
    float strand_id = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
    float strand_id2 = fract(sin(dot(cell, vec2(269.5, 183.3))) * 76321.1234);
    float strand_id3 = fract(sin(dot(cell, vec2(420.6, 631.2))) * 28917.8765);

    // Variation per-mèche discrète
    float amp_var   = 0.4 + strand_id * 1.2;           // [0.4 .. 1.6]
    float phase_var = strand_id2 * 6.2831;               // [0 .. 2π]
    float speed_var = 0.6 + strand_id3 * 0.8;            // [0.6 .. 1.4]

    // ══════════════════════════════════════════════════════════════════
    // FALLOFF : sommet crâne (Y haut) = 0, pointes pendantes (Y bas) = 1
    // ══════════════════════════════════════════════════════════════════
    vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
    float h = clamp(
        (hair_tip_y - world_pos.y) / max(hair_tip_y - hair_root_y, 0.01),
        0.0, 1.0
    );
    float falloff = h * h;

    // ══════════════════════════════════════════════════════════════════
    // VENT AMBIANT : 3 couches sinusoïdales avec variation per-mèche
    // ══════════════════════════════════════════════════════════════════
    float t = TIME;
    float slow_x = sin(VERTEX.y * wind_freq_y + t * wind_speed_slow * speed_var + phase_var);
    float slow_z = sin(VERTEX.x * wind_freq_x + t * wind_speed_slow * 0.8 * speed_var + phase_var + 1.3);

    float mid_x  = sin(VERTEX.y * wind_freq_y * 1.6 + t * wind_speed_fast * speed_var + phase_var + 0.7);
    float mid_z  = cos(VERTEX.x * wind_freq_x * 1.4 + t * wind_speed_fast * 1.2 * speed_var + phase_var + 2.4);

    float micro = sin(VERTEX.y * wind_freq_y * 3.1 + VERTEX.x * wind_freq_x * 2.3
                      + t * wind_speed_fast * 2.7 * speed_var + phase_var + 1.1) * 0.3;

    float disp_x = (slow_x * 0.55 + mid_x * 0.30 + micro) * amp_var;
    float disp_z = (slow_z * 0.55 + mid_z * 0.30 + micro * 0.7) * amp_var;

    vec3 wind_disp = vec3(disp_x, 0.0, disp_z) * wind_strength * falloff;

    // ══════════════════════════════════════════════════════════════════
    // TILT VITESSE : cheveux en arrière pendant le déplacement
    // ══════════════════════════════════════════════════════════════════
    vec2 vel_xz  = player_velocity.xz;
    float speed  = length(vel_xz);
    float tilt_mag = clamp(speed * speed * 0.008, 0.0, 0.25);
    vec2 tilt_dir = -normalize(vel_xz + vec2(0.0001));
    vec3 tilt = vec3(tilt_dir.x, -0.15 * tilt_mag, tilt_dir.y) * tilt_mag * falloff;

    // ══════════════════════════════════════════════════════════════════
    // DÉPLACEMENT TOTAL
    // ══════════════════════════════════════════════════════════════════
    vec3 displacement = wind_disp + tilt;

    // ══════════════════════════════════════════════════════════════════
    // ANTI-CLIPPING : rejeter la composante du déplacement qui pointe
    // vers l'intérieur du mesh (contre la normale du vertex)
    // ══════════════════════════════════════════════════════════════════
    float inward = dot(displacement, NORMAL);
    if (inward < 0.0) {
        // Retirer la composante qui pénètre dans le corps
        displacement -= NORMAL * inward * 1.2;  // 1.2x pour repousser légèrement
    }

    VERTEX += displacement;
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
