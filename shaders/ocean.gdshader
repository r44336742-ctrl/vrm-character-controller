shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 water_color_deep : source_color = vec3(0.02, 0.04, 0.08); // Très sombre, presque noir-bleuté
uniform vec3 water_color_shallow : source_color = vec3(0.06, 0.1, 0.15); // Bleu nuit pour les crêtes
uniform vec3 foam_color : source_color = vec3(0.6, 0.7, 0.8); // Écume bleutée/argentée

uniform float time_scale = 0.6;

// Gerstner Wave paramètres : dir X, dir Z, steepness, wavelength
uniform vec4 wave1 = vec4(1.0, 0.5, 0.08, 30.0);
uniform vec4 wave2 = vec4(0.8, 1.2, 0.06, 20.0);
uniform vec4 wave3 = vec4(-0.2, 1.0, 0.04, 12.0);

varying float height;

// Fonction de vague de Gerstner
// Permet d'avoir des crêtes pointues et des creux arrondis (houle réaliste)
vec3 get_gerstner_wave(vec4 wave, vec3 p, inout vec3 tangent, inout vec3 binormal) {
    float steepness = wave.z;
    float wavelength = wave.w;
    float k = 2.0 * 3.14159 / wavelength;
    float c = sqrt(9.8 / k);
    vec2 d = normalize(wave.xy);
    float f = k * (dot(d, p.xz) - c * TIME * time_scale);
    float a = steepness / k;
    
    tangent += vec3(
        -d.x * d.x * (steepness * sin(f)),
        d.x * (steepness * cos(f)),
        -d.x * d.y * (steepness * sin(f))
    );
    binormal += vec3(
        -d.x * d.y * (steepness * sin(f)),
        d.y * (steepness * cos(f)),
        -d.y * d.y * (steepness * sin(f))
    );
    return vec3(
        d.x * (a * cos(f)),
        a * sin(f),
        d.y * (a * cos(f))
    );
}

void vertex() {
    vec3 p = VERTEX;
    vec3 t = vec3(1.0, 0.0, 0.0);
    vec3 b = vec3(0.0, 0.0, 1.0);
    
    vec3 p_offset = vec3(0.0);
    p_offset += get_gerstner_wave(wave1, p, t, b);
    p_offset += get_gerstner_wave(wave2, p, t, b);
    p_offset += get_gerstner_wave(wave3, p, t, b);
    
    VERTEX += p_offset;
    
    // Calcul de la normale réelle à partir de la tangente et binormale perturbées
    NORMAL = normalize(cross(b, t));
    
    height = p_offset.y;
}

void fragment() {
    // Changement de couleur selon la hauteur de la vague
    vec3 color = mix(water_color_deep, water_color_shallow, smoothstep(-0.8, 0.8, height));
    
    // Ajout d'écume sur les crêtes les plus hautes
    float foam_amount = smoothstep(0.6, 1.2, height);
    color = mix(color, foam_color, foam_amount * 0.4); 

    ALBEDO = color;
    
    // L'océan doit refléter la lune : on baisse la rugosité et on augmente la métallicité
    ROUGHNESS = 0.15;
    METALLIC = 0.85;
}
