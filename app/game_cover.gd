extends Control
var metadata: Dictionary
var gameplay_preview: Texture2D

func _draw() -> void:
	if metadata.is_empty(): return
	var preview_path = "res://assets/previews/"+str(metadata.get("id",""))+".png"
	if gameplay_preview==null and ResourceLoader.exists(preview_path): gameplay_preview=load(preview_path)
	if gameplay_preview:
		draw_texture_rect(gameplay_preview,Rect2(Vector2.ZERO,size),false)
		return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(66,70))
	var color = Color(metadata.color)
	match metadata.scene.get_file().get_basename():
		"stack":
			for i in 4:
				var x = 10+i*2
				var y = 49-i*9
				draw_rect(Rect2(x,y,36,6),color.darkened(0.1+i*0.1))
				draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+9,y-6),Vector2(x+45,y-6),Vector2(x+36,y)]),color.lightened(i*0.1))
		"runner":
			draw_circle(Vector2(33,24),14,color)
			for i in 3: draw_line(Vector2(28+i*5,37),Vector2(10+i*23,63),color.darkened(0.3),2)
		"racer":
			for x in [12,52]: draw_line(Vector2(x,8),Vector2(x,63),color.darkened(0.4),2)
			draw_style_box(LoopDesign.box(color,5),Rect2(24,18,18,36))
			draw_rect(Rect2(27,25,12,8),Color("243b41"))
		"crowd":
			for i in 9:
				var p = Vector2(33,35)+Vector2(cos(i*2.4),sin(i*2.4))*sqrt(i)*7
				draw_circle(p,4,color)
		"color_gate":
			for i in 3: draw_line(Vector2(13,19+i*12),Vector2(53,19+i*12),color.lightened(i*0.12),5)
			draw_circle(Vector2(33,57),5,color)
		"merge":
			for y in 2:
				for x in 2:
					draw_style_box(LoopDesign.box(color.darkened((x+y)*0.12),4),Rect2(12+x*23,14+y*23,20,20))
