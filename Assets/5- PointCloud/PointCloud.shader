Shader "Tuto/PointCloud" 
{
	// Renders many points similar to a cloud in a sphere range with raycast.
	// Each point has main PBR parameters such as metallic, smoothness or glossiness.
	// An emission parameter is also available
	Properties 
	{
		_Eps ("Epsilon", Range(0.01, 1)) = 0.01
		_MainColor ("Main Color", Color) = (0,0,0,1)
		_Glossiness ("Glossiness", Float) = 16
		_MyTexture ("Texture", 2D) = "white" {} 

		_SmoothnessCustom ("_SmoothnessCustom", Range(0, 1)) = 0.5
		_MetallicCustom ("_MetallicCustom", Range(0, 1)) = 0.5
		[HDR] _Emission ("_Emission", Color) = (0,0,0,1)
	}
	SubShader 
	{
		Tags { "RenderType"="Opaque" }

		Cull Front
		
		Pass 
		{

			HLSLPROGRAM
            
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

			#include "SDFFunction.hlsl"

			float _Eps;
			float4 _MainColor;
			float _Glossiness;
			sampler2D _MyTexture;

			float _SmoothnessCustom;
			float _MetallicCustom;
			float4 _Emission;

			struct VertIn
			{
				float4 positionOS : POSITION;
				float2 radius : TEXCOORD0;
			};

			struct GeomIn
			{
   				float4 positionCS : SV_POSITION;
				float4 positionOS : POSITION1;
				float2 radius : TEXCOORD0;
			};

			struct FragIn
			{
				float4 positionCS : SV_POSITION;
				float4 positionOS : POSITION1;
				float4 particuleOriginOS : POSITION2;
				float2 radius : TEXCOORD0;
			};

			GeomIn vert(VertIn input) 
			{
				GeomIn result;
				result.positionCS = TransformObjectToHClip(input.positionOS);
				result.positionOS = input.positionOS;
				result.radius = input.radius;
				return result;
			}

			// Add a vertex converted into camera space in the vertex list to draw.
            void emitVertex(in FragIn o, in float3 positionOS, inout TriangleStream<FragIn> output)
            {
                o.positionOS.xyz = positionOS;
				o.positionCS = TransformObjectToHClip(o.positionOS);
                output.Append(o);
            }

			// Creating a new roundedbox by defining the vertex first then stripping the triangles
			[maxvertexcount(18)]
			void geom(point GeomIn input[1], inout TriangleStream<FragIn> output) 
			{
				float3 O = input[0].positionOS;
				float3 X = float3(1, 0, 0);
				float3 Y = float3(0, 1, 0);
				float3 Z = float3(0, 0, 1);


				float radius = 1;
	
				// View from above:
				// X is from left to right, Y from bottom to top, Z is toward us
				// 
				//         Y
				// pt_TLF  |   pt_TRF
				//         |
				//         |
				//         O --------> X
				//
				//
				// pt_BLF       pt_BRF

				float3 pt_BLF = O + radius * (-X - Y - Z);
				float3 pt_BRF = O + radius * (X - Y - Z);
				float3 pt_TLF = O + radius * (-X + Y - Z);
				float3 pt_TRF = O + radius * (X + Y - Z);

				float3 pt_BLB = O + radius * (-X - Y + Z);
				float3 pt_BRB = O + radius * (X - Y + Z);
				float3 pt_TLB = O + radius * (-X + Y + Z);
				float3 pt_TRB = O + radius * (X + Y + Z);


				// Build triangles strip
				//
				// pt_TLF ___TRF__TRB__TLB___ pt_TLF
				//       |   /|   /|   /|   /|
				//       |  / |  / |  / |  / |
				//       | /  | /  | /  | /  |
				//       |/___|/___|/___|/___|
				// pt_BLF    BRF  BRB  BLB    pt_BLF
				//
				//

                FragIn o;
                o.positionOS = float4(0, 0, 0, 1);
				o.particuleOriginOS = input[0].positionOS;
				o.radius = input[0].radius;

                emitVertex(o, pt_TLF, output);
                emitVertex(o, pt_BLF, output);
                emitVertex(o, pt_TRF, output);
                emitVertex(o, pt_BRF, output);
                emitVertex(o, pt_TRB, output);
                emitVertex(o, pt_BRB, output);
                emitVertex(o, pt_TLB, output);
                emitVertex(o, pt_BLB, output);
                emitVertex(o, pt_TLF, output);
                emitVertex(o, pt_BLF, output);

				output.RestartStrip();

                // Top cap
                emitVertex(o, pt_TLF, output);
                emitVertex(o, pt_TRF, output);
                emitVertex(o, pt_TLB, output);
                emitVertex(o, pt_TRB, output);

				output.RestartStrip();

                // Bottom cap
                emitVertex(o, pt_BRF, output);
                emitVertex(o, pt_BLF, output);
                emitVertex(o, pt_BRB, output);
                emitVertex(o, pt_BLB, output);
			}

			// Transform object space position into particule space position.
			float3 TransformObjectToParticule(float3 positionOS, float3 particulePosOS)
			{
				return positionOS - particulePosOS;
			}


			half4 frag(FragIn input,
						out float depth : SV_Depth
						) : SV_Target
			{
				// Getting raycast entry point and direction in object space.
				float3 rayDirOS = normalize(-GetObjectSpaceNormalizeViewDir(input.positionOS));
				float3 rayEntryOS = input.positionOS;
	
				// Transforming it to particule space.
				float3 rayEntryPS = TransformObjectToParticule(rayEntryOS, input.particuleOriginOS);
				float3 rayDirPS = rayDirOS;

				float3 boxSize = float3(0.1, 0.2, 0.3);
				float boxRad = input.radius.x;
	
				// Checking if the raycast intersect with the rounded box.
				float lambda = roundedboxIntersect(rayEntryPS, rayDirPS, boxSize, boxRad);
				float3 currentPositionOS = rayEntryOS;
				float3 normalOS = float3(0, 0, 0);
				if(lambda >= 0)
				{
					// If there is an intersection, then we compute our currentPosition and normal in object space.
					currentPositionOS = rayEntryOS + lambda.x * rayDirOS;
					float3 currentPositionPS = TransformObjectToParticule(currentPositionOS, input.particuleOriginOS);
					normalOS = roundedboxNormal(currentPositionPS, boxSize, boxRad);
				}
				else
				{
					discard;
				}
	
				float3 currentPositionOSNormalized = normalize(currentPositionOS);
	
				// Getting _MyTexture color at a specific UV position.
				float theta = atan2(currentPositionOSNormalized.z, currentPositionOSNormalized.x);
				float phi = atan2(1, currentPositionOSNormalized.y);
				float4 texColor = tex2D(_MyTexture, float2(theta, phi));

				// Initialize lighting computation input in order to apply properly the light on the material.
				InputData lightingInput = (InputData) 0;
				lightingInput.positionWS = TransformObjectToWorld(currentPositionOS);
				lightingInput.normalWS = TransformObjectToWorldNormal(normalOS);
				lightingInput.viewDirectionWS = GetWorldSpaceNormalizeViewDir(lightingInput.positionWS);
				lightingInput.shadowCoord = TransformWorldToShadowCoord(lightingInput.positionWS);
	
				float3 tangentWS;
				float3 bitangentWS;

				// Getting tangent and bitangent in world space through lighting normal
				buildBase(lightingInput.normalWS, tangentWS, bitangentWS);
				lightingInput.tangentToWorld = half3x3(tangentWS, bitangentWS, lightingInput.normalWS);

				// Setting up surface's parameters value.
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
	
				// Computing the final color through Unity PBR process and setting up the depth for this pixel.
				half4 finalColor = UniversalFragmentPBR(lightingInput, surfaceInput);
				float4 positionCS = TransformObjectToHClip(currentPositionOS);
				depth = positionCS.z / positionCS.w;

				return finalColor;
			}

            ENDHLSL
		}

	}
}
