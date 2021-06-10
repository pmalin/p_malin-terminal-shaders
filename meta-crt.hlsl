// Windows terminal version of
// Meta CRT - @P_Malin
// https://www.shadertoy.com/view/4dlyWX#

#define NO_OVERLAY

//#define LIMIT_RESOLUTION    

Texture2D shaderTexture;
SamplerState samplerState;

// Terminal settings such as the resolution of the texture
cbuffer PixelShaderSettings {
  // The number of seconds since the pixel shader was enabled
  float  Time;
  // UI Scale
  float  Scale;
  // Resolution of the shaderTexture
  float2 Resolution;
  // Background color as rgba
  float4 Background;
};



#define mix lerp
#define vec2 float2
#define vec3 float3
#define vec4 float4
#define fract frac
#define mat3 float3x3

// Meta CRT - @P_Malin
// https://www.shadertoy.com/view/4dlyWX#


#define PI 3.141592654


///////////////////////////
// Hash Functions
///////////////////////////

// From: Hash without Sine by Dave Hoskins
// https://www.shadertoy.com/view/4djSRW

// *** Use this for integer stepped ranges, ie Value-Noise/Perlin noise functions.
//#define HASHSCALE1 .1031
//#define HASHSCALE3 vec3(.1031, .1030, .0973)
//#define HASHSCALE4 vec4(1031, .1030, .0973, .1099)

// For smaller input rangers like audio tick or 0-1 UVs use these...
#define HASHSCALE1 443.8975
#define HASHSCALE3 vec3(443.897, 441.423, 437.195)
#define HASHSCALE4 vec3(443.897, 441.423, 437.195, 444.129)


//----------------------------------------------------------------------------------------
//  1 out, 1 in...
float hash11(float p)
{
	vec3 p3  = fract(vec3(p,p,p) * HASHSCALE1);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

//  2 out, 1 in...
vec2 hash21(float p)
{
	vec3 p3 = fract(vec3(p,p,p) * HASHSCALE3);
	p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.xx+p3.yz)*p3.zy);

}

///  2 out, 3 in...
vec2 hash23(vec3 p3)
{
	p3 = fract(p3 * HASHSCALE3);
    p3 += dot(p3, p3.yzx+19.19);
    return fract((p3.xx+p3.yz)*p3.zy);
}

//  1 out, 3 in...
float hash13(vec3 p3)
{
	p3  = fract(p3 * HASHSCALE1);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}


#define kMaxTraceDist 1000.0
#define kFarDist 1100.0

#define MAT_FG_BEGIN 	10

///////////////////////////
// Scene
///////////////////////////

struct SceneResult
{
	float fDist;
	int iObjectId;
    vec3 vUVW;
};
    
void Scene_Union( inout SceneResult a, in SceneResult b )
{
    if ( b.fDist < a.fDist )
    {
        a = b;
    }
}

    
void Scene_Subtract( inout SceneResult a, in SceneResult b )
{
    if ( a.fDist < -b.fDist )
    {
        a.fDist = -b.fDist;
        a.iObjectId = b.iObjectId;
        a.vUVW = b.vUVW;
    }
}

SceneResult Scene_GetDistance( vec3 vPos );    

vec3 Scene_GetNormal(const in vec3 vPos)
{
    const float fDelta = 0.0001;
    vec2 e = vec2( -1, 1 );
    
    vec3 vNormal = 
        Scene_GetDistance( e.yxx * fDelta + vPos ).fDist * e.yxx + 
        Scene_GetDistance( e.xxy * fDelta + vPos ).fDist * e.xxy + 
        Scene_GetDistance( e.xyx * fDelta + vPos ).fDist * e.xyx + 
        Scene_GetDistance( e.yyy * fDelta + vPos ).fDist * e.yyy;
    
    return normalize( vNormal );
}    
    
SceneResult Scene_Trace( const in vec3 vRayOrigin, const in vec3 vRayDir, float minDist, float maxDist )
{	
    SceneResult result;
    result.fDist = 0.0;
    result.vUVW = vec3(0.0,0.0,0.0);
    result.iObjectId = -1;
    
	float t = minDist;
	const int kRaymarchMaxIter = 128;
	for(int i=0; i<kRaymarchMaxIter; i++)
	{		
        float epsilon = 0.0001 * t;
		result = Scene_GetDistance( vRayOrigin + vRayDir * t );
        if ( abs(result.fDist) < epsilon )
		{
			break;
		}
                        
        if ( t > maxDist )
        {
            result.iObjectId = -1;
	        t = maxDist;
            break;
        }       
        
        if ( result.fDist > 1.0 )
        {
            result.iObjectId = -1;            
        }    
        
        t += result.fDist;        
	}
    
    result.fDist = t;


    return result;
}    

float Scene_TraceShadow( const in vec3 vRayOrigin, const in vec3 vRayDir, const in float fMinDist, const in float fLightDist )
{
    //return 1.0;
    //return ( Scene_Trace( vRayOrigin, vRayDir, 0.1, fLightDist ).fDist < fLightDist ? 0.0 : 1.0;
    
	float res = 1.0;
    float t = fMinDist;
    for( int i=0; i<16; i++ )
    {
		float h = Scene_GetDistance( vRayOrigin + vRayDir * t ).fDist;
        res = min( res, 8.0*h/t );
        t += clamp( h, 0.02, 0.10 );
        if( h<0.0001 || t>fLightDist ) break;
    }
    return clamp( res, 0.0, 1.0 );    
}

float Scene_GetAmbientOcclusion( const in vec3 vPos, const in vec3 vDir )
{
    float fOcclusion = 0.0;
    float fScale = 1.0;
    for( int i=0; i<5; i++ )
    {
        float fOffsetDist = 0.001 + 0.1*float(i)/4.0;
        vec3 vAOPos = vDir * fOffsetDist + vPos;
        float fDist = Scene_GetDistance( vAOPos ).fDist;
        fOcclusion += (fOffsetDist - fDist) * fScale;
        fScale *= 0.4;
    }
    
    return clamp( 1.0 - 30.0*fOcclusion, 0.0, 1.0 );
}

///////////////////////////
// Lighting
///////////////////////////
    
struct SurfaceInfo
{
    vec3 vPos;
    vec3 vNormal;
    vec3 vBumpNormal;    
    vec3 vAlbedo;
    vec3 vR0;
    float fSmoothness;
    vec3 vEmissive;
};
    
SurfaceInfo Scene_GetSurfaceInfo( const in vec3 vRayOrigin,  const in vec3 vRayDir, SceneResult traceResult );

struct SurfaceLighting
{
    vec3 vDiffuse;
    vec3 vSpecular;
};
    
SurfaceLighting Scene_GetSurfaceLighting( const in vec3 vRayDir, in SurfaceInfo surfaceInfo );

float Light_GIV( float dotNV, float k)
{
	return 1.0 / ((dotNV + 0.0001) * (1.0 - k)+k);
}

void Light_Add(inout SurfaceLighting lighting, SurfaceInfo surface, const in vec3 vViewDir, const in vec3 vLightDir, const in vec3 vLightColour)
{
	float fNDotL = clamp(dot(vLightDir, surface.vBumpNormal), 0.0, 1.0);
	
	lighting.vDiffuse += vLightColour * fNDotL;
    
	vec3 vH = normalize( -vViewDir + vLightDir );
	float fNdotV = clamp(dot(-vViewDir, surface.vBumpNormal), 0.0, 1.0);
	float fNdotH = clamp(dot(surface.vBumpNormal, vH), 0.0, 1.0);
    
	float alpha = 1.0 - surface.fSmoothness;
	// D

	float alphaSqr = alpha * alpha;
	float denom = fNdotH * fNdotH * (alphaSqr - 1.0) + 1.0;
	float d = alphaSqr / (PI * denom * denom);

	float k = alpha / 2.0;
	float vis = Light_GIV(fNDotL, k) * Light_GIV(fNdotV, k);

	float fSpecularIntensity = d * vis * fNDotL;    
	lighting.vSpecular += vLightColour * fSpecularIntensity;    
}

void Light_AddPoint(inout SurfaceLighting lighting, SurfaceInfo surface, const in vec3 vViewDir, const in vec3 vLightPos, const in vec3 vLightColour)
{    
    vec3 vPos = surface.vPos;
	vec3 vToLight = vLightPos - vPos;	
    
	vec3 vLightDir = normalize(vToLight);
	float fDistance2 = dot(vToLight, vToLight);
	float fAttenuation = 100.0 / (fDistance2);
	
	float fShadowFactor = Scene_TraceShadow( surface.vPos, vLightDir, 0.1, length(vToLight) );
	
	Light_Add( lighting, surface, vViewDir, vLightDir, vLightColour * fShadowFactor * fAttenuation);
}

void Light_AddDirectional(inout SurfaceLighting lighting, SurfaceInfo surface, const in vec3 vViewDir, const in vec3 vLightDir, const in vec3 vLightColour)
{	
	float fAttenuation = 1.0;
	float fShadowFactor = Scene_TraceShadow( surface.vPos, vLightDir, 0.1, 10.0 );
	
	Light_Add( lighting, surface, vViewDir, vLightDir, vLightColour * fShadowFactor * fAttenuation);
}

vec3 Light_GetFresnel( vec3 vView, vec3 vNormal, vec3 vR0, float fGloss )
{
    float NdotV = max( 0.0, dot( vView, vNormal ) );

    return vR0 + (vec3(1.0,1.0,1.0) - vR0) * pow( 1.0 - NdotV, 5.0 ) * pow( fGloss, 20.0 );
}

void Env_AddPointLightFlare(inout vec3 vEmissiveGlow, const in vec3 vRayOrigin, const in vec3 vRayDir, const in float fIntersectDistance, const in vec3 vLightPos, const in vec3 vLightColour)
{
    vec3 vToLight = vLightPos - vRayOrigin;
    float fPointDot = dot(vToLight, vRayDir);
    fPointDot = clamp(fPointDot, 0.0, fIntersectDistance);

    vec3 vClosestPoint = vRayOrigin + vRayDir * fPointDot;
    float fDist = length(vClosestPoint - vLightPos);
	vEmissiveGlow += sqrt(vLightColour * 0.05 / (fDist * fDist));
}

void Env_AddDirectionalLightFlareToFog(inout vec3 vFogColour, const in vec3 vRayDir, const in vec3 vLightDir, const in vec3 vLightColour)
{
	float fDirDot = clamp(dot(vLightDir, vRayDir) * 0.5 + 0.5, 0.0, 1.0);
	float kSpreadPower = 2.0;
	vFogColour += vLightColour * pow(fDirDot, kSpreadPower) * 0.25;
}


///////////////////////////
// Rendering
///////////////////////////

vec4 Env_GetSkyColor( const vec3 vViewPos, const vec3 vViewDir );
vec3 Env_ApplyAtmosphere( const in vec3 vColor, const in vec3 vRayOrigin,  const in vec3 vRayDir, const in float fDist );
vec3 FX_Apply( in vec3 vColor, const in vec3 vRayOrigin,  const in vec3 vRayDir, const in float fDist);

vec4 Scene_GetColorAndDepth( vec3 vRayOrigin, vec3 vRayDir )
{
	vec3 vResultColor = vec3(0.0,0.0,0.0);
            
	SceneResult firstTraceResult;
    
    float fStartDist = 0.0f;
    float fMaxDist = 10.0f;
    
    vec3 vRemaining = vec3(1.0,1.0,1.0);
    
	for( int iPassIndex=0; iPassIndex < 3; iPassIndex++ )
    {
    	SceneResult traceResult = Scene_Trace( vRayOrigin, vRayDir, fStartDist, fMaxDist );

        if ( iPassIndex == 0 )
        {
            firstTraceResult = traceResult;
        }
        
        vec3 vColor = vec3(0,0,0);
        vec3 vReflectAmount = vec3(0,0,0);
        
		if( traceResult.iObjectId < 0 )
		{
            vColor = Env_GetSkyColor( vRayOrigin, vRayDir ).rgb;
        }
        else
        {
            
            SurfaceInfo surfaceInfo = Scene_GetSurfaceInfo( vRayOrigin, vRayDir, traceResult );
            SurfaceLighting surfaceLighting = Scene_GetSurfaceLighting( vRayDir, surfaceInfo );
                
            // calculate reflectance (Fresnel)
			vReflectAmount = Light_GetFresnel( -vRayDir, surfaceInfo.vBumpNormal, surfaceInfo.vR0, surfaceInfo.fSmoothness );
			
			vColor = (surfaceInfo.vAlbedo * surfaceLighting.vDiffuse + surfaceInfo.vEmissive) * (vec3(1.0,1.0,1.0) - vReflectAmount); 
            
            vec3 vReflectRayOrigin = surfaceInfo.vPos;
            vec3 vReflectRayDir = normalize( reflect( vRayDir, surfaceInfo.vBumpNormal ) );
            fStartDist = 0.001 / max(0.0000001,abs(dot( vReflectRayDir, surfaceInfo.vNormal ))); 

            vColor += surfaceLighting.vSpecular * vReflectAmount;            

			vColor = Env_ApplyAtmosphere( vColor, vRayOrigin, vRayDir, traceResult.fDist );
			vColor = FX_Apply( vColor, vRayOrigin, vRayDir, traceResult.fDist );
            
            vRayOrigin = vReflectRayOrigin;
            vRayDir = vReflectRayDir;
        }
        
        vResultColor += vColor * vRemaining;
        vRemaining *= vReflectAmount;        
    }
 
    return vec4( vResultColor, firstTraceResult.fDist );
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////
// Scene Description
/////////////////////////

// Materials

#define MAT_SKY		 	-1
#define MAT_DEFAULT 	 0
#define MAT_SCREEN		 1
#define MAT_TV_CASING    2
#define MAT_TV_TRIM      3
#define MAT_CHROME       4


vec3 PulseIntegral( vec3 x, float s1, float s2 )
{
    // Integral of function where result is 1.0 between s1 and s2 and 0 otherwise        

    // V1
    //if ( x > s2 ) return s2 - s1;
	//else if ( x > s1 ) return x - s1;
	//return 0.0f; 
    
    // V2
    //return clamp( (x - s1), 0.0f, s2 - s1);
    //return t;
    
    return clamp( (x - s1), vec3(0.0f,0.0f,0.0f), vec3(s2 - s1,s2 - s1,s2 - s1));
}

float PulseIntegral( float x, float s1, float s2 )
{
    // Integral of function where result is 1.0 between s1 and s2 and 0 otherwise        

    // V1
    //if ( x > s2 ) return s2 - s1;
	//else if ( x > s1 ) return x - s1;
	//return 0.0f; 
    
    // V2
    //return clamp( (x - s1), 0.0f, s2 - s1);
    //return t;
    
    return clamp( (x - s1), (0.0f), (s2 - s1));
}

vec3 Bayer( vec2 vUV, vec2 vBlur )
{
    vec3 x = vec3(vUV.xxx);
    vec3 y = vec3(vUV.yyy);           

    x += vec3(0.66, 0.33, 0.0);
    y += 0.5 * step( fract( x * 0.5 ), vec3(0.5,0.5,0.5) );
        
    //x -= 0.5f;
    //y -= 0.5f;
    
    x = fract( x );
    y = fract( y );
    
    // cell centered at 0.5
    
    vec2 vSize = vec2(0.16f, 0.75f);
    
    vec2 vMin = 0.5 - vSize * 0.5;
    vec2 vMax = 0.5 + vSize * 0.5;
    
    vec3 vResult= vec3(0.0,0.0,0.0);
    
    vec3 vResultX = (PulseIntegral( x + vBlur.x, vMin.x, vMax.x) - PulseIntegral( x - vBlur.x, vMin.x, vMax.x)) / min( vBlur.x, 1.0);
    vec3 vResultY = (PulseIntegral(y + vBlur.y, vMin.y, vMax.y) - PulseIntegral(y - vBlur.y, vMin.y, vMax.y))  / min( vBlur.y, 1.0);
    
    vResult = min(vResultX,vResultY)  * 5.0;
        
    //vResult = vec3(1.0);
    
    return vResult;
}

vec3 GetPixelMatrix( vec2 vUV )
{
#if 1
    vec2 dx = ddx( vUV );
    vec2 dy = ddy( vUV );
    float dU = length( vec2( dx.x, dy.x ) );
    float dV = length( vec2( dx.y, dy.y ) );
    if (dU <= 0.0 || dV <= 0.0 ) return vec3(1.0,1.0,1.0);
    return Bayer( vUV, vec2(dU, dV) * 1.0);
#else
    return vec3(1.0,1.0,1.0);
#endif
}

float Scanline( float y, float fBlur )
{   
    float fResult = sin( y * 10.0 ) * 0.45 + 0.55;
    return mix( fResult, 1.0f, min( 1.0, fBlur ) );
}


float GetScanline( vec2 vUV )
{
#if 1
    vUV.y *= 0.25;
    vec2 dx = ddx( vUV );
    vec2 dy = ddy( vUV );
    float dV = length( vec2( dx.y, dy.y ) );
    if (dV <= 0.0 ) return 1.0;
    return Scanline( vUV.y, dV * 1.3 );
#else
    return 1.0;
#endif
}


static const vec2 kScreenRsolution = vec2(480.0f, 576.0f);

struct Interference
{
    float noise;
    float scanLineRandom;
};

float InterferenceHash(float p)
{
    float hashScale = 0.1031;

    vec3 p3  = fract(vec3(p, p, p) * hashScale);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}


float InterferenceSmoothNoise1D( float x )
{
    float f0 = floor(x);
    float fr = fract(x);

    float h0 = InterferenceHash( f0 );
    float h1 = InterferenceHash( f0 + 1.0 );

    return h1 * fr + h0 * (1.0 - fr);
}


float InterferenceNoise( vec2 uv )
{
	float displayVerticalLines = 483.0;
    float scanLine = floor(uv.y * displayVerticalLines); 
    float scanPos = scanLine + uv.x;
	float timeSeed = fract( Time * 123.78 );
    
    return InterferenceSmoothNoise1D( scanPos * 234.5 + timeSeed * 12345.6 );
}
    
Interference GetInterference( vec2 vUV )
{
    Interference interference;
        
    interference.noise = InterferenceNoise( vUV );
    interference.scanLineRandom = InterferenceHash(vUV.y * 100.0 + fract(Time * 1234.0) * 12345.0);
    
    return interference;
}
    
vec3 SampleScreen( vec3 vUVW )
{   
    vec3 vAmbientEmissive = vec3(0.1,0.1,0.1);
    vec3 vBlackEmissive = vec3(0.02,0.02,0.02);
    float fBrightness = 1.75;
    vec2 vResolution = vec2(480.0f, 576.0f);
    vec2 vPixelCoord = vUVW.xy * vResolution;
    
    vec3 vPixelMatrix = GetPixelMatrix( vPixelCoord );
    float fScanline = GetScanline( vPixelCoord );
      
    vec2 vTextureUV = vUVW.xy;
    //vec2 vTextureUV = vPixelCoord;
#ifdef LIMIT_RESOLUTION    
    vTextureUV = floor(vTextureUV * vResolution * 2.0) / (vResolution * 2.0f);
#endif    
    
    Interference interference = GetInterference( vTextureUV );

    float noiseIntensity = 0.1;
    
    //vTextureUV.x += (interference.scanLineRandom * 2.0f - 1.0f) * 0.025f * noiseIntensity;
    
    
    vTextureUV.y = 1.0f - vTextureUV.y;
    vec3 vPixelEmissive = shaderTexture.Sample(samplerState, vTextureUV); //vec3(0,0,0);// textureLod( iChannel0, vTextureUV.xy, 0.0 ).rgb;
        
    vPixelEmissive = clamp( vPixelEmissive + (interference.noise - 0.5) * 2.0 * noiseIntensity, 0.0, 1.0 );
    
	vec3 vResult = (vPixelEmissive * vPixelEmissive * fBrightness + vBlackEmissive) * vPixelMatrix * fScanline + vAmbientEmissive;
    
    // TODO: feather edge?
    if( ( vUVW.x >= 1.0 || vUVW.y >= 1.0) || ( vUVW.x < 0.0 || vUVW.y < 0.0) || ( vUVW.z > 0.0 ) )
    {
        vResult = vec3(0.0,0.0,0.0);
    }
    
    return vResult;
    
}

float Checker(vec2 vUV)
{
	return step(fract((floor(vUV.x) + floor(vUV.y)) * 0.5), 0.25);
}

SurfaceInfo Scene_GetSurfaceInfo( const in vec3 vRayOrigin,  const in vec3 vRayDir, SceneResult traceResult )
{
    SurfaceInfo surfaceInfo;
    
    surfaceInfo.vPos = vRayOrigin + vRayDir * (traceResult.fDist);
    
    surfaceInfo.vNormal = Scene_GetNormal( surfaceInfo.vPos ); 
    surfaceInfo.vBumpNormal = surfaceInfo.vNormal;
    surfaceInfo.vAlbedo = vec3(1.0,1.0,1.0);
    surfaceInfo.vR0 = vec3( 0.02,0.02,0.02 );
    surfaceInfo.fSmoothness = 1.0;
    surfaceInfo.vEmissive = vec3( 0.0,0.0,0.0 );
    //return surfaceInfo;
        
    if ( traceResult.iObjectId == MAT_DEFAULT )
    {
    	surfaceInfo.vR0 = vec3( 0.02, 0.02, 0.02 );
        float checker = Checker(traceResult.vUVW.xz * 4.0);
	    surfaceInfo.vAlbedo = mix( vec3(.9,.2,.2),vec3(.2,.2,.9), checker );                        
    	surfaceInfo.fSmoothness = clamp( 1.0 - surfaceInfo.vAlbedo.r * surfaceInfo.vAlbedo.r * 2.0, 0.0, 1.0);
        
    }
    
    if ( traceResult.iObjectId == MAT_SCREEN )
    {
        surfaceInfo.vAlbedo = vec3(0.02,0.02,0.02); 
        surfaceInfo.vEmissive = SampleScreen( traceResult.vUVW );        
    }

    if ( traceResult.iObjectId == MAT_TV_CASING )
    {
        surfaceInfo.vAlbedo = vec3(0.5, 0.4, 0.3); 
	    surfaceInfo.fSmoothness = 0.4;        
    }
    
    if ( traceResult.iObjectId == MAT_TV_TRIM )
    {
        surfaceInfo.vAlbedo = vec3(0.03, 0.03, 0.05); 
	    surfaceInfo.fSmoothness = 0.5;
    }    

    if ( traceResult.iObjectId == MAT_CHROME )
    {
        surfaceInfo.vAlbedo = vec3(0.01, 0.01, 0.01); 
	    surfaceInfo.fSmoothness = 0.9;
    	surfaceInfo.vR0 = vec3( 0.8,0.8,0.8 );
    }    
 
    return surfaceInfo;
}

// Scene Description

float SmoothMin( float a, float b, float k )
{
	//return min(a,b);
	
	
    //float k = 0.06;
	float h = clamp( 0.5 + 0.5*(b-a)/k, 0.0, 1.0 );
	return mix( b, a, h ) - k*h*(1.0-h);
}

float UdRoundBox( vec3 p, vec3 b, float r )
{
    //vec3 vToFace = abs(p) - b;
    //vec3 vConstrained = max( vToFace, 0.0 );
    //return length( vConstrained ) - r;
    return length(max(abs(p)-b,0.0))-r;
}

SceneResult Scene_GetCRT( vec3 vScreenDomain, vec2 vScreenWH, float fScreenCurveRadius, float fBevel, float fDepth )
{
    SceneResult resultScreen;
#if 1
    vec3 vScreenClosest;
    vScreenClosest.xy = max(abs(vScreenDomain.xy)-vScreenWH,0.0);
    vec2 vCurveScreenDomain = vScreenDomain.xy;
    vCurveScreenDomain = clamp( vCurveScreenDomain, -vScreenWH, vScreenWH );
    float fCurveScreenProjection2 = fScreenCurveRadius * fScreenCurveRadius - vCurveScreenDomain.x * vCurveScreenDomain.x - vCurveScreenDomain.y * vCurveScreenDomain.y;
    float fCurveScreenProjection = sqrt( fCurveScreenProjection2 ) - fScreenCurveRadius;
    vScreenClosest.z = vScreenDomain.z - clamp( vScreenDomain.z, -fCurveScreenProjection, fDepth );
    resultScreen.vUVW.z = vScreenDomain.z + fCurveScreenProjection;        
    resultScreen.fDist = (length( vScreenClosest ) - fBevel) * 0.95;
    //resultScreen.fDist = (length( vScreenDomain - vec3(0,0,fScreenCurveRadius)) - fScreenCurveRadius - fBevel);    
#endif    
    
#if 0
    vec3 vScreenClosest;
    vScreenClosest.xyz = max(abs(vScreenDomain.xyz)-vec3(vScreenWH, fDepth),0.0);
    float fRoundDist = length( vScreenClosest.xyz ) - fBevel;
    float fSphereDist = length( vScreenDomain - vec3(0,0,fScreenCurveRadius) ) - (fScreenCurveRadius + fBevel);    
    resultScreen.fDist = max(fRoundDist, fSphereDist);
#endif    
    
    resultScreen.vUVW.xy = (vScreenDomain.xy / vScreenWH) * 0.5 + 0.5f;
	resultScreen.iObjectId = MAT_SCREEN;
    return resultScreen;
}

SceneResult Scene_GetComputer( vec3 vPos )
{
    SceneResult resultComputer;
    resultComputer.vUVW = vPos.xzy;
	
    float fXSectionStart = -0.2;
    float fXSectionLength = 0.15;
    float fXSectionT = clamp( (vPos.z - fXSectionStart) / fXSectionLength, 0.0, 1.0);
    float fXSectionR1 = 0.03;
    float fXSectionR2 = 0.05;
    float fXSectionR = mix( fXSectionR1, fXSectionR2, fXSectionT );
    float fXSectionZ = fXSectionStart + fXSectionT * fXSectionLength;
    
    vec2 vXSectionCentre = vec2(fXSectionR, fXSectionZ );
    vec2 vToPos = vPos.yz - vXSectionCentre;
    float l = length( vToPos );
    if ( l > fXSectionR ) l = fXSectionR;
    vec2 vXSectionClosest = vXSectionCentre + normalize(vToPos) * l;
    //float fXSectionDist = length( vXSectionClosest ) - fXSectionR;
    
    float x = max( abs( vPos.x ) - 0.2f, 0.0 );

    resultComputer.fDist = length( vec3(x, vXSectionClosest - vPos.yz) )-0.01;
    //resultComputer.fDist = x;
        
    resultComputer.iObjectId = MAT_TV_CASING;
/*
    vec3 vKeyPos = vPos.xyz - vec3(0,0.125,0);
    vKeyPos.y -= vKeyPos.z * (fXSectionR2 - fXSectionR1) * 2.0 / fXSectionLength;
    float fDomainRepeatScale = 0.02;
    if ( fract(vKeyPos.z * 0.5 / fDomainRepeatScale + 0.25) > 0.5) vKeyPos.x += fDomainRepeatScale * 0.5;
    vec2 vKeyIndex = round(vKeyPos.xz / fDomainRepeatScale);
    vKeyIndex.x = clamp( vKeyIndex.x, -8.0, 8.0 );
    vKeyIndex.y = clamp( vKeyIndex.y, -10.0, -5.0 );
    //vKeyPos.xz = (fract( vKeyPos.xz / fDomainRepeatScale ) - 0.5) * fDomainRepeatScale;
    vKeyPos.xz = (vKeyPos.xz - (vKeyIndex) * fDomainRepeatScale);
    vKeyPos.xz /= 0.7 + vKeyPos.y;
    SceneResult resultKey;    
    resultKey.vUVW = vPos.xzy;
    resultKey.fDist = UdRoundBox( vKeyPos, vec3(0.01), 0.001 );
    resultKey.iObjectId = MAT_TV_TRIM;
    Scene_Union( resultComputer, resultKey );
*/    
    return resultComputer;
}

SceneResult Scene_GetDistance( vec3 vPos )
{
    SceneResult result;
    
	//result.fDist = vPos.y;
    float fBenchBevel = 0.01;
    result.fDist = UdRoundBox( vPos - vec3(0,-0.02-fBenchBevel,0.0), vec3(2.0, 0.02, 1.0), fBenchBevel );
    result.vUVW = vPos;
	result.iObjectId = MAT_DEFAULT;        
    
    vec3 vSetPos = vec3(0.0, 0.0, 0.0);
    vec3 vScreenPos = vSetPos + vec3(0.0, 0.25, 0.00);
    
    //vPos.x = fract( vPos.x - 0.5) - 0.5;
    
    vec2 vScreenWH = vec2(4.0, 3.0) / 25.0;

    SceneResult resultSet;
    resultSet.vUVW = vPos.xzy;
	resultSet.fDist = UdRoundBox( vPos - vScreenPos - vec3(0.0,-0.01,0.2), vec3(.21, 0.175, 0.18), 0.01 );
    resultSet.iObjectId = MAT_TV_CASING;
    Scene_Union( result, resultSet );

    SceneResult resultSetRecess;
    resultSetRecess.vUVW = vPos.xzy;
    resultSetRecess.fDist = UdRoundBox( vPos - vScreenPos - vec3(0.0,-0.0, -0.05), vec3(vScreenWH + 0.01, 0.05) + 0.005, 0.015 );
    resultSetRecess.iObjectId = MAT_TV_TRIM;
	Scene_Subtract( result, resultSetRecess );
    
    SceneResult resultSetBase;
    resultSetBase.vUVW = vPos.xzy;
    float fBaseBevel = 0.03;
	resultSetBase.fDist = UdRoundBox( vPos - vSetPos - vec3(0.0,0.04,0.22), vec3(0.2, 0.04, 0.17) - fBaseBevel, fBaseBevel );
    resultSetBase.iObjectId = MAT_TV_CASING;
    Scene_Union( result, resultSetBase );

	SceneResult resultScreen = Scene_GetCRT( vPos - vScreenPos, vScreenWH, 0.75f, 0.02f, 0.1f );
    Scene_Union( result, resultScreen );    
    
    //SceneResult resultComputer = Scene_GetComputer( vPos - vec3(0.0, 0.0, -0.1) );
    //Scene_Union( result, resultComputer );

    SceneResult resultSphere;
    resultSet.vUVW = vPos.xzy;
	resultSet.fDist = length(vPos - vec3(0.35,0.075,-0.1)) - 0.075;
    resultSet.iObjectId = MAT_CHROME;
    Scene_Union( result, resultSet );    
    
    return result;
}



// Scene Lighting

static const vec3 g_vSunDir = normalize(vec3(0.3, 0.4, -0.5));
static const vec3 g_vSunColor = vec3(1, 0.95, 0.8) * 3.0;
static const vec3 g_vAmbientColor = vec3(0.8, 0.8, 0.8) * 1.0;

SurfaceLighting Scene_GetSurfaceLighting( const in vec3 vViewDir, in SurfaceInfo surfaceInfo )
{
    SurfaceLighting surfaceLighting;
    
    surfaceLighting.vDiffuse = vec3(0.0,0.0,0.0);
    surfaceLighting.vSpecular = vec3(0.0,0.0,0.0);    
    
    Light_AddDirectional( surfaceLighting, surfaceInfo, vViewDir, g_vSunDir, g_vSunColor );
    
    Light_AddPoint( surfaceLighting, surfaceInfo, vViewDir, vec3(1.4, 2.0, 0.8), vec3(1,1,1) * 0.2 );
    
    float fAO = Scene_GetAmbientOcclusion( surfaceInfo.vPos, surfaceInfo.vNormal );
    // AO
    surfaceLighting.vDiffuse += fAO * (surfaceInfo.vBumpNormal.y * 0.5 + 0.5) * g_vAmbientColor;
    
    return surfaceLighting;
}

// Environment

vec4 Env_GetSkyColor( const vec3 vViewPos, const vec3 vViewDir )
{
	vec4 vResult = vec4( 0.0, 0.0, 0.0, kFarDist );

#if 0
    vec3 vEnvMap = textureLod( iChannel1, vViewDir.zyx, 0.0 ).rgb;
    vResult.rgb = vEnvMap;
#endif    
    
#if 0
    vec3 vEnvMap = textureLod( iChannel1, vViewDir.zyx, 0.0 ).rgb;
    vEnvMap = vEnvMap * vEnvMap;
    float kEnvmapExposure = 0.999;
    vResult.rgb = -log2(1.0 - vEnvMap * kEnvmapExposure);

#endif
    
    vResult.rgb = mix( vec3(0.3,0.8,0.9),vec3(0.3,0.4,0.9), vViewDir.y );
    
    // Sun
    float NdotV = dot( g_vSunDir, vViewDir );
    vResult.rgb += smoothstep( cos(radians(.7)), cos(radians(.5)), NdotV ) * g_vSunColor * 100.0;

    return vResult;	
}

float Env_GetFogFactor(const in vec3 vRayOrigin,  const in vec3 vRayDir, const in float fDist )
{    
	float kFogDensity = 0.00001;
	return exp(fDist * -kFogDensity);	
}

vec3 Env_GetFogColor(const in vec3 vDir)
{    
	return vec3(0.2, 0.5, 0.6) * 2.0;		
}

vec3 Env_ApplyAtmosphere( const in vec3 vColor, const in vec3 vRayOrigin,  const in vec3 vRayDir, const in float fDist )
{
    //return vColor;
    vec3 vResult = vColor;
    
    
	float fFogFactor = Env_GetFogFactor( vRayOrigin, vRayDir, fDist );
	vec3 vFogColor = Env_GetFogColor( vRayDir );	
	//Env_AddDirectionalLightFlareToFog( vFogColor, vRayDir, g_vSunDir, g_vSunColor * 3.0);    
    vResult = mix( vFogColor, vResult, fFogFactor );

    return vResult;	    
}


vec3 FX_Apply( in vec3 vColor, const in vec3 vRayOrigin,  const in vec3 vRayDir, const in float fDist)
{    
    return vColor;
}


vec4 MainCommon( vec3 vRayOrigin, vec3 vRayDir )
{
	vec4 vColorLinAndDepth = Scene_GetColorAndDepth( vRayOrigin, vRayDir );    
    vColorLinAndDepth.rgb = max( vColorLinAndDepth.rgb, vec3(0.0,0.0,0.0) );
    
    vec4 vFragColor = vColorLinAndDepth;
    
    float fExposure = 2.0f;
    
    vFragColor.rgb *= fExposure;
    
    vFragColor.a = vColorLinAndDepth.w;
    
    return vFragColor;
}

///////////////////////////
// Camera
///////////////////////////

struct CameraState
{
    vec3 vPos;
    vec3 vTarget;
    float fFov;
    vec2 vJitter;
    float fPlaneInFocus;
};

mat3 Cam_GetWorldToCameraRotMatrix( const CameraState cameraState )
{
    vec3 vForward = normalize( cameraState.vTarget - cameraState.vPos );
	vec3 vRight = normalize( cross(vec3(0, 1, 0), vForward) );
	vec3 vUp = normalize( cross(vForward, vRight) );
    
    return mat3( vRight, vUp, vForward );
}

vec2 Cam_GetViewCoordFromUV( vec2 vUV, vec2 res )
{
	vec2 vWindow = vUV * 2.0 - 1.0;
	vWindow.x *= res.x / res.y;

	return vWindow;	
}

void Cam_GetCameraRay( vec2 vUV, vec2 res, CameraState cam, out vec3 vRayOrigin, out vec3 vRayDir )
{
    vec2 vView = Cam_GetViewCoordFromUV( vUV, res );
    vRayOrigin = cam.vPos;
    float fPerspDist = 1.0 / tan( radians( cam.fFov ) );
    vRayDir = normalize( mul( vec3( vView, fPerspDist ), Cam_GetWorldToCameraRotMatrix( cam ) ) );
}

vec2 Cam_GetUVFromWindowCoord( vec2 vWindow, vec2 res )
{
    vec2 vScaledWindow = vWindow;
    vScaledWindow.x *= res.y / res.x;

    return (vScaledWindow * 0.5 + 0.5);
}

vec2 Cam_WorldToWindowCoord(const in vec3 vWorldPos, const in CameraState cameraState )
{
    vec3 vOffset = vWorldPos - cameraState.vPos;
    vec3 vCameraLocal;

    vCameraLocal =mul( Cam_GetWorldToCameraRotMatrix( cameraState ), vOffset );
	
    vec2 vWindowPos = vCameraLocal.xy / (vCameraLocal.z * tan( radians( cameraState.fFov ) ));
    
    return vWindowPos;
}


CameraState GetCameraPosition( int index )
{
    CameraState cam;

    cam.vPos = vec3(0,0,0);
    cam.vTarget = vec3(0,0,1);
    cam.fFov = 10.0;

    vec3 vFocus = vec3(0,0.25,-0.012);   
    
    if ( index > 9 )
    {
    	index = int(hash11(float(index) / 10.234) * 100.0);
    	index = (int)((uint)index % 10);
    }

    //index=7;
    
    if ( index == 0 )
    {
        cam.vPos = vec3(-0.1,0.2,-0.08);
        cam.vTarget = vec3(0,0.25,0.1);
        cam.fFov = 10.0;
    }
    if ( index == 1 )
    {
        cam.vPos = vec3(0.01,0.334,-0.6);
        cam.vTarget = vec3(0,0.3,0.1);
        cam.fFov = 10.0;
    }
    if ( index == 2 )
    {
        cam.vPos = vec3(-0.8,0.3,-1.0);
        cam.vTarget = vec3(0.4,0.18,0.5);
        cam.fFov = 10.0;
    }
    if ( index == 3 )
    {
        cam.vPos = vec3(-0.8,1.0,-1.5);
        cam.vTarget = vec3(0.2,0.0,0.5);
        cam.fFov = 10.0;
    }
    if ( index == 4 )
    {
        cam.vPos = vec3(-0.8,0.3,-1.0);
        cam.vTarget = vec3(0.4,0.18,0.5);
        cam.fFov = 20.0;
    }
    if ( index == 5 )
    {
        cam.vPos = vec3(-0.244,0.334,-0.0928);
        cam.vTarget = vec3(0,0.25,0.1);
        cam.fFov = 20.0;
    }
    if ( index == 6 )
    {
        cam.vPos = vec3(0.0,0.1,-0.5);
        cam.vTarget = vec3(0.2,0.075,-0.1);
        vFocus = cam.vTarget; 
        cam.fFov = 15.0;
    }
    if ( index == 7 )
    {
        cam.vPos = vec3(-0.01,0.01,-0.25);
        cam.vTarget = vec3(0.01,0.27,0.1);
        vFocus = cam.vTarget; 
        cam.fFov = 23.0;
    }
    if ( index == 8 )
    {
        cam.vPos = vec3(-0.23,0.3,-0.05);
        cam.vTarget = vec3(0.1,0.2,0.1);
        cam.fFov = 15.0;
    }
    if ( index == 9 )
    {
        cam.vPos = vec3(0.4,0.2,-0.2);
        cam.vTarget = vec3(-0.1,0.25,0.1);
        cam.fFov = 12.0;
    }

    // 
#ifdef NO_OVERLAY
    cam.vPos = vec3(0.0,0.25,-0.4);
    cam.vTarget = vec3(0.0,0.25,0.1);
    vFocus = cam.vTarget; 
    cam.fFov = 23.0;    
#endif    
    
    cam.fPlaneInFocus = length( vFocus - cam.vPos);
    cam.vJitter = vec2(0.0,0.0);        
    
    return cam;
}


vec3 Tonemap( vec3 x )
{
#if 0 
    
    vec3 luminanceCoeffsBT709 = vec3( 0.2126f, 0.7152f, 0.0722f );
    float f = dot( x, luminanceCoeffsBT709 );
    x /= f;        
    f = 1.0f - exp(-f);    
    x *= f;    
    x = mix( x, vec3(f), f*f );
    
    return x;
#else       
    float a = 0.010;
    float b = 0.132;
    float c = 0.010;
    float d = 0.163;
    float e = 0.101;

    return ( x * ( a * x + b ) ) / ( x * ( c * x + d ) + e );    
#endif    
}


float GetVignetting( const in vec2 vUV, float fScale, float fPower, float fStrength )
{
	vec2 vOffset = (vUV - 0.5) * sqrt(2.0) * fScale;
	
	float fDist = max( 0.0, 1.0 - length( vOffset ) );
    
	float fShade = 1.0 - pow( fDist, fPower );
    
    fShade = 1.0 - fShade * fStrength;

	return fShade;
}


void mainImage( out vec4 vFragColor, in vec2 vFragCoord )
{
    vec2 vUV = vFragCoord.xy / Resolution.xy; 

    CameraState cam;
    
    {
    	CameraState camA;
    	CameraState camB;
    
        float fSeqTime = Time;
        float fSequenceSegLength = 5.0;
        float fSeqIndex = floor(fSeqTime / fSequenceSegLength);
        float fSeqPos = fract(fSeqTime / fSequenceSegLength);
        int iIndex = int(fSeqIndex);
		int iIndexNext = int(fSeqIndex) + 1;
        camA = GetCameraPosition(iIndex);
        camB = GetCameraPosition(iIndexNext);
        
        float t = smoothstep(0.3, 1.0, fSeqPos);
        cam.vPos = mix(camA.vPos, camB.vPos, t );
        cam.vTarget = mix(camA.vTarget, camB.vTarget, t );
        cam.fFov = mix(camA.fFov, camB.fFov, t );
        cam.fPlaneInFocus = mix(camA.fPlaneInFocus, camB.fPlaneInFocus, t );
    }
    
    /*if ( iMouse.z > 0.0 )
    {
        float fDist = 0.01 + 3.0 * (iMouse.y / iResolution.y);

        float fAngle = (iMouse.x / iResolution.x) * radians(360.0);
    	//float fElevation = (iMouse.y / iResolution.y) * radians(90.0);
    	float fElevation = 0.15f * radians(90.0);    

        cam.vPos = vec3(sin(fAngle) * fDist * cos(fElevation),sin(fElevation) * fDist,cos(fAngle) * fDist * cos(fElevation));
        cam.vTarget = vec3(0,0.25,0.1);
        cam.vPos +=cam.vTarget;
        cam.fFov = 20.0 / (1.0 + fDist * 0.5);
    	vec3 vFocus = vec3(0,0.25,-0.012);	    
	    cam.fPlaneInFocus = length( vFocus - cam.vPos );
    }*/
    
#if 0
    {
        float fDist = 0.5;

        float fAngle = 0.6 * PI * 2.0f;
        float fElevation = 0.2;
        
        cam.vPos = vec3(sin(fAngle) * fDist * cos(fElevation),sin(fElevation) * fDist,cos(fAngle) * fDist * cos(fElevation));
        cam.vTarget = vec3(0.05,0.25,0.1);
        cam.vPos +=cam.vTarget;
        cam.fFov = 22.0;
    	vec3 vFocus = vec3(0,0.25,-0.012);	    
	    cam.fPlaneInFocus = length( vFocus - cam.vPos );
    }
#endif
    
#ifdef ENABLE_TAA_JITTER
    cam.vJitter = hash21( fract( Time ) ) - 0.5f;
#else
    cam.vJitter = vec2(0,0);
#endif
    
            
    vec3 vRayOrigin, vRayDir;
    vec2 vJitterUV = vUV + cam.vJitter / Resolution.xy;
    Cam_GetCameraRay( vJitterUV, Resolution.xy, cam, vRayOrigin, vRayDir );
 
    float fHitDist = 0.0f;
    vFragColor = MainCommon( vRayOrigin, vRayDir );
    
    float fShade = GetVignetting( vUV, 0.7, 2.0, 1.0 );
    
    vFragColor.rgb *= fShade;
    
    vFragColor.rgb = Tonemap( vFragColor.rgb );        
}


// Shim main to call shadertoy mainImage and composite terminal text

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float4 result;

    float2 uv = tex;
    uv.y = 1.0 - uv.y;

    mainImage( result, uv * Resolution );

#ifndef NO_OVERLAY
    float4 shadowCol = shaderTexture.Sample(samplerState, tex-(1.0/320.0));
    result.rgb = lerp( result.rgb, float3(0,0,0), shadowCol.a );

    float4 color = shaderTexture.Sample(samplerState, tex);
    result.rgb = lerp( result.rgb, color.rgb, color.a );
#endif    

    return result;
}