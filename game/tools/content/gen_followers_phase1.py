"""Conteúdo da fase 1 de PETS-E-MONTARIAS.md; sem alterar árvores ou TitleDef.bonus_skills."""
from pathlib import Path
import csv

GAME = Path(__file__).resolve().parents[2]
TEXT = {}

def text(key, value):
    TEXT[key] = value
    return '"' + key + '"'

def resource(folder, ident, cls, script, fields):
    dest = GAME / 'data' / folder / (ident + '.tres')
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(f'[gd_resource type="Resource" script_class="{cls}" format=3]\n\n'
                    f'[ext_resource type="Script" path="res://scripts/shared/data/{script}.gd" id="def"]\n\n'
                    '[resource]\nscript = ExtResource("def")\n' + '\n'.join(fields) + '\n')

def names(values):
    return 'Array[StringName]([' + ', '.join('&"'+v+'"' for v in values) + '])'

COMPANIONS = [
 ('harpy','Harpia','pindorama_bow_gaviao','harpy_eagle','Garra do Alto','bow_companion_hawk_strike','Olho no Céu','bow_companion_sky_eye',True,14,30,8),
 ('guara','Guará','pindorama_bow_brejo','maned_wolf','Mordida do Guará','bow_companion_guara_bite','Faro do Guará','bow_companion_guara_track',False,10,25,15),
 ('lume','Lume','pindorama_arcane_firefly','enchanted_firefly','Luz que Acompanha','arcane_companion_lume_light','Lume Guia','arcane_companion_lume_guide',True,0,60,20),
]

def main():
    for short, label, title, monster, pname, passive, aname, active, flies, mana, cooldown, duration in COMPANIONS:
        ident = 'pindorama_companion_' + short
        resource('companions', ident, 'CompanionDef', 'companion_def', [
            'id = &"'+ident+'"', 'name_key = '+text('COMPANION_'+short.upper(),label),
            'title_id = &"'+title+'"', 'bond_quest_id = &"quest_bond_'+short+'"',
            f'sprite_base = "res://assets/monsters/{monster}/mon_{monster}_s1"',
            'visual_scale = 0.7', 'flies = '+str(flies).lower(), 'bond_skills = '+names([passive,active])])
        descs = {
            'harpy': ('Ataques básicos com arco têm 4% + DES × 0,2% de chance (máximo 20%) de causar 80% ATK, ignorando metade da DEF. Recarga interna: 1,5 s.',
                     'Revela raros e invisíveis em 12 células por 8 s. O primeiro ataque nesse período recebe +10% de chance crítica.'),
            'guara': ('Tocaia e Armadilha de Cipó acionam uma mordida de 60% ATK, com lentidão de 20% por 2 s. Recarga interna: 4 s.',
                      'Marca um alvo por 15 s, revelando-o e mostrando-o no minimapa. Fora de combate, também revela coletas em 10 células.'),
            'lume': ('Ilumina 4 células à noite e nas cavernas. Efeito visual, sem dano.',
                     'Destaca coletas e baús em 15 células por 20 s, sem gastar mana.'),
        }
        for sid, sname, is_passive, desc in [(passive,pname,True,descs[short][0]),(active,aname,False,descs[short][1])]:
            resource('skills',sid,'SkillDef','skill_def',[
                'id = &"'+sid+'"', 'name_key = '+text('SK_'+sid.upper(),sname),
                'desc_key = '+text('SK_'+sid.upper()+'_DESC',desc), 'school = &"'+('arcane' if short=='lume' else 'bow')+'"',
                'companion_id = &"'+ident+'"', 'passive = '+str(is_passive).lower(), 'max_level = 1',
                'counts_for_titles = false', 'tree_title = &"'+title+'"',
                'tree_order = '+str(10 if is_passive else 11), 'target_type = '+str(0 if short=='guara' and not is_passive else 5),
                'effect = 10', 'mana_cost = '+str(0 if is_passive else mana),
                'cooldown_sec = '+str(0 if is_passive else cooldown), 'duration_sec = '+str(duration),
                'range_cells = 12.0', 'icon_text = "'+sname[:3]+'"'])
    resource('mounts','pindorama_mount_donkey','MountDef','mount_def',[
        'id = &"pindorama_mount_donkey"','name_key = '+text('MOUNT_DONKEY','Jumento do Sertão'),
        'sprite_base = "res://assets/mounts/pindorama_mount_donkey/mount_donkey"', 'walk_ms_per_cell = 160'])
    for ident,label,desc,price in [
        ('lobeira','Lobeira','Fruta-do-lobo colhida no cerrado.',0),
        ('glass_jar','Pote de Vidro','Um pote para transportar luzinhas com cuidado.',20),
        ('donkey_grass','Capim Fresco','Capim cortado para o jumento do Tropeiro.',0),
        ('rapadura','Rapadura','Um pedaço de rapadura da banca da vila.',0),
    ]:
        resource('items',ident,'ItemDef','item_def',[
            'id = &"'+ident+'"','name_key = '+text('ITEM_'+ident.upper(),label),
            'desc_key = '+text('ITEM_'+ident.upper()+'_DESC',desc), 'stackable = true', 'max_stack = 99',
            'buy_price = '+str(price)])
    quests = [
      ('harpy','Ninho na Sumaúma','master_taquari','pindorama_bow_gaviao',[
          (2,'HarpyBondNest',1,'Inspecione o ninho caído na Clareira da Mata.',{}),
          (1,'harpy_feather',6,'Pegue 6 Penas de Gavião do chão após aceitar esta etapa.',{}),
          (0,'harpy_eagle',3,'Derrote 3 Harpias Caçadoras (estágio 2).',{'required_stage':2}),
          (6,'pindorama_companion_harpy',1,'Dê nome ao filhote em Companheiros e Montarias.',{})]),
      ('guara','Fruta-do-Lobo','master_taquari','pindorama_bow_brejo',[
          (1,'lobeira',8,'Colha 8 Lobeiras na Encruzilhada dos Campos.',{}),
          (2,'GuaraTrack1',1,'Siga o primeiro rastro na Encruzilhada, de dia.',{'requires_day':True}),
          (2,'GuaraTrack2',1,'Siga o segundo rastro, de dia.',{'requires_day':True}),
          (2,'GuaraTrack3',1,'Siga o terceiro rastro, de dia.',{'requires_day':True}),
          (0,'maned_wolf',5,'Espante 5 Guarás da Alta Mata (estágio 2).',{'required_stage':2}),
          (5,'GuaraBondRest',1,'Use Lama no Corpo e espere 10 s parado junto à lobeira.',{'requires_hidden':True,'wait_sec':10})]),
      ('lume','Pote de Luz','master_orvalho','pindorama_arcane_firefly',[
          (1,'firefly_light',10,'À noite, pegue 10 Luzinhas de Vaga-lumes Encantados.',{'requires_night':True}),
          (1,'glass_jar',1,'Compre um Pote de Vidro no mercado.',{'allow_purchased':True}),
          (3,'elder_ze_ferreiro',1,'Leve o pote à forja do Seu Zé e ouça o causo.',{'lore_text_key':text('BOND_LUME_LORE','Você abre o pote. As luzinhas passeiam pela forja, e uma fica perto da sua mão. Seu Zé sorri: essa luz escolheu acompanhar sua viagem.')}),
          (3,'master_orvalho',1,'Conte a Mestre Orvalho como as luzinhas reacenderam a forja.',{})]),
    ]
    for short,label,npc,title,steps in quests:
        write_quest('quest_bond_'+short,label,npc,title,steps,'reward_companion = &"pindorama_companion_'+short+'"')
    write_quest('quest_mount_donkey','Um Amigo de Estrada','tropeiro','',[
        (1,'donkey_grass',4,'Colha 4 porções de capim junto ao Tropeiro.',{}),
        (1,'rapadura',2,'Pegue 2 rapaduras na banca da vila.',{}),
        (2,'DonkeyDelivery',1,'Leve a carga ao ponto de entrega perto do cais.',{}),
    ], 'reward_mount = &"pindorama_mount_donkey"\nturn_in_stars = 100')
    market = GAME/'data/shops/market.tres'
    source = market.read_text()
    if '&"glass_jar"' not in source:
        market.write_text(source.replace('items = Array[StringName]([','items = Array[StringName]([&"glass_jar", ',1))
    npc = GAME/'data/npcs/tropeiro.tres'
    npc.write_text('[gd_resource type="Resource" script_class="NpcDef" format=3]\n'
       '[ext_resource type="Script" path="res://scripts/shared/data/npc_def.gd" id="def"]\n'
       '[ext_resource type="Resource" path="res://data/dialogues/tropeiro.tres" id="dialogue"]\n'
       '[resource]\nscript = ExtResource("def")\nid = &"tropeiro"\nname_key = "NPC_TROPEIRO"\n'
       'sprite_base = "res://assets/npcs/npc_boatman"\nmap_id = &"city_awakening"\n'
       'spawn_marker = &"tropeiro"\ndialogue = ExtResource("dialogue")\n')
    TEXT['NPC_TROPEIRO']='Seu Benedito, Tropeiro'
    dialogue=GAME/'data/dialogues/tropeiro.tres'
    dialogue.write_text('[gd_resource type="Resource" script_class="DialogueDef" format=3]\n'
        '[ext_resource type="Script" path="res://scripts/shared/data/dialogue_def.gd" id="def"]\n'
        '[ext_resource type="Script" path="res://scripts/shared/data/dialogue_node.gd" id="node"]\n'
        '[sub_resource type="Resource" id="greeting"]\nscript = ExtResource("node")\nid = &"start"\n'
        'text_key = "TROPEIRO_GREETING"\n[resource]\nscript = ExtResource("def")\nid = &"tropeiro"\n'
        'start_node = &"start"\nnodes = Array[ExtResource("node")]([SubResource("greeting")])\n')
    TEXT['TROPEIRO_GREETING']='Estrada boa se faz com um amigo. Se você já tem dois Causos para contar, posso lhe apresentar um jumento de confiança.'
    # Zonas proibidas são explícitas, incluindo as cavernas e arenas privadas.
    for path in (GAME/'data/zones').glob('*.tres'):
        data=path.read_text()
        if any(token in path.stem for token in ('training','cave','hollow_earth','trial','arena','interior')):
            if 'mount_allowed =' not in data: data+='mount_allowed = false\n'
            if any(token in path.stem for token in ('training','arena')) and 'pets_allowed =' not in data: data+='pets_allowed = false\n'
            path.write_text(data)
    TEXT.update({'UI_FOLLOWERS': 'Companheiros e Montarias', 'FOLLOWER_NOT_OWNED': 'Você ainda não conquistou este vínculo.', 'FOLLOWER_STAND_STILL': 'Fique parado, fora de combate, para chamar seu companheiro.', 'FOLLOWER_OUT_OF_COMBAT': 'Só é possível montar fora de combate e em pé.', 'FOLLOWER_BUSY': 'Aguarde a ação atual terminar.', 'COMPANION_SWAP_COOLDOWN': 'Aguarde 60 segundos entre as trocas de companheiro.', 'MOUNT_ZONE_FORBIDDEN': 'Não é possível usar montarias nesta área.', 'MOUNT_HIT_LOCKOUT': 'Espere 5 segundos após receber dano para montar.', 'FOLLOWER_NAME_INVALID': 'Use um nome permitido, de 2 a 12 caracteres.', 'FOLLOWER_GATHER_COOLDOWN': 'Aguarde a coleta reaparecer em 30 segundos.', 'FOLLOWER_NAME_HINT': 'Nome (2 a 12 letras)', 'FOLLOWER_NAME_SAVE': 'Dar nome ao companheiro', 'FOLLOWERS_ALL': 'Outros companheiros: todos', 'FOLLOWERS_PARTY': 'Outros companheiros: apenas meu grupo', 'FOLLOWERS_NONE': 'Outros companheiros: nenhum', 'FOLLOWER_BONDS_HINT': 'Conquiste vínculos com Mestre Taquari, Mestre Orvalho e o Tropeiro. Requer 2 Causos e ter saído do treino.', 'FOLLOWER_ACTIVE_HINT': 'Um companheiro ativo por vez. Trocar leva 2 segundos, fora de combate.', 'FOLLOWER_ACTIVE': 'Ativo', 'FOLLOWER_DISMISS': 'Dispensar companheiro', 'MOUNT_RIDE': 'Montar', 'MOUNT_DISMOUNT': 'Desmontar', 'FOLLOWER_PASSIVE': 'Passiva automática', 'FOLLOWER_SLOT': 'Atalho %d', 'FOLLOWER_ASSIGN': 'Colocar no atalho', 'FOLLOWER_CHANNEL': 'Chamando… %.1f s. Fique parado.', 'FOLLOWER_SWAP_TIMER': 'Próxima troca em %d s.', 'FOLLOWER_WINDOW_HINT': 'Companheiros seguem você. Montarias de viagem desmontam ao lutar.'})
    with (GAME/'localization/followers.csv').open('w') as handle:
        writer=csv.writer(handle); writer.writerow(['keys','pt_BR']); writer.writerows(TEXT.items())

def write_quest(ident,label,npc,title,steps,rewards):
    prefix=ident.upper()
    head='[gd_resource type="Resource" script_class="QuestDef" format=3]\n'
    head+='[ext_resource type="Script" path="res://scripts/shared/data/quest_def.gd" id="quest"]\n'
    head+='[ext_resource type="Script" path="res://scripts/shared/data/quest_step.gd" id="step"]\n'
    for i,(kind,target,count,description,extras) in enumerate(steps):
        head+=f'\n[sub_resource type="Resource" id="s{i}"]\nscript = ExtResource("step")\ntype = {kind}\n'
        head+=f'target_id = &"{target}"\ncount = {count}\nscale_with_titles = false\ntext_key = '+text(prefix+f'_STEP_{i}',description)+'\n'
        for key,value in extras.items():
            head+=key+' = '+(str(value).lower() if isinstance(value,bool) else str(value))+'\n'
    head+='\n[resource]\nscript = ExtResource("quest")\nid = &"'+ident+'"\nname_key = '+text(prefix,label)+'\n'
    head+='giver_npc = &"'+npc+'"\nrequired_causos = 2\nrequires_left_training = true\n'
    if title: head+='required_titles = '+names([title])+'\n'
    head+='steps = Array[ExtResource("step")](['+', '.join(f'SubResource("s{i}")' for i in range(len(steps)))+'])\n'+rewards+'\n'
    for field,desc in [('desc_key','Complete a história de vínculo. Não exige nível.'),('offer_text_key',label+': podemos começar?'),
                        ('progress_text_key','Siga as etapas no diário. Eu espero seu retorno.'),('complete_text_key','Vocês agora têm uma estrada para seguir juntos.'),('option_text_key',label)]:
        head+=field+' = '+text(prefix+'_'+field.upper(),desc)+'\n'
    (GAME/'data/quests'/f'{ident}.tres').write_text(head)

if __name__ == '__main__': main()
