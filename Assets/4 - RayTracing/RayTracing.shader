Shader "Tuto/RayTracing"
{
    // Raytracing shader for cel-shading rendering.
    // This shader renders a rounded box with cel-shading effects, accounting for the object's rotation and scale.
    // It also casts shadows according to the current shape.
    // The default shape is a rounded box but we could add some options to allow the user to choose another shape
    
    Properties
    {
        _MainColor ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _MyTexture ("Texture", 2D) = "white" {}
        _Glossiness ("Glossiness", Float) = 0.0
        //_Eps ("Epsilon", Range(0.01, 1)) = 0.01         // Option to render a sphere, it represents th step size used for computing pixel's location of the sphere. 
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        
        // First pass used for rendering the rounded box with raytracing
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
            // float _Eps;
            
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
                // We invert the view direction in order to hae our raycast direction.
                float3 rayDirOS = -GetObjectSpaceNormalizeViewDir(input.positionOS);
                float3 rayEntryOS = input.positionOS;

                //float sphereCenter = float3(0, 0, 0);
                //float sphereRadius = 0.5;

                float3 currentPositionOS = rayEntryOS;
                int maxStep = 128;
                //bool hasHit = false;

                // roundedBox;
                
                // Defining some default value for our box such as the size and the radius of the corners.
                float3 boxSize = float3(0.1, 0.2, 0.3);
                float boxRad = 0.05;

                // Based on the raycast entry pos and direction in object space and the specifications of our box,
                // we check if our raycast intersect with our rounded box.
                float lambda = roundedboxIntersect(rayEntryOS, rayDirOS, boxSize, boxRad);
                float3 normalOS = float3(0, 0, 0);
                if (lambda >= 0)
                {
                    // If the ray intersect with our box, then we update our normal and current position in object space to render our pixel with the celshading.
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
                
                /*for (int i = 0; i < maxStep; i++)
                {
                    currentPositionOS = currentPositionOS + _Eps * rayDirOS;
                    float d = distance(currentPositionOS, sphereCenter);
                    if (d < sphereRadius)
                    {
                        hasHit = true;
                        break;
                    }
                }*/

                //if (!hasHit)
                //    discard;
                
                // Below we compute our current pixel to render it with a cel-shading effect.
                float3 normalWS = TransformObjectToWorldNormal(normalOS);
                float positionWS = TransformObjectToWorld(currentPositionOS);
                Light light = GetMainLight();
                float3 lightDirWS = normalize(light.direction);
                float NdotL = dot(lightDirWS, normalWS);
                float diffuseIntensity = clamp(NdotL, 0, 1);

                float3 viewDirectionWS = GetWorldSpaceNormalizeViewDir(positionWS);

                float3 halfVectorWS = normalize(lightDirWS + viewDirectionWS);
                float NdotH = clamp(dot(normalWS, halfVectorWS), 0, 1);
                float specularIntensity = pow(NdotH, _Glossiness * _Glossiness);

                float ambiant = 0.2;

                float3 currentPositionOSNormalized = normalize(currentPositionOS);
                float theta = atan2(currentPositionOSNormalized.y, currentPositionOSNormalized.x);
                float phi = atan2(1, currentPositionOSNormalized.z);
                
                float4 texColor = tex2D(_MyTexture, float2(theta, phi));

                float4 positionCS = TransformObjectToHClip(currentPositionOS);
                depth = positionCS.z / positionCS.w;

                return (diffuseIntensity + ambiant) * _MainColor * texColor + specularIntensity * float4(1.0, 1.0, 1.0, 1.0);
            }

            ENDHLSL
        }
        Pass
        {
            Name"ShadowCaster"
                        Tags
            {"lightMode"="ShadowCaster"
            }

            ZWrite On
            ColorMask 0         // Disables color writes for all channels.
            
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
                // Compute the ray direction in world space for an orthographic camera
                float3 rayDirWS = -UNITY_MATRIX_I_V._m02_m12_m22;

                float3 inputPositionWS = TransformObjectToWorld(input.positionOS);
                float4 inputPositionVS = mul(UNITY_MATRIX_V, float4(inputPositionWS, 1.0));

                // Flatten the View Space position to be on the camera plane
                inputPositionVS.z = 0.0;

                // Transform the flattened View Space position back to World Space
                float4 worldRayOrigin = mul(UNITY_MATRIX_I_V, inputPositionVS);

                float3 worldRayDir = rayDirWS;

                float3 rayDirOS = mul(unity_WorldToObject, float4(worldRayDir, 0.0));
                float3 rayEntryOS = mul(unity_WorldToObject, worldRayOrigin);

                //float sphereCenterOS = float3(0, 0, 0);
                //float sphereRadius = 0.5;

                // Below, we will start to use almost the same code for rendering pixels of our rounded box.
                // Instead of drawing the rounded box, we will draw his shadows.
                float3 currentPositionOS = rayEntryOS;
                int maxStep = 128;
                // bool hasHit = false; 

                // Define the dimensions and rounded radius of the rounded box
                float3 boxSize = float3(0.1, 0.2, 0.3);
                float boxRad = 0.05;

                // Compute the intersection of the ray with the rounded box
                float lambda = roundedboxIntersect(rayEntryOS, rayDirOS, boxSize, boxRad);
                float3 normalOS = float3(0, 0, 0);

                if (lambda >= 0)
                {
                    currentPositionOS = rayEntryOS + lambda * rayDirOS;
                    normalOS = roundedBoxNormal(currentPositionOS, boxSize, boxRad);
                }
                else
                {
                    discard;
                }

                /*
                float lambda = raySphereIntersect(rayEntryOS, rayDirOS, sphereCenterOS, sphereRadius);
                if (lambda >= 0)
                {
                    currentPositionOS = currentPositionOS + lambda * rayDirOS;
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

                // Compute the depth value
                depth = positionCS.z / positionCS.w;
            }

            ENDHLSL
        }
    }
}