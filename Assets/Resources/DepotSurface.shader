Shader "VectorRange/DepotSurface"
{
    Properties {
        _BaseColor ("Color", Color) = (1,1,1,1)
        _Glow ("Unlit amount", Range(0,1)) = 0
    }
    SubShader {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        Pass {
            Tags { "LightMode"="SRPDefaultUnlit" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half _Glow;
            CBUFFER_END
            struct Attributes { float4 pos : POSITION; float3 normal : NORMAL; };
            struct Varyings { float4 pos : SV_POSITION; half light : TEXCOORD0; float3 world : TEXCOORD1; };
            Varyings vert(Attributes input) {
                Varyings o;
                o.world = TransformObjectToWorld(input.pos.xyz);
                o.pos = TransformWorldToHClip(o.world);
                float3 normal = TransformObjectToWorldNormal(input.normal);
                o.light = 0.42h + 0.58h * saturate(dot(normal, normalize(float3(-0.55, 0.82, -0.38))));
                return o;
            }
            half4 frag(Varyings i) : SV_Target {
                half3 color = _BaseColor.rgb * lerp(i.light, 1.0h, _Glow);
                float fog = saturate((distance(_WorldSpaceCameraPos, i.world) - 10.0) / 48.0);
                return half4(lerp(color, half3(0.11,0.16,0.18), fog * 0.4), 1);
            }
            ENDHLSL
        }
    }
}
