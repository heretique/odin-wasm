package engine

import "core:fmt"

engine_init :: proc() {
	fmt.println("Engine initialized")
}

engine_update :: proc() {
	fmt.println("Engine updated")
}

engine_render :: proc() {
	fmt.println("Engine rendered")
}

engine_shutdown :: proc() {
	fmt.println("Engine shutdown")
}