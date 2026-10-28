extends RefCounted
## Presentation only: spread sparse authority positions over their observed cadence.
## Repeated snapshots must not restart the blend. No extrapolation past authority.
var initialized:=false
var target:=Vector2.ZERO
var origin:=Vector2.ZERO
var displayed:=Vector2.ZERO
var age:=0.0
var duration:=.4
var elapsed:=0.0

func advance(next: Vector2, delta: float, snap: bool=false) -> Vector2:
	age+=delta
	if not initialized or snap or next.distance_to(target)>256:
		initialized=true;target=next;origin=next;displayed=next;elapsed=0;age=0
	elif next!=target:
		duration=clampf(age,.08,.8)
		origin=displayed;target=next;elapsed=0;age=0
	elapsed+=delta
	displayed=origin.lerp(target,minf(1,elapsed/duration))
	return displayed
