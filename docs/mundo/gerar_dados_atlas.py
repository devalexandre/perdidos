#!/usr/bin/env python3
"""Fonte única dos dados do mapa-múndi (GDD §4.0.1). Agente G, 27/09/2026.

Gera, a partir das tabelas abaixo:
- game/data/world/atlas.tres e game/data/world/regions/<id>.tres (WorldAtlasDef / WorldRegionDef / WorldPlaceDef)
- game/localization/world_atlas.csv (chaves WA_*)
- as tabelas por região de docs/mundo/atlas.md (entre os marcadores GERADO-INICIO/GERADO-FIM)

Uso: python3 docs/mundo/gerar_dados_atlas.py   (depois: make check-names e reimportar no Godot)
Posições: normalizadas (0..1) sobre game/assets/worldmap/world_map.png (16:9).
"""
import csv, io, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
MAP_TEXTURE = "res://assets/worldmap/world_map.png"

# Tipos (mesma ordem de WorldPlaceDef.Kind) e estados (WorldPlaceDef.Status).
KINDS = ["capital", "town", "field", "dungeon", "mystery", "boss", "landmark", "port", "pvp", "training",
         "sea", "island", "doodle", "frontier"]
KIND_PT = {"capital": "Capital", "town": "Vila", "field": "Campo de caça", "dungeon": "Masmorra",
           "mystery": "Masmorra de mistério", "boss": "Chefe", "landmark": "Marco", "port": "Porto",
           "pvp": "Arena PVP", "training": "Área inicial", "sea": "Mar", "island": "Ilha",
           "doodle": "Desenho de monstro", "frontier": "Terra além do mapa"}
STATUS = {"open": 0, "soon": 1, "far": 2}
STATUS_PT = {"open": "**aberto (existe no jogo)**", "soon": "em breve (MVP)", "far": "não alcançada"}

# (id, tipo, nome, gancho, x, y, nível mín, nível máx, estado, mapas)
# Estado padrão "far" (terra ainda não alcançada). "mapas": map_id do jogo ou tupla com todos os mapas
# (andares/trechos) do lugar; o primeiro vira map_id e os demais map_ids (o "você está aqui" vale para
# todos). Níveis de um lugar com mapas = mín/máx das recomendações das zonas (game/data/zones/*.tres);
# conferir_zonas() avisa se divergirem ou se algum mapa CITY/HUNT ficar sem lugar.
REGIONS = [
    dict(id="sabia", name="Terra do Sabiá", insp="Brasil", label=(0.325, 0.47), reached=True,
         hook="Rios largos, cerrado de ipês e chapadas acima das nuvens: onde os Viajantes acordam.",
         places=[
        ("porto_despertar", "capital", "Porto do Despertar",
         "Cidade do rio onde os Viajantes acordam, sob o ipê amarelo gigante e o cristal azul.",
         0.315, 0.790, 0, 0, "open", "city_awakening"),
        ("campo_treino", "training", "Campo de Treino dos Viajantes",
         "Planalto sobre o Mar do Meio onde Mestres de todas as nações recebem os recém-chegados.",
         0.405, 0.612, 1, 10, "open", "training_field"),
        ("campos_sabia", "field", "Campos do Sabiá",
         "Cerrado de ipês em flor, buritis e cupinzeiros: os primeiros passos longe da cidade.",
         0.420, 0.690, 1, 10, "open", ("fields_sabia", "fields_sabia_buriti", "fields_sabia_crossroads")),
        ("mata_encantada", "field", "Mata Encantada",
         "Mata fechada de cipós e igarapés, com um velho forte engolido pelo musgo.",
         0.350, 0.725, 6, 12, "open",
         ("enchanted_forest", "enchanted_forest_glade", "enchanted_forest_roots", "enchanted_forest_heart")),
        ("chapada_ceu_partido", "field", "Chapada do Céu Partido",
         "Chapadas vermelhas sobre um mar de nuvens; cachoeiras caem no vazio.",
         0.318, 0.585, 12, 25, "open", ("split_sky_plateau", "split_sky_plateau_ridges", "split_sky_plateau_summit")),
        ("ninho_boitata", "boss", "Ninho do Boitatá",
         "A serpente de fogo, enfurecida pela fumaça das queimadas, guarda o alto da chapada.",
         0.286, 0.648, 25, 25, "soon", ""),
        ("arena_queimada", "pvp", "Arena da Queimada",
         "Clareira de cerrado queimado onde os Viajantes se enfrentam.",
         0.245, 0.765, 0, 0, "soon", ""),
        ("vila_buriti", "town", "Vila do Buriti",
         "Casas de palafita entre buritis, na foz do grande rio.",
         0.360, 0.865, 0, 0, "far", ""),
        ("mirante_ipe", "landmark", "Mirante do Ipê Solitário",
         "Um ipê roxo no topo das chapadas: dizem que dele se vê o mundo inteiro.",
         0.245, 0.515, 0, 0, "far", ""),
        ("caverna_reino_encoberto", "dungeon", "Caverna do Reino Encoberto",
         "Sob as raízes da Mata, pegadas fundas levam a uma câmara de pedra de onde vem um uivo.",
         0.335, 0.742, 12, 30, "open",
         ("cave_reino_encoberto", "cave_reino_encoberto_2", "cave_reino_encoberto_3", "cave_reino_encoberto_4")),
        # Além da Chapada (out/2026): a Serra Dourada no pico mais alto; Ratanabá e Z descem a encosta
        # oeste para a selva escura; o Arraial do Sumidouro fica no pico leste, entre a Charneca e a Serra.
        ("serra_dourada", "town", "Serra Dourada",
         "A Serra Resplandecente: casario de pedra no pico mais alto, acima do mar de nuvens da Chapada.",
         0.292, 0.505, 0, 0, "open", ("city_serra_dourada",)),
        ("selva_ratanaba", "field", "Selva de Ratanabá",
         "Trilhas de pirâmides engolidas pela selva e igarapés cheios de glifos que brilham.",
         0.250, 0.565, 20, 30, "open", ("jungle_ratanaba_trail", "jungle_ratanaba_waterfall", "jungle_ratanaba_gate")),
        ("ruinas_ratanaba", "dungeon", "Ruínas de Ratanabá",
         "Uma escadaria submersa desce à cidade de pedra polida, onde sentinelas de obsidiana ainda montam guarda.",
         0.218, 0.590, 24, 38, "open", ("ruins_ratanaba_1", "ruins_ratanaba_2", "ruins_ratanaba_3", "ruins_ratanaba_4")),
        ("dossel_z", "field", "Dossel de Z",
         "Mata tão fechada que a luz quase não chega ao chão; olhos acompanham cada passo na picada.",
         0.268, 0.608, 30, 38, "open", ("jungle_z_trail", "jungle_z_river", "jungle_z_gate")),
        ("cidade_perdida_z", "dungeon", "Cidade Perdida de Z",
         "Terraços de murais cobertos de musgo, guardados por onças de sombra, até o santuário de Kuarahy.",
         0.236, 0.667, 35, 44, "open", ("city_of_z_1", "city_of_z_2", "city_of_z_3", "city_of_z_4")),
        ("arraial_sumidouro", "town", "Arraial do Sumidouro",
         "Último arraial antes da névoa, no alto da serra; dali partem as trilhas para a Charneca e para a Boca do Sumidouro.",
         0.340, 0.530, 0, 0, "open", ("city_sumidouro",)),
        ("vilarejo_hoer_verde", "dungeon", "Vilarejo de Hoer Verde",
         "Uma vila abandonada na névoa, de sinos que dobram sozinhos. Na entrada: “Não há salvação”.",
         0.378, 0.543, 38, 52, "open", ("hoer_verde_1", "hoer_verde_2", "hoer_verde_3", "hoer_verde_4")),
        ("charneca_nevoa", "field", "Charneca da Névoa",
         "Brejos e urzes cobertos de névoa leitosa; a Trilha dos Lamentos leva ao vilarejo esquecido.",
         0.373, 0.610, 34, 42, "open", ("fog_moor_trail", "fog_moor_swamp", "fog_moor_gate")),
        ("serra_sumidouro", "field", "Serra do Sumidouro",
         "Trilhas de cristal à beira da Garganta do Abismo, até a boca que engole a montanha.",
         0.352, 0.648, 40, 48, "open", ("hollow_mountain_trail", "hollow_mountain_gorge", "hollow_mountain_gate")),
        ("terra_oca", "dungeon", "Túneis da Terra Oca",
         "Galerias titânicas de cristal sob a serra, onde tecelãs de sombra fiam no escuro e um titã dorme.",
         0.316, 0.674, 44, 60, "open", ("hollow_earth_1", "hollow_earth_2", "hollow_earth_3", "hollow_earth_4", "hollow_earth_5")),
        ("brejo_corpo_seco", "dungeon", "Brejo do Corpo-Seco",
         "Charco de árvores mortas onde brasas frias vagam à noite.",
         0.266, 0.702, 20, 30, "far", ""),
        ("remanso_iara", "dungeon", "Remanso da Iara",
         "Um palácio afogado no fundo do rio; o canto que sobe dele confunde os barqueiros.",
         0.283, 0.880, 25, 35, "far", ""),
        ("toca_mapinguari", "dungeon", "Toca do Mapinguari",
         "Pegadas enormes levam a uma gruta no coração da mata. O cheiro chega antes do dono.",
         0.395, 0.800, 30, 40, "far", ""),
        ("vagao_adormecido", "mystery", "Vagão Adormecido",
         "Um vagão de trem do Outro Lado, coberto de raízes, com o relógio parado nas 18h40.",
         0.420, 0.748, 40, 55, "far", ""),
    ]),
    dict(id="mouras", name="Reino das Mouras", insp="Portugal", label=(0.415, 0.395),
         hook="Muralhas caiadas, azulejos e fontes onde mouras encantadas fiam ouro ao luar.",
         places=[
        ("fiandouro", "capital", "Fiandouro",
         "Cidade de muralhas brancas e azulejos azuis; o fio de ouro das mouras é o seu brasão.",
         0.455, 0.435, 0, 0, "far", ""),
        ("vila_andorinhas", "town", "Vila das Andorinhas",
         "Aldeia de pescadores com barcos pintados de olhos na proa.",
         0.375, 0.470, 0, 0, "far", ""),
        ("cais_naus", "port", "Cais das Naus",
         "Estaleiros de onde saem as naus que cruzam o Mar do Meio.",
         0.430, 0.515, 0, 0, "far", ""),
        ("olival_ventos", "field", "Olival dos Ventos",
         "Olivais retorcidos e moinhos de vento; bichos pequenos e travessos.",
         0.400, 0.370, 10, 20, "far", ""),
        ("serra_cardos", "field", "Serra dos Cardos",
         "Encostas secas de cardos e pedras soltas, com lobos nas cristas.",
         0.475, 0.385, 20, 30, "far", ""),
        ("cova_moura", "dungeon", "Cova da Moura Encantada",
         "Uma fonte guardada por uma moura que fia ouro; quem cobiça o tesouro fica preso ao fio.",
         0.478, 0.490, 25, 35, "far", ""),
        ("toca_coca", "dungeon", "Toca da Coca",
         "O ninho da dragoa das lendas do reino, cheio de cascas de ovo e escamas verdes.",
         0.392, 0.508, 30, 40, "far", ""),
        ("cabo_gigante", "boss", "Cabo do Gigante",
         "Adamastor, o gigante de pedra do cabo, ergue tempestades contra os navios.",
         0.372, 0.430, 40, 50, "far", ""),
    ]),
    dict(id="colunas", name="Costa das Colunas", insp="Grécia antiga", label=(0.575, 0.505),
         hook="Colunas brancas, teatros voltados para o mar e ilhas cheias de monstros de lenda.",
         places=[
        ("heptastila", "capital", "Heptástila",
         "A cidade das sete colunas brancas, com teatros de pedra voltados para o Mar do Meio.",
         0.565, 0.455, 0, 0, "far", ""),
        ("ilha_figos", "town", "Ilha dos Figos",
         "Casinhas brancas e figueiras: parada obrigatória dos barcos do Mar do Meio.",
         0.585, 0.705, 0, 0, "far", ""),
        ("olivais_promontorio", "field", "Olivais do Promontório",
         "Terraços de oliveiras onde pastam cabras de chifres de bronze.",
         0.600, 0.555, 10, 20, "far", ""),
        ("recifes_sereias", "field", "Recifes das Sereias",
         "Ilhotas de pedra onde cantos trazidos pelo vento desviam os barcos.",
         0.515, 0.665, 20, 30, "far", ""),
        ("labirinto_minotauro", "dungeon", "Labirinto do Minotauro",
         "Corredores que mudam de lugar; só sai quem leva um fio.",
         0.535, 0.420, 25, 40, "far", ""),
        ("gruta_estatuas", "dungeon", "Gruta das Estátuas",
         "Estátuas de rostos assustados demais para serem obra de escultor. Não olhe nos olhos dela.",
         0.705, 0.700, 30, 40, "far", ""),
        ("pantano_hidra", "boss", "Pântano da Hidra",
         "Numa ilha de juncos, a serpente de muitas cabeças renasce a cada golpe descuidado.",
         0.730, 0.645, 40, 50, "far", ""),
    ]),
    dict(id="areias", name="Areias do Nilo", insp="Egito antigo", label=(0.850, 0.905),
         hook="Dunas douradas, um rio verde e as pirâmides que o povo do rio ergueu pedra por pedra.",
         places=[
        ("sesharis", "capital", "Sesháris",
         "A cidade dos escribas, à beira de um rio verde no meio das dunas.",
         0.830, 0.745, 0, 0, "far", ""),
        ("oasis_tamareiras", "town", "Oásis das Tamareiras",
         "Poços frescos e caravanas descansando à sombra das tamareiras.",
         0.870, 0.722, 0, 0, "far", ""),
        ("vale_piramides", "landmark", "Vale das Pirâmides",
         "As pirâmides erguidas pelos construtores de Sesháris; suas paredes contam a história do povo do rio.",
         0.860, 0.800, 0, 0, "far", ""),
        ("delta_juncos", "field", "Delta dos Juncos",
         "Canais de papiro, íbis e hipopótamos mal-humorados.",
         0.735, 0.835, 10, 20, "far", ""),
        ("dunas_escorpiao", "field", "Dunas do Escorpião",
         "Dunas altas onde escorpiões do tamanho de carroças caçam ao entardecer.",
         0.800, 0.875, 20, 30, "far", ""),
        ("galerias_esfinge", "dungeon", "Galerias da Esfinge",
         "Quem entra precisa responder aos enigmas da esfinge, ou se perde para sempre nas galerias.",
         0.895, 0.855, 30, 45, "far", ""),
        ("fenda_apep", "boss", "Fenda de Apep",
         "A serpente das trevas que, nas histórias, tenta engolir o sol ao fim de cada dia.",
         0.905, 0.735, 45, 55, "far", ""),
        ("capsula_estrela", "mystery", "Cápsula da Estrela Caída",
         "Uma cápsula de metal queimado no alto de uma duna, ainda piscando luzes que ninguém entende.",
         0.925, 0.800, 50, 65, "far", ""),
    ]),
    dict(id="jade", name="Império de Jade", insp="China", label=(0.705, 0.225),
         hook="Terraços de arroz, bambuzais que cantam e montanhas verdes onde a fera do Ano-Novo dorme.",
         places=[
        ("mil_degraus", "capital", "Mil Degraus",
         "Capital em terraços, subindo a montanha degrau por degrau, cheia de lanternas e casas de chá.",
         0.625, 0.335, 0, 0, "far", ""),
        ("porto_juncos", "port", "Porto dos Juncos",
         "Juncos de velas vermelhas trazem chá, seda e fogos de artifício.",
         0.735, 0.575, 0, 0, "far", ""),
        ("ponte_nove_curvas", "landmark", "Ponte das Nove Curvas",
         "Uma ponte em zigue-zague sobre o desfiladeiro. Dizem que monstros só andam em linha reta.",
         0.665, 0.430, 0, 0, "far", ""),
        ("terracos_arrozal", "field", "Terraços do Arrozal",
         "Terraços alagados que refletem o céu; sapos gordos e raposas espirituais.",
         0.600, 0.395, 10, 20, "far", ""),
        ("bambuzal_sussurrante", "field", "Bambuzal Sussurrante",
         "Um bambuzal tão alto que o vento toca música nele.",
         0.735, 0.470, 20, 30, "far", ""),
        ("vale_saltadores", "dungeon", "Vale dos Saltadores",
         "Mortos-vivos de túnica que andam aos saltos; só sinos e lanternas os fazem parar.",
         0.785, 0.370, 30, 40, "far", ""),
        ("covil_nian", "boss", "Covil do Nian",
         "A fera do Ano-Novo desce das montanhas; só o vermelho e o barulho a espantam.",
         0.695, 0.280, 40, 50, "far", ""),
        ("jardim_automato", "mystery", "Jardim do Autômato Paciente",
         "Um jardim perfeito no alto da montanha, cuidado há trezentos anos por mãos de metal.",
         0.800, 0.170, 50, 65, "far", ""),
    ]),
    dict(id="sol", name="Ilhas do Sol Nascente", insp="Japão", label=(0.905, 0.235),
         hook="Ilhas vulcânicas de cerejeiras, pontes vermelhas e picos onde os tengu desafiam os ousados.",
         places=[
        ("akarimachi", "capital", "Akarimachi",
         "A Vila das Lanternas: casas de madeira e papel, pontes vermelhas e cerejeiras.",
         0.872, 0.428, 0, 0, "far", ""),
        ("vila_kappa", "town", "Vila do Kappa",
         "Aldeia de pescadores onde os kappa trocam remédios para ossos por pepinos.",
         0.900, 0.315, 0, 0, "far", ""),
        ("praia_raposas", "field", "Praia das Raposas",
         "Areia negra e raposas que trocam de forma ao luar.",
         0.915, 0.440, 10, 20, "far", ""),
        ("passo_oni", "field", "Passo dos Oni",
         "Trilhas de lava fria onde os oni de chifre torto cobram pedágio.",
         0.875, 0.575, 20, 30, "far", ""),
        ("monte_tengu", "dungeon", "Monte do Tengu",
         "Pilares de pedra onde os tengu de nariz comprido desafiam quem ousa subir.",
         0.880, 0.370, 30, 40, "far", ""),
        ("ilha_orochi", "boss", "Ilha do Orochi",
         "Uma serpente de oito cabeças e oito caudas dorme enrolada no vulcão.",
         0.888, 0.512, 40, 50, "far", ""),
    ]),
    dict(id="fiordes", name="Fiordes de Gelo", insp="Noruega e Islândia", label=(0.335, 0.155),
         hook="Geleiras, auroras e salões de madeira onde as sagas são cantadas junto ao fogo.",
         places=[
        ("lumefiorde", "capital", "Lumefiorde",
         "Salões de madeira com fogueiras sempre acesas, no fundo de um fiorde azul.",
         0.400, 0.285, 0, 0, "far", ""),
        ("vila_auroras", "town", "Vila das Auroras",
         "Casas de turfa no gelo, onde o céu dança em verde nas noites longas.",
         0.300, 0.340, 0, 0, "far", ""),
        ("geleira_uivante", "field", "Geleira Uivante",
         "Um mar de gelo onde o vento uiva como lobo.",
         0.330, 0.245, 10, 25, "far", ""),
        ("pinheiral_trolls", "field", "Pinheiral dos Trolls",
         "Pinheiros escuros onde trolls viram pedra ao primeiro raio de sol.",
         0.440, 0.215, 20, 30, "far", ""),
        ("tumulos_draugr", "dungeon", "Túmulos dos Draugr",
         "Montes de pedra onde os mortos das sagas ainda guardam seus tesouros.",
         0.265, 0.205, 30, 40, "far", ""),
        ("covil_lindworm", "dungeon", "Covil do Lindworm",
         "Uma serpente-dragão sem asas dorme sob a geleira, enrolada no próprio frio.",
         0.370, 0.135, 35, 45, "far", ""),
        ("fenda_lobo", "boss", "Fenda do Lobo Acorrentado",
         "Fenrir, o lobo do tamanho de uma colina, puxa correntes presas no fundo do gelo.",
         0.405, 0.195, 45, 55, "far", ""),
        ("casco_gelo", "mystery", "Casco Preso no Gelo",
         "O casco negro de um navio que anda debaixo d'água, preso numa geleira há sessenta invernos.",
         0.255, 0.290, 50, 65, "far", ""),
    ]),
    dict(id="estepe", name="Estepe de Ferro", insp="povos eslavos", label=(0.535, 0.165),
         hook="Bosques de bétulas, isbás entalhadas e contos de feiticeiros imortais e pássaros de fogo.",
         places=[
        ("zharogrado", "capital", "Zharogrado",
         "Cidade de isbás entalhadas e torres de madeira, cercada por paliçadas e campos de girassol.",
         0.505, 0.265, 0, 0, "far", ""),
        ("isba_pes_galinha", "dungeon", "Isbá dos Pés de Galinha",
         "A cabana da Baba Yaga anda pelo bosque; ninguém a encontra duas vezes no mesmo lugar.",
         0.540, 0.210, 25, 40, "far", ""),
        ("bosque_betulas", "field", "Bosque das Bétulas",
         "Bétulas brancas e clareiras de flores; lobos cinzentos e plumas de fogo no chão.",
         0.478, 0.185, 10, 20, "far", ""),
        ("colinas_ferro", "field", "Colinas de Ferro",
         "Colinas escuras de minério onde o vento arrasta a neve de lado.",
         0.495, 0.340, 20, 30, "far", ""),
        ("ninho_zmey", "dungeon", "Ninho do Zmey",
         "O dragão de três cabeças faz ninho nos picos brancos.",
         0.600, 0.155, 35, 45, "far", ""),
        ("castelo_koschei", "boss", "Castelo de Koschei",
         "O feiticeiro imortal esconde a própria morte numa agulha, dentro de um ovo, dentro de um pato...",
         0.447, 0.325, 45, 55, "far", ""),
        ("antena_escuta", "mystery", "A Antena que Escuta",
         "Uma enorme concha de metal virada para o céu, no meio do bosque, zumbindo sozinha à noite.",
         0.572, 0.245, 50, 65, "far", ""),
    ]),
    dict(id="brumas", name="Brumas Verdes", insp="Irlanda e Escócia", label=(0.175, 0.295),
         hook="Ilhas de colinas verdes e névoa, onde harpas choram e cavalos d'água convidam a montar.",
         places=[
        ("dunbruma", "capital", "Dúnbruma",
         "Fortaleza de pedra verde no alto de um morro, sempre envolta em névoa.",
         0.215, 0.228, 0, 0, "far", ""),
        ("porto_focas", "port", "Porto das Focas",
         "Onde as selkies deixam a pele na praia para dançar em forma de gente.",
         0.085, 0.250, 0, 0, "far", ""),
        ("colinas_nevoa", "field", "Colinas da Névoa",
         "Colinas de urze e muros de pedra; ovelhas que somem na névoa e voltam diferentes.",
         0.140, 0.225, 10, 20, "far", ""),
        ("lago_kelpie", "field", "Lago do Kelpie",
         "Um cavalo d'água convida os viajantes a montar e mergulha com eles.",
         0.205, 0.445, 20, 30, "far", ""),
        ("estrada_sem_cabeca", "dungeon", "Estrada do Cocheiro sem Cabeça",
         "Uma carruagem negra passa à meia-noite; o cocheiro carrega a própria cabeça.",
         0.160, 0.160, 30, 40, "far", ""),
        ("olho_balor", "boss", "Olho de Balor",
         "O gigante de um olho só: quando a pálpebra se abre, tudo o que ele olha queima.",
         0.195, 0.125, 45, 55, "far", ""),
        ("oficina_horas_tortas", "mystery", "Oficina das Horas Tortas",
         "Uma máquina de latão e vidro no meio de um círculo de pedras; lá dentro os relógios andam para trás.",
         0.100, 0.430, 50, 65, "far", ""),
    ]),
    dict(id="obsidiana", name="Selvas de Obsidiana", insp="México antigo", label=(0.115, 0.605),
         hook="Selva fumegante, vulcões e cidades de pirâmides escalonadas erguidas pelo povo da selva.",
         places=[
        ("itzcalli", "capital", "Itzcalli",
         "Cidade de pirâmides escalonadas, jardins flutuantes e mercados de cacau, erguida pelo povo da selva.",
         0.125, 0.650, 0, 0, "far", ""),
        ("mercado_penas", "town", "Mercado das Penas",
         "Vila de artesãos de plumas, jade e obsidiana.",
         0.095, 0.690, 0, 0, "far", ""),
        ("trilha_jaguares", "field", "Trilha dos Jaguares",
         "Trilhas sob a copa, onde olhos amarelos acompanham cada passo.",
         0.178, 0.660, 10, 20, "far", ""),
        ("manguezal_esmeralda", "field", "Manguezal Esmeralda",
         "Raízes altas sobre a água verde, caranguejos-armadura e garças de crista.",
         0.200, 0.745, 20, 30, "far", ""),
        ("poco_mil_vozes", "dungeon", "Poço das Mil Vozes",
         "Um poço natural de água azul; lá embaixo, a água responde com a voz de quem já passou.",
         0.130, 0.720, 30, 40, "far", ""),
        ("boca_vulcao", "boss", "Boca do Vulcão Fumegante",
         "Cipactli, o grande crocodilo da terra das lendas antigas, desperta dentro do vulcão.",
         0.165, 0.585, 45, 55, "far", ""),
        ("nave_albatroz", "mystery", "Nave Albatroz",
         "Um navio que navegava no céu, encalhado na copa das árvores, ainda estalando relâmpagos.",
         0.225, 0.622, 50, 65, "far", ""),
    ]),
]

FEATURES = [
    ("mar_meio", "sea", "Mar do Meio", "O mar calmo no centro do mundo, cheio de ilhotas e rotas de comércio.",
     0.600, 0.765),
    ("mar_brumas", "sea", "Mar das Brumas", "Águas frias e cinzentas; a névoa esconde ilhas que não estavam lá ontem.",
     0.060, 0.330),
    ("mar_petalas", "sea", "Mar das Pétalas", "Na época da Florada, pétalas douradas boiam nestas águas sem ninguém saber de onde vêm.",
     0.200, 0.835),
    ("mar_sol", "sea", "Mar do Sol Nascente", "Correntes quentes que levam às ilhas vulcânicas do leste.",
     0.815, 0.675),
    ("mil_recifes", "island", "Arquipélago dos Mil Recifes", "Ninguém nunca contou as ilhotas. Os barqueiros dizem que algumas mudam de lugar.",
     0.540, 0.770),
    ("ilha_farol_torto", "island", "Ilha do Farol Torto", "Um farol inclinado que ilumina para o lado errado: e mesmo assim ninguém naufraga.",
     0.245, 0.922),
    ("baleia_ilha", "doodle", "Baleia-Ilha", "Uma baleia que dorme há tanto tempo que os marinheiros a desenham como ilha.",
     0.142, 0.790),
    ("serpente_pato", "doodle", "Serpente-Pato", "Cabeça de pato, corpo de serpente, humor péssimo. Os pescadores juram que existe.",
     0.085, 0.565),
    ("sapo_marinho", "doodle", "Sapo-Gigante do Mar", "Um sapo do tamanho de um barco, que boia de olhos abertos à espera de moscas grandes.",
     0.160, 0.880),
    ("enguia_tinta", "doodle", "Baleia-Velha e a Enguia de Tinta", "Uma baleia cansada carrega nas costas uma enguia negra que cospe tinta nos navios.",
     0.640, 0.805),
    ("serpente_brumas", "doodle", "Serpente das Brumas", "Enrolada numa ilhota, só aparece quando a névoa fica azul.",
     0.112, 0.370),
    ("fera_charneca", "doodle", "Fera da Charneca", "Um bicho negro que os pastores do reino desenham para assustar as crianças. Talvez seja filhote da Coca.",
     0.415, 0.470),
    ("galeao_errante", "doodle", "Galeão Errante", "Um navio que ninguém tripula e que sempre chega um dia antes da tempestade.",
     0.463, 0.855),
    ("revoada_corvos", "doodle", "Revoada dos Corvos de Ferro", "Pássaros escuros que voam para o leste antes de cada inverno.",
     0.925, 0.130),
    ("norte_nublado", "frontier", "Norte Nublado", "Terra ainda não alcançada. Além das nuvens do norte, os mapas ficam em branco.",
     0.500, 0.075),
    ("leste_alem", "frontier", "Além do Sol Nascente", "Terra ainda não alcançada. Ninguém que navegou para lá voltou para contar.",
     0.935, 0.595),
    ("sul_sem_fim", "frontier", "Areias Sem Fim", "Terra ainda não alcançada. Dizem que o deserto do sul não termina nunca.",
     0.600, 0.935),
]

UI = {
    "WA_TITLE": "Mapa-múndi",
    "WA_WORLD_NAME": "O mundo dos Viajantes",
    "WA_HINT": "Arrastar ou setas: mover · Roda ou +/-: zoom · 0: centralizar",
    "WA_LEGEND": "Legenda",
    "WA_EXPLORE": "Terras e lendas",
    "WA_INDEX_HINT": "Escolha uma região para explorar.\nArraste para mover • Roda para ampliar\nM ou Esc para voltar",
    "WA_ZOOM_IN": "Ampliar (+)",
    "WA_ZOOM_OUT": "Afastar (−)",
    "WA_OVERVIEW": "Ver o mundo inteiro (0)",
    "WA_CLOSE": "Fechar",
    "WA_LEG_CAPITAL": "Capital", "WA_LEG_TOWN": "Vila", "WA_LEG_FIELD": "Campo", "WA_LEG_DUNGEON": "Masmorra",
    "WA_LEG_MYSTERY": "Mistério", "WA_LEG_BOSS": "Chefe", "WA_LEG_PORT": "Porto", "WA_LEG_LANDMARK": "Marco",
    "WA_LEG_UNREACHED": "Não alcançada",
    "WA_YOU_ARE_HERE": "Você está aqui",
    "WA_STATUS_OPEN": "Aberto",
    "WA_STATUS_SOON": "Em breve",
    "WA_STATUS_UNREACHED": "Terra ainda não alcançada",
    "WA_LEVELS": "Nível recomendado: %d a %d",
    "WA_LEVEL_ONE": "Nível recomendado: %d",
    "WA_LEVELS_ANY": "Qualquer nível",
    "WA_REGION_OF": "Região: %s",
    "WA_KIND_CAPITAL": "Capital", "WA_KIND_TOWN": "Vila", "WA_KIND_FIELD": "Campo de caça",
    "WA_KIND_DUNGEON": "Masmorra", "WA_KIND_MYSTERY": "Masmorra de mistério", "WA_KIND_BOSS": "Chefe",
    "WA_KIND_LANDMARK": "Marco", "WA_KIND_PORT": "Porto", "WA_KIND_PVP": "Arena (combate entre jogadores)",
    "WA_KIND_TRAINING": "Área inicial", "WA_KIND_SEA": "Mar", "WA_KIND_ISLAND": "Ilha",
    "WA_KIND_DOODLE": "Desenho de monstro (lenda de marinheiro)", "WA_KIND_FRONTIER": "Terra além do mapa",
}


def key_region(rid, suffix=""):
    return f"WA_R_{rid.upper()}{suffix}"


def key_place(pid, suffix=""):
    return f"WA_P_{pid.upper()}{suffix}"


def s(v):  # string .tres
    return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'


def place_maps(maps):
    """map_id do jogo (str) ou tupla de mapas -> lista de map_ids."""
    if not maps:
        return []
    return [maps] if isinstance(maps, str) else list(maps)


def place_block(sub_id, p, region_id, kind, name, hook, x, y, lmin, lmax, status, maps):
    lines = [f'[sub_resource type="Resource" id="{sub_id}"]', 'script = ExtResource("place")',
             f'id = &"{p}"', f'region_id = &"{region_id}"', f"kind = {KINDS.index(kind)}",
             f"status = {STATUS[status]}", f"name_key = {s(key_place(p))}", f"hook_key = {s(key_place(p, '_HOOK'))}",
             f"pos = Vector2({x}, {y})", f"level_min = {lmin}", f"level_max = {lmax}"]
    map_ids = place_maps(maps)
    map_id = map_ids[0] if map_ids else ""
    if len(map_ids) > 1:
        lines.append("map_ids = Array[StringName]([" + ", ".join(f'&"{m}"' for m in map_ids[1:]) + "])")
    if map_id:
        lines.append(f'map_id = &"{map_id}"')
    if kind in ("doodle",):
        lines.append("always_label = false")
    return "\n".join(lines) + "\n"


def write_region(r):
    subs, ids = [], []
    for i, pl in enumerate(r["places"]):
        pid, kind, name, hook, x, y, lmin, lmax, status, maps = pl
        sid = f"p{i}"
        ids.append(f'SubResource("{sid}")')
        subs.append(place_block(sid, pid, r["id"], kind, name, hook, x, y, lmin, lmax, status, maps))
    out = ['[gd_resource type="Resource" script_class="WorldRegionDef" format=3]', "",
           '[ext_resource type="Script" path="res://scripts/shared/data/world_region_def.gd" id="region"]',
           '[ext_resource type="Script" path="res://scripts/shared/data/world_place_def.gd" id="place"]', ""]
    out += [b for b in subs]
    out += ["[resource]", 'script = ExtResource("region")', f'id = &"{r["id"]}"',
            f"name_key = {s(key_region(r['id']))}", f"hook_key = {s(key_region(r['id'], '_HOOK'))}",
            f"inspiration = {s(r['insp'])}", f"label_pos = Vector2({r['label'][0]}, {r['label'][1]})",
            f"reached = {'true' if r.get('reached') else 'false'}",
            f'places = Array[ExtResource("place")]([{", ".join(ids)}])', ""]
    path = GAME / "data/world/regions" / f"{r['id']}.tres"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(out), encoding="utf-8")


def write_atlas():
    out = ['[gd_resource type="Resource" script_class="WorldAtlasDef" format=3]', "",
           '[ext_resource type="Script" path="res://scripts/shared/data/world_atlas_def.gd" id="atlas"]',
           '[ext_resource type="Script" path="res://scripts/shared/data/world_region_def.gd" id="region"]',
           '[ext_resource type="Script" path="res://scripts/shared/data/world_place_def.gd" id="place"]',
           f'[ext_resource type="Texture2D" path="{MAP_TEXTURE}" id="map"]']
    for r in REGIONS:
        out.append(f'[ext_resource type="Resource" path="res://data/world/regions/{r["id"]}.tres" id="r_{r["id"]}"]')
    out.append("")
    ids = []
    for i, (pid, kind, name, hook, x, y) in enumerate(FEATURES):
        sid = f"f{i}"
        ids.append(f'SubResource("{sid}")')
        out.append(place_block(sid, pid, "", kind, name, hook, x, y, 0, 0, "far", ""))
    out += ["[resource]", 'script = ExtResource("atlas")', 'map_texture = ExtResource("map")',
            'regions = Array[ExtResource("region")]([' + ", ".join(f'ExtResource("r_{r["id"]}")' for r in REGIONS) + "])",
            'features = Array[ExtResource("place")]([' + ", ".join(ids) + "])", ""]
    (GAME / "data/world/atlas.tres").write_text("\n".join(out), encoding="utf-8")


def write_csv():
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow(["keys", "pt_BR"])
    for k, v in UI.items():
        w.writerow([k, v])
    for r in REGIONS:
        w.writerow([key_region(r["id"]), r["name"]])
        w.writerow([key_region(r["id"], "_HOOK"), r["hook"]])
        for pl in r["places"]:
            w.writerow([key_place(pl[0]), pl[2]])
            w.writerow([key_place(pl[0], "_HOOK"), pl[3]])
    for f in FEATURES:
        w.writerow([key_place(f[0]), f[2]])
        w.writerow([key_place(f[0], "_HOOK"), f[3]])
    (GAME / "localization/world_atlas.csv").write_text(buf.getvalue(), encoding="utf-8")


def levels(lmin, lmax):
    if lmax <= 0:
        return "—"
    return f"{lmin}" if lmin == lmax else f"{lmin}–{lmax}"


def write_md_tables():
    md = ROOT / "docs/mundo/atlas.md"
    parts = []
    for r in REGIONS:
        parts.append(f"#### {r['name']} ({r['insp']}) — `{r['id']}`\n\n*{r['hook']}*\n")
        parts.append("| Lugar | Tipo | Níveis | Estado | Gancho | Posição (x, y) |\n|---|---|---|---|---|---|")
        for pid, kind, name, hook, x, y, lmin, lmax, status, maps in r["places"]:
            nm = f"**{name}**" if kind == "capital" else name
            parts.append(f"| {nm} | {KIND_PT[kind]} | {levels(lmin, lmax)} | {STATUS_PT[status]} | {hook} | {x:.3f}, {y:.3f} |")
        parts.append("")
    parts.append("#### Mares, ilhas, desenhos e terras além do mapa\n")
    parts.append("| Elemento | Tipo | Texto | Posição (x, y) |\n|---|---|---|---|")
    for pid, kind, name, hook, x, y in FEATURES:
        parts.append(f"| {name} | {KIND_PT[kind]} | {hook} | {x:.3f}, {y:.3f} |")
    block = "\n".join(parts)
    text = md.read_text(encoding="utf-8")
    text = re.sub(r"(<!-- GERADO-INICIO -->\n).*?(<!-- GERADO-FIM -->)", lambda m: m.group(1) + block + "\n" + m.group(2),
                  text, flags=re.S)
    md.write_text(text, encoding="utf-8")


def conferir_zonas():
    """Avisa (sem falhar) se um mapa CITY/HUNT de game/data/zones não tem lugar no atlas, ou se os
    níveis do lugar divergem do mín/máx das zonas do grupo."""
    zones = {}
    for f in sorted((GAME / "data/zones").glob("*.tres")):
        t = f.read_text(encoding="utf-8")
        mid = re.search(r'^map_id = &"([^"]+)"', t, re.M)
        if not mid:
            continue
        kind = re.search(r"^kind = (\d+)", t, re.M)
        lmin = re.search(r"^recommended_level_min = (\d+)", t, re.M)
        lmax = re.search(r"^recommended_level_max = (\d+)", t, re.M)
        zones[mid.group(1)] = (int(kind.group(1)) if kind else 0, int(lmin.group(1)) if lmin else 0,
                               int(lmax.group(1)) if lmax else 0)
    placed = {}
    for r in REGIONS:
        for pl in r["places"]:
            for m in place_maps(pl[9]):
                placed[m] = pl
    avisos = 0
    for m, (kind, _lo, _hi) in zones.items():
        if kind in (0, 2) and m not in placed and m not in ZONES_SEM_LUGAR:  # ZoneDef.Kind CITY / HUNT
            print(f"AVISO: mapa {m} sem lugar no atlas")
            avisos += 1
    for pl in placed.values():
        lv = [zones[m] for m in place_maps(pl[9]) if m in zones and zones[m][2] > 0]
        if lv:
            lo, hi = min(z[1] for z in lv), max(z[2] for z in lv)
            if (pl[6], pl[7]) != (lo, hi):
                print(f"AVISO: {pl[0]} com níveis {pl[6]}–{pl[7]}, zonas dizem {lo}–{hi}")
                avisos += 1
    return avisos


# Mapas reais que não aparecem no atlas de propósito.
ZONES_SEM_LUGAR = {"elder_trial_arena"}


if __name__ == "__main__":
    conferir_zonas()
    for r in REGIONS:
        write_region(r)
    write_atlas()
    write_csv()
    if (ROOT / "docs/mundo/atlas.md").exists():
        write_md_tables()
    n = sum(len(r["places"]) for r in REGIONS)
    print(f"{len(REGIONS)} regiões, {n} lugares, {len(FEATURES)} elementos soltos.")
