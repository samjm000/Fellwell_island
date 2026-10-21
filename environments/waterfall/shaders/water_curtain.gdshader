// Fellwell Island: waterfall curtain (Godot 4.3, canvas_item, GL Compatibility OK).
// Drawn on the ribbon mesh built by waterfall_ribbon.gd:
//   UV.x = u across the curtain (0..1 is the water, the mesh extends past it)
//   UV.y = s down the drop (0 = brink, 1 = pool surface)
// All state comes from waterfall.gd through the uniforms below.
shader_type canvas_item;

uniform sampler2D streaks : repeat_enable, filter_linear;
uniform float anim_time = 0.0;          // driven by script (supports "on twos")
uniform float volume : hint_range(0.0, 1.0) = 1.0;
uniform float head : hint_range(0.0, 1.0) = 1.0;   // restart front (1 = reached pool)
uniform float tail : hint_range(0.0, 1.0) = 0.0;   // stop front (1 = all water gone)
uniform float impact : hint_range(0.0, 1.0) = 1.0;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 night_tint = vec3(0.26, 0.33, 0.58); // match the level's CanvasModulate

const float V0 = 0.35;                 // speed over the brink, in drop units
float tau(float s) { return sqrt(V0 * V0 + 2.0 * s) - V0; }   // time of flight, g = 1
const float TAU1 = 1.10713;            // tau(1.0)

vec4 water(vec2 us, float time){
  float u=us.x, s=clamp(us.y,0.0,1.0);
  float ta=tau(s);
  float tn=ta/TAU1;                        // 0 at lip, 1 at pool
  // Back layer (broad columns, slow) and front layer (strands, fast). Scrolling
  // linearly in tau-space gives gravitational acceleration and stretching.
  float broad=texture(streaks,vec2(u*0.42+0.31, ta*0.45-time*0.30)).g;
  float fine =texture(streaks,vec2(u*0.80,      ta*0.85-time*0.62)).r;
  float fine2=texture(streaks,vec2(u*1.30+0.5,  ta*1.20-time*0.88)).r;
  float brk  =texture(streaks,vec2(u*0.90+0.2,  ta*0.90-time*0.62)).b;

  // Near a stop/restart front the flow thins into strands, so fronts taper and
  // finger instead of ending as a straight cut.
  float strands0=max(fine,fine2*0.85);
  // Stopping front: smooth and gently curved (broad, slow noise only).
  float tfT=tn+(broad-0.5)*0.045;
  // Restart front: a little frothier, but still soft.
  float tf=tn+(strands0-0.5)*0.08+(brk-0.5)*0.04;
  float nearTail=smoothstep(tail,tail+0.30,tfT)*step(0.001,tail)+step(tail,0.001);
  float nearHead=1.0-smoothstep(head-0.22,head,tf)*0.6*step(head,0.995);
  float lv=volume*mix(0.25,1.0,nearTail)*nearHead;
  float keep=smoothstep((1.0-lv)*0.62-0.10,(1.0-lv)*0.62+0.10,broad);
  float d=abs(u-0.5)*2.0;
  float hw=mix(0.45,1.0,lv);
  float roundIn=0.10*(1.0-smoothstep(0.0,0.07,s));   // corners curl in over the brink
  float edge=1.0-smoothstep(hw-0.10,hw,d+roundIn+(brk-0.5)*0.30*smoothstep(0.0,0.3,s));
  float a=edge*mix(1.0,keep,step(lv,0.97));
  // Only cut where a front actually exists, so the lip edge is never fingered.
  a*=mix(1.0,smoothstep(tail-0.02,tail+0.03,tfT),step(0.001,tail));
  a*=mix(1.0,1.0-smoothstep(head-0.01,head+0.01,tf),step(head,0.995));
  float headFoam=smoothstep(0.08,0.0,head-tf)*step(head,0.995);
  float tailFoam=smoothstep(0.06,0.0,tfT-tail)*step(0.005,tail)*0.35;

  // Painterly palette: teal gaps between brighter aqua columns, white aeration
  // that grows with the fall, at the edges, and at the fronts.
  vec3 deep=vec3(0.07,0.42,0.52), mid=vec3(0.30,0.76,0.82), pale=vec3(0.78,0.95,0.96), foamc=vec3(0.97,1.0,1.0);
  vec3 col=mix(deep,mid,smoothstep(0.15,0.65,broad));
  col=mix(col,pale,smoothstep(0.45,0.85,broad)*0.8);
  float aer=0.30+0.45*smoothstep(0.1,1.0,s)+0.45*d*d+headFoam+tailFoam;
  float strands=max(fine,fine2*0.85);
  col=mix(col,pale,smoothstep(0.25,0.7,strands)*0.45);
  float white=smoothstep(0.95-aer*0.6,1.05-aer*0.45,strands*0.7+broad*0.45);
  col=mix(col,foamc,clamp(white+headFoam*0.7+tailFoam*0.5,0.0,1.0));
  // Glassy lip: the water bends over the edge as a smooth tongue, with long,
  // slow, low-contrast streaks and a soft sky reflection. Strands and foam
  // only fade in once it is properly falling.
  float calm=smoothstep(0.02,0.18,s);
  float lipStreak=texture(streaks,vec2(u*0.6+0.13, ta*0.22-time*0.14)).g;
  vec3 lipc=mix(deep*1.08,mid,0.5+0.35*lipStreak);
  // Sky reflection breaks into vertical glints, so the lip never reads as a stripe.
  float glintU=texture(streaks,vec2(u*0.9+0.71, ta*0.30-time*0.14)).r;
  float refl=smoothstep(0.004,0.02,s)*(1.0-smoothstep(0.025,0.075,s));
  lipc=mix(lipc,vec3(0.86,0.97,1.0),refl*smoothstep(0.25,0.8,glintU)*0.8);
  // Thin bright crest where light catches the bend.
  float crestHi=(1.0-smoothstep(0.0,0.008,s))*smoothstep(-0.004,0.0,s);
  lipc=mix(lipc,vec3(0.93,0.99,1.0),crestHi*(0.45+0.4*lipStreak));
  col=mix(lipc,col,calm);
  // Rounded crest: the top edge bows up slightly in the middle, soft AA.
  float crest=smoothstep(-0.004,0.0,us.y+0.008*(1.0-d*d));
  float alpha=a*mix(0.95,1.0,white*calm)*crest*(1.0-smoothstep(1.0,1.03,us.y));
  return vec4(col,alpha);
}

void fragment() {
	vec2 us = UV;
	vec4 w = water(us, anim_time);
	vec3 col = w.rgb;
	// Aerated foot of the curtain where it meets the pool.
	float s = us.y;
	float foot = smoothstep(0.80, 1.0, s) * impact * 0.6;
	float fine = texture(streaks, vec2(us.x * 0.8, s * 3.0 - anim_time * 1.3)).r;
	col = mix(col, vec3(0.94, 0.99, 1.0), clamp(foot * (0.6 + 0.4 * fine), 0.0, 1.0));
	// Night: CanvasModulate darkens everything; add back a moonlit glow so the
	// water stays luminous (divided by the tint so it survives the modulate).
	float lum = dot(col, vec3(0.3, 0.55, 0.15));
	col += night * 0.6 * lum * vec3(0.22, 0.33, 0.44) / max(night_tint, vec3(0.05));
	COLOR = vec4(col, w.a);
}
