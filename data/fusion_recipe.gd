class_name FusionRecipe
extends Resource
## Receita de peca + modulo, GDD 4.7.2. O resultado fica fora dos drops.
## Os recursos do catalogo nunca sao alterados pela bancada.

@export var id: StringName = &""
@export var source_part_id: StringName = &""
@export var module_id: StringName = &""
@export var result_part: PartData
@export var description: String = ""


func accepts(source: PartData) -> bool:
	return source != null and result_part != null and source.id == source_part_id and source.slot == result_part.slot


func craft(source: PartData) -> PartData:
	if not accepts(source):
		return null
	var result := result_part.clone()
	# Uma receita nao apaga a progressao ja comprada na peca de origem.
	result.fusion_level = source.fusion_level
	result.rarity = maxi(result.rarity, source.rarity) as PartData.Rarity
	return result
