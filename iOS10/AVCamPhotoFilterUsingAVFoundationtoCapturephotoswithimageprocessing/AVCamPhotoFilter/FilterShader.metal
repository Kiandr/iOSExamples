/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	Metal pass through shader.
 */


#include <metal_stdlib>
using namespace metal;

// Vertex input/output structure for passing results
// from a vertex shader to a fragment shader
struct VertexIO
{
	float4 m_Position [[position]];
	float2 m_TexCoord [[user(texturecoord)]];
};

// Vertex shader for a textured quad
vertex VertexIO texturedQuadVertex(device float4         *pPosition   [[ buffer(0) ]],
								   device packed_float2  *pTexCoords  [[ buffer(1) ]],
								   uint                   vid         [[ vertex_id ]])
{
	VertexIO outVertices;
	
	outVertices.m_Position = pPosition[vid];
	outVertices.m_TexCoord = pTexCoords[vid];
	
	return outVertices;
}

// Fragment shader for a textured quad
fragment half4 texturedQuadFragment(VertexIO         inFrag  [[ stage_in ]],
									texture2d<half>  tex2D   [[ texture(0) ]],
									sampler quadSampler [[sampler(0)]])
{
	half4 color = tex2D.sample(quadSampler, inFrag.m_TexCoord);
	
	return color;
}
