extends RefCounted
## Candidate policy contract; NOT used by the formal generator or stream.
const VERSION='environment-policy-0.1.0'

static func ground_at(gen:RefCounted,p:Vector2,explicit_surface:String='')->Dictionary:
	var v:Vector4=gen.sample(p)
	var env:Vector2=gen.subenvironment(p)
	# Mirrors formal terrain shader material contributions, not just biome name.
	var clearing:=1.-smoothstep(.24,.58,env.x)
	var exposed:=smoothstep(.58,.88,env.y)*clearing
	var soil:float=(v.w*.18+v.y*.12)*exposed
	var forest:float=v.x*(1.-clearing*.19)*(1.-soil)
	var rock:float=v.y*(1.-soil)
	var grass:float=(v.w+v.x*clearing*.19)*(1.-soil)
	var s:='rock' if rock>maxf(grass,forest) else ('forest' if forest>grass else 'grass')
	if explicit_surface!='':s=explicit_surface
	return {'surface':s,'water':v.z,'biome':gen.biome(p),'material_weights':Vector4(forest,rock,grass,soil),'moisture':env.x,'rockiness':env.y}

static func allowed(kind:int,contact:Dictionary)->bool:
	if contact.water>.03:return false
	if contact.surface=='snow':return false # Reserved; no approved species/assets.
	if kind<2:return contact.surface in ['grass','forest','dirt'] and contact.biome in ['森林','草原','山地']
	if kind<4:return contact.surface in ['grass','forest','dirt','rock']
	return contact.surface in ['grass','forest']

static func adapted(gen:RefCounted,entry:Dictionary)->Dictionary:
	var contact:=ground_at(gen,entry.position)
	if not allowed(entry.kind,contact):return {}
	var item:=entry.duplicate(true)
	item['surface']=contact.surface
	item['adapter_variant']=mini(1,int(gen.random_at(roundi(entry.position.x),roundi(entry.position.y),1201)*2.))
	item['policy_version']=VERSION
	return item
