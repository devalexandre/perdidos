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

## Provedores e Custos no Brasil (Máquina Inicial: até 50 online / 2 vCPU, 4 GB RAM, 40 GB NVMe)

Para manter a latência baixa no Brasil (**ping de 15 a 35 ms** em São Paulo), as principais opções do mercado para a máquina inicial (2 vCPU, 4 GB RAM, 40 GB NVMe, 1 processo Godot + authgate):

| Provedor | Região / Datacenter | Custo Estimado / mês | Forma de Pagamento / Cartão | Prós & Contras |
|---|---|---|---|---|
| **Oracle Cloud (OCI Always Free)** | São Paulo (`sa-saopaulo-1`) | **R$ 0,00** (Gratuito) | **Pede cartão internacional** (cobrança teste de ~$1 estornada na hora) | Até 4 vCPUs ARM Ampere A1 (3.0 GHz) + 24 GB RAM + 200 GB NVMe + 10 TB tráfego grátis para sempre. Exige binário Godot Server ARM64. |
| **VPS Gamer BR** *(HeavyHost, VirtusHost, EnxHost)* | São Paulo | **R$ 40 – R$ 80** | **PIX / Boleto** (não precisa de cartão) | Processadores com clock alto (Ryzen 5000/7000), proteção Anti-DDoS para jogos inclusa, cobrança fixa em Real sem IOF. |
| **Hostinger BR (KVM 2)** | São Paulo | **R$ 40 – R$ 60** | **PIX / Boleto / Cartão nacional** | 2 vCPU, 8 GB RAM, 100 GB NVMe, 2 TB de tráfego. Painel amigável e faturamento nacional. |
| **Linode / Vultr** | São Paulo | **~US$ 24** (~R$ 130 – 145) | Cartão internacional ou PayPal | 2 vCPU, 4 GB RAM, 80 GB SSD, 4 TB de tráfego já inclusos (sem surpresa de cobrança por GB). |
| **Google Cloud (GCP)** | São Paulo (`southamerica-east1`) | **~US$ 70 – 95** (~R$ 390 – 530) | Cartão internacional | Conta nova ganha $300 USD de crédito (90 dias grátis). Fora da promoção é a opção mais cara (tráfego de saída e IP cobrados por GB/hora). |

### Detalhamento GCP (São Paulo vs EUA)
- **EUA (`us-central1`):** ~US$ 45 a 60 / mês (~R$ 250 – 330), mas com ping de 120–160 ms para jogadores no Brasil.
- **São Paulo (`southamerica-east1`):** ~US$ 70 a 95 / mês com `e2-custom-2-4096`, ou ~US$ 110–130 / mês com `n2` (clock dedicado). O tráfego de saída (egress) em SP custa cerca de US$ 0,15–0,19 por GB.
- **Crédito de boas-vindas:** O Google oferece **US$ 300 de crédito gratuito por 90 dias** para contas novas, permitindo rodar a máquina de testes sem custo nos primeiros 3 meses.

### Recomendações Práticas
1. **Sem gastar nada:** Usar o **Oracle Cloud Always Free** (São Paulo) ou ativar os **créditos de $300 do GCP**.
2. **Sem cartão de crédito internacional:** Contratar uma **VPS Gamer nacional em São Paulo** (R$ 40 – 80/mês via PIX com Anti-DDoS e CPU Ryzen).

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
