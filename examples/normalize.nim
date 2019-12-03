import simple_parseopt

simple_parseopt.config: allow_repetition

let options = get_options:
    position: seq[float]    {. alias("p"), len(3) .}  # x y x
    independent: bool       {. alias("i"), info("Normalize each axis independently") .}

if options.position.len == 0:
    quit()


type Point = object
    x: float
    y: float
    z: float

var points: seq[Point] = @[]

var i = 0
while i + 2 < options.position.len:
    points.add Point(
        x: options.position[i],
        y: options.position[i + 1],
        z: options.position[i + 2])
    i += 3


var max_x = points[0].x.abs
var max_y = points[0].y.abs
var max_z = points[0].z.abs

template update_max(max, value) =
    if value.abs > max: max = value.abs

for point in points:
    update_max max_x, point.x
    update_max max_y, point.y
    update_max max_z, point.z

if not options.independent:
    max_x = max(max(max_x, max_y), max_z)
    max_y = max_x
    max_z = max_x


for point in points:
    let x = point.x / max_x
    let y = point.y / max_y
    let z = point.z / max_z
    echo x, " ", y, " ", z


# example: normalize.exe -p 10 -20 10 -p 30 10 -10 -p 5 7 9
