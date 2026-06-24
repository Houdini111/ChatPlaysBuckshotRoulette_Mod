class_name CircleSliceTimer extends Control

@export var angle_range_start_deg: float = 360
@export var angle_range_end_deg: float = 0
@export var color := Color.WHITE

@export var running: bool = false
@export var wait_time: float = 0
@export var time_left: float = 0
@export var arc_start_angle_deg: float = 0
@export var arc_end_angle_deg: float = 0

func _ready():
	pass

func _process(delta):
	if (running):
		time_left -= delta
		if time_left <= 0:
			time_left = 0
			running = false
		_UpdateCircleSlice()

func Start(time_to_run: float):
	self.wait_time = time_to_run
	self.time_left = time_to_run
	self.running = true

func Stop():
	self.time_left = 0
	self.running = false

func UpdateColor(_color: Color):
	color = _color
	queue_redraw()

func UpdateArcStartAngleDeg(_arc_start_angle_deg: float):
	arc_start_angle_deg = _arc_start_angle_deg
	queue_redraw()

func UpdateArcEndAngleDeg(_arc_end_angle_deg: float):
	arc_end_angle_deg = _arc_end_angle_deg
	queue_redraw()

func _UpdateCircleSlice():
	var progress_percent = (wait_time - time_left) / wait_time
	var progress_deg = lerpf(angle_range_start_deg, angle_range_end_deg, progress_percent)
	UpdateArcEndAngleDeg(progress_deg)
	
func _draw():
	var w := self.size.x
	var h := self.size.y
	var x := 0
	var y := 0
	var diameter := minf(w, h)
	var center_x := x + (w/2)
	var center_y := y + (h/2)
	var center := Vector2(center_x, center_y)
#	draw_rect(Rect2(0, 0, w, h), Color.RED)
	draw_circle_arc_poly(center, diameter/2, arc_start_angle_deg, arc_end_angle_deg, color)
	
# Based on https://docs.godotengine.org/en/4.0/tutorials/2d/custom_drawing_in_2d.html#arc-polygon-function
func draw_circle_arc_poly(center: Vector2, radius: float, angle_from: float, angle_to: float, color: Color, points: int = 32):
	var points_arc := PackedVector2Array()
	points_arc.push_back(center)
	var colors = PackedColorArray([color])

	for i in range(points + 1):
		var angle_point = deg_to_rad(angle_from + i * (angle_to - angle_from) / points - 90)
		points_arc.push_back(center + Vector2(cos(angle_point), sin(angle_point)) * radius)
	draw_polygon(points_arc, colors)
