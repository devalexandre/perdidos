shader_type canvas_item;

// Atmosfera viva: raios de sol volumétricos, pulso místico no portal rúnico e água cintilante.
void fragment() {
    vec2 uv = UV;

    // Distorção sutil de ondulação nas águas da cascata e do mar
    float water = smoothstep(0.52, 0.75, uv.y) * smoothstep(0.38, 0.75, uv.x);
    uv.x += sin(uv.y * 70.0 + TIME * 1.1) * 0.0008 * water;
    uv.y += cos(uv.x * 50.0 + TIME * 0.9) * 0.0004 * water;

    vec4 painted = texture(TEXTURE, uv);

    // Raios de sol divinos (god rays) dourados atravessando as nuvens
    vec2 ray_pos = uv - vec2(0.28, -0.05);
    float ray_angle = atan(ray_pos.y, ray_pos.x);
    float ray1 = sin(ray_angle * 16.0 + TIME * 0.09) * 0.5 + 0.5;
    float ray2 = sin(ray_angle * 32.0 - TIME * 0.06) * 0.5 + 0.5;
    float ray_mask = ray1 * ray2 * smoothstep(1.3, 0.15, length(ray_pos)) * (1.0 - uv.y * 0.45);
    vec3 sun_rays = vec3(1.0, 0.92, 0.70) * ray_mask * 0.15;

    // Pulso de energia mística azul-turquesa no portal antigo
    float portal_dist = pow((uv.x - 0.14) * 12.0, 2.0) + pow((uv.y - 0.49) * 6.0, 2.0);
    float portal = exp(-portal_dist);
    float pulse = 0.65 + 0.35 * sin(TIME * 1.4) + 0.15 * sin(TIME * 2.8);
    vec3 portal_glow = vec3(0.20, 0.68, 0.85) * portal * pulse * 0.50;

    // Cintilação suave nas corredeiras da cascata
    float water_sparkle = sin(uv.x * 80.0 + uv.y * 40.0 + TIME * 2.0) * 0.5 + 0.5;
    vec3 water_light = vec3(0.12, 0.28, 0.35) * water * water_sparkle * 0.18;

    painted.rgb += sun_rays + portal_glow + water_light;
    COLOR = painted;
}

