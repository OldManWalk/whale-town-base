shader_type canvas_item;
render_mode unshaded;
uniform sampler2D coast_mask : repeat_disable, filter_nearest;
uniform sampler2D sky_cache : repeat_disable, filter_nearest;
uniform float elapsed;
uniform float mist;
uniform float wetness;
uniform float rain;
uniform float tide;
uniform float night;
uniform float budget;
uniform float drift;
uniform float gust;
uniform float snow_cover;
uniform float wx_puddles;
uniform float wx_reflection;
uniform float wx_waveEnergy;
uniform float wx_lampHalo;
uniform float wx_cloudShadow;
uniform float wx_shadowContrast;
uniform float wx_saturation;
uniform float wx_coolTint;

float hash(vec2 p) {
	return fract(sin(dot(p,vec2(27.31,89.77)))*1931.37);
}
float swell(vec2 p) {
	vec2 cell = floor(p);
	vec2 offset = fract(p);
	vec2 ease = offset*offset*(3.0-2.0*offset);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),ease.x),
		mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),ease.x),ease.y);
}
float billow(vec2 p) {
	return swell(p)*0.65+swell(p*2.38+3.17)*0.25+swell(p*4.54+7.25)*0.10;
}
float wisp(vec2 p,vec2 center,vec2 spread) {
	vec2 r=(p-center)/spread;
	return exp(-dot(r,r)*2.5);
}
// World-anchored hollows grow into adjacent path pixels as the soil wets.
float hollow(vec2 p) {
	float level = mix(0.75,0.28,wetness);
	return smoothstep(level,level+0.14,billow(p*vec2(0.083,0.16)+12.0));
}

// Each cell has an independent impact time and center. A ring expands once,
// then dissolves. The center and every visible pixel must share a surface.
float impact(vec2 p, vec3 mask) {
	if (rain<=0.0 || mask.r+mask.g<0.5) return 0.0;
	vec2 cell_size=vec2(18.0,10.0);
	vec2 tile=floor(p/cell_size);
	float clock=elapsed*(0.58+rain*0.77)+hash(tile+11.3);
	vec2 seed=tile+floor(clock)*vec2(17.0,23.0);
	float density=rain*(0.35+budget*0.65);
	if (hash(seed+3.4)>=density) return 0.0;
	vec2 center=tile*cell_size+vec2(6.0,3.0)+floor(vec2(hash(seed+8.2)*6.0,hash(seed+37.1)*4.0));
	vec3 origin=texture(coast_mask,(center+0.5)/vec2(480.0,270.0)).rgb;
	if (mask.r*origin.r+mask.g*origin.g<0.5) return 0.0;
	float receiver=1.0;
	if (mask.g>0.5) receiver=wx_puddles*hollow(center)*hollow(p);
	float age=fract(clock);
	float radius=0.75+4.8*age;
	float distance_to_ring=abs(length((p-center)*vec2(1.0,2.1))-radius);
	float line=1.0-smoothstep(0.52,1.10,distance_to_ring);
	return line*receiver*(1.0-smoothstep(0.48,1.0,age))*(0.38+rain*0.27);
}

void fragment(){
	vec2 p=floor(UV*vec2(480.,270.));
	vec3 mask=texture(coast_mask,UV).rgb;
	float time=elapsed*drift*(1.0+gust*2.5);
	float wave=billow(vec2((p.x-time)*0.027,p.y*0.14));
	float arrival = 83. + tide*4. + wave*6.;
	float far_mist=exp(-pow((p.y-arrival)/(3.5+mist*8.),2.0));
	float breathing=sin(elapsed*0.19)*3.;
	float local=0.;
	if(budget>0.3) {
		local=wisp(p,vec2(211.+breathing+time*0.06,231.-tide*3.),vec2(70.,11.));
		local+=wisp(p,vec2(70.-breathing,202.),vec2(56.,10.));
		if(budget>0.7) local+=wisp(p,vec2(319.+breathing,208.),vec2(61.,8.));
	}
	float safe=(1.-smoothstep(0.72,0.88,SCREEN_UV.x)*smoothstep(0.62,0.86,SCREEN_UV.y))*(1.-smoothstep(0.84,0.96,SCREEN_UV.y));
	float fog=clamp((far_mist*(0.35+wave)+local*(0.18+wave))*mist*1.15,0.,0.84)*safe;
	vec3 fog_color=mix(vec3(0.89,0.90,0.77),vec3(0.43,0.58,0.64),night);
	float light=0.;
	for(int i=0;i<3;i++){
		vec2 lamp=vec2(50.+float(i)*123.,213.-float(i)*13.);
		light+=wisp(p,lamp,vec2(18.,11.))*(0.55+wave*0.5);
	}
	fog_color=mix(fog_color,vec3(1.,0.78,0.44),clamp(light*wx_lampHalo,0.,0.72));
	float crest=sin(p.x*0.14+p.y*1.47+elapsed*(0.4+wx_waveEnergy*2.5)+wave*(1.0+wx_waveEnergy*4.));
	float reflected_y=clamp((269.-p.y)/123.,0.,1.);
	vec3 reflection=texture(sky_cache,vec2(fract(UV.x+mask.r*wave*0.015),reflected_y)).rgb;
	float mirror=mask.r*(0.06+wx_reflection*0.33+max(crest,0.)*(0.06+wx_waveEnergy*0.25));
	float pool=0.;
	if (mask.g>0.5) pool=wx_puddles*hollow(p)*(0.23+wx_reflection*0.47);
	float film=mask.g*wetness*0.26;
	float soil=pool+film*(1.-pool);
	vec3 damp_color=vec3(0.31,0.32,0.28);
	vec3 wet_soil=mix(damp_color,reflection,pool/max(soil,0.001));
	vec3 sea=mix(reflection,vec3(0.84,0.90,0.84),max(crest,0.)*0.28);
	vec3 base=mix(wet_soil,sea,mask.r);
	float alpha=clamp(mirror+soil,0.,0.80);
	float drop=impact(p,mask);
	float layer=drop+alpha*(1.-drop);
	base=mix(base,mix(vec3(0.84,0.91,0.89),vec3(0.58,0.69,0.76),night),drop/max(layer,0.001));
	float ice=mask.b*snow_cover*step(0.45,wave)*0.82;
	alpha=layer+ice*(1.-layer);
	base=mix(base,vec3(0.89,0.94,0.93),ice/max(alpha,0.001));
	float cloud=(mask.b+mask.g)*wx_cloudShadow*(0.06+wx_shadowContrast*0.13)*smoothstep(0.25,0.72,swell(vec2((p.x-time*0.4)*0.013,p.y*0.022)));
	vec3 shade=mix(vec3(0.25,0.31,0.31),vec3(0.28,0.37,0.48),wx_coolTint);
	base=mix(base,shade,cloud/max(alpha+cloud*(1.-alpha),0.001));
	base=mix(vec3(dot(base,vec3(0.299,0.587,0.114))),base,wx_saturation);
	alpha+=cloud*(1.-alpha);
	float out_alpha=alpha+fog*(1.-alpha);
	COLOR=vec4(mix(base,fog_color,fog/max(out_alpha,0.001)),out_alpha);
}
