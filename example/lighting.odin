package example

import glm "core:math/linalg/glsl"
import gl  "../wasm/webgl"


@(private="file") SEGMENT_TRIANGLES :: 2 * 3
@(private="file") SEGMENT_VERTICES  :: SEGMENT_TRIANGLES * 3
@(private="file") RING_SEGMENTS     :: 32
@(private="file") RING_TRIANGLES    :: RING_SEGMENTS * SEGMENT_TRIANGLES
@(private="file") RING_VERTICES     :: RING_TRIANGLES * 3
@(private="file") RINGS             :: 3
@(private="file") RINGS_VERTICES    :: RINGS * RING_VERTICES
@(private="file") ALL_VERTICES      :: CUBE_VERTICES + RINGS_VERTICES

@(private="file") CUBE_HEIGHT :: 80
@(private="file") CUBE_RADIUS :: 300
@(private="file") RING_HEIGHT :: 30
@(private="file") RING_LENGTH :: 40
@(private="file") RING_SPACE  :: 30

lighting_state: struct {
	cube_rotation: f32,
	ring_rotation: f32,
	u_matrix:      i32,
	u_world:	   i32,
	u_light_dir:   i32,
	u_color:       i32,
	vao:           VAO,
	positions:     [ALL_VERTICES]Vec,
	normals:       [ALL_VERTICES]Vec,
}


lighting_start :: proc(program: gl.Program) {
	using lighting_state

	vao = gl.CreateVertexArray()
	gl.BindVertexArray(vao)

	a_position := gl.GetAttribLocation(program, "a_position")
	a_color    := gl.GetAttribLocation(program, "a_normal")

	u_matrix    = gl.GetUniformLocation(program, "u_matrix")
	u_world     = gl.GetUniformLocation(program, "u_world")
	u_light_dir = gl.GetUniformLocation(program, "u_light_dir")
	u_color     = gl.GetUniformLocation(program, "u_color")

	gl.EnableVertexAttribArray(a_position)
	gl.EnableVertexAttribArray(a_color)

	positions_buffer := gl.CreateBuffer()
	normals_buffer   := gl.CreateBuffer()

	gl.Enable(gl.CULL_FACE) // don't draw back faces
	gl.Enable(gl.DEPTH_TEST) // draw only closest faces

	
	/* Cube */
	copy_array(positions[:], get_cube_positions(0, CUBE_HEIGHT))
	copy_array(normals[:], get_cube_normals())

	/* Ring
	
	_____________ <- RING_LENGTH
	v  ramp top v
	     |      @ <|
	     v  @@@@@  |
	    @@@@@@@@@  |
	@@@@@@@@@@@@@  |<- RING_HEIGHT = SIDE
	    @@@@@@@@@  |
	        @@@@@  |
	        ^   @ <|
	ramp bottom
	*/

	rings_normals   := normals[CUBE_VERTICES:]
	rings_positions := positions[CUBE_VERTICES:]

	for ri in 0..<RINGS {
		ring_positions := rings_positions[ri*RING_VERTICES:]
		ring_normals   := rings_normals  [ri*RING_VERTICES:]

		radius := CUBE_RADIUS - CUBE_HEIGHT/2 - RING_SPACE - f32(ri) * (RING_LENGTH + RING_SPACE)

		for si in 0..<RING_SEGMENTS {
			theta0 := 2*PI * f32(si+1) / f32(RING_SEGMENTS)
			theta1 := 2*PI * f32(si  ) / f32(RING_SEGMENTS)

			out_x0 := cos(theta0) * radius
			out_z0 := sin(theta0) * radius
			out_x1 := cos(theta1) * radius
			out_z1 := sin(theta1) * radius

			in_x0  := cos(theta0) * (radius - RING_LENGTH)
			in_z0  := sin(theta0) * (radius - RING_LENGTH)
			in_x1  := cos(theta1) * (radius - RING_LENGTH)
			in_z1  := sin(theta1) * (radius - RING_LENGTH)

			positions: []Vec = {
				/* Side */
				{out_x0, -RING_HEIGHT/2, out_z0},
				{out_x1, -RING_HEIGHT/2, out_z1},
				{out_x1,  RING_HEIGHT/2, out_z1},
				{out_x0, -RING_HEIGHT/2, out_z0},
				{out_x1,  RING_HEIGHT/2, out_z1},
				{out_x0,  RING_HEIGHT/2, out_z0},
	
				/* Ramp Top */
				{out_x0,  RING_HEIGHT/2, out_z0},
				{out_x1,  RING_HEIGHT/2, out_z1},
				{in_x0 ,  0            , in_z0 },
				{in_x0 ,  0            , in_z0 },
				{out_x1,  RING_HEIGHT/2, out_z1},
				{in_x1 ,  0            , in_z1 },
	
				/* Ramp Bottom */
				{in_x0 ,  0            , in_z0 },
				{in_x1 ,  0            , in_z1 },
				{out_x1, -RING_HEIGHT/2, out_z1},
				{in_x0 ,  0            , in_z0 },
				{out_x1, -RING_HEIGHT/2, out_z1},
				{out_x0, -RING_HEIGHT/2, out_z0},
			}

			copy(ring_positions[si*SEGMENT_VERTICES:], positions)
			normals_from_positions(ring_normals[si*SEGMENT_VERTICES:], positions)
		}
	}

	gl.BindBuffer(gl.ARRAY_BUFFER, positions_buffer)
	gl.BufferDataSlice(gl.ARRAY_BUFFER, positions[:], gl.STATIC_DRAW)
	gl.VertexAttribPointer(a_position, 3, gl.FLOAT, false, 0, 0)

	gl.BindBuffer(gl.ARRAY_BUFFER, normals_buffer)
	gl.BufferDataSlice(gl.ARRAY_BUFFER, normals[:], gl.STATIC_DRAW)
	gl.VertexAttribPointer(a_color, 3, gl.FLOAT, false, 0, 0)

	gl.Uniform4fv(u_color, {1, 1, 1, 1})
}

lighting_frame :: proc(delta: f32) {
	using lighting_state

	gl.BindVertexArray(vao)

	gl.Viewport(0, 0, canvas_res.x, canvas_res.y)
	gl.ClearColor(0, 0.01, 0.02, 0)
	// Clear the canvas AND the depth buffer.
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	camera_mat: Mat4 = 1
	camera_mat *= mat4_translate({0, 0, 800 - 700 * (scale/1.2)})
	camera_mat = glm.inverse_mat4(camera_mat)

	view_mat := glm.mat4PerspectiveInfinite(
		fovy   = radians(80),
		aspect = aspect_ratio,
		near   = 1,
	)
	view_mat *= camera_mat

	/* Draw cube */
	cube_rotation += 0.01 * delta * mouse_rel.x

	cube_pos: Vec
	cube_pos.y = 500 * -mouse_rel.y
	cube_pos.x = CUBE_RADIUS * cos(cube_rotation)
	cube_pos.z = CUBE_RADIUS * sin(cube_rotation)

	cube_mat: Mat4 = 1
	cube_mat *= mat4_translate(cube_pos)
	cube_mat *= mat4_rotate_y(cube_rotation)

	gl.UniformMatrix4fv(u_matrix, view_mat * cube_mat)
	gl.UniformMatrix4fv(u_world, cube_mat)
	gl.DrawArrays(gl.TRIANGLES, 0, CUBE_VERTICES)

	/* Draw light from cube */
	light_dir := glm.normalize(cube_pos)
	gl.Uniform3fv(u_light_dir, light_dir)

	/* Draw rings */
	ring_rotation += 0.002 * delta
	
	for i in 0..<RINGS {
		ring_mat: Mat4 = 1
		ring_mat *= mat4_rotate_z(2*PI / (f32(RINGS)/f32(i)) + ring_rotation/4)
		ring_mat *= mat4_rotate_x(ring_rotation)

		gl.UniformMatrix4fv(u_matrix, view_mat * ring_mat)
		gl.UniformMatrix4fv(u_world, ring_mat)
		gl.DrawArrays(gl.TRIANGLES, CUBE_VERTICES + i*RING_VERTICES, RING_VERTICES)
	}
}
