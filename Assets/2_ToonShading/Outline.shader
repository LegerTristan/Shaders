Shader "Tuto/Outline" 
{
    // Simple outline shader, we compute the rendered pixels during the vertex shader process.
    // We simply return the main color during the fragment shader process.

    Properties 
    {
        _MainColor ("Main Color", Color) = (0,0,0,1)
        _OutlineWidth ("Outline width", Float) = 0.1
    }
    SubShader 
    {
        Tags { "RenderType"="Opaque" }

        // Global ShaderLab commands, apply on all Passes
        Cull Front // Cullling front ploygons in order to see the outline.

        ZWrite On // Enables depth buffer writing to render the outline.

        Pass 
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float4 _MainColor;
            float _OutlineWidth;

            struct VertIn
            {
                float4 positionOS : POSITION;
                float4 normalOS : NORMAL;
            };

            struct FragIn
            {
                float4 positionCS : SV_POSITION;
            };

            FragIn vert(VertIn input)
            {
                FragIn res;

                // Computing new object space position by getting into account the normal of the object multiplied by the width of the outline.
                float4 newPosOS = input.positionOS + _OutlineWidth * input.normalOS;
                res.positionCS = TransformObjectToHClip(newPosOS); // Transforming position from object space into camera space.
                return res;
            }

            half4 frag(FragIn input) : SV_Target
            {
                return _MainColor;
            }
            
            ENDHLSL
        }
    }
}