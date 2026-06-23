shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.01, 0.02, 0.06);
uniform vec3 sky_horizon_color : source_color = vec3(0.04, 0.06, 0.14);
uniform vec3 ground_bottom_color : source_color = vec3(0.0, 0.0, 0.01);
uniform vec3 ground_horizon_color : source_color = vec3(0.02, 0.03, 0.08);

// Moon
uniform vec3 moon_dir = vec3(-0.4, 0.6, -0.7);
uniform vec3 moon_color : source_color = vec3(0.8, 0.85, 1.0);
uniform float moon_size = 0.03;

// Stars
uniform float star_density = 0.985;
uniform float star_intensity = 3.0;

// Clouds
uniform float cloud_speed = 0.005;
uniform vec3 cloud_color_dark : source_color = vec3(0.02, 0.03, 0.06);
uniform vec3 cloud_color_light : source_color = vec3(0.2, 0.3, 0.5);
uniform float cloud_coverage = 0.45;

// Hash functions
float hash13(vec3 p3) {
	p3  = fract(p3 * 0.1031);
    p3 += vec3(dot(p3, p3.yzx + 33.33));
    return fract((p3.x + p3.y) * p3.z);
}

float hash12(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += vec3(dot(p3, p3.yzx + 33.33));
    return fract((p3.x + p3.y) * p3.z);
}

float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i + vec2(0.0, 0.0)), 
                   hash12(i + vec2(1.0, 0.0)), u.x),
               mix(hash12(i + vec2(0.0, 1.0)), 
                   hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 5 octaves FBM for ultra-detailed clouds
float fbm(vec2 p) {
    float f = 0.0;
    float amp = 0.5;
    float sum = 0.0;
    mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
    for(int i = 0; i < 5; i++) {
        f += amp * noise2D(p);
        p = rot * p * 2.02;
        sum += amp;
        amp *= 0.5;
    }
    return f / sum; // Normalized to exactly [0, 1]
}

void sky() {
    vec3 dir = normalize(EYEDIR);
    vec3 moon_d = normalize(moon_dir);
    
    // --- BACKGROUND GRADIENT ---
    float v_angle = dir.y;
    vec3 bg_color = mix(sky_horizon_color, sky_top_color, smoothstep(0.0, 0.5, v_angle));
    if (v_angle < 0.0) {
        bg_color = mix(ground_horizon_color, ground_bottom_color, smoothstep(0.0, -0.5, v_angle));
    }
    
    // --- STARS ---
    vec3 stars = vec3(0.0);
    if (v_angle > 0.0) {
        float h = hash13(dir * 250.0);
        float star_mask = step(star_density, h);
        float twinkle = sin(TIME * 2.0 + h * 100.0) * 0.5 + 0.5;
        // Make some stars bluer, some warmer
        vec3 star_color = mix(vec3(0.8, 0.9, 1.0), vec3(1.0, 0.9, 0.8), hash13(dir * 100.0));
        stars = star_color * star_mask * twinkle * star_intensity;
        
        // Fade stars near horizon
        stars *= smoothstep(0.0, 0.2, v_angle);
    }
    
    // --- MOON ---
    float moon_dist = distance(dir, moon_d);
    float moon_core = 1.0 - smoothstep(moon_size * 0.95, moon_size, moon_dist);
    float moon_glow = (1.0 - smoothstep(0.0, moon_size * 8.0, moon_dist)) * 0.6;
    vec3 moon = moon_color * (moon_core + moon_glow) * 2.0;
    
    vec3 final_color = bg_color + stars + moon;
    
    // --- CLOUDS ---
    if (v_angle > 0.01) { // Clouds only above horizon
        // Planar projection for perspective clouds (Stratus style)
        vec2 cloud_uv = dir.xz / (v_angle + 0.05); 
        
        // Multi-layered scrolling with larger scale to see the details
        vec2 uv1 = cloud_uv * 12.0 + TIME * cloud_speed * vec2(1.0, 0.2);
        vec2 uv2 = cloud_uv * 20.0 + TIME * cloud_speed * vec2(1.3, 0.4);
        
        // Compute FBM
        float n1 = fbm(uv1);
        float n2 = fbm(uv2);
        float n = mix(n1, n2, 0.5);
        
        // Edge fade near horizon
        float horizon_fade = smoothstep(0.01, 0.15, v_angle);
        
        // Density mapping : FBM range is strictly [0, 1]
        // Base threshold on coverage. 0.5 is middle.
        float threshold = 0.5; 
        float cloud_density = smoothstep(threshold, threshold + 0.3, n) * horizon_fade;
        
        // Lighting: clouds near the moon get illuminated
        float moon_cloud_dist = distance(dir, moon_d);
        float moon_lighting = 1.0 - smoothstep(0.0, 0.8, moon_cloud_dist);
        
        // Make the base cloud color slightly lighter than the sky so it's visible even without the moon
        vec3 base_cloud = vec3(0.03, 0.05, 0.10);
        vec3 cloud_col = mix(base_cloud, cloud_color_light, moon_lighting);
        
        // Add a rim light to the clouds from the moon
        float rim = smoothstep(threshold, threshold + 0.1, n) - smoothstep(threshold + 0.1, threshold + 0.3, n);
        cloud_col += moon_color * rim * moon_lighting * 1.5;
        
        // Blend clouds over the sky, but they block stars/moon
        final_color = mix(final_color, cloud_col, cloud_density * 0.95);
    }
    
    COLOR = final_color;
}
