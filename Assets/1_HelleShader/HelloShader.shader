Shader "Tuto/HelloSHader" 
{
    Properties 
    {
        _MainColor ("Main Color", Color) = (1.0, 0.0, 0.0, 1.0)
        _MyTexture ("Texture", 2D) = "white" {}
        _Glossiness ("Glossiness", Float) = 0.0
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
                float3 normalWS = normalize(input.normalWS);
                Light light = GetMainLight();
                float3 lightDirWS = normalize(light.direction);

                float NdotL = dot(lightDirWS, normalWS);
                float diffuseIntensity = clamp(NdotL, 0, 1);

                float3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

                float3 halfVectorWS = normalize(lightDirWS + viewDirectionWS);
                float NdotH = abs(dot(normalWS, halfVectorWS));
                float specularIntensity = pow(NdotH, _Glossiness * _Glossiness);
                
                float ambiant = 0.2;

                float shading = diffuseIntensity + ambiant + specularIntensity;

                return (diffuseIntensity + ambiant) * _MainColor + specularIntensity * float4(1.0, 1.0, 1.0, 1.0);
            }
            ENDHLSL
        }
    }
}