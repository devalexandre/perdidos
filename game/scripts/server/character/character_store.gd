class_name CharacterStore
extends RefCounted
## Interface de persistência de personagens. Neste marco a implementação é JsonCharacterStore
## (arquivo por personagem); na Fase 2 entra uma implementação com PostgreSQL (GDD §15.5) sem
## mudar quem usa.


## Carrega o personagem pelo nome; null se não existir (ou se estiver corrompido).
func load_character(_char_name: String) -> CharacterData:
	return null


## Salva; true = gravou.
func save_character(_data: CharacterData) -> bool:
	return false


func exists(_char_name: String) -> bool:
	return false
