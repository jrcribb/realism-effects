float color2float(in vec3 c) {
    c *= 255.;
    c = floor(c);  // without this value could be shifted for some intervals

    return c.r * 256. * 256. + c.g * 256. + c.b - 8388608.;
}

// values out of <-8388608;8388608> are stored as min/max values
vec3 float2color(in float val) {
    val += 8388608.;  // this makes values signed
    if (val < 0.) {
        return vec3(0.);
    }

    if (val > 16777216.) {
        return vec3(1.);
    }

    vec3 c = vec3(0.);
    c.b = mod(val, 256.);
    val = floor(val / 256.);
    c.g = mod(val, 256.);
    val = floor(val / 256.);
    c.r = mod(val, 256.);
    return c / 255.;
}

// source: https://knarkowicz.wordpress.com/2014/04/16/octahedron-normal-vector-encoding/
vec2 OctWrap(vec2 v) {
    vec2 w = 1.0 - abs(v.yx);
    if (v.x < 0.0) w.x = -w.x;
    if (v.y < 0.0) w.y = -w.y;
    return w;
}

vec2 Encode(vec3 n) {
    n /= (abs(n.x) + abs(n.y) + abs(n.z));
    n.xy = n.z > 0.0 ? n.xy : OctWrap(n.xy);
    n.xy = n.xy * 0.5 + 0.5;
    return n.xy;
}

// source: https://knarkowicz.wordpress.com/2014/04/16/octahedron-normal-vector-encoding/
vec3 Decode(vec2 f) {
    f = f * 2.0 - 1.0;

    // https://twitter.com/Stubbesaurus/status/937994790553227264
    vec3 n = vec3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
    float t = max(-n.z, 0.0);
    n.x += n.x >= 0.0 ? -t : t;
    n.y += n.y >= 0.0 ? -t : t;
    return normalize(n);
}

float packNormal(vec3 normal) {
    return uintBitsToFloat(packHalf2x16(Encode(normal)));
}

vec3 unpackNormal(float packedNormal) {
    return Decode(unpackHalf2x16(floatBitsToUint(packedNormal)));
}

float packVec2(vec2 value) {
    return uintBitsToFloat(packHalf2x16(value));
}

vec2 unpackVec2(float packedValue) {
    return unpackHalf2x16(floatBitsToUint(packedValue));
}

void getGDataAndGBuffer(sampler2D gBufferTexture, vec2 uv, out vec3 diffuse, out vec3 normal, out float roughness, out float metalness, out vec4 gBuffer) {
    gBuffer = textureLod(gBufferTexture, uv, 0.);

    diffuse = float2color(gBuffer.r);
    normal = unpackNormal(gBuffer.g);
    vec2 roughnessMetalness = unpackVec2(gBuffer.b);
    roughness = roughnessMetalness.r;
    metalness = roughnessMetalness.g;
}

void getGData(sampler2D gBufferTexture, vec2 uv, out vec3 diffuse, out vec3 normal, out float roughness, out float metalness, out vec3 emissive) {
    vec4 gBuffer;
    getGDataAndGBuffer(gBufferTexture, uv, diffuse, normal, roughness, metalness, gBuffer);
    emissive = float2color(gBuffer.a);
}

void getGData(sampler2D gBufferTexture, vec2 uv, out vec3 diffuse, out vec3 normal, out float roughness, out float metalness) {
    vec4 gBuffer;
    getGDataAndGBuffer(gBufferTexture, uv, diffuse, normal, roughness, metalness, gBuffer);
}

vec4 packGBuffer(vec3 diffuse, vec3 normal, float roughness, float metalness, vec3 emissive) {
    vec4 gBuffer;

    gBuffer.r = color2float(diffuse);
    gBuffer.g = packNormal(normal);
    gBuffer.b = packVec2(vec2(roughness, metalness));
    gBuffer.a = color2float(emissive);

    return gBuffer;
}