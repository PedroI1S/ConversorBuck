A aplicação de sistemas de controle em situações do cotidiano é cada vez mais comum. Sistemas com controle digital são encontrados desde brinquedos e fontes de alimentação de eletroeletrônicos domésticos até complexos sistemas robóticos, geração de energia fotovoltaica e acionamentos industriais. 

O conversor Buck, embora extremamente simples permite um grande número de aplicações e também representa um conceito fundamental para entendimento de sistemas de controle digital. Um diagrama funcional deste conversor com controle digital, proposto como projeto da disciplina, é apresentado na figura abaixo. Ainda que de forma remota, o desenvolvimento deste projeto permite integrar na implementação abordagens de sistemas de controle, eletrônica digital, eletrônica analógica, eletrônica de potência , entre outros conceitos utilizados durante a atividade. 

A partir da visão geral do conversor, discutido no tópico Apresentação do Projeto, e do material no PDF anexo, com detalhamento da análise do sistema de controle, desenvolva as seguintes atividades:

1. Gerar, através de linguagem de programação, o sinal de referência periódico para a tensão de saída do conversor Buck.

Considere a definição [Grupo] x [Sinal de referência] quanto ao formato, frequência do sinal e frequência de amostragem.
Avaliar o sinal com Matlab.
Gerar PWM com o sinal programado no microcontrolador e conectar a saída a um filtro passa-baixas avaliando o formato e frequência com osciloscópio.
2. Projete o conversor Buck de acordo com uma metodologia de sua escolha e verifique (utilizando simulações computacionais) se atende aos seguintes critérios:

Banda passante
Condução contínua
Ripple de corrente < 50%
Ripple de tensão < 2%
3. Projete o sistema de condicionamento de sinais e verifique (utilizando simulações computacionais) o comportamento de cada um dos circuitos:

Circuito de atenuação
Circuito de subtração
Circuito de filtragem
Circuito de offset
4. Analise os respectivos sistemas (conversor Buck e sistema de condicionamento de sinais) verificando características como :

tempo de subida e acomodação (respostas ao degrau)
ganho e fase em função da frequência (diagramas de Bode)
tensões de entrada e saída, atenuação de harmônicas e ruído de medida
resposta a sinais variantes no tempo (onda senoidal, quadrada, trapezoidal, triangular, ...) conforme a definição de seu grupo.
5. Discretize as funções de transferência referentes aos circuitos descritos em (2) e (3) para simulação como sistemas pseudocontínuos.

Considere que se tenha ao menos 100 pontos dos sistemas pseudocontínuos para cada amostra do sistema discreto. 
Para exemplos de como realizar esse procedimento verifique os materiais: 'Discretização de sistemas contínuos' e 'Modelagem de sistemas de atuação e aquisição de sinais'.
6. Com o objetivo de visualizar os efeitos das transformações de sinais que ocorrem em um sistema real, projete as operações a serem realizadas e os modelos dos dispositivos:

de atuação (PWM);
de condicionamento de sinais (atenuação, filtragem e offset);
do ADC (amostragem, retenção e quantização). 
7. Desenvolva um script para simulação em malha aberta do conversor, CCS, PWM, ADC, utilizando o sinal de referência como ação de controle. O script deve apresentar:

os parâmetros do conversor;
as discretizações;
inicializações de variáveis;
geração da referência;
geração de PWM;
simulação da planta;
simulação do circuito de condicionamento de sinais;
simulação do conversor ADC;
geração dos gráficos dos sinais a cada etapa.
8. Implementação dos controladores digitais aplicados ao conversor para geração da forma de onda especificada. Definir uma estratégia de controle, considerando:

Controladores P, PI, PID;
Ação feedforward
Outras modificações na estrutura de controle
9. Análise e parametrização do sistema em malha fechada para otimização da resposta na presença de perturbações.

Distúrbio (+/- 6V ) na tensão da fonte CC (Variação de 18 a 30V);
Alteração no modelo da planta (aumento de 30% no amortecimento).
10. Implementação experimental do sistema de controle digital para o conversor Buck:

Desenvolvimento da placa e montagem do circuito de transdutor e de condicionamento de sinais;
Desenvolvimento da placa e montagem do circuito de acionamento (drive) da "chave" e do conversor buck;
Análise experimental do funcionamento em malha aberta dos circuitos eletrônicos (com uso de gerador de funções e osciloscópio);
Aquisição de sinais e geração de PWM com DSP/microcontrolador (com uso de gerador de funções e osciloscópio);
Implementação em malha fechada do controlador no DSP/microcontrolador;
Análise experimental do funcionamento em malha fechada do sistema de controle digital (osciloscópio);
>> Resumidamente, o desenvolvimento deste projeto envolve as seguintes fases:

Geração do sinal digital de referência para a saída do conversor;
Projeto do circuito de potência considerando frequência de amostragem e parâmetros da forma de onda do sinal;
Projeto do circuito de condicionamento de sinais (CCS), considerando frequência de amostragem e frequência de corte do filtro LC do conversor;
Análise em malha aberta dos circuitos descritos em (2) e (3), delimitando características de interesse para o projeto;
Discretização dos circuitos descritos em (2) e (3) para simulação como sistemas pseudocontínuos;
Modelagem em linguagem de programação dos dispositivos de atuação (PWM), condicionamento de sinais e ADC;
Implementação da simulação em malha aberta do conversor, CCS, PWM, ADC, com um sinal de referência como ação de controle;
Implementação dos controladores digitais aplicados ao conversor para geração da forma de onda especificada;
Análise e parametrização do sistema em malha fechada para otimização da resposta na presença de perturbações.
Implementação de placas de circuitos de medição e de acionamento;
Análise em malha aberta dos circuitos projetados;
Aquisição de sinais com ADC e geração de sinais PWM em malha aberta utilizando DSP;
Análise experimental do sistema de controle digital em malha fechada.
Atividade - Artigo do projeto
Considerando as fases acima, utilizando os materiais abordados em aula e as implementações extraclasse, elabore um relatório/artigo que apresenta os procedimentos realizados. Devem ser encaminhados até a data limite desta tarefa:

O artigo deve estar em formato PDF, conforme modelo já estabelecido. Devem ser incluídos:
os diagramas do projeto e as discussões relativas a cada uma das fases;
os parâmetros utilizados nos projetos;
análise dos projetos realizados, tanto a resposta no tempo e quanto em frequência;
avaliações com simulações em outros softwares de simulação de circuitos elétricos;
os respectivos códigos comentados (em quadros conforme a função de cada rotina), tanto da simulação quanto da etapa experimental;
diagramas de circuitos e desenho das placas geradas;
formas de onda de simulação e experimental para os diversos testes em diferentes condições de operação e com diferentes ganhos.
O programa de simulação (script.m) deverá ser encaminhado na mesma submissão do artigo, como um arquivo em formato  texto, para que possa ser executado diretamente na plataforma Matlab/Octave ou Python. Dividir o programa em seções conforme as etapas (definições e projeto, inicialização de vetores, simulação e plotagem) e comentar todas as etapas do código.