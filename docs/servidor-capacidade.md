# Capacidade do servidor

Quanto de máquina o Perdidos precisa conforme o número de jogadores.

> **Estimativa, não medição.** Os números vêm de servidores de jogo parecidos.
> Antes de contratar a máquina, rode um teste de carga (bots entrando aos poucos
> até o tick atrasar) para saber quantos jogadores um núcleo aguenta de verdade.

## Base x online simultâneo

O que pesa no servidor é quem está **online ao mesmo tempo**, não o total de cadastrados.
Em jogos online, no horário de pico costumam estar conectados **10 a 20%** dos jogadores ativos.

| Jogadores na base | Online no pico (estimado) |
|---:|---:|
| 500 | 50 – 100 |
| 1.500 | 150 – 300 |
| 5.000 | **500 – 1.000** |
| 15.000 | 1.500 – 3.000 |

## Tabela de hardware

| Online simultâneo | Base aprox. | CPU (VM dedicada) | RAM | Disco | Rede | Arquitetura |
|---|---|---|---|---|---|---|
| até 50 | ~500 | 2 vCPU | 4 GB | 40 GB NVMe | 100 Mbps | 1 processo Godot + authgate |
| 50 – 200 | 500 – 1.500 | 4 vCPU, clock alto (≥ 3,5 GHz) | 8 GB | 80 GB NVMe | 200 Mbps | 1 processo, já perto do limite |
| 200 – 500 | 1.500 – 3.000 | 8 vCPU, clock alto | 16 GB | 160 GB NVMe | 500 Mbps | 2 – 4 processos Godot (mapas divididos) |
| **500 – 1.000** | **~5.000** | **8 – 16 vCPU dedicadas, clock alto** | **32 GB** | **250 GB NVMe** | **1 Gbps** | **4 – 8 processos, um por grupo de mapas** |
| 1.000 – 2.500 | 10 – 15 mil | 2 VMs de 16 vCPU | 2 × 32 GB | NVMe + banco separado | 1 Gbps cada | vários servidores de jogo |

## Recomendação para 5 mil jogadores

- **VM dedicada** com 8 a 16 núcleos **dedicados** e clock alto (Ryzen/EPYC recente).
- **32 GB de RAM**, **NVMe** e **1 Gbps**.
- **Banco fora da VM do jogo**: Neon ou outro PostgreSQL gerenciado.
- **Hospedar no Brasil (São Paulo)** reduz a latência para a maior parte dos jogadores.
- Custo esperado: **US$ 80 a 200 por mês**, conforme o provedor (Hetzner e OVH na ponta barata).

## Por que o clock importa mais que o número de núcleos

Hoje o servidor é **um único processo Godot em GDScript**, com todos os mapas no mesmo
loop (`game/scripts/server/server_world.gd`). A lógica do jogo usa praticamente **um núcleo**.

Consequências:

1. Até umas 200 pessoas online, um núcleo rápido rende mais que muitos núcleos lentos.
2. Acima disso é preciso **dividir os mapas em vários processos Godot** (um por grupo de mapas),
   cada um usando um núcleo. Só assim as 8 – 16 vCPUs da tabela são aproveitadas.
3. Essa divisão é trabalho de código (troca de mapa entre processos, chat e grupo
   entre servidores) e deve ser planejada antes de chegar perto de 200 online.

## Próximo passo

Teste de carga com bots headless:

1. Subir o servidor numa máquina conhecida.
2. Conectar bots em lotes (50, 100, 200…) andando e lutando nos mapas.
3. Medir o tempo de cada tick e o uso de CPU e RAM; anotar onde o tick passa do orçamento.
4. Atualizar esta tabela com os números reais.
