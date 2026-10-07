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
	var basename=metadata.scene.get_file().get_basename()
	if basename=="lantern_trail":
		var backdrop=load("res://assets/platformer_meadow.png") as Texture2D
		draw_texture_rect(backdrop,Rect2(Vector2.ZERO,size),false,Color(1,1,1,0.92))
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
		"merge":
			for y in 2:
				for x in 2:
					draw_style_box(LoopDesign.box(color.darkened((x+y)*0.12),4),Rect2(12+x*23,14+y*23,20,20))
		"prism_stack":
			for i in 4:
				var colors=[Color("55dbe8"),Color("ffd36b"),Color("bda0ff"),Color("7ce0a2")]
				var x=16+(i%2)*18+(i/2)*4
				var y=53-(i/2)*9-(i%2)*2
				draw_rect(Rect2(x,y,17,8),colors[i].darkened(0.32))
				draw_rect(Rect2(x+1,y+1,15,4),colors[i])
				draw_line(Vector2(x+3,y+1),Vector2(x+13,y+1),colors[i].lightened(0.4),1,true)
		"lantern_trail":
			draw_rect(Rect2(0,54,66,16),Color("273c3b"))
			draw_rect(Rect2(0,52,66,4),Color("718b68"))
			draw_rect(Rect2(0,52,66,2),Color("d0d58d"))
			draw_style_box(LoopDesign.box(Color("354e49"),4),Rect2(39,40,27,9))
			draw_style_box(LoopDesign.box(Color("7c9b70"),4),Rect2(39,39,27,3))
			for i in 3:
				var coin=Vector2(12+i*15,45-i%2*7)
				draw_circle(coin,4,Color("bd7845"))
				draw_circle(coin,2.7,Color("ffe4a0"))
				draw_line(coin+Vector2(0,-1.5),coin+Vector2(0,1.5),Color("fff7d5"),0.8,true)
			# Lantern keeper in stitched teal, leather, and warm brass.
			draw_colored_polygon(PackedVector2Array([Vector2(26,48),Vector2(18,45),Vector2(13,42),Vector2(20,41),Vector2(27,43)]),Color("ffc66d"))
			draw_line(Vector2(29,42),Vector2(29,51),Color("263e48"),3.2,true)
			draw_line(Vector2(34,42),Vector2(37,51),Color("263e48"),3.2,true)
			draw_circle(Vector2(28,51),2,Color("d08a61"))
			draw_circle(Vector2(38,51),2,Color("d08a61"))
			draw_colored_polygon(PackedVector2Array([Vector2(25,30),Vector2(35,30),Vector2(38,43),Vector2(24,43)]),Color("294f53"))
			draw_line(Vector2(27,32),Vector2(34,41),Color("b7784e"),1.5,true)
			draw_style_box(LoopDesign.box(Color("a96749"),2),Rect2(23,37,5,7))
			draw_circle(Vector2(31,25),5.7,Color("d89570"))
			draw_colored_polygon(PackedVector2Array([Vector2(25,25),Vector2(27,19),Vector2(35,19),Vector2(38,24),Vector2(34,23)]),Color("41505d"))
			draw_circle(Vector2(33,25),0.8,Color("263b46"))
			draw_circle(Vector2(42,38),5,Color("ffc66d",0.2))
			draw_style_box(LoopDesign.box(Color("8e5a3e"),1),Rect2(40,35,4,7))
			draw_rect(Rect2(41,36,2,4),Color("ffe59d"))
