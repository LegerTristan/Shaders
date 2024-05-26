Shader "Tuto/ToonShading" 
{
    // Cel-shading that allows user to edit main color of the material, change the texture, and edit the glossiness.
    // It is a simplified version that mostly handles the glossiness part of the reflection.

    Properties 
    {
        _MainColor ("Main Color", Color) = (1.0, 0.0, 0.0, 1.0)
        _MyTexture ("Texture", 2D) = "white" {}
        _Glossiness ("Glossiness", Float) = 32
    }
    SubShader 
    {
        Tags { "RenderType"="Opaque" }

        Pass 
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

            float4 _MainColor;
            sampler2D _MyTexture;
            float _Glossiness;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 uv : TEXCOORD;
                float4 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 normalOS : NORMAL0;
                float3 normalWS : NORMAL1;
                float3 positionWS : TEXCOORD1;
            };

            Varyings vert(Attributes input)
            {
                // Getting informations about pixel in world space and camera space for computing purposes in the fragment shader process.
                Varyings res;
                res.positionCS = TransformObjectToHClip(input.positionOS);
                res.uv = input.uv;
                res.normalOS = input.positionOS;
                res.normalWS = TransformObjectToWorldNormal(input.normalOS);
                res.positionWS = TransformObjectToWorld(input.positionOS);
                return res;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // Ensure that our pixel's normal in world space is normalized.
                float3 normalWS = normalize(input.normalWS);
                Light light = GetMainLight();
                float3 lightDirWS = normalize(light.direction);

                // Computes dot of our light direction and pixel's normal in world space in order to get the intensity of our diffuse light.
                float NdotL = dot(lightDirWS, normalWS);

                // Clamping our diffuse intensity to prevent opposed pixel from the light to be too dark.
                float diffuseIntensity = clamp(NdotL, 0, 1);
                if (diffuseIntensity < 0.2)
                    diffuseIntensity = 0.2;
                else
                    diffuseIntensity = 1.0;
                
                float3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

                 // Computing half vector based on light direction and view's direction in world space.
                 // It is a necessary step in order to compute the specular intensity
                float3 halfVectorWS = normalize(lightDirWS + viewDirectionWS);

                // Determining how much our pixel's normal direction is similar to our half vector direction,
                // meaning how much our current pixel is impacted by the light's reflection.
                // See Phong reflection to learn more about the specular.
                float NdotH = abs(dot(normalWS, halfVectorWS));

                // Clamp our specular intensity and rendering only important part of the specular, the minimum intensity could be defined as a variable
                // to allow more customization.
                float specularIntensity = pow(NdotH, _Glossiness * _Glossiness);
                if (specularIntensity < 0.5)
                    specularIntensity = 0;
                else
                    specularIntensity = 1.0;
                
                // Default's ambiant light, the light globally reflected in the scene, prevent some part of the scene to be too dark.
                float ambiant = 0.2;

                return (diffuseIntensity + ambiant) * _MainColor + specularIntensity * float4(1.0, 1.0, 1.0, 1.0);
            }
            ENDHLSL
        }
    }
}