#!/bin/bash

echo "========================================="
echo "ROS 2 Robotics - Clean Start"
echo "========================================="

# Configurações
SESSION_NAME="ros2_robotics"
WORKSPACE_DIR="/home/gus/robotica"
TMUX="tmux"

# Função SEGURA para limpar apenas processos ROS específicos
safe_cleanup() {
    echo "Limpando processos ROS anteriores..."

    # Lista ESPECÍFICA de comandos ROS que queremos matar
    # Não usamos pkill -f genérico para não matar o Distrobox!
    local ros_commands=(
        "ros2 launch robotics_class"
        "ros2 launch nav2_bringup"
        "ros2 run teleop_twist_keyboard"
        "rviz2"
        "gzserver"
        "gzclient"
    )

    echo "Procurando processos ROS para terminar..."

    # Método mais seguro: listar processos e matar apenas os específicos
    for cmd in "${ros_commands[@]}"; do
        # Encontrar PIDs dos processos específicos
        pids=$(ps aux | grep "$cmd" | grep -v grep | awk '{print $2}')

        if [ -n "$pids" ]; then
            echo "  Terminando: $cmd (PIDs: $pids)"
            # Matar gentilmente
            kill $pids 2>/dev/null
            sleep 0.5
            # Forçar se necessário
            kill -9 $pids 2>/dev/null 2>/dev/null
        fi
    done

    # Matar sessão Tmux ANTIGA (se existir)
    echo "Verificando sessão Tmux antiga..."
    if $TMUX has-session -t $SESSION_NAME 2>/dev/null; then
        echo "  Matando sessão Tmux anterior: $SESSION_NAME"
        $TMUX kill-session -t $SESSION_NAME 2>/dev/null
    fi

    echo "✓ Limpeza concluída"
    echo ""
}

# Executar limpeza SEGURA
safe_cleanup

# Build
echo "1. Build do workspace ROS 2..."
cd "$WORKSPACE_DIR" || {
    echo "ERRO: Workspace não encontrado em $WORKSPACE_DIR"
    echo "Criando diretório..."
    mkdir -p "$WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"
}
colcon build --symlink-install || {
    echo "ERRO: Build falhou!"
    exit 1
}
echo "✓ Build OK"
echo ""

# Source
echo "2. Configurando environment ROS..."
source "$WORKSPACE_DIR/install/local_setup.bash"

# Criar sessão Tmux
echo "3. Criando sessão Tmux '$SESSION_NAME'..."
echo ""

# Função auxiliar para criar janelas
create_tmux_window() {
    local idx=$1
    local name=$2
    local delay=$3
    local cmd=$4

    if [ $idx -eq 0 ]; then
        $TMUX new-session -d -s $SESSION_NAME -n "$name" \
            "echo 'Iniciando $name em $delay segundos...'; sleep $delay; $cmd; exec bash"
    else
        $TMUX new-window -t $SESSION_NAME:$idx -n "$name" \
            "echo 'Iniciando $name em $delay segundos...'; sleep $delay; $cmd; exec bash"
    fi
    echo "  [Janela $idx] $name ✔"
}

# Criar janelas com delays progressivos
create_tmux_window 0 "Robot_Desc" 0 "ros2 launch robotics_class robot_description.launch.py"
create_tmux_window 1 "Simulation" 2 "ros2 launch robotics_class simulation_world.launch.py"
create_tmux_window 2 "EKF" 4 "ros2 launch robotics_class ekf.launch.py"
create_tmux_window 3 "RViz" 6 "ros2 launch robotics_class rviz.launch.py rviz_config:=/home/gus/robotica/rviz_config.rviz"
create_tmux_window 4 "Teleop" 0 "ros2 run teleop_twist_keyboard teleop_twist_keyboard --ros-args --remap cmd_vel:=jetauto/cmd_vel"
# create_tmux_window 5 "Navigation" 10 "ros2 launch nav2_bringup navigation_launch.py use_sim_time:=true"
# create_tmux_window 6 "SLAM" 15 "ros2 launch robotics_class slam.launch.py"
create_tmux_window 5 "Localization" 18 "ros2 launch robotics_class localization.launch.py map:=$WORKSPACE_DIR/src/robotics_class/maps/class_map.yaml"
create_tmux_window 6 "Navigation" 20 "ros2 launch robotics_class navigation.launch.py params_file:=$WORKSPACE_DIR/src/robotics_class/params/nav2.yaml"


# Janela de monitoramento/controle
$TMUX new-window -t $SESSION_NAME:7 -n 'Control' \
    'clear;
     echo "╭────────────────────────────────────────────╮";
     echo "│        ROS 2 Robotics - Control Panel     │";
     echo "╰────────────────────────────────────────────╯";
     echo "";
     echo "📡 Nós ROS ativos:";
     echo "──────────────────────────────────────────────";
     ros2 node list 2>/dev/null || echo "   (Nenhum nó ativo ainda)";
     echo "";
     echo "🛠️  Comandos úteis:";
     echo "   ros2 topic list      # Listar tópicos";
     echo "   ros2 node info <nó>  # Info do nó";
     echo "   ros2 service list    # Listar serviços";
     echo "";
     echo "🎮 Controles Tmux:";
     echo "   Ctrl+b 0-7    # Navegar entre janelas";
     echo "   Ctrl+b d      # Desanexar (voltar ao terminal)";
     echo "   Ctrl+b [      # Modo scroll (Ctrl+C para sair)";
     echo "";
     echo "⚠️  Para sair completamente:";
     echo "   1. Ctrl+b d para desanexar do Tmux";
     echo "   2. ./stop_robotics.sh para limpar";
     echo "";
     exec bash'

echo ""
echo "4. Sessão criada com 8 janelas:"
echo "   [0] Robot Description"
echo "   [1] Simulation World"
echo "   [2] EKF Localization"
echo "   [3] RViz Visualization"
echo "   [4] Teleop Control"
echo "   [5] Navigation Stack"
echo "   [6] SLAM Mapping"
echo "   [7] Control Panel"
echo ""
echo "5. Conectando à sessão Tmux..."
sleep 2

# Anexar à sessão
$TMUX attach-session -t $SESSION_NAME
