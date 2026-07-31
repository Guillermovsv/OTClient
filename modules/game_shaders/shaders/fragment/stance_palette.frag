uniform sampler2D u_Tex0;
uniform int u_StancePalette;
uniform int u_StanceSpellId;
uniform vec4 u_Color;

varying vec2 v_TexCoord;

vec3 ramp(vec3 c0, vec3 c1, vec3 c2, vec3 c3, vec3 c4, float value)
{
  if (value < 0.20) return mix(c0, c1, value / 0.20);
  if (value < 0.42) return mix(c1, c2, (value - 0.20) / 0.22);
  if (value < 0.68) return mix(c2, c3, (value - 0.42) / 0.26);
  return mix(c3, c4, (value - 0.68) / 0.32);
}

vec3 stanceColor(float luminance)
{
  if (u_StancePalette == 1) {
    return ramp(
      vec3(0.278, 0.133, 0.078),
      vec3(0.604, 0.098, 0.024),
      vec3(0.800, 0.141, 0.024),
      vec3(0.969, 0.408, 0.047),
      vec3(1.000, 0.859, 0.267),
      luminance);
  }

  if (u_StancePalette == 2) {
    // Hell's Core and Rage retain their purple cloud family; beam and wave
    // effects retain the blue/cyan energy family while using the same source
    // luminance progression.
    if (u_StanceSpellId == 24 || u_StanceSpellId == 119) {
      return ramp(
        vec3(0.278, 0.078, 0.298),
        vec3(0.498, 0.098, 0.494),
        vec3(0.702, 0.149, 0.663),
        vec3(0.851, 0.478, 0.820),
        vec3(0.918, 0.651, 0.910),
        luminance);
    }
    return ramp(
      vec3(0.137, 0.290, 0.482),
      vec3(0.031, 0.369, 0.773),
      vec3(0.020, 0.490, 0.949),
      vec3(0.290, 0.788, 1.000),
      vec3(0.651, 1.000, 1.000),
      luminance);
  }

  if (u_StancePalette == 3) {
    return ramp(
      vec3(0.110, 0.110, 0.106),
      vec3(0.173, 0.173, 0.169),
      vec3(0.329, 0.329, 0.325),
      vec3(0.612, 0.608, 0.580),
      vec3(0.835, 0.835, 0.831),
      luminance);
  }

  return vec3(luminance);
}

void main()
{
  vec4 source = texture2D(u_Tex0, v_TexCoord);
  float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
  vec3 recolored = stanceColor(luminance);
  gl_FragColor = vec4(recolored * u_Color.rgb, source.a * u_Color.a);
}
