Shader"Tuto/RayTracingPBR"
{
    Properties
    {
        _MainColor ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _MyTexture ("Texture", 2D) = "white" {}
        _Glossiness ("Glossiness", Float) = 0.0
        _Eps ("Epsilon", Range(0.01, 1)) = 0.01
        _SmoothnessCustom ("SmoothnessCustom", Range(0, 1)) = 0.5
        _MetallicCustom ("MetallicCustom", Range(0, 1)) = 0.5
        _Emission ("Emission", Color) = (0,0,0,1)
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
            #include "SDFFunction.hlsl"

            float4 _MainColor;
            sampler2D _MyTexture;
            float _Glossiness;
            float _Eps;
            
            float _SmoothnessCustom;
            float _MetallicCustom;
            float4 _Emission;

            struct VertIn
            {
                float4 positionOS : POSITION;
            };

            struct FragIn
            {
                float4 positionCS : SV_POSITION;
                float4 positionOS : POSITION1;
            };

            FragIn vert(VertIn input)
            {
                FragIn result;
                result.positionCS = TransformObjectToHClip(input.positionOS);
                result.positionOS = input.positionOS;
                return result;
            }

            half4 frag(FragIn input, out float depth : SV_DEPTH) : SV_TARGET
            {
                float3 rayDirOS = -GetObjectSpaceNormalizeViewDir(input.positionOS);
                float3 rayEntryOS = input.positionOS;

                float sphereCenter = float3(0, 0, 0);
                float sphereRadius = 0.5;

                float3 currentPositionOS = rayEntryOS;

                // roundedBox;
                
                float3 boxSize = float3(0.1, 0.2, 0.3);
                float boxRad = 0.05;
                float lambda = roundedboxIntersect(rayEntryOS, rayDirOS, boxSize, boxRad);
                float3 normalOS = float3(0, 0, 0);
                if (lambda >= 0)
                {
                    currentPositionOS = rayEntryOS + lambda.x * rayDirOS;
                    normalOS = roundedBoxNormal(currentPositionOS, boxSize, boxRad);
                }
                else
                {
                    discard;
                }
                
                // sphere
                /*
                float lambda = raySphereIntersect(rayEntryOS, rayDirOS, sphereCenter, sphereRadius);
                if (lambda >= 0)
                {
                    currentPositionOS = currentPositionOS + lambda.x * rayDirOS;;
                }
                else
                {
                    discard;
                }
                float3 normalOS = normalize(currentPositionOS - sphereCenter);
                */
                
                float3 currentPositionOSNormalized = normalize(currentPositionOS);
                float theta = atan2(currentPositionOSNormalized.z, currentPositionOSNormalized.x);
                float phi = atan2(1,currentPositionOSNormalized.y);
                float4 texColor = tex2D(_MyTexture, float2(theta, phi));

                InputData lightingInput = (InputData)0;
                lightingInput.positionWS = TransformObjectToWorld(currentPositionOS);
                lightingInput.normalWS = normalize(TransformObjectToWorldNormal(TransformObjectToWorldNormal(normalOS)));
                lightingInput.viewDirectionWS = GetWorldSpaceNormalizeViewDir(lightingInput.positionWS);
                lightingInput.shadowCoord = TransformWorldToShadowCoord(lightingInput.positionWS);

                float3 tangentWS;
                float3 bitangentWS;
                buildBase(lightingInput.normalWS, tangentWS, bitangentWS);
                lightingInput.tangentToWorld = half3x3(tangentWS, bitangentWS, lightingInput.normalWS);

                SurfaceData surfaceInput = (SurfaceData)0;
                surfaceInput.albedo = texColor;
                surfaceInput.alpha = 1;
                surfaceInput.specular = 0;
                surfaceInput.smoothness = _SmoothnessCustom;
                surfaceInput.metallic = _MetallicCustom;
                surfaceInput.normalTS = float3(0, 0, 1);
                surfaceInput.emission = _Emission;
                surfaceInput.occlusion = 1;
                surfaceInput.alpha = 1;
                surfaceInput.clearCoatMask = 0;
                surfaceInput.clearCoatSmoothness = 0;

                float4 finalColor = UniversalFragmentPBR(lightingInput, surfaceInput);

                float4 positionCS = TransformObjectToHClip(currentPositionOS);
                depth = positionCS.z / positionCS.w;

                return finalColor;
            }

ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags{"lightMode"="ShadowCaster"}
            ZWrite On
            ColorMask 0
            
            HLSLPROGRAM

             #pragma vertex shadowVert
             #pragma fragment shadowFrag

             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
             #include "SDFFunction.hlsl"

            struct VertIn
             {
                float4 positionOS : POSITION;
             };
             
             struct FragIn
            {
                 float4 positionCS : SV_POSITION;
                 float4 positionOS : POSITION1;
            };

            FragIn shadowVert(VertIn input)
            {
                FragIn result;
                result.positionCS = TransformObjectToHClip(input.positionOS);
                result.positionOS = input.positionOS;
                return result;
            }

            void shadowFrag(FragIn input, out float depth : SV_DEPTH)
            {
                float3 rayDirWS =  -UNITY_MATRIX_I_V._m02_m12_m22;

                float3 inputPositionWS = TransformObjectToWorld(input.positionOS);
                // transform world space vertex position into view space
                float4 intputPositionVS = mul(UNITY_MATRIX_V, float4(inputPositionWS, 1.0));
                // flatten the view space position to be on the camera plane
                intputPositionVS.z = 0.0;
                // transform back into world space
                float4 worldRayOrigin = mul(UNITY_MATRIX_I_V, intputPositionVS);
                // orthographic ray dir
                float3 worldRayDir = rayDirWS;
                // and to object space
                float3 rayDirOS = mul(unity_WorldToObject, float4(worldRayDir, 0.0));
                float3 rayEntryOS = mul(unity_WorldToObject, worldRayOrigin);
                
                float sphereCenterOS = float3(0, 0, 0);
                float sphereRadius = 0.5;

                float3 currentPositionOS = rayEntryOS;
                int maxStep = 128;
                bool hasHit = false;

                // roundedBox;
                float3 boxSize = float3(0.1, 0.2, 0.3);
                float boxRad = 0.05;
                float lambda = roundedboxIntersect(rayEntryOS, rayDirOS, boxSize, sphereRadius);
                float3 normalOS = float3(0, 0, 0);
                if (lambda.x >= 0)
                {
                    currentPositionOS = rayEntryOS + lambda.x * rayDirOS;
                    normalOS = roundedBoxNormal(currentPositionOS, boxSize, boxRad);
                }
                else
                {
                    discard;
                }
                
                // sphere
                /*
                float lambda = raySphereIntersect(rayEntryOS, rayDirOS, sphereCenterOS, sphereRadius);
                if (lambda >= 0)
                {
                    currentPositionOS = currentPositionOS + lambda.x * rayDirOS;;
                }
                else
                {
                    discard;
                }
                float3 normalOS = normalize(currentPositionOS - sphereCenterOS);
                */

                float3 positionWS = TransformObjectToWorld(currentPositionOS);
                float3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(positionWS);

                float4 positionCS = TransformObjectToHClip(currentPositionOS);
                float3 normalWS = TransformObjectToWorldNormal(normalOS);

                depth = positionCS.z / positionCS.w;
            }

            ENDHLSL
        }
    }
}