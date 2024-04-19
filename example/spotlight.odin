//+private file
package example

import "core:slice"
import glm "core:math/linalg/glsl"
import gl  "../wasm/webgl"


CUBE_HEIGHT :: 40
CUBE_RADIUS :: 300
GUY_HEIGHT  :: 100
GUY_WIDTH   :: 70
PLANE_WIDTH :: 2000

GUY_JOINT_POSITIONS :: [?]struct {from: Vec, to: Vec, w: f32} {
	{{  0,  40,  0}, {  0, 120,  20}, 16},
	{{  0, 140, 35}, {  0, 120,  20}, 14},
	{{  0,  40,  0}, { 30,   5,  40}, 14},
	{{  0,  40,  0}, {-30,   5,  40}, 14},
	{{ 30,   5, 40}, { 20,   0, -40}, 10},
	{{-30,   5, 40}, {-20,   0, -40}, 10},
	{{  0, 120, 20}, { 35, 135,  30}, 10},
	{{  0, 120, 20}, {-35, 135,  30}, 10},
	{{ 35, 135, 30}, { 30, 185,  40},  8},
	{{-35, 135, 30}, {-30, 185,  40},  8},
}

GUY_JOINTS     :: len(GUY_JOINT_POSITIONS)
GUY_VERTICES   :: GUY_JOINTS * JOINT_VERTICES
PLANE_VERTICES :: 6
ALL_VERTICES   :: PLANE_VERTICES + CUBE_VERTICES*2 + GUY_VERTICES

#assert(ALL_VERTICES % 3 == 0)

camera_angle : f32
u_view       : i32
u_local      : i32
u_light_pos  : [2]i32
u_light_color: [2]i32
u_light_dir  : [2]i32
u_light_add  : [2]i32
vao          : VAO
positions    : [ALL_VERTICES]Vec
normals      : [ALL_VERTICES]Vec


@(private="package")
spotlight_start :: proc(program: gl.Program) {

	vao = gl.CreateVertexArray()
	gl.BindVertexArray(vao)

	a_position := gl.GetAttribLocation(program, "a_position")
	a_normal   := gl.GetAttribLocation(program, "a_normal")

	u_view           = gl.GetUniformLocation(program, "u_view")
	u_local          = gl.GetUniformLocation(program, "u_local")
	u_light_pos[0]   = gl.GetUniformLocation(program, "u_light_pos[0]")
	u_light_pos[1]   = gl.GetUniformLocation(program, "u_light_pos[1]")
	u_light_color[0] = gl.GetUniformLocation(program, "u_light_color[0]")
	u_light_dir[0]   = gl.GetUniformLocation(program, "u_light_dir[0]")
	u_light_color[1] = gl.GetUniformLocation(program, "u_light_color[1]")
	u_light_dir[1]   = gl.GetUniformLocation(program, "u_light_dir[1]")
	u_light_add[0]   = gl.GetUniformLocation(program, "u_light_add[0]")
	u_light_add[1]   = gl.GetUniformLocation(program, "u_light_add[1]")

	gl.EnableVertexAttribArray(a_position)
	gl.EnableVertexAttribArray(a_normal)

	positions_buffer := gl.CreateBuffer()
	normals_buffer   := gl.CreateBuffer()

	gl.Enable(gl.CULL_FACE)
	gl.Enable(gl.DEPTH_TEST)

	vi := 0

	/* Plane */

	plane_positions := positions[vi:][:PLANE_VERTICES]
	plane_normals   := normals  [vi:][:PLANE_VERTICES]
	vi += PLANE_VERTICES

	plane_positions[0] = {-PLANE_WIDTH/2, 0, -PLANE_WIDTH/2}
	plane_positions[1] = { PLANE_WIDTH/2, 0,  PLANE_WIDTH/2}
	plane_positions[2] = { PLANE_WIDTH/2, 0, -PLANE_WIDTH/2}
	plane_positions[3] = {-PLANE_WIDTH/2, 0, -PLANE_WIDTH/2}
	plane_positions[4] = {-PLANE_WIDTH/2, 0,  PLANE_WIDTH/2}
	plane_positions[5] = { PLANE_WIDTH/2, 0,  PLANE_WIDTH/2}

	slice.fill(plane_normals, Vec{0, 1, 0})

	/* Cube RED */
	cube_red_positions := positions[vi:][:CUBE_VERTICES]
	cube_red_normals   := normals  [vi:][:CUBE_VERTICES]
	vi += CUBE_VERTICES

	copy_array(cube_red_positions, get_cube_positions(0, CUBE_HEIGHT))
	slice.fill(cube_red_normals, 1)

	/* Cube BLUE */
	cube_blue_positions := positions[vi:][:CUBE_VERTICES]
	cube_blue_normals   := normals  [vi:][:CUBE_VERTICES]
	vi += CUBE_VERTICES

	copy_array(cube_blue_positions, get_cube_positions(0, CUBE_HEIGHT))
	slice.fill(cube_blue_normals, 1)

	/* Guy */
	guy_positions := positions[vi:][:GUY_VERTICES]
	guy_normals   := normals  [vi:][:GUY_VERTICES]
	vi += GUY_VERTICES

	for joint, ji in GUY_JOINT_POSITIONS {
		copy_array(guy_positions[JOINT_VERTICES*ji:], get_joint(joint.from, joint.to, joint.w))
	}

	normals_from_positions(guy_normals, guy_positions)


	gl.BindBuffer(gl.ARRAY_BUFFER, positions_buffer)
	gl.BufferDataSlice(gl.ARRAY_BUFFER, positions[:], gl.STATIC_DRAW)
	gl.VertexAttribPointer(a_position, 3, gl.FLOAT, false, 0, 0)

	gl.BindBuffer(gl.ARRAY_BUFFER, normals_buffer)
	gl.BufferDataSlice(gl.ARRAY_BUFFER, normals[:], gl.STATIC_DRAW)
	gl.VertexAttribPointer(a_normal, 3, gl.FLOAT, false, 0, 0)

	gl.Uniform4fv(u_light_color[0], rgba_to_vec4(RED))
	gl.Uniform4fv(u_light_color[1], rgba_to_vec4(BLUE))
}

@(private="package")
spotlight_frame :: proc(delta: f32) {
	gl.BindVertexArray(vao)

	gl.Viewport(0, 0, canvas_res.x, canvas_res.y)
	gl.ClearColor(0, 0, 0, 0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	camera_pos := Vec{0, 200 + 300 * mouse_rel.y, 200 - 300 * (scale-0.5)}
	camera_angle += 0.01 * delta * mouse_rel.x

	camera_mat: Mat4 = 1
	camera_mat *= mat4_rotate_y(camera_angle)
	camera_mat *= mat4_translate(camera_pos)
	camera_mat *= mat4_look_at(camera_pos, {0, 50, 0}, {0, 1, 0})
	camera_mat = glm.inverse_mat4(camera_mat)

	view_mat := glm.mat4PerspectiveInfinite(
		fovy   = radians(80),
		aspect = aspect_ratio,
		near   = 1,
	)
	view_mat *= camera_mat

	/* Light */

	cube_red_angle : f32 = PI/2 + PI/6
	cube_blue_angle: f32 = PI/2 - PI/6

	cube_red_pos: Vec
	cube_red_pos.x = CUBE_RADIUS * cos(cube_red_angle)
	cube_red_pos.z = CUBE_RADIUS * sin(cube_red_angle)
	cube_red_pos.y = CUBE_HEIGHT*8

	cube_blue_pos: Vec
	cube_blue_pos.x = CUBE_RADIUS * cos(cube_blue_angle)
	cube_blue_pos.z = CUBE_RADIUS * sin(cube_blue_angle)
	cube_blue_pos.y = CUBE_HEIGHT*8

	gl.Uniform3fv(u_light_pos[0], cube_red_pos)
	gl.Uniform3fv(u_light_pos[1], cube_blue_pos)
	gl.Uniform3fv(u_light_dir[0], normalize(-cube_red_pos))
	gl.Uniform3fv(u_light_dir[1], normalize(-cube_blue_pos))
	gl.UniformMatrix4fv(u_view, view_mat)

	vi := 0

	/* Draw plane */
	gl.UniformMatrix4fv(u_local, 1)
	gl.DrawArrays(gl.TRIANGLES, vi, PLANE_VERTICES)
	vi += PLANE_VERTICES

	/* Draw cube RED */
	gl.UniformMatrix4fv(u_local, mat4_translate(cube_red_pos))
	gl.Uniform1f(u_light_add[0], 1)
	gl.DrawArrays(gl.TRIANGLES, vi, CUBE_VERTICES)
	gl.Uniform1f(u_light_add[0], 0)
	vi += CUBE_VERTICES

	/* Draw cube BLUE */
	gl.UniformMatrix4fv(u_local, mat4_translate(cube_blue_pos))
	gl.Uniform1f(u_light_add[1], 1)
	gl.DrawArrays(gl.TRIANGLES, vi, CUBE_VERTICES)
	gl.Uniform1f(u_light_add[1], 0)
	vi += CUBE_VERTICES

	/* Draw guy */
	gl.UniformMatrix4fv(u_local, 1)
	gl.DrawArrays(gl.TRIANGLES, vi, GUY_VERTICES)
	vi += GUY_VERTICES
}
