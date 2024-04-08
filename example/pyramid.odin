package example

import "core:math"
import glm "core:math/linalg/glsl"

import gl "../wasm/webgl"

@(private="file") TRIANGLES :: 4
@(private="file") VERTICES  :: TRIANGLES * 3
@(private="file") SIDE      :: 200
@(private="file") H         :: math.SQRT_TWO * SIDE / 2

/*
Points should be in counter-clockwise order
to show the front-face.
*/
@(private="file") colors: [VERTICES*4]u8 = {
	60,  210, 0,   255, // G
	210, 210, 0,   255, // Y
	0,   80,  190, 255, // B

	230, 20,  0,   255, // R
	0,   80,  190, 255, // B
	210, 210, 0,   255, // Y

	60,  210, 0,   255, // G
	230, 20,  0,   255, // R
	210, 210, 0,   255, // Y

	0,   80,  190, 255, // B
	230, 20,  0,   255, // R
	60,  210, 0,   255, // G
}
@(private="file") positions: [VERTICES*3]f32 = {
	 0,      0,   SIDE/2,
	 SIDE/2, H,   0,
	-SIDE/2, H,   0,

	 0,      0,  -SIDE/2,
	-SIDE/2, H,   0,
	 SIDE/2, H,   0,

	 0,      0,   SIDE/2,
	 0,      0,  -SIDE/2,
	 SIDE/2, H,   0,

	-SIDE/2, H,   0,
	0,      0,  -SIDE/2,
	0,      0,   SIDE/2,
}

@(private="file") pyramid_state: struct {
	rotation: [2]f32,
	u_matrix: i32,
	vao:      VAO,
}

pyramid_start :: proc(program: gl.Program) {
	using pyramid_state

	vao = gl.CreateVertexArray()
	gl.BindVertexArray(vao)

	a_position := gl.GetAttribLocation (program, "a_position")
	a_color    := gl.GetAttribLocation (program, "a_color")
	u_matrix    = gl.GetUniformLocation(program, "u_matrix")

	gl.EnableVertexAttribArray(a_position)
	gl.EnableVertexAttribArray(a_color)

	positions_buffer := gl.CreateBuffer()
	colors_buffer    := gl.CreateBuffer()

	gl.Enable(gl.CULL_FACE) // don't draw back faces

	gl.BindBuffer(gl.ARRAY_BUFFER, positions_buffer)
	gl.BufferDataSlice(gl.ARRAY_BUFFER, positions[:], gl.STATIC_DRAW)
	gl.VertexAttribPointer(a_position, 3, gl.FLOAT, false, 0, 0)
	
	gl.BindBuffer(gl.ARRAY_BUFFER, colors_buffer)
	gl.BufferDataSlice(gl.ARRAY_BUFFER, colors[:], gl.STATIC_DRAW)
	gl.VertexAttribPointer(a_color, 4, gl.UNSIGNED_BYTE, true, 0, 0)
}

pyramid_frame :: proc(delta: f32) {
	using pyramid_state
	
	gl.BindVertexArray(vao)
	
	gl.Viewport(0, 0, canvas_res.x, canvas_res.y)
	gl.ClearColor(0, 0.01, 0.02, 0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	rotation -= 0.01 * delta * mouse_rel.yx

	mat := glm.mat4Ortho3d(
		left   = 0,
		right  = canvas_size.x,
		bottom = canvas_size.y,
		top    = 0,
		near   = -1000,
		far    = 1000,
	)
	mat *= glm.mat4Translate(vec2_to_vec3(mouse_pos - canvas_pos))
	mat *= glm.mat4Scale(scale*2 + 0.4)
	mat *= mat4_rotate_y(-rotation.y)
	mat *= mat4_rotate_x(rotation.x)
	mat *= glm.mat4Translate({0, -H / 2, 0})

	gl.UniformMatrix4fv(u_matrix, mat)

	gl.DrawArrays(gl.TRIANGLES, 0, VERTICES)
}
