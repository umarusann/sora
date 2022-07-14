Shader "Custom/Toon"
{
    Properties
    {
        [KeywordEnum(Base,Face,Hair)]_ShaderEnum("",int) = 0

        _BaseMap("BaseMap",2D) = "white"{}
        [HDR][MainColor]_BaseColor("BaseColor",Color) = (1,1,1,1)

        _ParamTex("LightMap",2D) = "white"{}

        _RampMap("Ramp",2D) = "white" {}
        _RampMapYRange("RampMapYRange",Range(0.0,0.5)) = 0.0

        _Matcap("Matcap",2D) = "white" {}
        _MetalColor("MetalColor",Color) = (1,1,1,1)
        _HairSpecularIntensity("HairHighLight",Range(0.0,10))=0.5

        _FaceShadowRangeSmooth("FaceShadowSmooth",Range(0.01,1.0)) = 0.1

        _RimIntensity("RimLight",Range(0.0,5.0))=0
        _RimRadius("RimRadius",Range(0.0,1.0))= 0.1
        
        _EmissionIntensity("自发光",Range(0.0,25.0))=0.0

        _outlinecolor("outLineColor",Color)=(0,0,0,1)
        _outlineWidth("width",Range(0,1))=0.01
        
    }
    SubShader{
        
            Tags{
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType" = "Opaque"
            }
            HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma vertex vert 
            #pragma fragment frag 

            #pragma shader_feature_SHADERENUM_BASE_SHADERENUM_FACE_SHADERENUM_HAIR

            #pragma multi_compile__MAIN_LIGHT_SHADOWS
            #pragma multi_compile__MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment__SHADOWS_SOFT

            CBUFFER_START(UnityPerMaterial)

            float4 _BaseMap_ST;
            float _BaseColor;

            uniform float4 _ShadowMultColor;//shadow
            uniform float4 _DarkShadowMultColor;//darkshadow 

            uniform int _inNight;

            uniform float _RimIntensity;
            uniform float _RimRadius;
            uniform float _RampMapYRange;

            uniform float _FaceShadowRangeSmooth;

            uniform float _HairSpecularIntensity;

            uniform float _EmissionIntensity;

            uniform float4 _outlinecolor;
            uniform float _outlineWidth;

            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_ParamTex);
            SAMPLER(sampler_ParamTex);

            TEXTURE2D(_RampMap);
            SAMPLER(sampler_RampMap);

            uniform TEXTURE2D(_Matcap);
            uniform SAMPLER(sampler_Matcap);

            struct VertexInput{
                float4 vertex: POSITION;
                float2 uv: TEXCOORD0;
                half4 color: COLOR;
                float4 normalOS: NORMAL;
            };

            struct VertexOutput{
                float4 posCS: POSITION;
                float2 uv: TEXCOORD0;
                float4 vertexColor: COLOR;
                float3 nDirWS: TEXCOORD1;
                float3 nDirVS: TEXCOORD2;
                float3 vDirWS: TEXCOORD3;
                float3 posWS: TEXCOORD4;
            };

            float3 NPR_Ramp(float NdotL,float _inNight,float _RampMapYRange){
                float halfLambert = smoothstep(0.0,0.5,NdotL);
                if(_inNight>0.0){
                    return SAMPLE_TEXTURE2D(_RampMap,sampler_RampMap,float2(halfLambert,_RampMapYRange)).rgb;
                }
                else{
                    return SAMPLE_TEXTURE2D(_RampMap,sampler_RampMap,float2(halfLambert,_RampMapYRange+0.5)).rgb;
                }
            }

            float3 NPR_Specular(float3 NdotH,float3 baseColor,float4 var_paramTex){
                #if _SHADERENUM_HAIR
                float SpecularRadius = pow(NdotH,var_paramTex.a * 50);
                #else 
                float SpecularRadius = pow(NdotH,var_paramTex.r * 50);
                #endif

                float3 SpecularColor = var_paramTex.b * baseColor;

                #if _SHADERENUM_HAIR
                return smoothstep(0.3,0.4,SpecularRadius)*SpecularColor*lerp(_HairSpecularIntensity,1,step(0.9,var_paramTex.b));
                #else 
                return smoothstep(0.3,0.4,SpecularRadius)*SpecularColor * var_paramTex.b;
                #endif 
            }

            float3 NPR_Metal(float3 nDir,float4 var_paramTex,float3 baseColor){
                float3 viewNormal = normalize(mul(UNITY_MATRIX_V,nDir));//V空间N，采用MATCAP
                float var_Matcap = SAMPLE_TEXTURE2D(_Matcap,sampler_Matcap,viewNormal * 0.5+0.5)*2;
                #if _SHADERENUM_HAIR
                return var_Matcap * baseColor * var_paramTex.a;
                #endif
                return var_Matcap * baseColor * var_paramTex.r;
            }
            float3 NRP_Rim(float NdotV,float NdotL,float4 baseColor){
                float3 rim = (1-smoothstep(_RimRadius,_RimRadius +0.03,NdotV))*_RimIntensity * (1-(NdotL * 0.5 + 0.5))*baseColor;
                return rim;
            }
            float3 NRP_Emission(float4 baseColor){
                return baseColor.a * baseColor * _EmissionIntensity * abs((frac(_Time.y * 0.5)-0.5)*2);
            }
            float3 NPR_Base(float NdotL,float NdotH,float NdotV,float3 nDir,float4 baseColor,float4 var_paramTex,float _inNight,float _RampMapYRange){
                float3 RampColor = NPR_Ramp(NdotL,_inNight,_RampMapYRange);
                float3 Albedo = baseColor * RampColor;
                float3 Specular = NPR_Specular(NdotH,baseColor,var_paramTex);
                float3 Metal = NPR_Metal(nDir,var_paramTex,baseColor);
                float3 RimLight = NRP_Rim(NdotV,NdotL,baseColor)*var_paramTex.g;
                float3 Emission = NRP_Emission(baseColor);
                float3 FinalColor = Albedo * (1-var_paramTex.r)+Specular+Metal+RimLight+Emission;
                return FinalColor;
            }
            float3 NPR_Face(float4 baseColor,float4 var_paramTex,float3 lDir,float _inNight,float _FaceShadowRangeSmooth,float _RampMapYRange){
                float3 Up = float3(0.0,1.0,0.0);
                float3 Front = unity_ObjectToWorld._12_22_32;
                float3 Right = cross(Up,Front);
                float switchShadow = dot(normalize(Right.xz),lDir.xz)*0.5+0.5<0.5;

                float FaceShadow = lerp(var_paramTex,1-var_paramTex,switchShadow);
                float FaceShadowRange = dot(normalize(Front.xz),normalize(lDir.xz));

                float lightAttenuation = 1-smoothstep(FaceShadowRange - _FaceShadowRangeSmooth,FaceShadowRange + _FaceShadowRangeSmooth,FaceShadow);

                float3 rampColor = NPR_Ramp(lightAttenuation,_inNight,_RampMapYRange);
                return baseColor*rampColor;
            }
            float3 NPR_Hair(float NdotL,float NdotH,float NdotV,float3 nDir,float4 baseColor,float4 var_paramTex,float _inNight,float _RampMapYRange){
                float3 RampColor = NPR_Ramp(NdotL,_inNight,_RampMapYRange);
                float Albedo = baseColor * RampColor;
                
                float HairSpecularRadius = 0.25;
                float HairSpecDir = normalize(mul(UNITY_MATRIX_V,nDir))*0.5+0.5;

                float3 HairSpecular = smoothstep(HairSpecularRadius,HairSpecularRadius+0.1,1-HairSpecDir)*smoothstep(HairSpecularRadius,HairSpecularRadius+0.1,HairSpecDir)*NdotL;
                float3 Specular = NPR_Specular(NdotH,baseColor,var_paramTex)+HairSpecular * _HairSpecularIntensity*var_paramTex.g*step(var_paramTex.r,0.1);

                float3 Metal = NPR_Metal(nDir,var_paramTex,baseColor);
                float3 RimLight = NRP_Rim(NdotV,NdotL,baseColor);
                float3 finalRGB = Albedo +Specular *RampColor +Metal+RimLight;
                return finalRGB;
            }
            
            ENDHLSL
        
        pass{
            Name "FORWARD"
            Tags{
                "LightMode"="UniversalForward"
                "RenderType"="Opaque"
            }
            Cull off 

            HLSLPROGRAM
            VertexOutput vert(VertexInput v){
                VertexOutput o = (VertexOutput)0;
                ZERO_INITIALIZE(VertexOutput,o);
                o.vertexColor = v.color;
                o.uv = v.uv;
                o.uv = float2(o.uv.x,1-o.uv.y);
                o.posCS=TransformObjectToHClip(v.vertex);
                o.posWS=TransformObjectToWorld(v.vertex);
                o.nDirWS=TransformObjectToWorldNormal(v.normalOS);
                o.nDirVS=TransformWorldToView(o.nDirWS);
                o.vDirWS = _WorldSpaceCameraPos.xyz - o.posWS;
                return o;
            }
            float4 frag(VertexOutput i):COLOR{
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv);

                float4 var_paramTex = SAMPLE_TEXTURE2D(_ParamTex,sampler_ParamTex,i.uv);

                Light light =GetMainLight(TransformWorldToShadowCoord(i.posWS));

                float3 nDir = normalize(i.nDirWS);
                float3 vDir = normalize(i.vDirWS);
                float3 lDir = normalize(light.direction);
                float3 halfDir = normalize(lDir+vDir);

                float NdotL = dot(nDir,lDir);
                float NdotH = dot(nDir,halfDir);
                float NdotV = dot(nDir,vDir);

                float3 FinalColor = float3(1.0,1.0,0.0);
                FinalColor = NPR_Base(NdotL,NdotH,NdotV,nDir,baseColor,var_paramTex,_inNight,_RampMapYRange);
                #if _SHADERENUM_BASE
                FinalColor = NPR_Base(NdotL,NdotH,NdotV,nDir,baseColor,var_paramTex,_inNight,_RampMapYRange);
                #elif _SHADERENUM_FACE
                FinalColor = NPR_Face(baseColor,var_paramTex,lDir,_inNight,_FaceShadowRangeSmooth,_RampMapYRange);
                #elif _SHADERENUM_HAIR
                FinalColor = NPR_Hair(NdotL,NdotH,NdotV,nDir,baseColor,var_paramTex,_inNight,_RampMapYRange);
                #endif
                return float4(FinalColor,1.0);
            }
            ENDHLSL
        }
        
        Pass{
            Name "Outline"
            Tags{}
            Cull off 
            ZWrite on 
            Cull front 

            HLSLPROGRAM
            VertexOutput vert(VertexInput v){
                VertexOutput o = (VertexOutput)0;
                ZERO_INITIALIZE(VertexOutput,o);
                o.posCS = TransformObjectToHClip(float4(v.vertex.xyz+v.normalOS*_outlineWidth,1));
                o.uv = v.uv;
                o.uv = float2(o.uv.x,1-o.uv.y);
                o.posWS = TransformObjectToWorld(v.vertex.xyz);
                o.nDirWS = v.normalOS;
                return o;
            }
            float4 frag(VertexOutput i):COLOR{
                float4 var_MainTex = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv);
                float4 FinalColor = _outlinecolor * var_MainTex;
                return FinalColor;
            }
            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"

    }
  

}
