/*
	確率論的プロシージャルテクスチャ シェーダー for Godot Engine / Ported by あるる（きのもと 結衣） @arlez80
	Stochastic Procedural Texture Shader for Godot Engine / Ported by Yui Kinomoto @arlez80

	MIT License

	References:
		https://eheitzresearch.wordpress.com/722-2/
			High-Performance By-Example Noise using a Histogram-Preserving Blending Operator
		https://eheitzresearch.wordpress.com/738-2/
 			Procedural Stochastic Textures by Tiling and Blending
*/
shader_type spatial;

uniform vec2 uv_scale = vec2( 1.0, 1.0 );

uniform sampler2D t_input;
uniform sampler2D inv_t;

uniform vec3 color_space_vector1;
uniform vec3 color_space_vector2;
uniform vec3 color_space_vector3;
uniform vec3 color_space_origin;

vec3 return_to_original_color_space( vec3 c )
{
	return pow(
		color_space_origin
	+	color_space_vector1 * c.r
	+	color_space_vector2 * c.g
	+	color_space_vector3 * c.b
	, vec3( 2.2 ) );
}

void triangle_grid( vec2 uv, out float w1, out float w2, out float w3, out ivec2 vertex1, out ivec2 vertex2, out ivec2 vertex3 )
{
	uv *= 3.464;	// 2 * sqrt(3)

	vec2 skewed_coord = mat2( vec2( 1.0, 0.0 ), vec2( -0.57735027, 1.15470054 ) ) * uv;
	ivec2 base_id = ivec2( floor( skewed_coord ) );
	vec3 temp = vec3( fract( skewed_coord ), 0.0 );
	temp.z = 1.0 - temp.x - temp.y;

	if( 0.0 < temp.z ) {
		w1 = temp.z;
		w2 = temp.y;
		w3 = temp.x;
		vertex1 = base_id;
		vertex2 = base_id + ivec2( 0, 1 );
		vertex3 = base_id + ivec2( 1, 0 );
	}else {
		w1 = -temp.z;
		w2 = 1.0 - temp.y;
		w3 = 1.0 - temp.x;
		vertex1 = base_id + ivec2( 1, 1 );
		vertex2 = base_id + ivec2( 1, 0 );
		vertex3 = base_id + ivec2( 0, 1 );
	}
}

vec2 hash( vec2 p )
{
	return fract( sin( p * mat2( vec2( 127.1, 311.7 ), vec2( 269.5, 183.3 ) ) ) * 43758.5453 );
}

vec3 by_example_procedural_noise( vec2 uv )
{
	float w1, w2, w3;
	ivec2 vertex1, vertex2, vertex3;
	triangle_grid( uv, w1, w2, w3, vertex1, vertex2, vertex3 );

	vec2 uv1 = uv + hash( vec2( vertex1 ) );
	vec2 uv2 = uv + hash( vec2( vertex2 ) );
	vec2 uv3 = uv + hash( vec2( vertex3 ) );

	vec2 duvdx = dFdx( uv );
	vec2 duvdy = dFdy( uv );

	vec3 g1 = textureGrad( t_input, uv1, duvdx, duvdy ).rgb;
	vec3 g2 = textureGrad( t_input, uv2, duvdx, duvdy ).rgb;
	vec3 g3 = textureGrad( t_input, uv3, duvdx, duvdy ).rgb;

	vec3 g = w1*g1 + w2*g2 + w3*g3 - vec3( 0.5 );
	g = g * inversesqrt( w1*w1 + w2*w2 + w3*w3 );
	g = g + vec3( 0.5 );

	//float lod = textureQueryLod( t_input, uv ).y / float( textureSize( inv_t, 0 ).y );
	return return_to_original_color_space( vec3(
		texture( inv_t, vec2( g.r, 0.0 ) ).r
	,	texture( inv_t, vec2( g.g, 0.0 ) ).g
	,	texture( inv_t, vec2( g.b, 0.0 ) ).b
	) );
}

void fragment( )
{
	ALBEDO = by_example_procedural_noise( UV * uv_scale );
}