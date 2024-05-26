#pragma once

// Utils function for computing the diffuse and specular light and apply the base color in parameter on the result.
// Can be added to a fragment shader process to get a simple cel-shading.
void Toonshading_float(float3 lightDirWS, float3 normalWS, float4 baseColor, float3 viewDirWS, float Glossiness, out float4 color)
{
    float NdotL = dot(-lightDirWS, normalWS);
    float diffuseIntensity = clamp(NdotL, 0, 1);
    
    diffuseIntensity = smoothstep(0.2, 0.3, diffuseIntensity);
    diffuseIntensity = lerp(0.2, 1, diffuseIntensity);
    
    float3 halfVectorWS = normalize(-lightDirWS + viewDirWS);
    float3 NdotH = clamp(dot(normalWS, halfVectorWS), 0, 1);
    
    float specularIntensity = pow(NdotH, Glossiness * Glossiness);
    specularIntensity = smoothstep(0.7, 0.9, specularIntensity);

    color = diffuseIntensity * baseColor + specularIntensity * float4(1, 1, 1, 1);

}