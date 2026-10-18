extends 'res://prototypes/environment-v01/prop.gd'
const Catalog=preload('res://prototypes/environment-adapt-v01/catalog.gd')
var variant_id:=''
func build()->void:
	root_height=40.
	super.build()
	collision.name='Footprint';collision.polygon=Catalog.footprint(variant_id)
func hit()->void:
	if kind==0:super.hit()
func remove_rock()->void:pass # Ordinary stones are collision-only.
