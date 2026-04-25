#!/bin/bash

# =================================================================
# 1. ATUALIZANDO O SISTEMA
# Este comando abaixo vai buscar as ultimas atualizacoes do Fedora 
# e instalar automaticamente sem pedir confirmacao (gracas ao -y).
# =================================================================
sudo dnf upgrade -y

echo "Atualizacao concluida com sucesso!"