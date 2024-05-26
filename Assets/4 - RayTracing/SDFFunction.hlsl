#pragma once

// Utility functions for computing 3D signed distance field (SDF) shapes.
// These functions were created by Inigo Quilez. For more information, see : https://iquilezles.org/articles/distfunctions/

float raySphereIntersect(float3 r0, float3 rd, float3 s0, float3 sr)
{
    // - r0: ray origin
    // - rd: normalized ray direction
    // - s0: sphere center
    // - sr: sphere radius
    // - Returns distance from r0 to first intersecion with sphere,
    //   or -1.0 if no intersection.
    float a = dot(rd, rd);
    float3 s0_r0 = r0 - s0;
    float b = 2.0 * dot(rd, s0_r0);
    float c = dot(s0_r0, s0_r0) - (sr * sr);
    if (b * b - 4.0 * a * c < 0.0)
    {
        return -1.0;
    }
    return (-b - sqrt((b * b) - 4.0 * a * c)) / (2.0 * a);
}

// axis aligned box centered at the origin, with dimensions "size" and extruded by "rad"
float roundedboxIntersect(in float3 ro, in float3 rd, in float3 size, in float rad)
{
    // bounding box
    float3 m = 1.0 / rd;
    float3 n = m * ro;
    float3 k = abs(m) * (size + rad);
    float3 t1 = -n - k;
    float3 t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if (tN > tF || tF < 0.0)
        return -1.0;
    float t = tN;

    // convert to first octant
    float3 pos = ro + t * rd;
    float3 s = sign(pos);
    ro *= s;
    rd *= s;
    pos *= s;

    // faces
    pos -= size;
    pos = max(pos.xyz, pos.yzx);
    if (min(min(pos.x, pos.y), pos.z) < 0.0)
        return t;

    // some precomputation
    float3 oc = ro - size;
    float3 dd = rd * rd;
    float3 oo = oc * oc;
    float3 od = oc * rd;
    float ra2 = rad * rad;

    t = 1e20;

    // corner
    {
        float b = od.x + od.y + od.z;
        float c = oo.x + oo.y + oo.z - ra2;
        float h = b * b - c;
        if (h > 0.0)
            t = -b - sqrt(h);
    }
    // edge X
    {
        float a = dd.y + dd.z;
        float b = od.y + od.z;
        float c = oo.y + oo.z - ra2;
        float h = b * b - a * c;
        if (h > 0.0)
        {
            h = (-b - sqrt(h)) / a;
            if (h > 0.0 && h < t && abs(ro.x + rd.x * h) < size.x)
                t = h;
        }
    }
    // edge Y
    {
        float a = dd.z + dd.x;
        float b = od.z + od.x;
        float c = oo.z + oo.x - ra2;
        float h = b * b - a * c;
        if (h > 0.0)
        {
            h = (-b - sqrt(h)) / a;
            if (h > 0.0 && h < t && abs(ro.y + rd.y * h) < size.y)
                t = h;
        }
    }
    // edge Z
    {
        float a = dd.x + dd.y;
        float b = od.x + od.y;
        float c = oo.x + oo.y - ra2;
        float h = b * b - a * c;
        if (h > 0.0)
        {
            h = (-b - sqrt(h)) / a;
            if (h > 0.0 && h < t && abs(ro.z + rd.z * h) < size.z)
                t = h;
        }
    }

    if (t > 1e19)
        t = -1.0;

    return t;
}

// normal of a rounded box
float3 roundedBoxNormal(in float3 pos, in float3 siz, in float rad)
{
    return sign(pos) * normalize(max(abs(pos) - siz, 0.0));
}

float gouIntersect(in float3 ro, in float3 rd, in float ka, float kb)
{
    float po = 1.0;
    float3 rd2 = rd * rd;
    float3 rd3 = rd2 * rd;
    float3 ro2 = ro * ro;
    float3 ro3 = ro2 * ro;
    float k4 = dot(rd2, rd2);
    float k3 = dot(ro, rd3);
    float k2 = dot(ro2, rd2) - kb / 6.0;
    float k1 = dot(ro3, rd) - kb * dot(rd, ro) / 2.0;
    float k0 = dot(ro2, ro2) + ka - kb * dot(ro, ro);
    k3 /= k4;
    k2 /= k4;
    k1 /= k4;
    k0 /= k4;
    float c2 = k2 - k3 * (k3);
    float c1 = k1 + k3 * (2.0 * k3 * k3 - 3.0 * k2);
    float c0 = k0 + k3 * (k3 * (c2 + k2) * 3.0 - 4.0 * k1);

    if (abs(c1) < 0.1 * abs(c2))
    {
        po = -1.0;
        float tmp = k1;
        k1 = k3;
        k3 = tmp;
        k0 = 1.0 / k0;
        k1 = k1 * k0;
        k2 = k2 * k0;
        k3 = k3 * k0;
        c2 = k2 - k3 * (k3);
        c1 = k1 + k3 * (2.0 * k3 * k3 - 3.0 * k2);
        c0 = k0 + k3 * (k3 * (c2 + k2) * 3.0 - 4.0 * k1);
    }

    c0 /= 3.0;
    float Q = c2 * c2 + c0;
    float R = c2 * c2 * c2 - 3.0 * c0 * c2 + c1 * c1;
    float h = R * R - Q * Q * Q;
    
    if (h > 0.0) // 2 intersections
    {
        h = sqrt(h);
        float s = sign(R + h) * pow(abs(R + h), 1.0 / 3.0); // cube root
        float u = sign(R - h) * pow(abs(R - h), 1.0 / 3.0); // cube root
        float x = s + u + 4.0 * c2;
        float y = s - u;
        float ks = x * x + y * y * 3.0;
        float k = sqrt(ks);
        float t = -0.5 * po * abs(y) * sqrt(6.0 / (k + x)) - 2.0 * c1 * (k + x) / (ks + x * k) - k3;
        return (po < 0.0) ? 1.0 / t : t;
    }
    
    // 4 intersections
    float sQ = sqrt(Q);
    float w = sQ * cos(acos(-R / (sQ * Q)) / 3.0);
    float d2 = -w - c2;
    if (d2 < 0.0)
        return -1.0; //no intersection
    float d1 = sqrt(d2);
    float h1 = sqrt(w - 2.0 * c2 + c1 / d1);
    float h2 = sqrt(w - 2.0 * c2 - c1 / d1);
    float t1 = -d1 - h1 - k3;
    t1 = (po < 0.0) ? 1.0 / t1 : t1;
    float t2 = -d1 + h1 - k3;
    t2 = (po < 0.0) ? 1.0 / t2 : t2;
    float t3 = d1 - h2 - k3;
    t3 = (po < 0.0) ? 1.0 / t3 : t3;
    float t4 = d1 + h2 - k3;
    t4 = (po < 0.0) ? 1.0 / t4 : t4;
    float t = 1e20;
    if (t1 > 0.0)
        t = t1;
    if (t2 > 0.0)
        t = min(t, t2);
    if (t3 > 0.0)
        t = min(t, t3);
    if (t4 > 0.0)
        t = min(t, t4);
    return t;
}

float3 gouNormal(in float3 pos, float ka, float kb)
{
    return normalize(4.0 * pos * pos * pos - 2.0 * pos * kb);
}

void buildBase(in float3 localZ, out float3 localX, out float3 localY)
{
    float eps = 0.01;
    if (abs(localZ.x) > eps)
    {
        localY.y = 1;
        localY.z = 1;
        localY.x = -(localZ.y + localZ.z) / localZ.x;
    }
    else if (abs(localZ.y) > eps)
    {
        localY.x = 1;
        localY.z = 1;
        localY.y = -(localZ.x + localZ.z) / localZ.y;
    }
    else
    {
        localY.x = 1;
        localY.y = 1;
        localY.z = -(localZ.x + localZ.y) / localZ.z;
    }
    localY = normalize(localY);
    localX = normalize(cross(localY, localZ));
}