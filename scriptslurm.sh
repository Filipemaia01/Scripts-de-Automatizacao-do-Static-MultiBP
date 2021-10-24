#!/bin/bash

##########################################################
#  Script de escalonamento de execuções MultiBP em SLURM #
#  Estratégia: Static-MultiBP                            #
#  Parâmetros de entrada:                                #
#     $1: identificação das sequências                   #
#     $2: quantidade de GPUs por host                    #
#  Autor: Marco Figueiredo                               #
########################################################## 



#BASE_IP=compute-st-g4dnxlarge-1    # Endereço IP base (nos testes que realizamos até agora, foi possível executar com o nome da instância)
#BASE_IP=10.0.10.119

baseport=2000       # Porta base
sol=multibp
instancia=g4dnxlarge
nos=4

# Função que recupera os nomes dos hosts
function getips ()
{
	nodelist=`scontrol show hostnames compute-st-$instancia-[1-$nos]`
	nodeips=$nodelist
	echo $nodeips
}

# Função que retorna o IP do host corrente
function getip ()
{
  for j in `seq 0 $((MYNODEID-1))`; do # o comando seq cria uma lista de numeros de acordo com os parâmetros passados: início da lista, passo, final da lista
     shift #comando usado para mudar o parâmtro recebido
  done
  elem=$1
  echo $elem
}

# Função que retorna o IP do host anterior
function getpip ()
{
  if [ $MYNODEID -eq 0 ]; then #if $MYNODEID == 0: -eq -> igual
      return;
  fi
  n=`expr $MYNODEID - 2` # calcula uma expressão. Neste caso, calcula o ID do nó - 2
  for j in `seq 0 $n`; do
     shift
  done
  elem=$1
  echo  $elem #usar echo para retornar strings
}

# Função que retorna o IP do próximo host
function getnip ()
{
  if [ $MYNODEID == `expr $SLURM_NNODES - 1` ]; then
     return;
  fi
  n=`expr $MYNODEID`
  for j in `seq 0 $n`; do
     shift
  done
  elem=$1
  echo $elem #usar echo para retornar strings
}

# Funçãp principal
TIMESTAMP=$SLURM_JOBID.`date +%Y%m%d` # Timestamp da execução

export MYNODEID=$SLURM_PROCID
gpus=$2   # Quantidade de GPUs 
basepart=`expr $MYNODEID '*' $gpus + 1` # Parte do host atual
split=`expr $SLURM_NNODES '*' $gpus` # Quantidade de partes

touch `hostname`.out.txt
echo "gpus: $gpus" >> `hostname`.out.txt
echo "basepart: $basepart" >> `hostname`.out.txt
echo "split: $split" >> `hostname`.out.txt

# Criação da pasta de saída
if [ ! -d "./resultfiles/$1/${split}GPU/$TIMESTAMP" ] 
then
  mkdir -p ./resultfiles/$1/${split}GPU/$TIMESTAMP
fi

# Coleta de logs de execução
HNAME=./resultfiles/$1/${split}GPU/$TIMESTAMP/$TIMESTAMP.`hostname`.$SLURM_PROCID 
rm -f $HNAME
touch $HNAME #criar arquivo
echo SLURM_NODELIST $SLURM_NODELIST >>$HNAME #gravando a lista de nós em arquivo >>
getips "$SLURM_NODELIST" >>$HNAME
echo $SLURM_NODEID >>$HNAME

ips=`getips "$SLURM_NODELIST"` # Chamada de função que obtem todos os IPs
myip=`getip $ips` # Chamada de função que obtem todos os IPs
previp=`getpip $ips` # Chamada de função que obtem IP anterior
nextip=`getnip $ips` # Chamada de função que obtem IP seguinte

echo "lista de ips: $ips" >> `hostname`.out.txt

echo myip $myip >>$HNAME
echo previp $previp >>$HNAME
echo nextip $nextip >>$HNAME

echo "myip: $myip" >> `hostname`.out.txt
echo "previp: $previp" >> `hostname`.out.txt
echo "nextip: $nextip" >> `hostname`.out.txt


#home=/gpfs/fs1/jpnavarro/projects/nvidia_unb # Diretório raiz

home=$HOME # Diretório raiz

# Criação de pasta de saída de resultados
if [ ! -d "$home/results" ] 
then
 mkdir $home/results
fi


# Case para verificar qual o par de sequências a comparar
case "$1" in
		1-3m) seq1=$home/sequences/1-3M/BA000035.2.fasta
			  seq2=$home/sequences/1-3M/BX927147.1.fasta ;;
		2-5m) seq1=$home/sequences/2-5M/AE016879.1.fasta
			  seq2=$home/sequences/2-5M/AE017225.1.fasta ;;
		3-7m) seq1=$home/sequences/3-7M/NC_003997.3.fasta
			  seq2=$home/sequences/3-7M/NC_005027.1.fasta ;;
		4-10m) seq1=$home/sequences/4-10M/NC_014318.1.fasta
			  seq2=$home/sequences/4-10M/NC_017186.1.fasta ;;
		5-23m) seq1=$home/sequences/5-23M/NT_033779.4.fasta
			  seq2=$home/sequences/5-23M/NT_037436.3.fasta ;;
        6-47m) seq1=$home/sequences/6-47M/BA000046.3.fasta
              seq2=$home/sequences/6-47M/NC_000021.7.fasta ;;
        chr17) seq1=$home/sequences/chr17/NC_000017.11.fasta
              seq2=$home/sequences/chr17/NC_006484.4.fasta  ;;
        chr21) seq1=$home/sequences/chr21/NC_000021.9.fasta
              seq2=$home/sequences/chr21/NC_006488.4.fasta  ;;
        chr22) seq1=$home/sequences/chr22/NC_000022.11.fasta
              seq2=$home/sequences/chr22/NC_006489.4.fasta ;;
	chrY)  seq2=$home/sequences/chrY/NC_000024.10.fasta
              seq1=$home/sequences/chrY/NC_006492.4.fasta ;;
*) echo "Error: Unknown comparison"; exit 1 ;;
esac

# Definição de pastas
workdir="./resultfiles/$1/${split}GPU/$TIMESTAMP/$sol.result_$1_${split}GPU.$MYNODEID.$TIMESTAMP" 
shareddir="./resultfiles/$1/${split}GPU/$TIMESTAMP/$sol.result_$1_${split}GPU.$TIMESTAMP"

# Parâmetros de execução
PARAMS="--stage-1 --no-flush --blocks=512 --shared-dir=$shareddir --split=$split" 

nextport=$baseport

echo "baseport: $nextport" >> `hostname`.out.txt

touch "saida"
#echo "host: ".`hostname` >> "saida"
#echo "MyNodeID: ". $MYNODEID  >> "saida"

#falta calcular as portas anteriores e as próximas
#nextport=$baseport


if [ x$previp == x ]; then   # Se primeiro host
echo `hostname`."Iniciou o primeiro host 1: "  >> "saida"
    ./$sol/cudalign $PARAMS --work-dir=$workdir --part=1 --flush-column=socket://127.0.0.1:$baseport $seq1 $seq2 
	echo `hostname`."Iniciou o primeiro host "  >> "saida"
	echo `hostname`  >> "saida"
	echo "iniciou a execucao do primeiro host"
elif [ x$nextip == x ]; then # Se último host
	prevport=$((baseport+basepart-2))
	echo `hostname`."Iniciou o ultimo host "  >> "saida"
    ./$sol/cudalign $PARAMS --work-dir=$workdir --part=$basepart --load-column=socket://$previp:$prevport $seq1 $seq2

else  # Demais hosts
	echo `hostname`."Iniciou o host intermediario"  >> "saida"
   prevport=$((baseport+basepart-2))
   nextport=$((baseport+basepart-1))
   ./$sol/cudalign $PARAMS --work-dir=$workdir --part=$basepart --load-column=socket://$previp:$prevport --flush-column=socket://127.0.0.1:$nextport $seq1 $seq2 
fi

echo "prevport: $prevport" >> `hostname`.out.txt

if [ x$nextip == x ]; then # Se último host, copia arquivos resultado
   echo "$MYNODEID: Last node finished the execution. Slurm will now kill other tasks!"
   cp $workdir/status $home/results/status_${split}GPU_$1_s.txt
   cp $workdir/statistics $home/results/statistics_${split}GPU_$1_s.txt
else
   echo "$MYNODEID: Waiting the last node to finish the execution..."
fi
