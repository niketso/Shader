Shader "Unlit/Test"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            
            /*
            ----------------------------------------------------
            ----------------------------------------------------
            ----------------------------------------------------
            */
#define SCENE 1
#define BUMPY
#define AUTOCAM
#define SPIN

float3 sunDir = normalize(float3(0.0,0.3,1.0));



// rotate camera
#define pee 3.141592653
#ifdef AUTOCAM
#define anglex2 (sin(_Time.y*0.3)*0.4)
#define angley2 (_Time.y*0.2-0.4)
#else
//float anglex2 = (0.5 - iMouse.y/iResolution.y)*pee*1.2; // mouse cam
//float angley2 = -iMouse.x/iResolution.x*pee*2.0;
#endif

float3 campos;
float3 dir;

 
float3 backGround2() // unused checkerboard
{
	if (dir.y>0.0) return float3(1,1,1);
	float2 floorcoords = campos.xz + dir.xz*(-campos.y/dir.y);
	float2 t = (frac(floorcoords.xy*0.5))-float2(0.5,0.5);
	return float3(1,1,1) - float3(0.6,0.3,0)*float(t.x*t.y>0.0);
}


float texture_iq_heart(float2 pos) // let's steal his heart
{
	float rot = pos.x;
	pos.x += pos.y*0.3; // rotate and scale to misalign
	pos.y -= rot*0.3;
	pos=(frac((pos))-float2(0.5,0.7))*0.8; // frac makes it repetitive, 0.8 scales the heart size
	float f1 = abs(atan2(pos.y,pos.x)/pee);
	return (f1*6.5 - f1*f1*11.0 + f1*f1*f1*5.0)/(6.0-f1*5.0)-length(pos);
}


float3 sky()
{
	float f = max(dir.y,0.0);
	float3 color = 1.0-float3(1,0.85,0.7)*f;
	color *= dir.z*0.2+0.8;
	
	if (dot(sunDir,dir)>0.0)
	{
	 f = max(length(cross(sunDir,dir))*10.0,1.0);
		
	 color += float3(1,0.9,0.7)*40.0/(f*f*f*f);
	}
	return color;
	
}

float3 backGround()
{
//    return float3(dir.y*0.5+0.5);
 	if (dir.y>=0.0) return sky();
 	float3 raypos2 = campos - dir*(campos.y / dir.y);
	float fog = exp(length(raypos2)/-8.0);
 	return sky()*(1.0-fog)+(float3(0.3,0.5,0.7)+float3(0.3,0.15,0.0)*((clamp(texture_iq_heart(raypos2.xz)*20.0,0.0,1.0))))*fog;
}



float3 rotatex(float3 v,float anglex)
{
	float t;
	t =   v.y*cos(anglex) - v.z*sin(anglex);
	v.z = v.z*cos(anglex) + v.y*sin(anglex);
	v.y = t;
	return v;
}

float3 rotcam(float3 v)
{
	float t;
	v = rotatex(v,anglex2);
	
	t = v.x * cos(angley2) - v.z*sin(angley2);
	v.z = v.z*cos(angley2) + v.x*sin(angley2);
	v.x = t;
	return v;
}

int side; // 1 for raytracing outside glass,  -1 for raytracing inside glass

float gTravel;
float3 gNormal;

float travelMax,travelMin;
float3 normalMax,normalMin;

// a ray hits a surface surfaceside shows weather it hit from the rear or front of the plane 
void update(float surfaceside,float travel,float3 normal)
{
	if (surfaceside<0.0)
	{
		if (travelMax<travel)
		{
			travelMax = travel;
			normalMax = normal;
		}
	}
	else
	{
		if (travelMin>travel)
		{
			travelMin = travel;
			normalMin = normal;
		}
	}
}

void hitPlane(float3 normal,float shift) // check ray-plane intersection. Planes are infinte large
{
#ifdef SPIN
	float angle = frac(_Time.y*0.25);
	angle = min(angle*1.5,1.0);
	
	normal = rotatex(normal,angle*pee*2.0);        // rotate object
#endif
	shift += normal.y*1.0;         // and shift up from the ground height
	
	float distFromPlane = dot(normal,campos) - shift;
	float travel = -distFromPlane / dot(normal,dir);
	update(dot(normal,dir),travel,normal);
}

void startObj()
{
	travelMax = -1e35;
	travelMin = 1e35;
}

void endObj()
{
//	if (travelMax<travelMin)     // enable this for nonconvex objects
	{
		if (side>0)
		{
			if (travelMax<travelMin && travelMax>0.0 && travelMax<gTravel)
			{
				gTravel = travelMax;
				gNormal = normalMax;
			}
		}
		else
		{
			if (travelMin>0.0 && travelMin<gTravel)
			{
				gTravel = travelMin;
				gNormal = -normalMin;
			}
		}
	}
}


void hitKocka() // trace the mesh
{
	startObj();
		
	if (SCENE==0)
	{
	
		hitPlane(float3(1,0,0),0.6);
		hitPlane(float3(-1,0,0),0.6);
		hitPlane(float3(0,0,1),0.2);
		hitPlane(float3(0,0,-1),0.2);
		hitPlane(float3(0,1,0),0.75);
		hitPlane(float3(0,-1,0),0.75);
		hitPlane(normalize(float3(1,1,0)),0.6); // cut off it's edge
	}
	
	if (SCENE==1)
	{
		for(float angle=0.0;angle<pee*2.0;angle+=pee/4.0)
		{
			hitPlane(float3(sin(angle),0.5,cos(angle)),0.4);
			hitPlane(float3(sin(angle),-2.0,cos(angle)),1.5);
		}
	}
	
	if (SCENE==2)
	{
		for(float angle2=pee/8.0;angle2<pee;angle2+=pee/6.0)
		for(float angle=0.0;angle<pee*2.0;angle+=pee/6.0)
		{
			{
				hitPlane(float3(sin(angle)*sin(angle2),cos(angle2),cos(angle)*sin(angle2)),0.7);
			}
		}
	}
	

	endObj();	
}



float3 getInsideFake() // use this only for debigging
{
	gTravel = 1e35;
	hitKocka();
	if (gTravel>1e34){return  backGround();}
	return float3(  dot(float3(0.7,0.7,0.2),gNormal)*0.5+0.5,0,0);
}


float3 glassColorFunc(float dist) // exponentioanly turn light green as it travels within glass (real glass has this porperty)
{
	if(side>0) return float3(1,1,1);
	return float3(exp(dist*-0.4),exp(dist*-0.05),exp(dist*-0.2));
}

float3 black()
{
	return float3(0.0,0.0,0.0);
}


void bumpit()
{
#ifdef BUMPY
	gNormal.x += sin(campos.x*30.0)*0.007;
	gNormal.y += sin(campos.y*30.0)*0.007;
	gNormal.z += sin(campos.z*30.0)*0.007;
	gNormal = normalize(gNormal);
#endif
}

					 
// recursion unsupported, let's overcome it like this
// CHILD0 refraced ray proc
// CHILD1 reflected ray proc
#define GET(BASE,CHILD0,CHILD1) float3 BASE(){if (!(length(dir)<1.01) || !(length(dir)>0.99)) return float3(0.0,0.0,0.0); gTravel = 1e35; hitKocka();if (gTravel>1e34){return  backGround();}campos += dir * gTravel;bumpit();float3 glassColor = glassColorFunc(gTravel); float3 originalDir = dir;	float3 originalPos = campos;	float3 originalNormal = gNormal;	dir = refract(originalDir,originalNormal,side>0 ? 1.0/1.55 : 1.55);  float t = clamp(1.0+dot(gNormal,side>0?originalDir : dir),0.0,1.0);	float fresnel = 0.1 + (t*t*t*t*t)*0.9;		side *=-1; float3 color =  CHILD0()*(1.0-fresnel);	side *=-1; campos = originalPos;	dir = reflect(originalDir,originalNormal);	 color += CHILD1()*(fresnel);  return color*glassColor;	}


// having to deal with just one convex object, any ray refracing out of it is casted 
// to the background directly without other ray checking

GET(get8,backGround,black) 
GET(get7,backGround,get8)
GET(get6,backGround,get7)
GET(get5,backGround,get6)
GET(get4,backGround,get5)
GET(get3,backGround,get4)
GET(get2,backGround,get3) 
GET(get,get2,backGround)  // starting from the camera, the reflected ray goes to the background, refrated part handled in get2

	
float func(float x) // the func for HDR (looks better with HDR disabled)
{
	return x/(x+3.0)*3.0;
}
float3 HDR(float3 color)
{
	float pow = length(color);
	return color * func(pow)/pow*1.2;
}

fixed4 frag (v2f i) : SV_Target
{
	float brightNess = min(_Time.y/5.0,1.0);
	float2 uv = (i.uv);
	campos = float3(0,1.0,0);
	dir = float3(uv*2.0-1.0,1);
	dir.y *= 9.0/16.0; // wide screen
	
	dir = normalize(rotcam(dir));
    
	campos -= rotcam(float3(0,0,2)); // back up from subject
	
	gTravel = 1e35;
	side = 1;
	
		
	return float4((get()*brightNess),1.0); // add HDR() if you like it
}
            
            ENDCG
        }
    }
}
