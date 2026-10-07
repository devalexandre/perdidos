class_name TitleTalkDef
extends Resource
## Agente R (GDD §9.3, 27/09/2026): conversa de um Mestre sobre o título que ele ensina, liberada no
## nível 10 (min_level). data/title_talks/<npc_id>.tres. O servidor (TitleTalk) acrescenta a opção
## "Fale sobre o título que você ensina" no primeiro nó do diálogo do NPC e gera 3 falas:
##   1) o que é o título (nome + descrição);  2) estilo de jogo + skills que ele libera;
##   3) a cidade onde o Viajante começa com ele (ou "a travessia ainda não está aberta").
## Com title_id (TitleDef existente) nome, descrição, skills e cidade vêm do TitleDef/SkillDef;
## os campos *_key abaixo só completam o que o TitleDef não tem (títulos de nações ainda fechadas).

@export var id: StringName = &""
## NpcDef.id do Mestre.
@export var npc_id: StringName = &""
## TitleDef.id do primeiro título que o Mestre ensina (vazio = título ainda não existe em dados).
@export var title_id: StringName = &""
## Nação do título (chave REGION_<ID>_NAME) — usada na fala da cidade quando não há start_map_id.
@export var region_id: StringName = &"brasil"
## Fallbacks sem TitleDef: nome e descrição do título.
@export var title_name_key: String = ""
@export var title_desc_key: String = ""
## Estilo de jogo (sempre deste arquivo: o TitleDef não descreve o estilo).
@export var style_key: String = ""
## Fallback sem TitleDef: nomes (chaves) das skills que o título libera.
@export var skill_name_keys: Array[String] = []
## Nível mínimo para a opção aparecer (GDD §9.3: 10).
@export var min_level: int = 10
