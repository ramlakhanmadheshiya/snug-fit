extends SceneTree
## Renders the icon artwork (tools/make_icons.py) to the PNGs Android and the boot
## splash use. Run: godot --headless --path . -s res://tools/render_icons.gd

const OUT: Array = [
	["res://assets/icon.svg", "res://assets/android/icon_main.png", 192],
	["res://assets/android/src/foreground.svg", "res://assets/android/icon_foreground.png", 432],
	["res://assets/android/src/background.svg", "res://assets/android/icon_background.png", 432],
	["res://assets/android/src/monochrome.svg", "res://assets/android/icon_monochrome.png", 432],
	["res://assets/android/src/foreground.svg", "res://assets/splash.png", 348],
]


func _init() -> void:
	for item: Array in OUT:
		var img: Image = Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string(item[0]), float(item[2]) / 1024.0)
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(ProjectSettings.globalize_path(item[1]))
		print(item[1], " ", img.get_size())
	quit()
